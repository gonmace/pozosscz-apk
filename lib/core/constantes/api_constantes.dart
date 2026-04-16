class ApiConstantes {
  // Se inyecta en tiempo de compilacion con --dart-define=API_URL=...
  // Default: produccion
  static const String urlBase = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://pozosscz.com',
  );

  static const String urlToken = '/api/v1/auth/token/';
  static const String urlProyectos = '/api/v1/clientes/programados/';
  static const String urlUbicacion = '/api/v1/ubicacion/camion/';
  static const String urlCamiones = '/api/v1/camiones/';
  static const String urlConfigTracking = '/api/v1/camiones/config/';
  static const String urlEvento = '/api/v1/moviles/evento/';
}
