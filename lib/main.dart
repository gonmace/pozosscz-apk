import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/servicios/servicio_fcm.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  // Debe registrarse en main() antes de runApp para que funcione
  // cuando el app está terminada y Flutter levanta un isolate background.
  FirebaseMessaging.onBackgroundMessage(onBackgroundMessage);
  await ServicioFCM.inicializar();
  runApp(
    const ProviderScope(
      child: App(),
    ),
  );
}
