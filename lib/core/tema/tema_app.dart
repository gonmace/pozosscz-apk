import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TemaApp {
  static const Color colorPrimario = Color(0xFF1F8E43);
  static const Color colorSecundario = Color(0xFFFF4444);
  static const Color colorAcento = Color(0xFF52B551);
  static const Color colorFondo = Color(0xFF111320);
  static const Color colorSuperficie = Color(0xFF1A1D2E);
  static const Color colorSuperficieVariante = Color(0xFF1E2235);

  static ThemeData get temaOscuro {
    final esquemaColor = ColorScheme.dark(
      primary: colorPrimario,
      onPrimary: Colors.white,
      secondary: colorSecundario,
      onSecondary: Colors.white,
      tertiary: colorAcento,
      onTertiary: Colors.white,
      surface: colorSuperficie,
      onSurface: Colors.white,
      surfaceContainerHighest: colorSuperficieVariante,
      error: colorSecundario,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: esquemaColor,
      scaffoldBackgroundColor: colorSuperficieVariante,
      textTheme: GoogleFonts.nunitoTextTheme(
        ThemeData.dark().textTheme,
      ).apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: colorSuperficie,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorPrimario,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorSuperficieVariante,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: colorPrimario),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorPrimario.withValues(alpha: 0.4)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: colorPrimario, width: 2),
        ),
        labelStyle: const TextStyle(color: Colors.white70),
      ),
      cardTheme: CardThemeData(
        color: colorFondo,
        elevation: 4,
        shadowColor: Colors.black54,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((estados) {
          if (estados.contains(WidgetState.selected)) return colorPrimario;
          return Colors.grey;
        }),
        trackColor: WidgetStateProperty.resolveWith((estados) {
          if (estados.contains(WidgetState.selected)) {
            return colorPrimario.withValues(alpha: 0.4);
          }
          return Colors.grey.withValues(alpha: 0.3);
        }),
      ),
    );
  }
}
