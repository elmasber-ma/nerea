import 'gui_node.dart';

/// Imagen cargada desde una URL. En Lua:
/// ```lua
/// { type = "rect_image", src = "https://.../img.png", fit = "cover", width = 200, height = 120 }
/// ```
class GuiRectImage extends GuiNode {
  final String? src;
  final String? fit;

  GuiRectImage({required super.style, this.src, this.fit})
      : super(type: 'rect_image');

  factory GuiRectImage.fromMap(Map<String, Object?> m) => GuiRectImage(
        style: GuiNode.parseStyle(m),
        src: m['src'] as String?,
        fit: m['fit'] as String?,
      );
}
