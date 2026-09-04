/// Almacén global de cookies del browser sobre GeckoView: misma API que
/// antes para que la UI no cambie. GeckoView no expone lectura/escritura
/// fina de cookies por API pública; el borrado total sí va al motor
/// (limpia cookies + caché + datos de sitio).
import 'gecko_tab_controller.dart';

class Cookie {
  Cookie({required this.name, required this.value});

  final String name;
  final String value;
}

class CookieStore {
  CookieStore._();
  static final CookieStore instance = CookieStore._();

  Future<List<Cookie>> forUrl(String url) async => const [];

  Future<void> set(String url, String name, String value) async {}

  /// Borra TODAS las cookies (y datos de sitio) del motor. Devuelve si pudo.
  Future<bool> clearAll() async {
    try {
      await GeckoTabController.limpiarCache();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Vuelca legible las cookies de una URL (para consola/debug futuro).
  Future<String> dump(String url) async {
    try {
      final list = await forUrl(url);
      if (list.isEmpty) return '(sin cookies visibles por API)';
      return list.map((c) => '${c.name}=${c.value.length}B').join('\n');
    } catch (e) {
      return 'error: $e';
    }
  }
}
