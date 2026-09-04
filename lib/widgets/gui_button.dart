import 'gui_node.dart';

/// Botón. En Lua:
/// ```lua
/// { type = "button", text = "Ok", on_click = "saludar", width = 120, align = "center" }
/// ```
class GuiButton extends GuiNode {
  GuiButton({required super.style}) : super(type: 'button');

  factory GuiButton.fromMap(Map<String, Object?> m) =>
      GuiButton(style: GuiNode.parseStyle(m));
}
