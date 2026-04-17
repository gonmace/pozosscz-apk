import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/presentation/screens/pantalla_admin.dart';
import '../../features/auth/data/modelo_usuario.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/pantalla_login.dart';
import '../../features/inicio/presentation/screens/pantalla_inicio.dart';

class _RouterAuth extends ChangeNotifier {
  _RouterAuth(Ref ref) {
    ref.listen<AsyncValue<EstadoAuth>>(authProvider, (_, next) {
      // Solo notificar cuando el estado ya resolvio, nunca durante loading
      if (!next.isLoading) notifyListeners();
    });
  }
}

final rutasAppProvider = Provider<GoRouter>((ref) {
  final auth = _RouterAuth(ref);
  ref.onDispose(auth.dispose);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: auth,
    redirect: (context, state) {
      final authState = ref.read(authProvider);

      // Todavia cargando el token guardado → no hacer nada
      if (authState.isLoading) return null;

      final usuario = authState.valueOrNull?.usuario;
      final autenticado = usuario != null;
      final ubicacion = state.matchedLocation;
      final enLogin = ubicacion == '/login';

      // Sin sesion: ir al login
      if (!autenticado && !enLogin) return '/login';

      if (autenticado) {
        final esAdmin = usuario.rol == RolUsuario.administrador;

        // Desde login: ir a la pantalla del rol
        if (enLogin) return esAdmin ? '/admin' : '/';

        // Guardia de rol: operador en pantalla admin → a su pantalla
        if (!esAdmin && ubicacion == '/admin') return '/';

        // Guardia de rol: admin en pantalla operador → a su pantalla
        if (esAdmin && ubicacion == '/') return '/admin';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const PantallaLogin(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const PantallaInicio(),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const PantallaAdmin(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Pagina no encontrada: ${state.error}')),
    ),
  );
});
