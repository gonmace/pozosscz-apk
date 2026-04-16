import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/tema/tema_app.dart';
import '../providers/auth_provider.dart';

class PantallaLogin extends ConsumerStatefulWidget {
  const PantallaLogin({super.key});

  @override
  ConsumerState<PantallaLogin> createState() => _PantallaLoginState();
}

class _PantallaLoginState extends ConsumerState<PantallaLogin> {
  final _formKey = GlobalKey<FormState>();
  final _ctrlUsuario = TextEditingController();
  final _ctrlContrasena = TextEditingController();
  bool _verContrasena = false;

  @override
  void dispose() {
    _ctrlUsuario.dispose();
    _ctrlContrasena.dispose();
    super.dispose();
  }

  Future<void> _ingresar() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authProvider.notifier).iniciarSesion(
          nombreUsuario: _ctrlUsuario.text.trim(),
          contrasena: _ctrlContrasena.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final estadoAsync = ref.watch(authProvider);
    final estado = estadoAsync.valueOrNull;
    final cargando = estado?.cargando ?? false;
    final error = estado?.error;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              TemaApp.colorPrimario,
              Color(0xFF1A1C2E),
              TemaApp.colorPrimario,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  SvgPicture.asset(
                    'assets/images/logo.svg',
                    height: 80,
                    colorFilter: const ColorFilter.mode(
                      Colors.white,
                      BlendMode.srcIn,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Pozos SCZ',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Text(
                    'Panel Operador',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Card login
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Iniciar Sesion',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Error
                          if (error != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: TemaApp.colorSecundario
                                    .withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: TemaApp.colorSecundario
                                        .withValues(alpha: 0.5)),
                              ),
                              child: Text(
                                error,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 13),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Campo usuario
                          TextFormField(
                            controller: _ctrlUsuario,
                            decoration: const InputDecoration(
                              labelText: 'Usuario',
                              prefixIcon:
                                  Icon(Icons.person_outline, color: Colors.white54),
                            ),
                            style: const TextStyle(color: Colors.white),
                            textInputAction: TextInputAction.next,
                            validator: (v) =>
                                (v == null || v.trim().isEmpty) ? 'Ingrese su usuario' : null,
                          ),
                          const SizedBox(height: 16),

                          // Campo contrasena
                          TextFormField(
                            controller: _ctrlContrasena,
                            decoration: InputDecoration(
                              labelText: 'Contrasena',
                              prefixIcon: const Icon(Icons.lock_outline,
                                  color: Colors.white54),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _verContrasena
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: Colors.white54,
                                ),
                                onPressed: () =>
                                    setState(() => _verContrasena = !_verContrasena),
                              ),
                            ),
                            style: const TextStyle(color: Colors.white),
                            obscureText: !_verContrasena,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _ingresar(),
                            validator: (v) =>
                                (v == null || v.isEmpty) ? 'Ingrese su contrasena' : null,
                          ),
                          const SizedBox(height: 24),

                          // Boton ingresar
                          SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              onPressed: cargando ? null : _ingresar,
                              child: cargando
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : const Text(
                                      'Ingresar',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700),
                                    ),
                            ),
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
      ),
    );
  }
}
