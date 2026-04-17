import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart'
    show
        AndroidWebViewController,
        AndroidWebViewWidget,
        AndroidWebViewWidgetCreationParams;

import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constantes/api_constantes.dart';
import '../../../../features/auth/data/repositorio_auth.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/admin_providers.dart';
import '../widgets/vista_chofer.dart';

class PantallaAdmin extends ConsumerStatefulWidget {
  const PantallaAdmin({super.key});

  @override
  ConsumerState<PantallaAdmin> createState() => _PantallaAdminState();
}

class _PantallaAdminState extends ConsumerState<PantallaAdmin> {
  late final WebViewController _controlador;
  bool _cargando = true;

  // Credenciales leidas desde almacenamiento seguro para auto-login
  String? _usuario;
  String? _contrasena;

  // Chofer seleccionado para ver su vista (null = modo admin/WebView)
  ModeloCamion? _choferSeleccionado;

  // Texto compartido recibido via Android share intent
  String? _textoCompartido;

  static const _shareChannel = MethodChannel('pozosscz/share');
  static const _shareEvents = EventChannel('pozosscz/share/events');
  StreamSubscription<dynamic>? _shareSubscription;

  @override
  void initState() {
    super.initState();
    _controlador = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _cargando = true),
          onPageFinished: _alTerminarCarga,
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url;
            if (url.startsWith('https://wa.me/') ||
                url.startsWith('whatsapp://') ||
                url.startsWith('tel:') ||
                url.startsWith('mailto:')) {
              launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      );

