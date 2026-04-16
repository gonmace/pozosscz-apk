import 'package:flutter/material.dart';

/// Widget que muestra el nivel del tanque en 3 niveles discretos:
/// 1/3 (bajo), 2/3 (medio), Lleno (alto)
///
/// [nivel] va de 0.0 a 1.0 pero se muestra snapeado a 1/3, 2/3 o 1.0
class IndicadorTanque extends StatelessWidget {
  final double nivel;
  final double ancho;
  final double alto;
  final VoidCallback? onTap;

  const IndicadorTanque({
    super.key,
    required this.nivel,
    this.ancho = 23,
    this.alto = 102,
    this.onTap,
  });

  static const _colorLleno  = Color(0xFFE53935);
  static const _colorMedio  = Color(0xFFFDD835);
  static const _colorBajo   = Color(0xFF43A047);

  Color get _colorRelleno {
    if (nivel > 0.9) return _colorLleno;
    if (nivel > 0.5) return _colorMedio;
    if (nivel > 0.0)  return _colorBajo;
    return const Color(0xFF78909C);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Tanque',
              style: TextStyle(fontSize: 11, color: Colors.white60),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              const Icon(Icons.edit, size: 9, color: Colors.white30),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Tubo del tanque
            Container(
              width: ancho,
              height: alto,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white30, width: 1.5),
                color: Colors.black26,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6.5),
                child: Stack(
                  children: [
                    // Secciones de fondo según nivel actual
                    Column(
                      children: [
                        Expanded(child: Container(
                          color: nivel > 0.9 ? _colorLleno.withValues(alpha: 0.25) : Colors.transparent,
                        )),
                        Container(height: 1, color: Colors.white12),
                        Expanded(child: Container(
                          color: nivel > 0.5 ? _colorMedio.withValues(alpha: 0.25) : Colors.transparent,
                        )),
                        Container(height: 1, color: Colors.white12),
                        Expanded(child: Container(
                          color: nivel > 0.0 ? _colorBajo.withValues(alpha: 0.25) : Colors.transparent,
                        )),
                      ],
                    ),
                    // Relleno animado
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: alto * nivel.clamp(0.0, 1.0),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeOut,
                        decoration: BoxDecoration(
                          color: _colorRelleno.withValues(alpha: 0.85),
                          boxShadow: [
                            BoxShadow(
                              color: _colorRelleno.withValues(alpha: 0.4),
                              blurRadius: 8,
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
            const SizedBox(width: 5),
            // Etiquetas de sección
            SizedBox(
              height: alto,
              width: 32,
              child: Stack(
                children: [
                  Positioned(
                    top: alto / 6 - 7,
                    left: 0,
                    child: _Etiqueta('Lleno', _colorLleno),
                  ),
                  Positioned(
                    top: alto / 2 - 7,
                    left: 0,
                    child: _Etiqueta('2/3', _colorMedio),
                  ),
                  Positioned(
                    top: 5 * alto / 6 - 7,
                    left: 0,
                    child: _Etiqueta('1/3', _colorBajo),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          nivel > 0.9
              ? 'Lleno'
              : nivel > 0.5
                  ? '2/3'
                  : nivel > 0.0
                      ? '1/3'
                      : 'Vacío',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: _colorRelleno,
          ),
        ),
      ],
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  final String texto;
  final Color color;

  const _Etiqueta(this.texto, this.color);

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      style: TextStyle(
        fontSize: 8,
        fontWeight: FontWeight.w700,
        color: color.withValues(alpha: 0.85),
      ),
    );
  }
}
