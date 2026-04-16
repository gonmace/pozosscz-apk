import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constantes/api_constantes.dart';
import '../../../../core/servicios/dio_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../inicio/data/modelo_proyecto.dart';
import '../../data/modelo_camion.dart';

export '../../data/modelo_camion.dart';

final camionesProvider = FutureProvider<List<ModeloCamion>>((ref) async {
  final token = ref.read(authProvider).valueOrNull?.usuario?.token;
  if (token == null) return [];
  final dio = ref.read(dioProvider);
  final respuesta = await dio.get(ApiConstantes.urlCamiones);
  return (respuesta.data as List)
      .cast<Map<String, dynamic>>()
      .map(ModeloCamion.desdeJson)
      .toList();
});

final proyectosChoferProvider =
    FutureProvider.family<List<ModeloProyecto>, int>((ref, camionId) async {
  final token = ref.read(authProvider).valueOrNull?.usuario?.token;
  if (token == null) return [];
  final dio = ref.read(dioProvider);
  final respuesta = await dio.get(
    ApiConstantes.urlProyectos,
    queryParameters: {'camion_id': camionId},
  );
  return (respuesta.data as List)
      .cast<Map<String, dynamic>>()
      .map(ModeloProyecto.desdeJson)
      .where((p) => p.status != 'COT')
      .toList();
});
