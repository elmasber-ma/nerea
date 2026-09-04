import 'package:flutter/foundation.dart';

import 'browser_cookies.dart';
import 'browser_tab.dart';
import 'gecko_tab_controller.dart';

/// Gestor de pestañas del browser: lista, activa, alta/baja con tope por
/// memoria y registro de controladores Gecko vivos. Notifica a la
/// pantalla para redibujar chips e IndexedStack.
///
/// El toggle global de JavaScript también vive acá: al cambiarlo se aplica
/// en vivo a todos los controladores registrados y queda como valor inicial
/// de las pestañas nuevas.
///
/// Es un singleton: las pestañas (y el host global de vistas) sobreviven a
/// la navegación dentro de la app. `openBrowser`/`closeBrowser` controlan el
/// overlay global montado en app.dart.
class BrowserTabs extends ChangeNotifier {
  BrowserTabs._() {
    tabs.add(BrowserTab(id: _nextId()));
  }
  static final BrowserTabs instance = BrowserTabs._();

  static const maxTabs = 8;

  final List<BrowserTab> tabs = [];
  final Map<int, GeckoTabController> _controllers = {};
  int activeIndex = 0;
  bool jsEnabled = true;
  int _idSeq = 0;

  // Ajustes del navegador (preferencias vivas, aplicadas a cada pestaña).
  bool thirdPartyCookies = true;
  bool sharedCookies = false;
  bool blockNetworkImage = false;
  bool geolocation = false; // false = "sin geolocalizar"
  bool safeBrowsing = true; // "modo seguro"
  bool incognito = false;
  bool proxyEnabled = false;
  String proxyHostPort = '';
  String proxyScheme = 'PROXY';

  final ValueNotifier<bool> _open = ValueNotifier(false);
  bool get isOpen => _open.value;
  void openBrowser() {
    _open.value = true;
    notifyListeners();
  }

  void closeBrowser() {
    _open.value = false;
    notifyListeners();
  }

  BrowserTab get active {
    if (tabs.isEmpty) tabs.add(BrowserTab(id: _nextId()));
    final i = activeIndex.clamp(0, tabs.length - 1);
    return tabs[i];
  }

  int _nextId() => _idSeq++;

  GeckoAjustes ajustesActuales() => GeckoAjustes(
        js: jsEnabled,
        cookiesTerceros: thirdPartyCookies,
        geo: geolocation,
        seguro: safeBrowsing,
        incognito: incognito,
      );

  /// Registra el controlador que [BrowserWebview] crea para esa pestaña;
  /// aplica de una vez todos los ajustes actuales.
  Future<void> registerController(int tabId, GeckoTabController c) async {
    _controllers[tabId] = c;
    await c.listo(ajustesActuales());
  }

  /// Olvida el controlador de la vista que se desmontó SIN cerrar la
  /// sesión Gecko: al reabrir el browser la pestaña retoma donde estaba
  /// (mismo comportamiento persistente que antes).
  void forgetController(int tabId) {
    _controllers.remove(tabId);
  }

  void activate(int index) {
    if (index < 0 || index >= tabs.length) return;
    activeIndex = index;
    notifyListeners();
  }

  void add() {
    if (tabs.length >= maxTabs) return;
    tabs.add(BrowserTab(
        id: _nextId(), title: 'Nueva pestaña', url: 'https://duckduckgo.com/'));
    activeIndex = tabs.length - 1;
    notifyListeners();
  }

  /// Cierra SOLO la pestaña en [index] (sin cascada). Si era la última,
  /// crea una "Nueva pestaña" fresca para que siempre haya una.
  Future<void> closeAt(int index) async {
    if (index < 0 || index >= tabs.length) return;
    final id = tabs[index].id;
    final c = _controllers.remove(id);
    try {
      await c?.cerrar();
    } catch (_) {}
    tabs[index].dispose();
    tabs.removeAt(index);
    if (tabs.isEmpty) {
      tabs.add(BrowserTab(
          id: _nextId(), title: 'Nueva pestaña', url: 'https://duckduckgo.com/'));
    }
    if (activeIndex >= tabs.length) activeIndex = tabs.length - 1;
    if (activeIndex < 0) activeIndex = 0;
    notifyListeners();
  }

