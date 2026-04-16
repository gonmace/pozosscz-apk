/// Claves de almacenamiento persistente (FlutterSecureStorage y FlutterForegroundTask).
/// Fuente única de verdad para evitar duplicación entre repositorios y servicios.
class StorageConstantes {
  // Auth
  static const String authToken = 'auth_token';
  static const String userId = 'user_id';
  static const String username = 'username';
  static const String rol = 'rol';
  static const String contrasena = 'contrasena';

  // FCM
  static const String fcmUltimoEnvio = 'fcm_ultimo_envio';

  // Configuración de tracking (persistida en foreground task storage)
  static const String trackingActivo = 'tracking_activo';
  static const String intervaloTracking = 'intervalo_seg';

  // Estado del camión (foreground task + FCM handler)
  static const String nivelTanque = 'nivel_tanque';
  static const String diesel = 'diesel';
  static const String fechaDiesel = 'fecha_diesel';
  static const String ultimaVelocidad = 'ultima_velocidad';
  static const String ultimaDireccion = 'ultima_direccion';
}
