import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constantes/api_constantes.dart';
import '../../../../core/servicios/dio_provider.dart';
import '../../../../core/tema/tema_app.dart';
import '../../../ubicacion/presentation/providers/ubicacion_provider.dart';
import '../providers/inicio_provider.dart';

class TarjetaProyecto extends ConsumerWidget {
  final ModeloProyecto proyecto;
  final bool servicioActivo;

  const TarjetaProyecto({
    super.key,
    required this.proyecto,
    this.servicioActivo = true,
  });

  Future<void> _abrirWhatsApp() async {
    final telefono = proyecto.telefono.replaceAll(RegExp(r'\D'), '');
    final uri = Uri.parse('https://wa.me/591$telefono');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _abrirMaps() async {
    final uri = Uri.parse(
      'google.navigation:q=${proyecto.lat},${proyecto.lon}',
    );
    final uriFallback = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${proyecto.lat},${proyecto.lon}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (await canLaunchUrl(uriFallback)) {
      await launchUrl(uriFallback, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _actualizarEstado(
    BuildContext context,
    WidgetRef ref,
    String nuevoEstado, {
    String? comentario,
    double? nivel,
    int? monto,
  }) async {
    try {
      final dio = ref.read(dioProvider);
      final posicion = ref.read(posicionProvider).valueOrNull?.posicion;

      // Para SRV_CAN: no enviar monto; armar comentario como "Bs. X - comentario"
      String? comentarioFinal = comentario;
      int? montoFinal = monto;
      if (nuevoEstado == 'CAN') {
        montoFinal = null;
        final partes = <String>[
          if (monto != null) 'Bs. $monto',
          if (comentario != null && comentario.isNotEmpty) comentario,
        ];
        comentarioFinal = partes.isNotEmpty ? partes.join(' - ') : null;
      }

      await dio.post(
        ApiConstantes.urlEvento,
        data: {
          'tipo': nuevoEstado == 'EJE' ? 'SRV_EJE' : 'SRV_CAN',
          'lat': posicion?.latitude ?? proyecto.lat,
          'lon': posicion?.longitude ?? proyecto.lon,
          'cliente_id': proyecto.id,
          if (comentarioFinal != null && comentarioFinal.isNotEmpty) 'comentario': comentarioFinal,
          if (nivel != null) 'nivel_tanque': double.parse(nivel.toStringAsFixed(2)),
          if (montoFinal != null) 'monto': montoFinal,
        },
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al actualizar el estado'),
            backgroundColor: TemaApp.colorSecundario,
          ),
        );
      }
    }
  }

  void _mostrarDialogTerminar(BuildContext context, WidgetRef ref) {
    // Capture everything from ref before the dialog opens — ref may be
    // disposed by the time the user taps Confirmar (e.g. after list refresh).
    final nivelActual = ref.read(nivelTanqueProvider);
    final nivelNotifier = ref.read(nivelTanqueProvider.notifier);
    final container = ProviderScope.containerOf(context);

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 180),
      transitionBuilder: (_, anim, __, child) => FadeTransition(
        opacity: anim,
        child: child,
      ),
      pageBuilder: (ctx, _, __) => _PanelTerminarServicio(
        nombreCliente: proyecto.nombreCliente,
        nivelInicial: nivelActual,
        precioInicial: proyecto.precio,
        onConfirmar: (estado, nivel, comentario, monto) {
          nivelNotifier.state = nivel;
          final actuales = container.read(estadosLocalesProvider);
          container.read(estadosLocalesProvider.notifier).state = {
            ...actuales,
            proyecto.id: estado,
          };
          _actualizarEstado(context, ref, estado,
              comentario: comentario, nivel: nivel, monto: monto);
        },
      ),
    );
  }

