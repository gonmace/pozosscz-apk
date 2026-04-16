# Plan: Fix location data + refactor architecture

## Problema 1 — Datos que no llegan (velocidad, dirección, nivel_tanque, diesel)

### Diagnóstico real

**velocidad / dirección**
- El código SÍ las envía. Muestran 0 cuando el dispositivo está quieto (GPS de Android reporta `speed=0`, `heading=0` sin movimiento). No es un bug del app.

**nivel_tanque / diesel — bug confirmado**
- `ref.listen` solo dispara en *cambios* al provider, no en el valor inicial.
- Cuando el usuario activa el tracking sin haber tocado los controles de diesel/tanque, `FlutterForegroundTask.getData` devuelve `null` → fallback a 0.
- Resultado: siempre se envían 0 hasta que el usuario abre el diálogo y guarda.

**Fix concreto**
En `UbicacionNotifier.activar()` (`ubicacion_provider.dart`), antes de llamar a `ServicioUbicacion.iniciarTracking()`, leer los valores actuales de `nivelTanqueProvider` y `dieselProvider` y guardarlos en el almacenamiento del foreground task:

```dart
Future<void> activar() async {
  // ... permisos ...
  final nivelTanque = ref.read(nivelTanqueProvider);
  final diesel = ref.read(dieselProvider) ?? 0;
  await FlutterForegroundTask.saveData(key: 'nivel_tanque', value: nivelTanque);
  await FlutterForegroundTask.saveData(key: 'diesel', value: diesel);
  await ServicioUbicacion.iniciarTracking(token: usuario.token);
  // ...
}
```

---

## Problema 2 — Problemas arquitecturales a corregir

### A) ModeloProyecto está en la capa de presentación (crítico)

`ModeloProyecto` está definido dentro de `tarjeta_proyecto.dart` (widget). Debe moverse a la capa de datos.

**Cambio:**
- Crear `features/inicio/data/modelo_proyecto.dart` con la clase `ModeloProyecto`
- Actualizar imports en `tarjeta_proyecto.dart` e `inicio_provider.dart`

### B) Claves de storage duplicadas en 3 archivos (crítico)

`repositorio_auth.dart`, `servicio_fcm.dart` y `pantalla_inicio.dart` definen sus propias claves. La misma clave `auth_token` existe con dos nombres distintos.

**Cambio:**
- Crear `core/constantes/storage_constantes.dart` con todas las claves
- Actualizar los 3 archivos para importar desde ahí

### C) Lógica de persistencia en la UI (importante)

`pantalla_inicio.dart` hace `FlutterForegroundTask.saveData()` y `_storage.write()` directamente en el `build()`. Eso es lógica de datos en la capa de presentación.

**Cambio:**
- Agregar métodos `guardarNivelTanque()` y `guardarDiesel()` en `UbicacionNotifier`
- `pantalla_inicio.dart` llama `ref.read(ubicacionProvider.notifier).guardarNivelTanque(nivel)` en lugar de escribir al storage directamente
- El notifier escribe a ambos storages

### D) Instancias de Dio dispersas (mejora)

`Dio()` se instancia 5+ veces en distintos archivos sin configuración compartida. Fuera del foreground task (isolate separado), se puede centralizar.

**Cambio limitado** — solo en el isolate principal:
- Crear `core/servicios/dio_provider.dart` con un `Provider<Dio>` configurado con `baseUrl`, timeouts
- Usar en `repositorio_auth.dart`, `inicio_provider.dart`, `tarjeta_proyecto.dart`
- **NO** tocar `servicio_ubicacion.dart` ni `servicio_fcm.dart` (corren en isolates separados donde los providers de Riverpod no están disponibles)

---

## Orden de implementación

1. **Fix bug datos** → `ubicacion_provider.dart` (5 líneas)
2. **Mover `ModeloProyecto`** → nuevo archivo, actualizar 2 imports
3. **`storage_constantes.dart`** → nuevo archivo, actualizar 3 archivos
4. **Lógica persistencia → notifier** → `ubicacion_provider.dart` + `pantalla_inicio.dart`
5. **`dio_provider.dart`** → nuevo provider, actualizar 3 archivos

## Archivos que NO se tocan

- `servicio_ubicacion.dart` (isolate): solo el fix del bug de storage inicial ya aplicado
- `servicio_fcm.dart` (isolate): idem
- `pantalla_login.dart`: no tiene problemas
- `indicador_tanque.dart`: widget puro, correcto
- `tema_app.dart`: se puede mejorar colores pero no es crítico ahora
