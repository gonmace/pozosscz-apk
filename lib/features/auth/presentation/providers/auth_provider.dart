import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/servicios/servicio_fcm.dart';
import '../../../inicio/presentation/providers/inicio_provider.dart';
import '../../data/modelo_usuario.dart';
import '../../data/repositorio_auth.dart';

class EstadoAuth {
  final ModeloUsuario? usuario;
  final bool cargando;
  final String? error;

  const EstadoAuth({
    this.usuario,
    this.cargando = false,
    this.error,
  });

  EstadoAuth copiarCon({
    ModeloUsuario? usuario,
    bool? cargando,
    String? error,
    bool limpiarUsuario = false,
    bool limpiarError = false,
  }) {
    return EstadoAuth(
      usuario: limpiarUsuario ? null : usuario ?? this.usuario,
      cargando: cargando ?? this.cargando,
      error: limpiarError ? null : error ?? this.error,
    );
  }
}

class AuthNotifier extends AsyncNotifier<EstadoAuth> {
  @override
  Future<EstadoAuth> build() async {
    final repositorio = ref.read(repositorioAuthProvider);
    final usuario = await repositorio.obtenerUsuarioGuardado();
    // Actualizar token FCM en el backend cada vez que el app arranca con sesión activa.
    // Sin esto, el token en la DB queda obsoleto y las solicitudes de ubicación
    // se envían a un token viejo que Firebase acepta pero el dispositivo ignora.
    if (usuario != null && usuario.token.isNotEmpty) {
      ServicioFCM.registrarDispositivo(authToken: usuario.token);
    }
    return EstadoAuth(usuario: usuario);
  }

  Future<void> iniciarSesion({
    required String nombreUsuario,
    required String contrasena,
  }) async {
    final estadoActual = state.valueOrNull ?? const EstadoAuth();
    state = AsyncData(estadoActual.copiarCon(cargando: true, limpiarError: true));
    try {
      final repositorio = ref.read(repositorioAuthProvider);
      final usuario = await repositorio.iniciarSesion(
        nombreUsuario: nombreUsuario,
        contrasena: contrasena,
      );
      state = AsyncData(EstadoAuth(usuario: usuario));
      // Registrar token FCM en el backend para recibir solicitudes de ubicación
      if (usuario.token.isNotEmpty) {
        debugPrint('[AUTH] Login OK — registrando dispositivo FCM...');
        await ServicioFCM.registrarDispositivo(authToken: usuario.token);
      }
    } catch (e) {
      state = AsyncData(
        EstadoAuth(
          cargando: false,
          error: _mensajeError(e),
        ),
      );
    }
  }

  Future<void> cerrarSesion() async {
    final repositorio = ref.read(repositorioAuthProvider);
    await repositorio.cerrarSesion();
    // Limpiar datos en caché del usuario anterior
    ref.invalidate(proyectosProvider);
    ref.invalidate(estadosLocalesProvider);
    state = const AsyncData(EstadoAuth());
  }

  String _mensajeError(Object e) {
    return 'Usuario o contraseña incorrectos';
  }
}

final authProvider = AsyncNotifierProvider<AuthNotifier, EstadoAuth>(
  AuthNotifier.new,
);
