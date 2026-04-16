class ModeloCamion {
  final int id;
  final String operador;
  final String marca;
  final int capacidad;

  const ModeloCamion({
    required this.id,
    required this.operador,
    required this.marca,
    required this.capacidad,
  });

  factory ModeloCamion.desdeJson(Map<String, dynamic> json) {
    return ModeloCamion(
      id: json['id'] as int,
      operador: json['operador'] as String? ?? '',
      marca: json['marca'] as String? ?? '',
      capacidad: json['capacidad'] as int? ?? 0,
    );
  }
}
