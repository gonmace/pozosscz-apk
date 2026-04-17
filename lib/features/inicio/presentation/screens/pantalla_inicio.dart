import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../core/tema/tema_app.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../ubicacion/presentation/providers/ubicacion_provider.dart';
import '../providers/inicio_provider.dart';
import '../widgets/indicador_tanque.dart';
import '../widgets/tarjeta_proyecto.dart';

class PantallaInicio extends ConsumerStatefulWidget {
  const PantallaInicio({super.key});

  @override
  ConsumerState<PantallaInicio> createState() => _PantallaInicioState();
}

class _PantallaInicioState extends ConsumerState<PantallaInicio>
    with WidgetsBindingObserver {
  // id → índice anterior en la lista
  Map<int, int> _posicionesAnteriores = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Al volver a primer plano refrescar proyectos (cubre el caso background FCM)
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(proyectosProvider);
    }
  }

  static void _mostrarDialogDiesel(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1D2E),
        title: const Row(
          children: [
            Icon(Icons.local_gas_station, color: Color(0xFFFDD835), size: 20),
            SizedBox(width: 8),
            Text('Diesel cargado',
                style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 18),
          decoration: const InputDecoration(
            prefixText: 'Bs. ',
            prefixStyle: TextStyle(color: Colors.white54),
            hintText: '0',
            hintStyle: TextStyle(color: Colors.white24),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar',
                style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFDD835),
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              final valor = int.tryParse(controller.text.trim());
              ref.read(dieselProvider.notifier).state = valor;
              ref.read(fechaDieselProvider.notifier).state =
                  valor != null ? DateTime.now() : null;
              Navigator.pop(context);
              // Reportar la carga de diesel al backend como DSL_CAR
              if (valor != null) {
                ref.read(ubicacionProvider.notifier).reportarCargaDiesel(valor);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  static void _mostrarSelectorNivel(BuildContext context, WidgetRef ref) {
    const niveles = [
      (0.0,   'Vacío', Color(0xFF78909C)),
      (1 / 3, '1/3',   Color(0xFF43A047)),
      (2 / 3, '2/3',   Color(0xFFFDD835)),
      (1.0,   'Lleno', Color(0xFFE53935)),
    ];
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1D2E),
        title: const Text('Nivel del tanque',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: niveles.map((n) {
            final (valor, etiqueta, color) = n;
            final seleccionado =
                (ref.read(nivelTanqueProvider) - valor).abs() < 0.01;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  if (valor == 0.0) {
                    Navigator.pop(context);
                    _mostrarDialogComentarioVacio(context, ref);
                    return;
                  }
                  ref.read(nivelTanqueProvider.notifier).state = valor;
                  Navigator.pop(context);
                  ref.read(ubicacionProvider.notifier).reportarCambioTanque(valor);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: seleccionado
                        ? color.withValues(alpha: 0.2)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: seleccionado
                          ? color
                          : Colors.white24,
                      width: seleccionado ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    etiqueta,
                    style: TextStyle(
                      color: seleccionado ? color : Colors.white70,
                      fontWeight: seleccionado
                          ? FontWeight.w700
                          : FontWeight.normal,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  static void _mostrarDialogComentarioVacio(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1D2E),
        scrollable: true,
        title: Row(
          children: [
            const Icon(Icons.water_drop_outlined, color: Color(0xFF78909C), size: 20),
            const SizedBox(width: 8),
            const Flexible(
              child: Text('Tanque vacío — ¿Dónde estás?',
                  style: TextStyle(color: Colors.white, fontSize: 14)),
            ),
          ],
        ),
        content: TextField(
          controller: ctrl,
          autofocus: false,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            hintText: 'Planta Saguapac',
            hintStyle: const TextStyle(color: Colors.white38),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.white24),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF78909C), width: 1.5),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar',
                style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF78909C),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final comentario = ctrl.text.trim();
              ref.read(nivelTanqueProvider.notifier).state = 0.0;
              Navigator.pop(context);
              ref.read(ubicacionProvider.notifier).reportarCambioTanque(
                0.0,
                comentario: comentario,
              );
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Delegar la persistencia al notifier (capa de datos, no UI)
    ref.listen(nivelTanqueProvider, (_, nivel) {
      ref.read(ubicacionProvider.notifier).guardarNivelTanque(nivel);
    });
    ref.listen(dieselProvider, (_, diesel) {
      ref.read(ubicacionProvider.notifier).guardarDiesel(diesel);
    });

    final estadoAuth = ref.read(authProvider).valueOrNull;
    final estadoUbicacion = ref.watch(ubicacionProvider);
    final proyectosAsync = ref.watch(proyectosProvider);
    final estadosLocales = ref.watch(estadosLocalesProvider);
    final nivelTanque = ref.watch(nivelTanqueProvider);
    final posicionAsync = ref.watch(posicionProvider);
    final diesel = ref.watch(dieselProvider);
    final fechaDiesel = ref.watch(fechaDieselProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              'assets/images/logo.svg',
              height: 28,
              colorFilter: const ColorFilter.mode(
                TemaApp.colorPrimario,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: 10),
            const Flexible(
              child: Text(
                'Pozos SCZ',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: estadoUbicacion.activo
                    ? const Color(0xFF43A047)
                    : const Color(0xFFE53935),
              ),
            ),
          ],
        ),
        actions: [
          // Toggle activo/inactivo
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  estadoUbicacion.activo ? 'Activo' : 'Inactivo',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: estadoUbicacion.activo
                        ? TemaApp.colorPrimario
                        : Colors.grey,
                  ),
                ),
                Switch(
                  value: estadoUbicacion.activo,
                  onChanged: (valor) {
                    if (valor) {
                      ref.read(ubicacionProvider.notifier).activar();
                    } else {
                      ref.read(ubicacionProvider.notifier).desactivar();
                    }
                  },
                ),
              ],
            ),
          ),
          // Boton cerrar sesion
          IconButton(
            icon: const Icon(Icons.logout, size: 20),
            tooltip: 'Cerrar sesion',
            onPressed: () =>
                ref.read(authProvider.notifier).cerrarSesion(),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
        children: [
          // Seccion superior: camion + indicador tanque
          Container(
            color: TemaApp.colorSuperficie,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Indicador Diesel
                GestureDetector(
                  onTap: () => _mostrarDialogDiesel(context, ref),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Diesel',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.white60)),
                          const SizedBox(width: 4),
                          const Icon(Icons.edit, size: 9, color: Colors.white30),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDD835).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: const Color(0xFFFDD835)
                                  .withValues(alpha: diesel != null ? 0.6 : 0.25),
                              width: 1.5),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.local_gas_station,
                                size: 20, color: Color(0xFFFDD835)),
                            const SizedBox(height: 4),
                            Text(
                              diesel != null ? 'Bs.$diesel' : '—',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: diesel != null
                                    ? const Color(0xFFFDD835)
                                    : Colors.white30,
                              ),
                            ),
                            if (fechaDiesel != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                '${fechaDiesel.day.toString().padLeft(2, '0')}/${fechaDiesel.month.toString().padLeft(2, '0')}',
                                style: const TextStyle(
                                    fontSize: 9, color: Colors.white70),
                              ),
                              Text(
                                '${fechaDiesel.hour.toString().padLeft(2, '0')}:${fechaDiesel.minute.toString().padLeft(2, '0')}',
                                style: const TextStyle(
                                    fontSize: 9, color: Colors.white70),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // Camion SVG
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      SvgPicture.asset(
                        'assets/images/logo.svg',
                        height: 101,
                        colorFilter: const ColorFilter.mode(
                          TemaApp.colorPrimario,
                          BlendMode.srcIn,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Hola, ${estadoAuth?.usuario?.nombreUsuario ?? ''}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 20),

                // Indicador de tanque
                IndicadorTanque(
                  nivel: nivelTanque,
                  onTap: () => _mostrarSelectorNivel(context, ref),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Colors.white24),

          // Encabezado lista de proyectos
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Text(
                  'Servicios Programados',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                // Indicador de actualizacion automatica
                proyectosAsync.isLoading
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: TemaApp.colorPrimario,
                        ),
                      )
                    : const Icon(Icons.sync, size: 14, color: Colors.white24),
                const Spacer(),
                proyectosAsync.when(
                  data: (lista) {
                    final conLocal = lista.map((p) {
                      final local = estadosLocales[p.id];
                      return local != null ? p.copyWith(status: local) : p;
                    }).toList();
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ContadorEstado(
                          cantidad: conLocal.where((p) => p.status == 'PRG').length,
                          color: const Color(0xFF1976D2),
                        ),
                        const SizedBox(width: 6),
                        _ContadorEstado(
                          cantidad: conLocal.where((p) => p.status == 'EJE').length,
                          color: const Color(0xFF1F8E43),
                        ),
                        const SizedBox(width: 6),
                        _ContadorEstado(
                          cantidad: conLocal.where((p) => p.status == 'CAN').length,
                          color: const Color(0xFFE53935),
                        ),
                      ],
                    );
                  },
                  loading: () => const SizedBox(),
                  error: (_, __) => const SizedBox(),
                ),
              ],
            ),
          ),

          // Banner de servicio inactivo
          if (!estadoUbicacion.activo)
            Container(
              width: double.infinity,
              color: Colors.black54,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: const Row(
                children: [
                  Icon(Icons.lock_outline, size: 14, color: Colors.white54),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Servicio inactivo — activá el toggle para operar',
                      style: TextStyle(
                          fontSize: 12, color: Colors.white54),
                    ),
                  ),
                ],
              ),
            ),

          // Lista de proyectos
          Expanded(
            child: proyectosAsync.when(
              data: (proyectos) {
                const ordenStatus = {'PRG': 0, 'EJE': 1, 'CAN': 2};
                final visibles = proyectos
                    .where((p) => p.activo)
                    .map((p) {
                      final local = estadosLocales[p.id];
                      return local != null ? p.copyWith(status: local) : p;
                    })
                    .toList()
                  ..sort((a, b) {
                    final oa = ordenStatus[a.status] ?? 9;
                    final ob = ordenStatus[b.status] ?? 9;
                    return oa.compareTo(ob);
                  });
                // Guardar posiciones nuevas para el próximo build
                final nuevasPosiciones = {
                  for (var i = 0; i < visibles.length; i++) visibles[i].id: i,
                };
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _posicionesAnteriores = nuevasPosiciones);
                });

                if (visibles.isEmpty) {
                  return const Center(
                    child: Text(
                      'No hay servicios programados',
                      style: TextStyle(color: Colors.white54),
                    ),
                  );
                }
                final ordenados = visibles;
                return RefreshIndicator(
                  color: TemaApp.colorPrimario,
                  onRefresh: () =>
                      ref.refresh(proyectosProvider.future),
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: ordenados.length,
                    itemBuilder: (context, index) {
                      final proyecto = ordenados[index];
                      final prevIndex = _posicionesAnteriores[proyecto.id];
                      final bajando = prevIndex != null && index > prevIndex;
                      final duracion = bajando ? 520.ms : 280.ms;
                      final curva = bajando ? Curves.easeInOut : Curves.easeOut;
                      final desplazamiento = bajando ? -0.12 : 0.08;

                      return TarjetaProyecto(
                        key: ValueKey(proyecto.id),
                        proyecto: proyecto,
                        servicioActivo: estadoUbicacion.activo,
                      )
                          .animate(key: ValueKey('${proyecto.id}-${proyecto.status}'))
                          .fadeIn(duration: duracion, curve: curva)
                          .slideY(
                            begin: desplazamiento,
                            end: 0,
                            duration: duracion,
                            curve: curva,
                          );
                    },
                  ),
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(
                  color: TemaApp.colorPrimario,
                ),
              ),
              error: (error, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        color: TemaApp.colorSecundario, size: 40),
                    const SizedBox(height: 8),
                    Text(
                      'Error al cargar proyectos',
                      style: TextStyle(color: Colors.white54),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () =>
                          ref.refresh(proyectosProvider.future),
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ],
          ),

        ],
      ),
    );
  }
}

class _ContadorEstado extends StatelessWidget {
  final int cantidad;
  final Color color;

  const _ContadorEstado({required this.cantidad, required this.color});

  @override
  Widget build(BuildContext context) {
    if (cantidad == 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        '$cantidad',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }
}

