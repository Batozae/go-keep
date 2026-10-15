/// Model representasi label / tag kategori catatan
class Label {
  final int id;
  final String name;
  final int notesCount;

  const Label({
    required this.id,
    required this.name,
    this.notesCount = 0,
  });

  factory Label.fromJson(Map<String, dynamic> json) {
    return Label(
      id: json['id'] is int ? json['id'] as int : int.parse(json['id'].toString()),
      name: json['name']?.toString() ?? '',
      notesCount: json['notes_count'] != null
          ? (json['notes_count'] is int
              ? json['notes_count'] as int
              : int.tryParse(json['notes_count'].toString()) ?? 0)
          : 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'notes_count': notesCount,
    };
  }

  Label copyWith({
    int? id,
    String? name,
    int? notesCount,
  }) {
    return Label(
      id: id ?? this.id,
      name: name ?? this.name,
      notesCount: notesCount ?? this.notesCount,
    );
  }

  @override
  String toString() => 'Label(id: $id, name: $name, notesCount: $notesCount)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Label &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

