class ModeloProyecto {
  final int id;
  final String nombreCliente;
  final String telefono;
  final double lat;
  final double lon;
  final int precio;
  final String? direccion;
  final String status;
  final bool activo;
  final DateTime? updatedAt;
  final String? horaProgramada;
  final int? orden;

  const ModeloProyecto({
    required this.id,
    required this.nombreCliente,
    required this.telefono,
    required this.lat,
    required this.lon,
    required this.precio,
    this.direccion,
    this.status = 'PRG',
    this.activo = false,
    this.updatedAt,
    this.horaProgramada,
    this.orden,
  });

  factory ModeloProyecto.desdeJson(Map<String, dynamic> json) {
    return ModeloProyecto(
      id: json['id'] as int,
      nombreCliente: json['name'] as String? ?? 'Sin nombre',
      telefono: json['tel1'] as String? ?? '',
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
      precio: (json['cost'] as num?)?.toInt() ?? 0,
      direccion: json['address'] as String?,
      status: json['status'] as String? ?? 'PRG',
      activo: json['activo'] as bool? ?? false,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
      horaProgramada: json['hora_programada'] as String?,
      orden: json['orden'] as int?,
    );
  }

  ModeloProyecto copyWith({String? status}) {
    return ModeloProyecto(
      id: id,
      nombreCliente: nombreCliente,
      telefono: telefono,
      lat: lat,
      lon: lon,
      precio: precio,
      direccion: direccion,
      status: status ?? this.status,
      activo: activo,
      updatedAt: updatedAt,
      horaProgramada: horaProgramada,
      orden: orden,
    );
  }
}