  double? _calcularDistancia(Position? posicion) {
    if (posicion == null) return null;
    return Geolocator.distanceBetween(
          posicion.latitude, posicion.longitude, proyecto.lat, proyecto.lon,
        ) /
        1000;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultado = ref.watch(posicionProvider).valueOrNull;
    final distanciaKm = _calcularDistancia(resultado?.posicion);

    final bloqueado = proyecto.status != 'PRG';
    final colorBarra = switch (proyecto.status) {
      'EJE' => const Color(0xFF1F8E43),
      'CAN' => const Color(0xFFE53935),
      _     => const Color(0xFF1976D2), // PRG → azul
    };

    return Stack(
      children: [
      Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colorBarra.withValues(alpha: 0.4), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: colorBarra),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Nombre + hora + precio
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        proyecto.nombreCliente,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                      if (distanciaKm != null) ...[
                        const SizedBox(height: 2),
                        Padding(
                          padding: const EdgeInsets.only(left: 36),
                          child: Row(
                            children: [
                              const Icon(Icons.near_me,
                                  size: 11, color: Colors.white38),
                              const SizedBox(width: 4),
                              Text(
                                distanciaKm < 1
                                    ? '${(distanciaKm * 1000).round()} m'
                                    : '${distanciaKm.toStringAsFixed(1)} km',
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (proyecto.horaProgramada != null) ...[
                  _IndicadorHora(horaProgramada: proyecto.horaProgramada!),
                  const SizedBox(width: 8),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD54F).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFFFD54F).withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    'Bs. ${proyecto.precio}',
                    style: const TextStyle(
                      color: Color(0xFFFFD54F),
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),

            if (proyecto.direccion != null &&
                proyecto.direccion!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        size: 15, color: Color(0xFFFF6D00)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        proyecto.direccion!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white60,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Acciones
            if (!bloqueado && servicioActivo)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _BotonAccion(
                  icono: Icons.check_circle_outline,
                  etiqueta: 'Terminado',
                  color: const Color(0xFF42A5F5),
                  onTap: () => _mostrarDialogTerminar(context, ref),
                ),
                const SizedBox(width: 8),
                _BotonAccion(
                  icono: Icons.location_on,
                  etiqueta: 'Mapa',
                  color: const Color(0xFFBF5300),
                  onTap: _abrirMaps,
                ),
                const SizedBox(width: 8),
                _BotonAccion(
                  icono: Icons.chat_rounded,
                  etiqueta: 'WhatsApp',
                  color: const Color(0xFF1A9E4A),
                  onTap: _abrirWhatsApp,
                ),
              ],
            ),
          ],
        ),
              ),
            ),
          ],
        ),
      ),
    ),
  ),
      // Overlay bloqueado (EJE / CAN)
      if (bloqueado)
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                color: Colors.black.withValues(alpha: 0.45),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Icon(
                      proyecto.status == 'EJE'
                          ? Icons.check_circle_outline
                          : Icons.cancel_outlined,
                      color: proyecto.status == 'EJE'
                          ? const Color(0xFF43A047).withValues(alpha: 0.6)
                          : const Color(0xFFE53935).withValues(alpha: 0.6),
                      size: 28,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );
  }
}

// ─── Panel flotante de finalización (draggable + minimizable) ───────────────

class _PanelTerminarServicio extends StatefulWidget {
  final String nombreCliente;
  final double nivelInicial;
  final int precioInicial;
  final void Function(String estado, double nivel, String comentario, int? monto) onConfirmar;

  const _PanelTerminarServicio({
    required this.nombreCliente,
    required this.nivelInicial,
    required this.precioInicial,
    required this.onConfirmar,
  });

  @override
  State<_PanelTerminarServicio> createState() => _PanelTerminarServicioState();
}

class _PanelTerminarServicioState extends State<_PanelTerminarServicio> {
  static const double _panelAncho = 320;

  Offset _pos = Offset.zero;
  bool _posIniciada = false;
  bool _minimizado = false;

  String _estado = 'EJE';
  late double _nivel;
  late TextEditingController _comentarioCtrl;
  late TextEditingController _precioCtrl;

  @override
  void initState() {
    super.initState();
    _nivel = widget.nivelInicial;
    _comentarioCtrl = TextEditingController();
    _precioCtrl = TextEditingController(
      text: widget.precioInicial > 0 ? widget.precioInicial.toString() : '',
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_posIniciada) {
      final size = MediaQuery.of(context).size;
      _pos = Offset((size.width - _panelAncho) / 2, size.height * 0.12);
      _posIniciada = true;
    }
  }

  @override
  void dispose() {
    _comentarioCtrl.dispose();
    _precioCtrl.dispose();
    super.dispose();
  }

  void _onDrag(DragUpdateDetails d) {
    final size = MediaQuery.of(context).size;
    setState(() {
      _pos = Offset(
        (_pos.dx + d.delta.dx).clamp(0, size.width - _panelAncho),
        (_pos.dy + d.delta.dy).clamp(0, size.height - 60),
      );
    });
  }

