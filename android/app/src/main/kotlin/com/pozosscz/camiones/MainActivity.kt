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

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        textoCompartidoInicial = extraerTextoCompartido(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val texto = extraerTextoCompartido(intent) ?: return
        // App ya en ejecucion: enviar via EventChannel
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
        if (intent?.action == Intent.ACTION_SEND && intent.type == "text/plain") {
            return intent.getStringExtra(Intent.EXTRA_TEXT)
        }
        return null
    }
}
