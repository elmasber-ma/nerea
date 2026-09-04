/// Descriptor de fuente/estilo de texto, definible desde Lua.
///
/// En Lua:
/// ```lua
/// { type = "text", text = "Hola", font = { size = 18, bold = true, italic = false, color = "#1976d2", family = "monospace" } }
/// ```
class GuiFont {
  final String? family;
  final double? size;
  final bool bold;
  final bool italic;
  final String? color;

  const GuiFont({
    this.family,
    this.size,
    this.bold = false,
    this.italic = false,
    this.color,
  });

  factory GuiFont.fromMap(Map<String, Object?>? m) {
    if (m == null) return const GuiFont();
    return GuiFont(
      family: m['family'] as String?,
      size: (m['size'] as num?)?.toDouble(),
      bold: m['bold'] == true,
      italic: m['italic'] == true,
      color: m['color'] as String?,
    );
  }
}
