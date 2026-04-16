import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/constantes/api_constantes.dart';
import '../../../core/constantes/storage_constantes.dart';
import 'modelo_usuario.dart';

class RepositorioAuth {
  final Dio _dio;
  final FlutterSecureStorage _almacenamiento;

  RepositorioAuth({
    required Dio dio,
    required FlutterSecureStorage almacenamiento,
  })  : _dio = dio,
        _almacenamiento = almacenamiento;

  Future<ModeloUsuario> iniciarSesion({
    required String nombreUsuario,
    required String contrasena,
  }) async {
    final respuesta = await _dio.post(
      '${ApiConstantes.urlBase}${ApiConstantes.urlToken}',
      data: {
        'username': nombreUsuario,
        'password': contrasena,
      },
    );
    final usuario = ModeloUsuario.desdeJson(respuesta.data);
    await _guardarSesion(usuario, contrasena: contrasena);
    return usuario;
  }

  Future<ModeloUsuario?> obtenerUsuarioGuardado() async {
    final token = await _almacenamiento.read(key: StorageConstantes.authToken);
    final userIdStr = await _almacenamiento.read(key: StorageConstantes.userId);
    final username = await _almacenamiento.read(key: StorageConstantes.username);
    final rolStr = await _almacenamiento.read(key: StorageConstantes.rol);
    if (token == null || userIdStr == null || username == null) return null;
    return ModeloUsuario(
      id: int.parse(userIdStr),
      nombreUsuario: username,
      token: token,
      rol: rolStr == 'ADM' ? RolUsuario.administrador : RolUsuario.operador,
    );
  }

  Future<void> cerrarSesion() async {
    await _almacenamiento.deleteAll();
  }

  Future<({String? usuario, String? contrasena})> obtenerCredenciales() async {
    final usuario = await _almacenamiento.read(key: StorageConstantes.username);
    final contrasena = await _almacenamiento.read(key: StorageConstantes.contrasena);
    return (usuario: usuario, contrasena: contrasena);
  }

  Future<void> _guardarSesion(ModeloUsuario usuario, {required String contrasena}) async {
    await _almacenamiento.write(key: StorageConstantes.authToken, value: usuario.token);
    await _almacenamiento.write(key: StorageConstantes.userId, value: usuario.id.toString());
    await _almacenamiento.write(key: StorageConstantes.username, value: usuario.nombreUsuario);
    await _almacenamiento.write(
      key: StorageConstantes.rol,
      value: usuario.esAdministrador ? 'ADM' : 'OPR',
    );
    await _almacenamiento.write(key: StorageConstantes.contrasena, value: contrasena);
  }
}

final repositorioAuthProvider = Provider<RepositorioAuth>((ref) {
  return RepositorioAuth(
    dio: Dio(),
    almacenamiento: const FlutterSecureStorage(),
  );
});
