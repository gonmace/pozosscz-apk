import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/rutas/rutas_app.dart';
import 'core/tema/tema_app.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(rutasAppProvider);

    return MaterialApp.router(
      title: 'Pozos SCZ',
      debugShowCheckedModeBanner: false,
      theme: TemaApp.temaOscuro,
      routerConfig: router,
    );
  }
}