  Color _colorNivel(double nivel) {
    if (nivel > 0.9) return const Color(0xFFE53935);
    if (nivel > 0.5) return const Color(0xFFFDD835);
    if (nivel > 0.0) return const Color(0xFF43A047);
    return const Color(0xFF78909C);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Stack(
        children: [
          Positioned(
            left: _pos.dx,
            top: _pos.dy,
            width: _panelAncho,
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1e2030),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(color: Colors.black54, blurRadius: 24, offset: Offset(0, 8)),
                  ],
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Barra de título (draggable) ──────────────────────────
                    GestureDetector(
                      onPanUpdate: _onDrag,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.vertical(
                            top: const Radius.circular(16),
                            bottom: _minimizado
                                ? const Radius.circular(16)
                                : Radius.zero,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.drag_handle,
                                size: 16, color: Colors.white30),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Finalizar servicio',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    widget.nombreCliente,
                                    style: const TextStyle(
                                        color: Colors.white54, fontSize: 11),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            // Minimize / expand
                            GestureDetector(
                              onTap: () =>
                                  setState(() => _minimizado = !_minimizado),
                              child: Padding(
                                padding: const EdgeInsets.all(6),
                                child: Icon(
                                  _minimizado
                                      ? Icons.expand_less
                                      : Icons.expand_more,
                                  size: 18,
                                  color: Colors.white54,
                                ),
                              ),
                            ),
                            // Close
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: const Padding(
                                padding: EdgeInsets.all(6),
                                child: Icon(Icons.close,
                                    size: 16, color: Colors.white38),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ── Cuerpo (oculto cuando minimizado) ───────────────────
                    if (!_minimizado)
                      SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Chips EJE / CAN
                            Row(
                              children: [
                                _ChipEstado(
                                  label: 'Ejecutado',
                                  color: const Color(0xFF1F8E43),
                                  seleccionado: _estado == 'EJE',
                                  onTap: () => setState(() => _estado = 'EJE'),
                                ),
                                const SizedBox(width: 8),
                                _ChipEstado(
                                  label: 'Cancelado',
                                  color: const Color(0xFFE53935),
                                  seleccionado: _estado == 'CAN',
                                  onTap: () => setState(() => _estado = 'CAN'),
                                ),
                              ],
                            ),

                            // Comentario cancelación
                            if (_estado == 'CAN') ...[
                              const SizedBox(height: 14),
                              TextField(
                                controller: _comentarioCtrl,
                                maxLines: 1,
                                maxLength: 200,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => FocusScope.of(context).unfocus(),
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 13),
                                decoration: InputDecoration(
                                  labelText: 'Comentario (opcional)',
                                  labelStyle: const TextStyle(
                                      color: Colors.white54, fontSize: 13),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.all(10),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                        color: Color(0xFFE53935), width: 1),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                        color: Color(0xFFE53935), width: 1.5),
                                  ),
                                  counterStyle: const TextStyle(
                                      color: Colors.white24, fontSize: 10),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            if (_estado == 'EJE') ...[
                              const SizedBox(height: 16),

                              // Comentario
                              TextField(
                                controller: _comentarioCtrl,
                                maxLines: 1,
                                maxLength: 200,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => FocusScope.of(context).unfocus(),
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 13),
                                decoration: InputDecoration(
                                  labelText: 'Comentarios (opcional)',
                                  labelStyle: const TextStyle(
                                      color: Colors.white54, fontSize: 13),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.all(10),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                        color: Colors.white24),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                        color: TemaApp.colorPrimario,
                                        width: 1.5),
                                  ),
                                  counterStyle: const TextStyle(
                                      color: Colors.white24, fontSize: 10),
                                ),
                              ),

                              const SizedBox(height: 12),

