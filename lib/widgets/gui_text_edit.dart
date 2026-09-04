import 'gui_node.dart';

/// Campo de entrada de texto. En Lua:
/// ```lua
/// { type = "input", id = "name", label = "Nombre", value = "Ana" }
/// ```
class GuiTextEdit extends GuiNode {
  final String? label;
  final String? value;

  GuiTextEdit({required super.style, this.label, this.value})
      : super(type: 'text_edit');

  factory GuiTextEdit.fromMap(Map<String, Object?> m) => GuiTextEdit(
        style: GuiNode.parseStyle(m),
        label: m['label'] as String?,
        value: m['value'] as String?,
      );
}
