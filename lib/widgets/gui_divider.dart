import 'gui_node.dart';

/// Separador horizontal. En Lua:
/// ```lua
/// { type = "divider", height = 24 }
/// ```
class GuiDivider extends GuiNode {
  GuiDivider({required super.style}) : super(type: 'divider');

  factory GuiDivider.fromMap(Map<String, Object?> m) =>
      GuiDivider(style: GuiNode.parseStyle(m));
}
