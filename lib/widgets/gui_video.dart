import 'gui_node.dart';

/// Reproductor de video embebido (media_kit). En Lua:
/// ```lua
/// { type = "video", width = 320, height = 180 }
/// ```
class GuiVideo extends GuiNode {
  GuiVideo({required super.style}) : super(type: 'video');

  factory GuiVideo.fromMap(Map<String, Object?> m) =>
      GuiVideo(style: GuiNode.parseStyle(m));
}
