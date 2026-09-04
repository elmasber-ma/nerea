import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/browser_downloads.dart';
import 'browser_tab.dart';
import 'browser_tabs.dart';
import 'gecko_tab_controller.dart';

/// Envuelve UNA vista Gecko (una pestaña): registra su controlador en el
/// gestor, propaga progreso/url/título y deriva descargas al gestor global.
/// Misma UI que antes (barra de progreso fina abajo).
class BrowserWebview extends StatefulWidget {
  const BrowserWebview({
    super.key,
    required this.tabs,
    required this.tab,
  });

  final BrowserTabs tabs;
  final BrowserTabLike tab;

  @override
  State<BrowserWebview> createState() => _BrowserWebviewState();
}

class _BrowserWebviewState extends State<BrowserWebview> {
  double _progress = 1;

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Column(children: [
        Expanded(
          child: AndroidView(
            viewType: 'nerea/gecko',
            creationParams: {
              'tabId': widget.tab.id,
              'url': widget.tab.url,
            },
            creationParamsCodec: const StandardMessageCodec(),
            onPlatformViewCreated: (_) {
              final c = GeckoTabController(widget.tab.id);
              c.onProgreso = (p) {
                if (mounted) setState(() => _progress = p);
              };
              c.onUrl = (u) => widget.tabs.updateUrl(widget.tab.id, u);
              c.onTitulo = (t) => widget.tabs.rename(widget.tab.id, t);
              c.onDescarga = (u, nombre) {
                DownloadManager.instance.start(
                  u,
                  suggestedName: nombre.isEmpty ? null : nombre,
                );
              };
              widget.tabs.registerController(widget.tab.id, c);
            },
          ),
        ),
        if (_progress < 1)
          LinearProgressIndicator(value: _progress, minHeight: 2),
      ]),
    ]);
  }

  @override
  void dispose() {
    widget.tabs.forgetController(widget.tab.id);
    super.dispose();
  }
}
