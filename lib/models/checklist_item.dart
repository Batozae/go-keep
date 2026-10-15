/// Model representasi item dalam catatan bertipe 'checklist'
class ChecklistItem {
  final int? id;
  final int? noteId;
  final String text;
  final bool isChecked;
  final int position;

  const ChecklistItem({
    this.id,
    this.noteId,
    required this.text,
    this.isChecked = false,
    this.position = 0,
  });

  factory ChecklistItem.fromJson(Map<String, dynamic> json) {
    return ChecklistItem(
      id: json['id'] != null
          ? (json['id'] is int ? json['id'] as int : int.tryParse(json['id'].toString()))
          : null,
      noteId: json['note_id'] != null
          ? (json['note_id'] is int ? json['note_id'] as int : int.tryParse(json['note_id'].toString()))
          : null,
      text: json['text']?.toString() ?? '',
      isChecked: json['is_checked'] == true ||
          json['is_checked'] == 1 ||
          json['is_checked'] == '1',
      position: json['position'] != null
          ? (json['position'] is int
              ? json['position'] as int
              : int.tryParse(json['position'].toString()) ?? 0)
          : 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (noteId != null) 'note_id': noteId,
      'text': text,
      'is_checked': isChecked,
      'position': position,
    };
  }

  ChecklistItem copyWith({
    int? id,
    int? noteId,
    String? text,
    bool? isChecked,
    int? position,
  }) {
    return ChecklistItem(
      id: id ?? this.id,
      noteId: noteId ?? this.noteId,
      text: text ?? this.text,
      isChecked: isChecked ?? this.isChecked,
      position: position ?? this.position,
    );
  }

  @override
  String toString() =>
      'ChecklistItem(id: $id, text: "$text", isChecked: $isChecked, position: $position)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChecklistItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          text == other.text &&
          isChecked == other.isChecked &&
          position == other.position;

  @override
  int get hashCode => Object.hash(id, text, isChecked, position);
}

