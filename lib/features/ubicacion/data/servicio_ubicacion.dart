import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/constantes/api_constantes.dart';
import '../../../core/constantes/storage_constantes.dart';

class ConfigTracking {
  final bool activo;
  final int intervaloSeg;
  const ConfigTracking({required this.activo, required this.intervaloSeg});
}

// Callback que se ejecuta en el isolate del foreground service
@pragma('vm:entry-point')
void callbackForegroundTask() {
  FlutterForegroundTask.setTaskHandler(_UbicacionTaskHandler());
}

class _UbicacionTaskHandler extends TaskHandler {
  final Dio _dio = Dio();

  StreamSubscription<Position>? _gpsSub;
  Position? _ultimaPosicion;
  Position? _penultimaPosicion; // para calcular bearing manualmente

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    debugPrint('[UbicacionTask] Iniciado');
    _gpsSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // actualiza cada 5 m de movimiento
      ),
    ).listen(
      (pos) {
        _penultimaPosicion = _ultimaPosicion;
        _ultimaPosicion = pos;
      },
      onError: (_) {},
      cancelOnError: false,
    );
  }

  /// Calcula la dirección de desplazamiento entre las últimas dos posiciones.
  /// Fallback: lee el último valor guardado en storage.
  /// Android no popula `heading` en capturas puntuales ni siempre en el stream;
  /// el bearing entre dos coordenadas es el método más confiable.
  Future<double> _calcularDireccion(Position posicion) async {
    // 1. Bearing entre penúltima y última posición del stream (más confiable)
    if (_penultimaPosicion != null) {
      final dist = Geolocator.distanceBetween(
        _penultimaPosicion!.latitude, _penultimaPosicion!.longitude,
        posicion.latitude, posicion.longitude,
      );
      if (dist >= 2) {
        double bearing = Geolocator.bearingBetween(
          _penultimaPosicion!.latitude, _penultimaPosicion!.longitude,
          posicion.latitude, posicion.longitude,
        );
        if (bearing < 0) bearing += 360; // normalizar a 0–360
        return bearing;
      }
    }

    // 2. heading del GPS si lo reportó (raro en Android, pero por si acaso)
    if (posicion.heading > 0) return posicion.heading;

    // 3. Último valor guardado en storage (evita enviar 0 cuando está quieto)
    return await FlutterForegroundTask.getData<double>(
            key: StorageConstantes.ultimaDireccion) ??
        0.0;
  }

  @override
  void onRepeatEvent(DateTime timestamp) async {
    final token = await FlutterForegroundTask.getData<String>(key: 'token');
    if (token == null) return;

    // Verificar si el admin desactivó el tracking
    final config = await ServicioUbicacion.obtenerConfig(token: token);
    if (!config.activo) {
      debugPrint('[UbicacionTask] Tracking desactivado por admin — deteniendo servicio');
      await FlutterForegroundTask.stopService();
      return;
    }

    try {
      final posicion = _ultimaPosicion ??
          await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
            ),
          );

      final velocidad = posicion.speed >= 0 ? posicion.speed * 3.6 : 0.0;
      final direccion = await _calcularDireccion(posicion);

      await _dio.post(
        '${ApiConstantes.urlBase}${ApiConstantes.urlUbicacion}',
        data: {
          'lat': posicion.latitude,
          'lon': posicion.longitude,
          'velocidad': velocidad.toStringAsFixed(1),
          'direccion': direccion.toStringAsFixed(1),
          'timestamp': DateTime.now().toIso8601String(),
        },
        options: Options(headers: {'Authorization': 'Token $token'}),
      );

      // Persistir para enviarEstadoAhora (que no tiene el stream)
      await FlutterForegroundTask.saveData(
          key: StorageConstantes.ultimaVelocidad, value: velocidad);
      await FlutterForegroundTask.saveData(
          key: StorageConstantes.ultimaDireccion, value: direccion);

      final velKmh = velocidad.round();
      FlutterForegroundTask.updateService(
        notificationText:
            '${posicion.latitude.toStringAsFixed(4)}, ${posicion.longitude.toStringAsFixed(4)} — $velKmh km/h',
      );
    } catch (e) {
      debugPrint('[UbicacionTask] Error: $e');
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    await _gpsSub?.cancel();
    debugPrint('[UbicacionTask] Detenido');
  }
}

