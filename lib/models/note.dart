import 'checklist_item.dart';
import 'label.dart';

/// Model representasi catatan (teks atau checklist) dari backend Go-Keep
class Note {
  final int? id;
  final int userId;
  final String title;
  final String? content;
  final String type; // 'text' | 'checklist'
  final String color; // 'default', 'red', 'orange', dll.
  final bool isPinned;
  final bool isArchived;
  final DateTime? deletedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<ChecklistItem> checklistItems;
  final List<Label> labels;

  const Note({
    this.id,
    required this.userId,
    this.title = '',
    this.content,
    this.type = 'text',
    this.color = 'default',
    this.isPinned = false,
    this.isArchived = false,
    this.deletedAt,
    this.createdAt,
    this.updatedAt,
    this.checklistItems = const [],
    this.labels = const [],
  });

  /// Factory untuk membuat objek Note dari JSON respons backend Express
  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'] != null
          ? (json['id'] is int ? json['id'] as int : int.tryParse(json['id'].toString()))
          : null,
      userId: json['user_id'] != null
          ? (json['user_id'] is int ? json['user_id'] as int : int.tryParse(json['user_id'].toString()) ?? 0)
          : 0,
      title: json['title']?.toString() ?? '',
      content: json['content']?.toString(),
      type: json['type']?.toString() ?? 'text',
      color: json['color']?.toString() ?? 'default',
      isPinned: json['is_pinned'] == true ||
          json['is_pinned'] == 1 ||
          json['is_pinned'] == '1',
      isArchived: json['is_archived'] == true ||
          json['is_archived'] == 1 ||
          json['is_archived'] == '1',
      deletedAt: json['deleted_at'] != null
          ? DateTime.tryParse(json['deleted_at'].toString())
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
      checklistItems: json['checklist_items'] != null && json['checklist_items'] is List
          ? (json['checklist_items'] as List)
              .map((item) => ChecklistItem.fromJson(item as Map<String, dynamic>))
              .toList()
          : const [],
      labels: json['labels'] != null && json['labels'] is List
          ? (json['labels'] as List)
              .map((lbl) => Label.fromJson(lbl as Map<String, dynamic>))
              .toList()
          : const [],
    );
  }

  /// Serialisasi ke Map dengan format snake_case sesuai payload backend
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'title': title,
      if (content != null) 'content': content,
      'type': type,
      'color': color,
      'is_pinned': isPinned,
      'is_archived': isArchived,
      'deleted_at': deletedAt?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'checklist_items': checklistItems.map((item) => item.toJson()).toList(),
      'labels': labels.map((lbl) => lbl.toJson()).toList(),
    };
  }

  /// Helper status catatan
  bool get isActive => !isArchived && deletedAt == null;
  bool get isTrash => deletedAt != null;
  bool get isChecklist => type == 'checklist';

  Note copyWith({
    int? id,
    int? userId,
    String? title,
    String? content,
    String? type,
    String? color,
    bool? isPinned,
    bool? isArchived,
    DateTime? deletedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ChecklistItem>? checklistItems,
    List<Label>? labels,
  }) {
    return Note(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      content: content ?? this.content,
      type: type ?? this.type,
      color: color ?? this.color,
      isPinned: isPinned ?? this.isPinned,
      isArchived: isArchived ?? this.isArchived,
      deletedAt: deletedAt ?? this.deletedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      checklistItems: checklistItems ?? this.checklistItems,
      labels: labels ?? this.labels,
    );
  }

  @override
  String toString() =>
      'Note(id: $id, title: "$title", type: $type, color: $color, isPinned: $isPinned, isArchived: $isArchived)';
}