                              // Nivel tanque
                              Row(
                                children: [
                                  const Text('Nivel del tanque',
                                      style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600)),
                                  const Spacer(),
                                  Text(
                                    _nivel > 0.9
                                        ? 'Lleno'
                                        : _nivel > 0.5
                                            ? '2/3'
                                            : _nivel > 0.0
                                                ? '1/3'
                                                : 'Vacío',
                                    style: TextStyle(
                                        color: _colorNivel(_nivel),
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 12),

                              Center(
                                child: Transform.scale(
                                  scale: 0.75,
                                  child: _ReglaTanqueInteractiva(
                                    nivel: _nivel,
                                    onCambio: (v) =>
                                        setState(() => _nivel = v),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 12),

                              // Precio del servicio (solo lectura)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFD54F).withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFFFD54F).withValues(alpha: 0.4)),
                                ),
                                child: Row(
                                  children: [
                                    const Text(
                                      'Precio del servicio',
                                      style: TextStyle(color: Colors.white54, fontSize: 13),
                                    ),
                                    const Spacer(),
                                    Text(
                                      'Bs. ${_precioCtrl.text}',
                                      style: const TextStyle(
                                        color: Color(0xFFFFD54F),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 16),
                            ], // fin EJE

                            // Botones
                            Row(
                              children: [
                                Expanded(
                                  child: _BotonDialog(
                                    etiqueta: 'Cancelar',
                                    color: Colors.white38,
                                    onTap: () => Navigator.pop(context),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _BotonDialog(
                                    etiqueta: 'Confirmar',
                                    color: TemaApp.colorPrimario,
                                    onTap: () {
                                      Navigator.pop(context);
                                      widget.onConfirmar(
                                        _estado,
                                        _nivel,
                                        _comentarioCtrl.text.trim(),
                                        int.tryParse(_precioCtrl.text.trim()),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Chip de selección de estado ────────────────────────────────────────────

class _ChipEstado extends StatelessWidget {
  final String label;
  final Color color;
  final bool seleccionado;
  final VoidCallback onTap;

  const _ChipEstado({
    required this.label,
    required this.color,
    required this.seleccionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: seleccionado ? color.withValues(alpha: 0.25) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: seleccionado ? color : Colors.white24,
              width: seleccionado ? 1.5 : 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: seleccionado ? color : Colors.white38,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Regla de tanque interactiva ────────────────────────────────────────────

class _ReglaTanqueInteractiva extends StatefulWidget {
  final double nivel;
  final ValueChanged<double> onCambio;

  const _ReglaTanqueInteractiva({
    required this.nivel,
    required this.onCambio,
  });

  @override
  State<_ReglaTanqueInteractiva> createState() =>
      _ReglaTanqueInteractivaState();
}

class _ReglaTanqueInteractivaState extends State<_ReglaTanqueInteractiva> {
  static const double _ancho = 72;
  static const double _alto = 220;

  double _nivelLocal = 0;

  static double _snap(double raw) {
    const opciones = [0.0, 1 / 3, 2 / 3, 1.0];
    return opciones.reduce(
      (a, b) => (a - raw).abs() < (b - raw).abs() ? a : b,
    );
  }

  @override
  void initState() {
    super.initState();
    _nivelLocal = _snap(widget.nivel);
  }

  void _actualizarDesdeY(double dy) {
    final snapped = _snap((1.0 - dy / _alto).clamp(0.0, 1.0));
    setState(() => _nivelLocal = snapped);
    widget.onCambio(snapped);
  }

  Color get _colorRelleno {
    if (_nivelLocal > 0.9) return const Color(0xFFE53935);
    if (_nivelLocal > 0.5) return const Color(0xFFFDD835);
    if (_nivelLocal > 0.0)  return const Color(0xFF43A047);
    return const Color(0xFF78909C);
  }

  @override
  Widget build(BuildContext context) {
    final alturaRelleno = _alto * _nivelLocal.clamp(0.0, 1.0);
    final posicionIndicador = _alto - alturaRelleno;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Gráfico interactivo
        GestureDetector(
          onVerticalDragUpdate: (d) => _actualizarDesdeY(d.localPosition.dy),
          onTapDown: (d) => _actualizarDesdeY(d.localPosition.dy),
          child: SizedBox(
            width: _ancho + 20,
            height: _alto,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Contenedor principal del tanque
                Positioned(
                  left: 20,
                  top: 0,
                  child: Container(
                    width: _ancho,
                    height: _alto,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white30, width: 1.5),
                      color: Colors.black26,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8.5),
                      child: Stack(
                        children: [
                          // Secciones de fondo según nivel actual
                          Column(
                            children: [
                              Expanded(child: Container(
                                color: _nivelLocal > 0.9
                                    ? const Color(0xFFE53935).withValues(alpha: 0.25)
                                    : Colors.transparent,
                              )),
                              Container(height: 1, color: Colors.white12),
                              Expanded(child: Container(
                                color: _nivelLocal > 0.5
                                    ? const Color(0xFFFDD835).withValues(alpha: 0.25)
                                    : Colors.transparent,
                              )),
                              Container(height: 1, color: Colors.white12),
                              Expanded(child: Container(
                                color: _nivelLocal > 0.0
                                    ? const Color(0xFF43A047).withValues(alpha: 0.25)
                                    : Colors.transparent,
                              )),
                            ],
                          ),
                          // Relleno animado
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            height: alturaRelleno,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 80),
                              decoration: BoxDecoration(
                                color: _colorRelleno.withValues(alpha: 0.80),
                                boxShadow: [
                                  BoxShadow(
                                    color: _colorRelleno.withValues(alpha: 0.35),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Indicador de nivel (triángulo + línea)
                Positioned(
                  top: posicionIndicador - 1,
                  left: 0,
                  right: 0,
                  child: Row(
                    children: [
                      CustomPaint(
                        size: const Size(12, 10),
                        painter: _TrianguloPainter(color: _colorRelleno),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Container(height: 2, color: _colorRelleno),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(width: 10),

        // Etiquetas a la derecha del gráfico
        SizedBox(
          height: _alto,
          width: 38,
          child: Stack(
            children: [
              _etiqueta('Lleno', _alto * (1 - 0.83) - 8, const Color(0xFFE53935)),
              _etiqueta('2/3',   _alto * (1 - 0.50) - 8, const Color(0xFFFDD835)),
              _etiqueta('1/3',   _alto * (1 - 0.17) - 8, const Color(0xFF43A047)),
              _etiqueta('Vacío', _alto - 14,              const Color(0xFF78909C)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _etiqueta(String texto, double top, Color color) {
    return Positioned(
      top: top,
      left: 0,
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color.withValues(alpha: 0.85),
        ),
      ),
    );
  }
}

class _TrianguloPainter extends CustomPainter {
  final Color color;

  const _TrianguloPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TrianguloPainter old) => old.color != color;
}

// ─── Indicador de fecha y hora programada ───────────────────────────────────

class _IndicadorHora extends StatefulWidget {
  // ISO 8601 devuelto por Django DateTimeField, ej: "2026-04-10T14:30:00Z"
  final String horaProgramada;

  const _IndicadorHora({required this.horaProgramada});

  @override
  State<_IndicadorHora> createState() => _IndicadorHoraState();
}

class _IndicadorHoraState extends State<_IndicadorHora>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pulso;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _pulso = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color _color(Duration diferencia) {
    final min = diferencia.inMinutes;
    if (min >= 120) return const Color(0xFF43A047); // verde ≥ 2h
    if (min >= 60)  return const Color(0xFFFDD835); // amarillo < 2h
    return const Color(0xFFE53935);                  // rojo < 1h (o pasada)
  }

  String _etiqueta(Duration diferencia) {
    if (diferencia.isNegative) return 'Hora pasada';
    final h = diferencia.inHours;
    final m = diferencia.inMinutes % 60;
    if (h > 0 && m > 0) return 'En ${h}h ${m}m';
    if (h > 0) return 'En ${h}h';
    return 'En ${m}m';
  }

  String _formatFechaHora(DateTime dt) {
    final ahora = DateTime.now();
    final esHoy = dt.year == ahora.year &&
        dt.month == ahora.month &&
        dt.day == ahora.day;
    final hora =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    if (esHoy) return hora;
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} $hora';
  }

  @override
  Widget build(BuildContext context) {
    final fechaHora = DateTime.tryParse(widget.horaProgramada)?.toLocal();
    if (fechaHora == null) return const SizedBox.shrink();

    final diferencia = fechaHora.difference(DateTime.now());
    final color = _color(diferencia);
    final vencido = diferencia.isNegative;

    // Arrancar/detener animación según estado
    if (vencido && !_ctrl.isAnimating) {
      _ctrl.repeat(reverse: true);
    } else if (!vencido && _ctrl.isAnimating) {
      _ctrl.stop();
      _ctrl.value = 0;
    }

    if (!vencido) {
      return _contenido(color, diferencia, fechaHora, pulso: 0);
    }

    return AnimatedBuilder(
      animation: _pulso,
      builder: (_, __) => _contenido(color, diferencia, fechaHora, pulso: _pulso.value),
    );
  }

  Widget _contenido(
    Color color,
    Duration diferencia,
    DateTime fechaHora, {
    required double pulso,
  }) {
    // pulso: 0.0 (apagado) → 1.0 (brillante) — solo anima el borde
    const bgAlpha  = 0.12;                 // fijo
    final brdAlpha = 0.50 + pulso * 0.50; // 0.50 → 1.0

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: bgAlpha),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: brdAlpha)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule, size: 11, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              _formatFechaHora(fechaHora),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


// ─── Botón de diálogo ───────────────────────────────────────────────────────

class _BotonDialog extends StatelessWidget {
  final String etiqueta;
  final Color color;
  final VoidCallback onTap;

  const _BotonDialog({
    required this.etiqueta,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Center(
          child: Text(
            etiqueta,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Botón de acción ────────────────────────────────────────────────────────

class _BotonAccion extends StatelessWidget {
  final IconData icono;
  final String etiqueta;
  final Color color;
  final VoidCallback onTap;

  const _BotonAccion({
    required this.icono,
    required this.etiqueta,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 15, color: color),
            const SizedBox(width: 5),
            Text(
              etiqueta,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
