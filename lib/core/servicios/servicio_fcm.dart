import 'dart:async';

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';

import '../constantes/api_constantes.dart';
import '../constantes/storage_constantes.dart';
import '../../features/ubicacion/data/servicio_ubicacion.dart';

// Canal de notificaciones locales para asignaciones de clientes
const _canalId = 'pozosscz_asignaciones';
const _canalNombre = 'Asignaciones';
const _detallesAndroid = AndroidNotificationDetails(
  _canalId,
  _canalNombre,
  importance: Importance.max,
  priority: Priority.max,
  playSound: true,
  enableVibration: true,
);
const _detalles = NotificationDetails(android: _detallesAndroid);
final _notificacionesLocales = FlutterLocalNotificationsPlugin();

// Stream para notificar a Riverpod que debe refrescar la lista de proyectos.
// Solo accesible desde el isolate principal (foreground); los mensajes background
// se ignoran aquí — el refresh ocurre cuando la app vuelve a primer plano.
final _streamProyectos = StreamController<void>.broadcast();
Stream<void> get streamActualizarProyectos => _streamProyectos.stream;

const _storage = FlutterSecureStorage();

// Handler de mensajes FCM en background — corre en isolate separado.
// Debe ser top-level y estar registrado en main() antes de runApp().
@pragma('vm:entry-point')
Future<void> onBackgroundMessage(RemoteMessage mensaje) async {
  await Firebase.initializeApp();
  final tipo = mensaje.data['tipo'];
  if (tipo == 'solicitar_ubicacion') {
    final token = await _storage.read(key: StorageConstantes.authToken) ?? '';
    await _enviarUbicacion(token: token);
  } else if (tipo == 'actualizar_config') {
    await _aplicarConfig(mensaje.data);
  }
  // asignacion_cliente: la notificación FCM ya muestra sonido+vibración via sistema
}

Future<void> _aplicarConfig(Map<String, dynamic> data) async {
  final activo = data['tracking_activo'] == 'true';
  final intervalo = int.tryParse(data['intervalo_tracking'] ?? '30') ?? 30;
  debugPrint('[FCM] Config recibida: activo=$activo, intervalo=${intervalo}s');

  final token = await _storage.read(key: StorageConstantes.authToken) ?? '';
  await ServicioUbicacion.aplicarConfigDirecta(
    activo: activo,
    intervaloSeg: intervalo,
    token: token,
  );
}

// Deduplicación cross-isolate usando FlutterSecureStorage (almacenamiento nativo compartido).
Future<bool> _yaEnviadoRecientemente() async {
  final ultimoStr = await _storage.read(key: StorageConstantes.fcmUltimoEnvio);
  if (ultimoStr == null) return false;
  final ultimo = DateTime.tryParse(ultimoStr);
  if (ultimo == null) return false;
  return DateTime.now().difference(ultimo).inSeconds < 5;
}

Future<void> _enviarUbicacion({required String token}) async {
  if (await _yaEnviadoRecientemente()) {
    debugPrint('[FCM] Envío duplicado ignorado (cross-isolate)');
    return;
  }
  await _storage.write(
    key: StorageConstantes.fcmUltimoEnvio,
    value: DateTime.now().toIso8601String(),
  );

  try {
    if (token.isEmpty) {
      debugPrint('[FCM] Sin token de auth, no se puede enviar ubicación');
      return;
    }
    final posicion = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    final nivelTanqueStr = await _storage.read(key: StorageConstantes.nivelTanque) ?? '0.0';
    final dieselStr = await _storage.read(key: StorageConstantes.diesel) ?? '0';

    // getCurrentPosition devuelve speed=0 y heading=0 porque son valores
    // calculados a partir de actualizaciones sucesivas del GPS. Usar los
    // últimos valores reales guardados por el foreground task como fallback.
    final velocidadGps = posicion.speed * 3.6;
    final direccionGps = posicion.heading;
    final velocidadCached = await FlutterForegroundTask.getData<double>(
        key: StorageConstantes.ultimaVelocidad) ?? 0.0;
    final direccionCached = await FlutterForegroundTask.getData<double>(
        key: StorageConstantes.ultimaDireccion) ?? 0.0;
    final velocidad = velocidadGps > 0 ? velocidadGps : velocidadCached;
    final direccion = direccionGps != 0 ? direccionGps : direccionCached;

    final dio = Dio();
    await dio.post(
      '${ApiConstantes.urlBase}${ApiConstantes.urlUbicacion}',
      data: {
        'lat': posicion.latitude,
        'lon': posicion.longitude,
        'velocidad': velocidad.toStringAsFixed(1),
        'direccion': direccion.toStringAsFixed(1),
        'nivel_tanque': double.tryParse(nivelTanqueStr) ?? 0.0,
        'diesel': int.tryParse(dieselStr) ?? 0,
        'timestamp': DateTime.now().toIso8601String(),
      },
      options: Options(headers: {'Authorization': 'Token $token'}),
    );
    debugPrint('[FCM] Ubicación enviada: ${posicion.latitude}, ${posicion.longitude}');
  } catch (e) {
    debugPrint('[FCM] Error enviando ubicación: $e');
  }
}

