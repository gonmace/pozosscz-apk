enum RolUsuario { administrador, operador }

class ModeloUsuario {
  final int id;
  final String nombreUsuario;
  final String token;
  final RolUsuario rol;

  const ModeloUsuario({
    required this.id,
    required this.nombreUsuario,
    required this.token,
    required this.rol,
  });

  bool get esAdministrador => rol == RolUsuario.administrador;

  factory ModeloUsuario.desdeJson(Map<String, dynamic> json) {
    return ModeloUsuario(
      id: json['user_id'] as int,
      nombreUsuario: json['username'] as String,
      token: json['token'] as String,
      rol: json['rol'] == 'ADM' ? RolUsuario.administrador : RolUsuario.operador,
    );
  }
}
