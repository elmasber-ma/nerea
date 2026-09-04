import '../widgets/gui_node.dart';

/// Página ya parseada: título + lista de nodos de la GUI.
class PageModel {
  final String title;
  final List<GuiNode> body;

  PageModel({required this.title, required this.body});
}
