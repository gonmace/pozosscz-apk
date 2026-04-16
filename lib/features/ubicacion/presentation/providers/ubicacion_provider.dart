import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../core/constantes/storage_constantes.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../inicio/presentation/providers/inicio_provider.dart';
import '../../data/servicio_ubicacion.dart';

const _storage = FlutterSecureStorage();

class Coordenadas {
  final double latitude;
  final double longitude;

  const Coordenadas({required this.latitude, required this.longitude});
}

class EstadoUbicacion {
  final bool activo;
  final Coordenadas? ultimaUbicacion;

  const EstadoUbicacion({
    this.activo = false,
    this.ultimaUbicacion,
  });

  EstadoUbicacion copiarCon({bool? activo, Coordenadas? ultimaUbicacion}) {
    return EstadoUbicacion(
      activo: activo ?? this.activo,
      ultimaUbicacion: ultimaUbicacion ?? this.ultimaUbicacion,
    );
  }
}

class UbicacionNotifier extends Notifier<EstadoUbicacion> {
  @override
  EstadoUbicacion build() {
    ServicioUbicacion.inicializar();
    Future.microtask(_hidratarDesdeStorage);

    // Al cerrar sesión, marcar el camión como inactivo automáticamente.
    ref.listen(authProvider, (anterior, siguiente) {
      final habiaSesion = anterior?.valueOrNull?.usuario != null;
      final hayUsuario = siguiente.valueOrNull?.usuario != null;
      if (habiaSesion && !hayUsuario) {
        desactivar();
      }
    });

    return const EstadoUbicacion();
  }

  /// Carga nivel de tanque, diesel y fecha diesel desde storage al iniciar la app.
  Future<void> _hidratarDesdeStorage() async {
    final nivelStr = await _storage.read(key: StorageConstantes.nivelTanque);
    final dieselStr = await _storage.read(key: StorageConstantes.diesel);
    final fechaStr = await _storage.read(key: StorageConstantes.fechaDiesel);

    final nivel = double.tryParse(nivelStr ?? '');
    final diesel = int.tryParse(dieselStr ?? '');
    final fecha = fechaStr != null ? DateTime.tryParse(fechaStr) : null;

    if (nivel != null) ref.read(nivelTanqueProvider.notifier).state = nivel;
    if (diesel != null) ref.read(dieselProvider.notifier).state = diesel;
    if (fecha != null) ref.read(fechaDieselProvider.notifier).state = fecha;
  }

  Future<void> activar() async {
    final usuario = ref.read(authProvider).valueOrNull?.usuario;
    if (usuario == null) return;

    LocationPermission permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
      if (permiso == LocationPermission.denied) return;
    }
    if (permiso == LocationPermission.deniedForever) return;

    // Persistir estado del camión antes de iniciar el servicio para que el
    // foreground task los tenga disponibles desde el primer ciclo.
    await _persistirEstadoCamion();

    await ServicioUbicacion.iniciarTracking(token: usuario.token);
    state = state.copiarCon(activo: true);

    // Registrar evento de activación con nivel de tanque actual
    await ServicioUbicacion.reportarEvento(
      token: usuario.token,
      tipo: 'TRK_ACT',
      nivelTanque: ref.read(nivelTanqueProvider),
    );

    // Enviar ubicación inmediatamente al activar para que el mapa se actualice
    // sin esperar el primer ciclo del foreground task.
    await enviarEstado(activo: true);

    try {
      final pos = await Geolocator.getCurrentPosition();
      state = state.copiarCon(
        ultimaUbicacion: Coordenadas(
          latitude: pos.latitude,
          longitude: pos.longitude,
        ),
      );
    } catch (_) {}
  }

  Future<void> desactivar() async {
    final token = ref.read(authProvider).valueOrNull?.usuario?.token;
    await enviarEstado(activo: false);
    if (token != null) {
      await ServicioUbicacion.reportarEvento(
        token: token,
        tipo: 'TRK_DES',
        nivelTanque: ref.read(nivelTanqueProvider),
      );
    }
    await ServicioUbicacion.detenerTracking();
    state = state.copiarCon(activo: false);
  }

  /// Persiste nivel de tanque para el foreground task y el FCM handler.
  Future<void> guardarNivelTanque(double nivel) async {
    await FlutterForegroundTask.saveData(
        key: StorageConstantes.nivelTanque, value: nivel);
    await _storage.write(
        key: StorageConstantes.nivelTanque, value: nivel.toString());
  }

  /// Persiste diesel (y fecha del cargado) para el foreground task y el FCM handler.
  Future<void> guardarDiesel(int? diesel) async {
    final valor = diesel ?? 0;
    await FlutterForegroundTask.saveData(
        key: StorageConstantes.diesel, value: valor);
    await _storage.write(
        key: StorageConstantes.diesel, value: valor.toString());
    // Persistir la fecha para rehidratarla al reiniciar la app.
    if (diesel != null) {
      await _storage.write(
          key: StorageConstantes.fechaDiesel,
          value: DateTime.now().toIso8601String());
    } else {
      await _storage.delete(key: StorageConstantes.fechaDiesel);
    }
  }

  /// Envía un estado puntual al backend (comentario, activo).
  Future<void> enviarEstado({
    String comentario = '',
    bool activo = true,
  }) async {
    final token = ref.read(authProvider).valueOrNull?.usuario?.token;
    if (token == null) return;
    await ServicioUbicacion.enviarEstadoAhora(
      token: token,
      comentario: comentario,
      activo: activo,
    );
  }

  /// Reporta un cambio de nivel de tanque como EventoCamion.
  Future<void> reportarCambioTanque(double nivel, {String comentario = ''}) async {
    final token = ref.read(authProvider).valueOrNull?.usuario?.token;
    if (token == null) return;
    final String tipo;
    if (nivel == 0.0) {
      tipo = 'TKQ_VAC';
    } else if (nivel >= 1.0) {
      tipo = 'TKQ_LLE';
    } else {
      tipo = 'TKQ_UPD';
    }
    await ServicioUbicacion.reportarEvento(
      token: token,
      tipo: tipo,
      nivelTanque: nivel,
      comentario: comentario,
    );
  }

  /// Reporta una carga de diesel como EventoCamion (DSL_CAR).
  /// El monto se guarda negativo para indicar egreso de dinero.
  Future<void> reportarCargaDiesel(int diesel) async {
    final token = ref.read(authProvider).valueOrNull?.usuario?.token;
    if (token == null) return;
    await ServicioUbicacion.reportarEvento(
      token: token,
      tipo: 'DSL_CAR',
      monto: -diesel.abs(),
      nivelTanque: ref.read(nivelTanqueProvider),
    );
  }

  Future<void> _persistirEstadoCamion() async {
    // Escribe los valores actuales en ambos storages para garantizar que el
    // foreground task los tenga desde el ciclo 0, aunque el usuario no haya
    // interactuado con los controles de tanque/diesel en esta sesión.
    await guardarNivelTanque(ref.read(nivelTanqueProvider));
    await guardarDiesel(ref.read(dieselProvider));
  }
}

final ubicacionProvider =
    NotifierProvider<UbicacionNotifier, EstadoUbicacion>(
  UbicacionNotifier.new,
);
