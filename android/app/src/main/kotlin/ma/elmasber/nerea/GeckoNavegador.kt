package ma.elmasber.nerea

import android.content.Context
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import org.mozilla.geckoview.ContentBlocking
import org.mozilla.geckoview.GeckoResult
import org.mozilla.geckoview.GeckoRuntime
import org.mozilla.geckoview.GeckoRuntimeSettings
import org.mozilla.geckoview.GeckoSession
import org.mozilla.geckoview.GeckoSessionSettings
import org.mozilla.geckoview.GeckoView
import org.mozilla.geckoview.StorageController
import org.mozilla.geckoview.WebResponse

// Puente Flutter <-> GeckoView para el browser de Nerea.
//
// - UN GeckoRuntime compartido; UNA GeckoSession por pestaña (tabId).
// - Cada pestaña Dart monta un AndroidView 'nerea/gecko' con su tabId; la
//   vista ata la sesión ya abierta (las pestañas ocultas siguen vivas,
//   igual que antes con el webview anterior).
// - Órdenes Dart->Kotlin por MethodChannel 'nerea/gecko'.
// - Eventos Kotlin->Dart (url/progreso/título/historial/descarga) por
//   EventChannel 'nerea/gecko/eventos' con el tabId en cada mapa.
object GeckoNavegador {

    private const val CANAL = "nerea/gecko"
    private const val EVENTOS = "nerea/gecko/eventos"
    private const val VISTA = "nerea/gecko"

    private var runtime: GeckoRuntime? = null
    private var eventos: EventChannel.EventSink? = null
    private val sesiones = mutableMapOf<Int, GeckoSession>()
    private val visitas = mutableMapOf<Int, MutableList<Map<String, String>>>()

    // Ajustes vivos (los que la UI cambia en caliente).
    @Volatile var js = true
    @Volatile var geo = false
    @Volatile var seguro = true
    @Volatile var cookiesTerceros = true
    @Volatile var incognito = false