class ServicioUbicacion {
  static void inicializar() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'pozosscz_ubicacion',
        channelName: 'Ubicacion Chofer',
        channelDescription: 'Pozos SCZ esta enviando tu ubicacion',
        channelImportance: NotificationChannelImportance.NONE,
        priority: NotificationPriority.MIN,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(30000), // cada 30s
        autoRunOnBoot: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  /// Obtiene la configuración de tracking desde el servidor.
  /// Si no hay conexión, usa los valores guardados en storage como fallback.
  static Future<ConfigTracking> obtenerConfig({required String token}) async {
    try {
      final dio = Dio();
      final resp = await dio.get(
        '${ApiConstantes.urlBase}${ApiConstantes.urlConfigTracking}',
        options: Options(headers: {'Authorization': 'Token $token'}),
      );
      final activo = resp.data['tracking_activo'] as bool? ?? true;
      final intervalo = (resp.data['intervalo_tracking'] as int?) ?? 30;
      // Persistir la config recibida del servidor
      await FlutterForegroundTask.saveData(key: StorageConstantes.trackingActivo, value: activo);
      await FlutterForegroundTask.saveData(key: StorageConstantes.intervaloTracking, value: intervalo);
      return ConfigTracking(activo: activo, intervaloSeg: intervalo);
    } catch (_) {
      // Sin conexión — usar config guardada en storage
      final activo = await FlutterForegroundTask.getData<bool>(key: StorageConstantes.trackingActivo) ?? true;
      final intervalo = await FlutterForegroundTask.getData<int>(key: StorageConstantes.intervaloTracking) ?? 30;
      return ConfigTracking(activo: activo, intervaloSeg: intervalo);
    }
  }

