import 'ink_models.dart';

/// Modelo que representa uma Nota e seus dados associados
class NoteDocument {
  final String id;
  String title;
  final List<NoteDocument> children; // Subnotas hierárquicas
  final List<InkStroke> strokes;     // Desenhos vetoriais específicos desta nota
  double panX;
  double panY;

  NoteDocument({
    required this.id,
    required this.title,
    List<NoteDocument>? children,
    List<InkStroke>? strokes,
    this.panX = 0.0,
    this.panY = 0.0,
  })  : children = children ?? [],
        strokes = strokes ?? [];
}