  void rename(int tabId, String title) {
    final t = tabs.where((x) => x.id == tabId).firstOrNull;
    if (t == null) return;
    t.title = title.isEmpty ? 'Pestaña' : title;
    notifyListeners();
  }

  void updateUrl(int tabId, String url) {
    final t = tabs.where((x) => x.id == tabId).firstOrNull;
    if (t == null) return;
    t.url = url;
    notifyListeners();
  }

  GeckoTabController? controllerOf(int tabId) => _controllers[tabId];

  /// Carga [input] en la pestaña dada; agrega https:// si falta esquema.
  Future<void> loadUrl(int tabId, String input) async {
    var u = input.trim();
    if (u.isEmpty) return;
    if (!u.startsWith('http://') && !u.startsWith('https://')) {
      u = 'https://$u';
    }
    updateUrl(tabId, u);
    await controllerOf(tabId)?.cargar(u);
  }

  Future<void> reload(int tabId) async {
    await controllerOf(tabId)?.recargar();
  }

  Future<bool> goBack(int tabId) async {
    final c = controllerOf(tabId);
    if (c == null) return false;
    await c.atras();
    return true;
  }

  Future<bool> goForward(int tabId) async {
    final c = controllerOf(tabId);
    if (c == null) return false;
    await c.adelante();
    return true;
  }

  /// Configuración completa que se aplica a cada pestaña (nuevas y vivas).
  GeckoAjustes currentWebViewSettings() => ajustesActuales();

  /// Aplica todos los ajustes actuales a un controlador concreto.
  Future<void> applyTo(GeckoTabController c) async {
    try {
      await c.aplicarAjustes(ajustesActuales());
    } catch (_) {}
  }

  Future<void> _applyAll() async {
    for (final c in _controllers.values) {
      await applyTo(c);
    }
  }

  /// Cambia el JavaScript global y lo aplica en vivo a cada pestaña viva.
  Future<void> setJs(bool enabled) async {
    jsEnabled = enabled;
    await _applyAll();
    notifyListeners();
  }

  Future<void> setThirdPartyCookies(bool v) async {
    thirdPartyCookies = v;
    notifyListeners();
    await _applyAll();
  }

  Future<void> setSharedCookies(bool v) async {
    sharedCookies = v;
    notifyListeners();
    await _applyAll();
  }

  Future<void> setBlockNetworkImage(bool v) async {
    blockNetworkImage = v;
    notifyListeners();
    await _applyAll();
  }

  Future<void> setGeolocation(bool v) async {
    geolocation = v;
    notifyListeners();
    await _applyAll();
  }

  Future<void> setSafeBrowsing(bool v) async {
    safeBrowsing = v;
    notifyListeners();
    await _applyAll();
  }

  Future<void> setIncognito(bool v) async {
    incognito = v;
    notifyListeners();
    // Las pestañas ya vivas no cambian a privadas en caliente: limpiamos su
    // rastro y las nuevas respetan el modo al abrir la sesión.
    if (v) {
      try {
        await GeckoTabController.limpiarCache();
      } catch (_) {}
      await CookieStore.instance.clearAll();
    }
  }

  /// Aplica (o quita) un proxy genérico. GeckoView no expone API de proxy:
  /// se guarda la preferencia y la UI queda igual que antes.
  /// [scheme] es 'PROXY' (HTTP) o 'SOCKS'.
  Future<bool> setProxy(bool enabled, String hostPort, String scheme) async {
    proxyEnabled = enabled;
    proxyHostPort = hostPort.trim();
    proxyScheme = scheme;
    notifyListeners();
    try {
      return await ProxyNerea.instance
          .aplicar(enabled, proxyHostPort, proxyScheme);
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    for (final t in tabs) {
      t.dispose();
    }
    super.dispose();
  }
}
