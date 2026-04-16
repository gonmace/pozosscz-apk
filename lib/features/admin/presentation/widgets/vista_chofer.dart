import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/tema/tema_app.dart';
import '../../../inicio/presentation/providers/inicio_provider.dart';
import '../../../inicio/presentation/widgets/tarjeta_proyecto.dart';
import '../providers/admin_providers.dart';

class VistaChofer extends ConsumerWidget {
  final ModeloCamion camion;

  const VistaChofer({super.key, required this.camion});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proyectosAsync = ref.watch(proyectosChoferProvider(camion.id));
    final estadosLocales = ref.watch(estadosLocalesProvider);

    return Container(
      color: TemaApp.colorFondo,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cabecera: info del chofer
          Container(
            color: TemaApp.colorSuperficie,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: TemaApp.colorPrimario.withValues(alpha: 0.18),
                  child: Text(
                    _iniciales(camion.operador),
                    style: const TextStyle(
                      color: TemaApp.colorPrimario,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        camion.operador,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        camion.marca,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                // Botón refrescar
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white54, size: 20),
                  onPressed: () => ref.invalidate(proyectosChoferProvider(camion.id)),
                  tooltip: 'Refrescar',
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Colors.white12),

          // Encabezado lista
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(
              children: [
                const Text(
                  'Servicios Programados',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
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
                proyectosAsync.whenData((lista) {
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
                }).value ?? const SizedBox(),
              ],
            ),
          ),

          // Lista de proyectos
          Expanded(
            child: proyectosAsync.when(
              data: (proyectos) {
                final visibles = proyectos.where((p) => p.activo).toList();
                if (visibles.isEmpty) {
                  return const Center(
                    child: Text(
                      'Sin servicios programados',
                      style: TextStyle(color: Colors.white54),
                    ),
                  );
                }
                return RefreshIndicator(
                  color: TemaApp.colorPrimario,
                  onRefresh: () =>
                      ref.refresh(proyectosChoferProvider(camion.id).future),
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: visibles.length,
                    itemBuilder: (context, index) =>
                        TarjetaProyecto(proyecto: visibles[index]),
                  ),
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: TemaApp.colorPrimario),
              ),
              error: (error, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        color: TemaApp.colorSecundario, size: 40),
                    const SizedBox(height: 8),
                    const Text(
                      'Error al cargar proyectos',
                      style: TextStyle(color: Colors.white54),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () =>
                          ref.invalidate(proyectosChoferProvider(camion.id)),
                      child: const Text('Reintentar'),
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

  String _iniciales(String nombre) {
    final partes = nombre.trim().split(RegExp(r'\s+'));
    if (partes.length >= 2) {
      return '${partes[0][0]}${partes[1][0]}'.toUpperCase();
    }
    return nombre.isNotEmpty ? nombre[0].toUpperCase() : '?';
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