class ServicioFCM {
  static final _messaging = FirebaseMessaging.instance;
  static String? _tokenGuardado;
  static bool _inicializado = false;

  static Future<void> inicializar() async {
    if (_inicializado) return;
    _inicializado = true;

    await _messaging.requestPermission(alert: true, badge: true, sound: true);
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: true,
      sound: false,
    );

    // Inicializar flutter_local_notifications
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _notificacionesLocales.initialize(
      const InitializationSettings(android: androidSettings),
    );
    await _notificacionesLocales
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          _canalId,
          _canalNombre,
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        ));

    FirebaseMessaging.onMessage.listen((mensaje) async {
      debugPrint('[FCM] Mensaje en foreground: ${mensaje.data}');
      final tipo = mensaje.data['tipo'];
      if (tipo == 'solicitar_ubicacion') {
        final token = _tokenGuardado ?? await _storage.read(key: StorageConstantes.authToken) ?? '';
        await _enviarUbicacion(token: token);
      } else if (tipo == 'actualizar_config') {
        await _aplicarConfig(mensaje.data);
      } else if (tipo == 'actualizar_proyectos') {
        _streamProyectos.add(null);
      } else if (tipo == 'asignacion_cliente') {
        // Mostrar notificación local visible + vibración + refresco
        final titulo = mensaje.notification?.title ?? '🚛 Servicio asignado';
        final cuerpo = mensaje.notification?.body ?? 'Nuevo servicio programado';
        await _notificacionesLocales.show(
          mensaje.hashCode,
          titulo,
          cuerpo,
          _detalles,
        );
        HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 300));
        HapticFeedback.heavyImpact();
        _streamProyectos.add(null);
      }
    });

    _messaging.onTokenRefresh.listen((nuevoToken) {
      debugPrint('[FCM] Token renovado: $nuevoToken');
      if (_tokenGuardado != null) {
        registrarDispositivo(authToken: _tokenGuardado!);
      }
    });
  }

  static Future<void> registrarDispositivo({required String authToken}) async {
    _tokenGuardado = authToken;
    debugPrint('[FCM] Iniciando registro de dispositivo...');
    try {
      final fcmToken = await _messaging.getToken();
      if (fcmToken == null) {
        debugPrint('[FCM] ⚠️  getToken() devolvió null');
        return;
      }
      debugPrint('[FCM] Token FCM obtenido: ${fcmToken.substring(0, 20)}...');

      final url = '${ApiConstantes.urlBase}/api/v1/dispositivo/registrar/';
      final dio = Dio();
      final respuesta = await dio.post(
        url,
        data: {'fcm_token': fcmToken},
        options: Options(headers: {'Authorization': 'Token $authToken'}),
      );
      debugPrint('[FCM] ✅ Dispositivo registrado. Status: ${respuesta.statusCode}');
    } on DioException catch (e) {
      debugPrint('[FCM] ❌ Error de red: ${e.type} — ${e.message}');
      debugPrint('[FCM]    Response: ${e.response?.data}');
    } catch (e) {
      debugPrint('[FCM] ❌ Error inesperado: $e');
    }
  }
}
