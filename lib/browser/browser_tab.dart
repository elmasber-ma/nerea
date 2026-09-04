/// Contrato mínimo de pestaña para desacoplar widgets de la clase concreta.
abstract class BrowserTabLike {
  int get id;
  String get url;
}

/// Una pestaña del browser Gecko. Solo datos: el estado vivo del motor
/// vive en [BrowserTabs] vía los controladores que registra
/// [BrowserWebview] al crearse.
class BrowserTab implements BrowserTabLike {
  BrowserTab({
    required this.id,
    this.title = 'Nueva pestaña',
    this.url = 'https://duckduckgo.com/',
  });

  @override
  final int id;
  String title;
  @override
  String url;

  void dispose() {}
}
