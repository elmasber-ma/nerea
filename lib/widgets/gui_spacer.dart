import 'gui_node.dart';

/// Espacio vertical. En Lua:
/// ```lua
/// { type = "spacer", space = 16 }
/// ```
class GuiSpacer extends GuiNode {
  final double space;

  GuiSpacer({required super.style, this.space = 16}) : super(type: 'spacer');

  factory GuiSpacer.fromMap(Map<String, Object?> m) => GuiSpacer(
        style: GuiNode.parseStyle(m),
        space: (m['space'] as num?)?.toDouble() ??
            (m['height'] as num?)?.toDouble() ??
            16,
      );
}