  static Future<bool> iniciarTracking({required String token}) async {
    final config = await obtenerConfig(token: token);

    if (!config.activo) {
      debugPrint('[Tracking] Desactivado por el administrador');
      return false;
    }

    await FlutterForegroundTask.saveData(key: 'token', value: token);

    // Reinicializar con el intervalo configurado
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'pozosscz_ubicacion',
        channelName: 'Ubicacion Chofer',
        channelDescription: 'Pozos SCZ esta enviando tu ubicacion',
        channelImportance: NotificationChannelImportance.NONE,
        priority: NotificationPriority.MIN,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(config.intervaloSeg * 1000),
        autoRunOnBoot: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );

    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
      await Future.delayed(const Duration(milliseconds: 500));
    }
    await FlutterForegroundTask.startService(
      notificationTitle: 'Pozos SCZ — Activo',
      notificationText: 'Enviando ubicacion...',
      callback: callbackForegroundTask,
    );
    return true;
  }

  static Future<void> detenerTracking() async {
    await FlutterForegroundTask.stopService();
  }

  /// Envía un estado puntual al backend (sin esperar el ciclo del foreground task).
  /// Útil para reportar cambios de nivel de tanque, diesel o comentario en el momento.
  static Future<void> enviarEstadoAhora({
    required String token,
    String comentario = '',
    bool activo = true,
  }) async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );

      final ultimaDireccion = await FlutterForegroundTask.getData<double>(
              key: StorageConstantes.ultimaDireccion) ??
          0.0;
      final ultimaVelocidad = await FlutterForegroundTask.getData<double>(
              key: StorageConstantes.ultimaVelocidad) ??
          0.0;

      final dio = Dio();
      await dio.post(
        '${ApiConstantes.urlBase}${ApiConstantes.urlUbicacion}',
        data: {
          'lat': pos.latitude,
          'lon': pos.longitude,
          'velocidad': ultimaVelocidad.toStringAsFixed(1),
          'direccion': ultimaDireccion.toStringAsFixed(1),
          'comentario': comentario,
          'activo': activo,
          'timestamp': DateTime.now().toIso8601String(),
        },
        options: Options(headers: {'Authorization': 'Token $token'}),
      );
      debugPrint('[enviarEstadoAhora] activo=$activo comentario=$comentario');
    } catch (e) {
      debugPrint('[enviarEstadoAhora] Error: $e');
    }
  }

  /// Envía un evento discreto al backend (cambio de tanque, diesel, etc.).
  static Future<void> reportarEvento({
    required String token,
    required String tipo,
    double? nivelTanque,
    int? monto,
    String motivo = '',
    String comentario = '',
  }) async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      final dio = Dio();
      await dio.post(
        '${ApiConstantes.urlBase}${ApiConstantes.urlEvento}',
        data: {
          'tipo': tipo,
          'lat': pos.latitude,
          'lon': pos.longitude,
          if (nivelTanque != null) 'nivel_tanque': double.parse(nivelTanque.toStringAsFixed(2)),
          if (monto != null) 'monto': monto,
          if (motivo.isNotEmpty) 'motivo_cancelacion': motivo,
          if (comentario.isNotEmpty) 'comentario': comentario,
        },
        options: Options(headers: {'Authorization': 'Token $token'}),
      );
      debugPrint('[reportarEvento] tipo=$tipo nivel=$nivelTanque');
    } catch (e) {
      debugPrint('[reportarEvento] Error: $e');
    }
  }

  /// Informa al backend que el chofer activó o desactivó el tracking.
  static Future<void> reportarConfigTracking({
    required String token,
    required bool activo,
  }) async {
    try {
      final dio = Dio();
      await dio.post(
        '${ApiConstantes.urlBase}${ApiConstantes.urlConfigTracking}',
        data: {'tracking_activo': activo},
        options: Options(headers: {'Authorization': 'Token $token'}),
      );
      debugPrint('[reportarConfigTracking] activo=$activo');
    } catch (e) {
      debugPrint('[reportarConfigTracking] Error: $e');
    }
  }

  /// Aplica una configuración recibida por FCM sin hacer llamada al servidor.
  static Future<void> aplicarConfigDirecta({
    required bool activo,
    required int intervaloSeg,
    required String token,
  }) async {
    // Persistir config recibida por FCM (fuente de verdad para reinicios sin red)
    await FlutterForegroundTask.saveData(key: StorageConstantes.trackingActivo, value: activo);
    await FlutterForegroundTask.saveData(key: StorageConstantes.intervaloTracking, value: intervaloSeg);

    if (!activo) {
      debugPrint('[Tracking] Desactivado por push — deteniendo servicio');
      await FlutterForegroundTask.stopService();
      return;
    }

    // Evitar reinicio innecesario si el intervalo no cambió
    final corriendo = await FlutterForegroundTask.isRunningService;
    final intervaloActual = await FlutterForegroundTask.getData<int>(key: StorageConstantes.intervaloTracking);
    if (corriendo && intervaloActual == intervaloSeg) {
      debugPrint('[Tracking] Intervalo sin cambios ($intervaloSeg s) — sin reinicio');
      return;
    }

    await FlutterForegroundTask.saveData(key: 'token', value: token);

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'pozosscz_ubicacion',
        channelName: 'Ubicacion Chofer',
        channelDescription: 'Pozos SCZ esta enviando tu ubicacion',
        channelImportance: NotificationChannelImportance.NONE,
        priority: NotificationPriority.MIN,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(intervaloSeg * 1000),
        autoRunOnBoot: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );

    debugPrint('[Tracking] Aplicando nuevo intervalo: ${intervaloSeg}s');
    if (corriendo) {
      await FlutterForegroundTask.stopService();
      await Future.delayed(const Duration(milliseconds: 1000));
    }
    await FlutterForegroundTask.startService(
      notificationTitle: 'Pozos SCZ — Activo',
      notificationText: 'Enviando ubicacion...',
      callback: callbackForegroundTask,
    );
  }
}
