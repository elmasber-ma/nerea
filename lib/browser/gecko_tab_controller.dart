import 'dart:async';

import 'package:flutter/services.dart';

/// Ajustes del navegador aplicados a cada pestaña Gecko (mismo contenido
/// que los settings del webview anterior).
class GeckoAjustes {
  GeckoAjustes({
    required this.js,
    required this.cookiesTerceros,
    required this.geo,
    required this.seguro,
    required this.incognito,
  });

  final bool js;
  final bool cookiesTerceros;
  final bool geo;
  final bool seguro;
  final bool incognito;
}

/// Un item del historial de la pestaña (misma forma que antes).
class HistorialItem {
  HistorialItem({this.titulo, required this.url});

  final String? titulo;
  final Uri url;
}

/// Controlador de UNA pestaña Gecko. Misma API que usaba la UI con el
/// webview anterior: la barra, los paneles y el gestor de pestañas no
/// cambian; solo cambia el motor que está debajo.
class GeckoTabController {
  GeckoTabController(this.tabId);

  final int tabId;
  static const _canal = MethodChannel('nerea/gecko');
  static const _eventos = EventChannel('nerea/gecko/eventos');

  static final _vivos = <int, GeckoTabController>{};
  static StreamSubscription? _sub;

  void Function(double)? onProgreso;
  void Function(String)? onUrl;
  void Function(String)? onTitulo;
  void Function(String url, String nombre)? onDescarga;

  static void _asegurarEventos() {
    if (_sub != null) return;
    _sub = _eventos.receiveBroadcastStream().listen((e) {
      if (e is! Map) return;
      final tab = (e['tab'] as num?)?.toInt();
      final c = _vivos[tab];
      if (c == null) return;
      switch (e['tipo']) {
        case 'progreso':
          c.onProgreso?.call(((e['valor'] as num?) ?? 0) / 100);
        case 'url':
          final u = e['url'] as String?;
          if (u != null) c.onUrl?.call(u);
        case 'titulo':
          final t = e['titulo'] as String?;
          if (t != null) c.onTitulo?.call(t);
        case 'descarga':
          final u = e['url'] as String?;
          if (u != null && u.isNotEmpty) {
            c.onDescarga?.call(u, (e['nombre'] as String?) ?? '');
          }
      }
    });
  }

  /// La vista ya se montó: registra el controlador y avisa ajustes.
  Future<void> listo(GeckoAjustes a) async {
    _asegurarEventos();
    _vivos[tabId] = this;
    await aplicarAjustes(a);
  }

  Future<void> cargar(String url) async {
    try {
      await _canal.invokeMethod('cargar', {'tab': tabId, 'url': url});
    } catch (_) {}
  }

  Future<void> recargar() async {
    try {
      await _canal.invokeMethod('recargar', {'tab': tabId});
    } catch (_) {}
  }

  Future<void> atras() async {
    try {
      await _canal.invokeMethod('atras', {'tab': tabId});
    } catch (_) {}
  }

  Future<void> adelante() async {
    try {
      await _canal.invokeMethod('adelante', {'tab': tabId});
    } catch (_) {}
  }

  Future<void> aplicarAjustes(GeckoAjustes a) async {
    try {
      await _canal.invokeMethod('js', {'valor': a.js});
      await _canal.invokeMethod('geo', {'valor': a.geo});
      await _canal.invokeMethod('seguro', {'valor': a.seguro});
      await _canal
          .invokeMethod('cookiesTerceros', {'valor': a.cookiesTerceros});
      await _canal.invokeMethod('incognito', {'valor': a.incognito});
    } catch (_) {}
  }

  Future<List<HistorialItem>> historial() async {
    try {
      final r = await _canal.invokeMethod('historial', {'tab': tabId});
      if (r is List) {
        return [
          for (final e in r)
            if (e is Map && (e['url'] as String?)?.isNotEmpty == true)
              HistorialItem(
                titulo: e['titulo'] as String?,
                url: Uri.parse(e['url'] as String),
              ),
        ];
      }
    } catch (_) {}
    return const [];
  }

  Future<void> irA(HistorialItem item) => cargar(item.url.toString());

  Future<void> limpiarHistorial() async {
    try {
      await _canal.invokeMethod('limpiarHistorial', {'tab': tabId});
    } catch (_) {}
  }

  /// Borra caché + cookies + datos de sitio del motor.
  static Future<void> limpiarCache() async {
    try {
      await _canal.invokeMethod('borrarDatos');
    } catch (_) {}
  }

  Future<void> cerrar() async {
    _vivos.remove(tabId);
    try {
      await _canal.invokeMethod('cerrar', {'tab': tabId});
    } catch (_) {}
  }
}

/// Proxy genérico: GeckoView no expone API de proxy, se guarda la
/// preferencia en Dart (misma UI que antes).
class ProxyNerea {
  ProxyNerea._();
  static final ProxyNerea instance = ProxyNerea._();

  Future<bool> aplicar(bool on, String hostPuerto, String esquema) async {
    if (!on || hostPuerto.trim().isEmpty) {
      await quitar();
      return true;
    }
    try {
      final ok = await GeckoTabController._canal
          .invokeMethod('proxy', {'host': hostPuerto.trim(), 'esq': esquema});
      return ok == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> quitar() async {
    try {
      await GeckoTabController._canal.invokeMethod('proxy', {'host': ''});
    } catch (_) {}
  }
}