    fun registrar(engine: io.flutter.embedding.engine.FlutterEngine, contexto: Context) {
        val mensajero = engine.dartExecutor.binaryMessenger
        MethodChannel(mensajero, CANAL).setMethodCallHandler { llamada, resp ->
            atender(llamada, resp)
        }
        EventChannel(mensajero, EVENTOS).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(a: Any?, sink: EventChannel.EventSink) {
                    eventos = sink
                }
                override fun onCancel(a: Any?) {
                    eventos = null
                }
            }
        )
        engine.platformViewsController.registry
            .registerViewFactory(VISTA, factory(contexto))
    }

    fun factory(contexto: Context): PlatformViewFactory =
        object : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
            override fun create(c: Context, id: Int, args: Any?): PlatformView {
                @Suppress("UNCHECKED_CAST")
                val p = args as? Map<String, Any?>
                val tabId = (p?.get("tabId") as? Number)?.toInt() ?: id
                val vista = GeckoView(c)
                val sesion = sesionDe(tabId, c.applicationContext)
                vista.setSession(sesion)
                val url = p?.get("url") as? String
                if (!url.isNullOrBlank() && sesion.isOpen) {
                    // Solo carga inicial si la sesión es nueva (sin visitas).
                    if ((visitas[tabId]?.size ?: 0) == 0) sesion.loadUri(url)
                }
                return object : PlatformView {
                    override fun getView() = vista
                    override fun dispose() {
                        try {
                            vista.releaseSession()
                        } catch (_: Exception) {
                        }
                    }
                }
            }
        }

    fun tipoVista(): String = VISTA

    private fun rt(contexto: Context): GeckoRuntime {
        var r = runtime
        if (r == null) {
            val ajustes = GeckoRuntimeSettings.Builder()
                .contentBlocking(
                    ContentBlocking.Settings.Builder()
                        .safeBrowsing(
                            if (seguro) ContentBlocking.SafeBrowsing.DEFAULT
                            else ContentBlocking.SafeBrowsing.NONE
                        )
                        .cookieBehavior(
                            if (cookiesTerceros) ContentBlocking.CookieBehavior.ACCEPT_ALL
                            else ContentBlocking.CookieBehavior.ACCEPT_FIRST_PARTY
                        )
                        .enhancedTrackingProtectionLevel(
                            if (seguro) ContentBlocking.EtpLevel.STRICT
                            else ContentBlocking.EtpLevel.NONE
                        )
                        .build()
                )
                .build()
            r = GeckoRuntime.create(contexto, ajustes)
            runtime = r
        }
        return r
    }

    private fun sesionDe(tabId: Int, contexto: Context): GeckoSession {
        sesiones[tabId]?.let { return it }
        val aj = GeckoSessionSettings.Builder()
            .allowJavascript(js)
            .usePrivateMode(incognito)
            .build()
        val s = GeckoSession(aj)
        s.open(rt(contexto))
        s.setNavigationDelegate(navegacion(tabId))
        s.setProgressDelegate(progreso(tabId))
        s.setContentDelegate(contenido(tabId))
        s.setHistoryDelegate(historial(tabId))
        s.setPermissionDelegate(permiso())
        sesiones[tabId] = s
        visitas[tabId] = mutableListOf()
        return s
    }

    private fun emitir(m: Map<String, Any?>) {
        try {
            eventos?.success(m)
        } catch (_: Exception) {
        }
    }

    private fun navegacion(tabId: Int) = object : GeckoSession.NavigationDelegate {
        override fun onLocationChange(
            session: GeckoSession,
            url: String?,
            permisos: List<GeckoSession.PermissionDelegate.ContentPermission>,
            gesto: Boolean,
        ) {
            if (url != null) {
                val lista = visitas.getOrPut(tabId) { mutableListOf() }
                if (lista.lastOrNull()?.get("url") != url) {
                    lista.add(mapOf("titulo" to "", "url" to url))
                    if (lista.size > 100) lista.removeAt(0)
                }
                emitir(mapOf("tab" to tabId, "tipo" to "url", "url" to url))
            }
        }

        override fun onCanGoBack(session: GeckoSession, valor: Boolean) {
            emitir(mapOf("tab" to tabId, "tipo" to "atras", "valor" to valor))
        }

        override fun onCanGoForward(session: GeckoSession, valor: Boolean) {
            emitir(mapOf("tab" to tabId, "tipo" to "adelante", "valor" to valor))
        }
    }

    private fun progreso(tabId: Int) = object : GeckoSession.ProgressDelegate {
        override fun onPageStart(session: GeckoSession, url: String) {
            emitir(mapOf("tab" to tabId, "tipo" to "progreso", "valor" to 0))
        }

        override fun onPageStop(session: GeckoSession, ok: Boolean) {
            emitir(mapOf("tab" to tabId, "tipo" to "progreso", "valor" to 100))
        }

        override fun onProgressChange(session: GeckoSession, valor: Int) {
            emitir(mapOf("tab" to tabId, "tipo" to "progreso", "valor" to valor))
        }
    }

    private fun contenido(tabId: Int) = object : GeckoSession.ContentDelegate {
        override fun onTitleChange(session: GeckoSession, titulo: String?) {
            if (titulo != null) {
                visitas[tabId]?.lastOrNull()?.let { ultima ->
                    (ultima as? MutableMap<String, String>)?.put("titulo", titulo)
                }
                emitir(mapOf("tab" to tabId, "tipo" to "titulo", "titulo" to titulo))
            }
        }

        override fun onExternalResponse(session: GeckoSession, respuesta: WebResponse) {
            emitir(
                mapOf(
                    "tab" to tabId,
                    "tipo" to "descarga",
                    "url" to (respuesta.uri ?: ""),
                    "nombre" to (respuesta.filename ?: ""),
                )
            )
        }
    }

    private fun historial(tabId: Int) = object : GeckoSession.HistoryDelegate {
        override fun onHistoryStateChange(session: GeckoSession, lista: GeckoSession.HistoryDelegate.HistoryList) {
            // El listado para la UI sale de `visitas` (ver método historial()).
        }

        override fun onVisited(
            session: GeckoSession,
            url: String,
            ultima: String?,
            banderas: Int,
        ): GeckoResult<Boolean>? = null
    }

    private fun permiso() = object : GeckoSession.PermissionDelegate {
        override fun onContentPermissionRequest(
            session: GeckoSession,
            solicitud: GeckoSession.PermissionDelegate.ContentPermission,
        ): GeckoResult<Int>? {
            val tipo = solicitud.permission
            val r = GeckoResult<Int>()
            if (tipo == GeckoSession.PermissionDelegate.PERMISSION_GEOLOCATION && !geo) {
                r.complete(GeckoSession.PermissionDelegate.ContentPermission.VALUE_DENY)
            } else {
                r.complete(GeckoSession.PermissionDelegate.ContentPermission.VALUE_ALLOW)
            }
            return r
        }
    }

    private fun atender(llamada: MethodCall, resp: MethodChannel.Result) {
        try {
            when (llamada.method) {
                "cargar" -> {
                    val tab = llamada.argument<Int>("tab") ?: return resp.success(false)
                    val url = llamada.argument<String>("url") ?: return resp.success(false)
                    sesiones[tab]?.loadUri(url)
                    resp.success(true)
                }
                "recargar" -> {
                    val tab = llamada.argument<Int>("tab") ?: return resp.success(false)
                    sesiones[tab]?.reload()
                    resp.success(true)
                }
                "atras" -> {
                    val tab = llamada.argument<Int>("tab") ?: return resp.success(false)
                    sesiones[tab]?.goBack()
                    resp.success(true)
                }
                "adelante" -> {
                    val tab = llamada.argument<Int>("tab") ?: return resp.success(false)
                    sesiones[tab]?.goForward()
                    resp.success(true)
                }
                "js" -> {
                    js = llamada.argument<Boolean>("valor") ?: true
                    for (s in sesiones.values) {
                        try {
                            s.settings.allowJavascript = js
                        } catch (_: Exception) {
                        }
                    }
                    resp.success(true)
                }
                "geo" -> {
                    geo = llamada.argument<Boolean>("valor") ?: false
                    resp.success(true)
                }
                "seguro" -> {
                    seguro = llamada.argument<Boolean>("valor") ?: true
                    resp.success(true)
                }
                "cookiesTerceros" -> {
                    cookiesTerceros = llamada.argument<Boolean>("valor") ?: true
                    resp.success(true)
                }
                "incognito" -> {
                    incognito = llamada.argument<Boolean>("valor") ?: false
                    resp.success(true)
                }
                "historial" -> {
                    val tab = llamada.argument<Int>("tab")
                    val lista = if (tab == null) emptyList() else visitas[tab].orEmpty()
                    resp.success(lista.map { mapOf("titulo" to it["titulo"], "url" to it["url"]) })
                }
                "limpiarHistorial" -> {
                    val tab = llamada.argument<Int>("tab")
                    if (tab == null) {
                        for (s in sesiones.values) s.purgeHistory()
                        visitas.clear()
                    } else {
                        sesiones[tab]?.purgeHistory()
                        visitas[tab]?.clear()
                    }
                    resp.success(true)
                }
                "borrarDatos" -> {
                    val r = runtime
                    if (r == null) {
                        resp.success(false)
                    } else {
                        r.storageController.clearData(StorageController.ClearFlags.ALL)
                        visitas.clear()
                        resp.success(true)
                    }
                }
                "cerrar" -> {
                    val tab = llamada.argument<Int>("tab") ?: return resp.success(false)
                    try {
                        sesiones.remove(tab)?.close()
                    } catch (_: Exception) {
                    }
                    visitas.remove(tab)
                    resp.success(true)
                }
                "proxy" -> {
                    // GeckoView no expone API de proxy (los prefs network.proxy.*
                    // requieren firma privilegiada). Se guarda en Dart y listo.
                    resp.success(false)
                }
                else -> resp.notImplemented()
            }
        } catch (e: Exception) {
            resp.error("gecko", e.message, null)
        }
    }
}