    // Configuracion Android para reducir conflictos de compositing GPU (driver MediaTek)
    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidController =
          _controlador.platform as AndroidWebViewController;
      androidController.setOverScrollMode(WebViewOverScrollMode.never);
      androidController.setVerticalScrollBarEnabled(false);
      androidController.setHorizontalScrollBarEnabled(false);
      androidController.setBackgroundColor(Colors.black);
    }

    _controlador.loadRequest(Uri.parse('${ApiConstantes.urlBase}/mapa/'));
    _cargarCredenciales();
    _leerCompartidoInicial();
    _escucharCompartidos();
  }

  @override
  void dispose() {
    _shareSubscription?.cancel();
    super.dispose();
  }

  Future<void> _cargarCredenciales() async {
    final repositorio = ref.read(repositorioAuthProvider);
    final creds = await repositorio.obtenerCredenciales();
    _usuario = creds.usuario;
    _contrasena = creds.contrasena;
  }

  Future<void> _leerCompartidoInicial() async {
    try {
      final texto =
          await _shareChannel.invokeMethod<String>('getInitialSharedText');
      if (texto != null && texto.isNotEmpty) {
        _textoCompartido = texto;
      }
    } catch (_) {}
  }

  void _escucharCompartidos() {
    _shareSubscription =
        _shareEvents.receiveBroadcastStream().listen((event) async {
      if (event is String && event.isNotEmpty && _esAdmin()) {
        if (_choferSeleccionado != null) {
          setState(() => _choferSeleccionado = null);
        }
        // Si ya estamos en el mapa, inyectar directamente sin recargar la página
        final urlActual = await _controlador.currentUrl() ?? '';
        if (urlActual.contains('/mapa')) {
          await _inyectarCoordenadas(event);
        } else {
          // Navegar al mapa; la inyección ocurrirá en _alTerminarCarga
          _textoCompartido = event;
          _controlador.loadRequest(
            Uri.parse('${ApiConstantes.urlBase}/mapa/'),
          );
        }
      }
    });
  }

  /// Solo procesa intents de ubicación si el usuario es administrador.
  bool _esAdmin() {
    final usuario = ref.read(authProvider).valueOrNull?.usuario;
    return usuario?.esAdministrador ?? false;
  }

  /// Inyecta las coordenadas directamente en el campo #URLwhatsapp via JavaScript,
  /// igual que el auto-login. No recarga la página.
  Future<void> _inyectarCoordenadas(String texto) async {
    final coords = _extraerCoordenadas(texto);
    final String valor =
        coords != null ? '${coords.$1},${coords.$2}' : texto;
    final valorEscapado = _escaparParaJs(valor);
    await _controlador.runJavaScript('''
      (function() {
        var input = document.getElementById('URLwhatsapp');
        var btn   = document.getElementById('putMarker');
        if (!input || !btn) return;
        input.value = '$valorEscapado';
        input.dispatchEvent(new Event('input', { bubbles: true }));
        input.scrollIntoView({ behavior: 'smooth', block: 'center' });
        setTimeout(function() { if (!btn.disabled) btn.click(); }, 350);
      })();
    ''');
  }

  /// Intenta extraer (lat, lon) de un texto.
  /// Soporta: "lat,lon", "lat, lon", "geo:lat,lon", URLs de Google Maps con ?q=lat,lon
  (double, double)? _extraerCoordenadas(String texto) {
    // Formato geo:lat,lon (viene de MainActivity al manejar ACTION_VIEW)
    final sinGeo = texto.startsWith('geo:') ? texto.substring(4) : texto;

    // Buscar patrón numérico: número, coma, número (con signo y decimales)
    final regex = RegExp(r'(-?\d{1,3}(?:\.\d+)?)\s*,\s*(-?\d{1,3}(?:\.\d+)?)');
    final match = regex.firstMatch(sinGeo);
    if (match != null) {
      final lat = double.tryParse(match.group(1)!);
      final lon = double.tryParse(match.group(2)!);
      if (lat != null && lon != null &&
          lat >= -90 && lat <= 90 &&
          lon >= -180 && lon <= 180) {
        return (lat, lon);
      }
    }
    return null;
  }

  Future<void> _alTerminarCarga(String url) async {
    // Solo mostrar el mapa cuando ya cargó la página correcta, no el login de Django
    if (url.contains('/mapa')) {
      setState(() => _cargando = false);
    }

    // Si Django redirigió al login, rellenar y enviar el formulario
    if (url.contains('/login') && _usuario != null && _contrasena != null) {
      final usuarioEscapado = _escaparParaJs(_usuario!);
      final contrasenaEscapada = _escaparParaJs(_contrasena!);

      await _controlador.runJavaScript('''
        (function() {
          var u = document.querySelector('input[name="username"]');
          var p = document.querySelector('input[name="password"]');
          if (u && p) {
            u.value = '$usuarioEscapado';
            p.value = '$contrasenaEscapada';
            u.closest('form').submit();
          }
        })();
      ''');
      return;
    }

    // Si llegamos al mapa y hay coordenadas pendientes, inyectarlas via JS
    if (url.contains('/mapa') && _textoCompartido != null && _esAdmin()) {
      final texto = _textoCompartido!;
      _textoCompartido = null;
      await _inyectarCoordenadas(texto);
    }
  }

  String _escaparParaJs(String valor) {
    return valor.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
  }

  Widget _buildWebView() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidWebViewWidget(
        AndroidWebViewWidgetCreationParams(
          controller: _controlador.platform as AndroidWebViewController,
          displayWithHybridComposition: true,
        ),
      ).build(context);
    }
    return WebViewWidget(controller: _controlador);
  }

  Widget _buildDropdown(List<ModeloCamion> camiones) {
    final colorTexto = Theme.of(context).appBarTheme.foregroundColor ??
        Theme.of(context).colorScheme.onSurface;

    return DropdownButtonHideUnderline(
      child: DropdownButton<ModeloCamion?>(
        value: _choferSeleccionado,
        icon: Icon(Icons.arrow_drop_down, color: colorTexto),
        dropdownColor: Theme.of(context).colorScheme.surface,
        isDense: true,
        onChanged: (camion) => setState(() => _choferSeleccionado = camion),
        selectedItemBuilder: (_) => [
          // Ítem "Mapa" seleccionado
          _labelDropdown(
            Icons.map_outlined,
            'Mapa',
            colorTexto,
          ),
          // Un ítem por chofer cuando está seleccionado
          ...camiones.map(
            (c) => _labelDropdown(Icons.person_outline, c.operador, colorTexto),
          ),
        ],
        items: [
          DropdownMenuItem<ModeloCamion?>(
            value: null,
            child: Row(
              children: [
                Icon(Icons.map_outlined,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurface),
                const SizedBox(width: 8),
                const Text('Mapa'),
              ],
            ),
          ),
          ...camiones.map(
            (c) => DropdownMenuItem<ModeloCamion?>(
              value: c,
              child: Row(
                children: [
                  const Icon(Icons.person_outline, size: 16),
                  const SizedBox(width: 8),
                  Text(c.operador),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _labelDropdown(IconData icono, String texto, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icono, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          texto,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final camionesAsync = ref.watch(camionesProvider);

    return Scaffold(
      appBar: AppBar(
        title: camionesAsync.when(
          data: _buildDropdown,
          loading: () => const SizedBox.shrink(),
          error: (error, stack) => const SizedBox.shrink(),
        ),
        actions: [
          if (_choferSeleccionado == null) ...[
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Recargar',
              onPressed: () => _controlador.reload(),
            ),
          ],
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () async {
              await ref.read(authProvider.notifier).cerrarSesion();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // WebView siempre en el árbol para mantener el estado de la página
          _buildWebView(),
          // Pantalla opaca mientras Django hace login — oculta el formulario al usuario
          if (_cargando && _choferSeleccionado == null)
            Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: const Center(child: CircularProgressIndicator()),
            ),
          // Vista del chofer encima del WebView cuando se selecciona uno
          if (_choferSeleccionado != null)
            VistaChofer(
              key: ValueKey(_choferSeleccionado!.id),
              camion: _choferSeleccionado!,
            ),
        ],
      ),
    );
  }
}
