import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../core/constantes/api_constantes.dart';
import '../../../../core/servicios/dio_provider.dart';
import '../../../../core/servicios/servicio_fcm.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/modelo_proyecto.dart';

export '../../data/modelo_proyecto.dart';

// Resultado del proveedor de posicion con causa en caso de fallo
enum EstadoGps {
  verificando,
  sinSenal,
  ok,
  servicioApagado,
  permisoDenegado,
  permisoPermanente,
}

class ResultadoPosicion {
  final Position? posicion;
  final EstadoGps estado;

  const ResultadoPosicion({this.posicion, required this.estado});
}

final posicionProvider = StreamProvider<ResultadoPosicion>((ref) {
  final controller = StreamController<ResultadoPosicion>();

  StreamSubscription<Position>? gpsSub;

  ref.onDispose(() {
    gpsSub?.cancel();
    controller.close();
  });

  _iniciarGps(controller, onSuscripcion: (sub) => gpsSub = sub);

  return controller.stream;
});

Future<void> _iniciarGps(
  StreamController<ResultadoPosicion> controller, {
  required void Function(StreamSubscription<Position>) onSuscripcion,
}) async {
  controller.add(const ResultadoPosicion(estado: EstadoGps.verificando));

  try {
    final servicioActivo = await Geolocator.isLocationServiceEnabled()
        .timeout(const Duration(seconds: 5), onTimeout: () => true);

    if (controller.isClosed) return;

    if (!servicioActivo) {
      controller.add(const ResultadoPosicion(estado: EstadoGps.servicioApagado));
      return;
    }

    var permiso = await Geolocator.checkPermission()
        .timeout(const Duration(seconds: 5), onTimeout: () => LocationPermission.whileInUse);

    if (controller.isClosed) return;

    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission()
          .timeout(const Duration(seconds: 30), onTimeout: () => LocationPermission.denied);
    }

    if (controller.isClosed) return;

    if (permiso == LocationPermission.deniedForever) {
      controller.add(const ResultadoPosicion(estado: EstadoGps.permisoPermanente));
      return;
    }
    if (permiso == LocationPermission.denied) {
      controller.add(const ResultadoPosicion(estado: EstadoGps.permisoDenegado));
      return;
    }

    controller.add(const ResultadoPosicion(estado: EstadoGps.sinSenal));

    final sub = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: kDebugMode ? 0 : 20,
      ),
    ).listen(
      (pos) {
        if (!controller.isClosed) {
          controller.add(ResultadoPosicion(posicion: pos, estado: EstadoGps.ok));
        }
      },
      onError: (_) {},
      cancelOnError: false,
    );
    onSuscripcion(sub);
  } catch (_) {
    if (!controller.isClosed) {
      controller.add(const ResultadoPosicion(estado: EstadoGps.sinSenal));
    }
  }
}

// Se refresca al recibir FCM tipo 'actualizar_proyectos' o al volver de background.
final proyectosProvider = FutureProvider<List<ModeloProyecto>>((ref) async {
  // Escuchar actualizaciones push (foreground)
  final sub = streamActualizarProyectos.listen((_) => ref.invalidateSelf());
  ref.onDispose(sub.cancel);

  final token = ref.read(authProvider).valueOrNull?.usuario?.token;
  if (token == null) return [];

  final dio = ref.read(dioProvider);
  final respuesta = await dio.get(ApiConstantes.urlProyectos);

  final lista = (respuesta.data as List).cast<Map<String, dynamic>>();
  return lista
      .map((json) => ModeloProyecto.desdeJson(json))
      .where((p) => p.status != 'COT')
      .toList();
});

// Overrides locales de status: { id: 'EJE' | 'CAN' }
final estadosLocalesProvider = StateProvider<Map<int, String>>((ref) => {});

// Estado del camión — persiste en storage vía UbicacionNotifier
final nivelTanqueProvider = StateProvider<double>((ref) => 0.0);
final dieselProvider = StateProvider<int?>((ref) => null);
final fechaDieselProvider = StateProvider<DateTime?>((ref) => null);
