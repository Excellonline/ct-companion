import '../models/note.dart';

class SearchService {
  static List<Note> filter(List<Note> notes, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return notes;
    return notes.where((n) {
      if (n.title.toLowerCase().contains(q)) return true;
      if (n.body.toLowerCase().contains(q)) return true;
      if (n.ownerLabel.toLowerCase().contains(q)) return true;
      if (n.tags.any((t) => t.toLowerCase().contains(q))) return true;
      if (n.items.any((i) => i.text.toLowerCase().contains(q))) return true;
      if (n.attachments.any((a) => a.name.toLowerCase().contains(q))) {
        return true;
      }
      return false;
    }).toList();
  }
}
