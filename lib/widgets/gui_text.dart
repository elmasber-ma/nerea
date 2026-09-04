import 'gui_node.dart';

/// Texto (o encabezado si `heading`). En Lua:
/// ```lua
/// { type = "text", text = "Hola", align = "center", font = { size = 18, bold = true } }
/// ```
class GuiText extends GuiNode {
  final bool heading;

  GuiText({required super.style, this.heading = false})
      : super(type: heading ? 'heading' : 'text');

  factory GuiText.fromMap(Map<String, Object?> m, {bool heading = false}) =>
      GuiText(style: GuiNode.parseStyle(m), heading: heading);
}
