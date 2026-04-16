import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../constantes/api_constantes.dart';

/// Tipos de evento que el chofer puede enviar al backend.
enum TipoEvento {
  servicioEjecutado('SRV_EJE'),
  servicioCancelado('SRV_CAN'),
  tanqueVaciado('TKQ_VAC'),
  tanqueActualizado('TKQ_UPD'),
  dieselCargado('DSL_CAR');

  const TipoEvento(this.codigo);
  final String codigo;
}

class ServicioEvento {
  static final _dio = Dio();

  /// Envía un evento al backend. Obtiene las coordenadas actuales automáticamente.
  ///
  /// [token]    Token de auth del chofer.
  /// [tipo]     Tipo de evento (ver [TipoEvento]).
  /// [clienteId] Requerido para SRV_EJE y SRV_CAN.
  /// [motivoCancelacion] Requerido para SRV_CAN.
  /// [nivelTanque] Requerido para TKQ_VAC y TKQ_UPD (0.0 – 1.0).
  /// [diesel]   Requerido para DSL_CAR (monto en Bs).
  static Future<bool> enviar({
    required String token,
    required TipoEvento tipo,
    int? clienteId,
    String motivoCancelacion = '',
    double? nivelTanque,
    int? diesel,
  }) async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      final Map<String, dynamic> body = {
        'tipo': tipo.codigo,
        'lat': pos.latitude,
        'lon': pos.longitude,
      };

      if (clienteId != null) body['cliente_id'] = clienteId;
      if (motivoCancelacion.isNotEmpty) body['motivo_cancelacion'] = motivoCancelacion;
      if (nivelTanque != null) body['nivel_tanque'] = nivelTanque;
      if (diesel != null) body['monto'] = diesel;

      final resp = await _dio.post(
        '${ApiConstantes.urlBase}${ApiConstantes.urlEvento}',
        data: body,
        options: Options(headers: {'Authorization': 'Token $token'}),
      );

      final ok = resp.data['ok'] == true;
      debugPrint('[Evento] ${tipo.codigo} → ok=$ok id=${resp.data['evento_id']}');
      return ok;
    } catch (e) {
      debugPrint('[Evento] Error enviando ${tipo.codigo}: $e');
      return false;
    }
  }
}
