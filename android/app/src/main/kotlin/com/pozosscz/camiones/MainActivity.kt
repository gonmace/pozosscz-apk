package com.pozosscz.camiones

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private var textoCompartidoInicial: String? = null
    private var eventSink: EventChannel.EventSink? = null

    // Evita que Flutter reciba el URI geo: como ruta inicial (crashea go_router)
    override fun getInitialRoute(): String? {
        val i = intent
        if (i?.action == Intent.ACTION_VIEW && i.data?.scheme == "geo") {
            return "/"
        }
        return super.getInitialRoute()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        textoCompartidoInicial = extraerTextoCompartido(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val texto = extraerTextoCompartido(intent) ?: return
        eventSink?.success(texto)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Canal para obtener el texto compartido al iniciar la app (cold start)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "pozosscz/share")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialSharedText" -> {
                        result.success(textoCompartidoInicial)
                        textoCompartidoInicial = null // consumir una sola vez
                    }
                    else -> result.notImplemented()
                }
            }

        // Canal de eventos para textos compartidos mientras la app ya estaba abierta
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "pozosscz/share/events")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    eventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })
    }

    private fun extraerTextoCompartido(intent: Intent?): String? {
        // Texto compartido via ACTION_SEND (ej: link copiado desde WhatsApp)
        if (intent?.action == Intent.ACTION_SEND && intent.type == "text/plain") {
            return intent.getStringExtra(Intent.EXTRA_TEXT)
        }
        // URI de ubicacion via ACTION_VIEW + geo: (ej: "Abrir con" desde WhatsApp)
        if (intent?.action == Intent.ACTION_VIEW) {
            val data = intent.data
            if (data?.scheme == "geo") {
                return data.toString()  // "geo:-17.783,63.182?q=-17.783,63.182"
            }
        }
        return null
    }
}
