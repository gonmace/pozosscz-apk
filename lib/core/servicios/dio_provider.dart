import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constantes/api_constantes.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';

/// Instancia de Dio compartida para el isolate principal.
/// Incluye baseUrl, timeouts y un interceptor que inyecta el token de auth.
///
/// NO usar en foreground task ni en handlers FCM (corren en isolates separados
/// donde los providers de Riverpod no están disponibles).
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConstantes.urlBase,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final usuario = ref.read(authProvider).valueOrNull?.usuario;
        if (usuario != null) {
          options.headers['Authorization'] = 'Token ${usuario.token}';
        }
        handler.next(options);
      },
    ),
  );

  return dio;
});
