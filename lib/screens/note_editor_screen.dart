import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../models/checklist_item.dart';
import '../models/label.dart';
import '../models/note.dart';
import '../providers/labels_provider.dart';
import '../providers/notes_provider.dart';

/// Item sementara untuk pengeditan checklist di dalam NoteEditorScreen
class _EditorItem {
  int? id;
  bool isChecked;
  final TextEditingController controller;
  final FocusNode focusNode;

  _EditorItem({
    this.id,
    required String text,
    this.isChecked = false,
  })  : controller = TextEditingController(text: text),
        focusNode = FocusNode();

  void dispose() {
    controller.dispose();
    focusNode.dispose();
  }
}

/// Layar Editor Catatan (buat baru, ubah, atau mode baca saja untuk sampah)
class NoteEditorScreen extends StatefulWidget {
  final Note? note;
  final String initialType; // 'text' atau 'checklist'
  final bool isReadOnly;
  final List<Label>? initialLabels;

  const NoteEditorScreen({
    super.key,
    this.note,
    this.initialType = 'text',
    this.isReadOnly = false,
    this.initialLabels,
  });

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late FocusNode _contentFocusNode;

  late String _type;
  late String _selectedColor;
  late bool _isPinned;
  late List<Label> _selectedLabels;

  final List<_EditorItem> _items = [];
  bool _isExited = false;
  bool _isSaving = false;

  bool get _isTrashMode => widget.isReadOnly || (widget.note != null && widget.note!.isTrash);
  bool get _isArchivedMode => widget.note != null && widget.note!.isArchived;

  @override
  void initState() {
    super.initState();
    final note = widget.note;
    _type = note?.type ?? widget.initialType;
    _selectedColor = note?.color ?? 'default';
    _isPinned = note?.isPinned ?? false;

    _titleController = TextEditingController(text: note?.title ?? '');
    _contentController = TextEditingController(text: note?.content ?? '');
    _contentFocusNode = FocusNode();

    _selectedLabels = List<Label>.from(note?.labels ?? widget.initialLabels ?? const []);

    if (note != null && note.isChecklist) {
      for (final item in note.checklistItems) {
        _items.add(_EditorItem(
          id: item.id,
          text: item.text,
          isChecked: item.isChecked,
        ));
      }
    } else if (note == null && widget.initialType == 'checklist') {
      _items.add(_EditorItem(text: ''));
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _contentFocusNode.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  Color get _backgroundColor => AppTheme.getNoteColor(_selectedColor);

  // ===========================================================================
  // Manajemen Checklist
  // ===========================================================================

  void _addItem({int? afterIndex}) {
    if (_isTrashMode) return;
    final newItem = _EditorItem(text: '');
    setState(() {
      if (afterIndex != null && afterIndex >= 0 && afterIndex < _items.length) {
        _items.insert(afterIndex + 1, newItem);
      } else {
        _items.add(newItem);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        newItem.focusNode.requestFocus();
      }
    });
  }

  void _removeItem(_EditorItem item) {
    if (_isTrashMode) return;
    final index = _items.indexOf(item);
    if (index == -1) return;

    FocusNode? nextFocus;
    if (index > 0) {
      nextFocus = _items[index - 1].focusNode;
    }

    setState(() {
      _items.removeAt(index);
      item.dispose();
      if (_items.isEmpty) {
        _items.add(_EditorItem(text: ''));
      }
    });

    if (nextFocus != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          nextFocus?.requestFocus();
        }
      });
    }
  }

  // ===========================================================================
  // Konversi Mode Teks <-> Checklist
  // ===========================================================================

  void _convertTextToChecklist() {
    if (_isTrashMode) return;
    final rawText = _contentController.text;
    final lines = rawText.split('\n');

    for (final item in _items) {
      item.dispose();
    }
    _items.clear();

    for (final line in lines) {
      if (line.trim().isNotEmpty) {
        _items.add(_EditorItem(text: line));
      }
    }

    if (_items.isEmpty) {
      _items.add(_EditorItem(text: ''));
    }

    _contentController.clear();
    setState(() {
      _type = 'checklist';
    });
  }

  void _convertChecklistToText() {
    if (_isTrashMode) return;
    final buffer = StringBuffer();
    for (int i = 0; i < _items.length; i++) {
      final t = _items[i].controller.text.trim();
      if (t.isNotEmpty) {
        buffer.writeln(t);
      }
    }

    _contentController.text = buffer.toString().trim();

    for (final item in _items) {
      item.dispose();
    }
    _items.clear();

    setState(() {
      _type = 'text';
    });
  }

  // ===========================================================================
  // Simpan Otomatis & Logika Keluar
  // ===========================================================================

  bool _hasChecklistChanged() {
    final oldItems = widget.note?.checklistItems ?? const [];
    final currentNonEmpty = _items.where((i) => i.controller.text.trim().isNotEmpty).toList();

    if (oldItems.length != currentNonEmpty.length) return true;

    for (int i = 0; i < oldItems.length; i++) {
      if (oldItems[i].text != currentNonEmpty[i].controller.text ||
          oldItems[i].isChecked != currentNonEmpty[i].isChecked) {
        return true;
      }
    }
    return false;
  }

  bool _hasLabelsChanged() {
    final oldLabelIds = (widget.note?.labels ?? const []).map((l) => l.id).toSet();
    final newLabelIds = _selectedLabels.map((l) => l.id).toSet();
    return !setEquals(oldLabelIds, newLabelIds);
  }

  Future<void> _saveNote() async {
    if (_isTrashMode || _isSaving || _isExited) return;
    _isSaving = true;

    final provider = context.read<NotesProvider>();
    final title = _titleController.text.trim();
    final content = _type == 'text' ? _contentController.text.trim() : null;

    final currentItems = _items
        .where((i) => i.controller.text.trim().isNotEmpty)
        .map((i) => ChecklistItem(
              id: i.id,
              text: i.controller.text,
              isChecked: i.isChecked,
            ))
        .toList();

    final labelIds = _selectedLabels.map((l) => l.id).toList();

    // Catatan baru yang judul, isi, dan itemnya kosong tidak disimpan
    if (widget.note == null) {
      final isTitleEmpty = title.isEmpty;
      final isContentEmpty = content == null || content.isEmpty;
      final isItemsEmpty = currentItems.isEmpty;

      if (isTitleEmpty && isContentEmpty && isItemsEmpty) {
        return;
      }

      try {
        await provider.createNote(
          title: title,
          content: content,
          type: _type,
          color: _selectedColor,
          isPinned: _isPinned,
          checklistItems: currentItems,
          labelIds: labelIds.isNotEmpty ? labelIds : null,
        );
      } catch (_) {}
      return;
    }

    // Catatan lama tanpa perubahan tidak memanggil API
    final note = widget.note!;
    final titleChanged = title != note.title;
    final contentChanged = _type == 'text' && (content ?? '') != (note.content ?? '');
    final typeChanged = _type != note.type;
    final colorChanged = _selectedColor != note.color;
    final pinChanged = _isPinned != note.isPinned;
    final checklistChanged = _hasChecklistChanged();
    final labelsChanged = _hasLabelsChanged();

    if (!titleChanged &&
        !contentChanged &&
        !typeChanged &&
        !colorChanged &&
        !pinChanged &&
        !checklistChanged &&
        !labelsChanged) {
      return;
    }

    try {
      await provider.updateNote(
        id: note.id!,
        title: title,
        content: _type == 'text' ? content : '',
        type: _type,
        color: _selectedColor,
        isPinned: _isPinned,
        checklistItems: _type == 'checklist' ? currentItems : [],
        labelIds: labelIds,
      );
    } catch (_) {}
  }

  // ===========================================================================
  // Aksi Arsip, Unarchive, Hapus, Pulihkan, Hapus Permanen
  // ===========================================================================

  Future<void> _handleArchiveOrUnarchive() async {
    _isExited = true;
    final provider = context.read<NotesProvider>();

    if (widget.note != null) {
      final noteId = widget.note!.id!;
      if (_isArchivedMode) {
        // Keluarkan dari arsip
        Navigator.pop(context, {
          'action': 'unarchive',
          'noteId': noteId,
        });
        await provider.unarchive(noteId);
      } else {
        // Arsipkan
        Navigator.pop(context, {
          'action': 'archive',
          'noteId': noteId,
        });
        await provider.archive(noteId);
      }
    } else {
      // Catatan baru langsung diarsipkan
      final title = _titleController.text.trim();
      final content = _type == 'text' ? _contentController.text.trim() : null;
      final currentItems = _items
          .where((i) => i.controller.text.trim().isNotEmpty)
          .map((i) => ChecklistItem(
                text: i.controller.text,
                isChecked: i.isChecked,
              ))
          .toList();

      final labelIds = _selectedLabels.map((l) => l.id).toList();

      if (title.isNotEmpty || (content != null && content.isNotEmpty) || currentItems.isNotEmpty) {
        final newNote = await provider.createNote(
          title: title,
          content: content,
          type: _type,
          color: _selectedColor,
          isPinned: false,
          isArchived: true,
          checklistItems: currentItems,
          labelIds: labelIds.isNotEmpty ? labelIds : null,
        );
        if (mounted) {
          Navigator.pop(context, {
            'action': 'archive',
            'noteId': newNote.id,
          });
        }
      } else {
        Navigator.pop(context);
      }
    }
  }

  Future<void> _handleTrash() async {
    _isExited = true;
    final provider = context.read<NotesProvider>();

    if (widget.note != null) {
      final noteId = widget.note!.id!;
      Navigator.pop(context, {
        'action': 'trash',
        'noteId': noteId,
      });
      await provider.trash(noteId);
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _handleRestoreFromTrash() async {
    if (widget.note == null) return;
    _isExited = true;
    final provider = context.read<NotesProvider>();
    final noteId = widget.note!.id!;

    Navigator.pop(context, {
      'action': 'restore',
      'noteId': noteId,
    });
    await provider.restore(noteId);
  }

  void _confirmDeletePermanently() {
    if (widget.note == null) return;
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Hapus permanen?',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: const Text(
            'Catatan ini akan dihapus secara permanen dan tidak dapat dipulihkan.',
            style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                _isExited = true;
                final provider = context.read<NotesProvider>();
                final noteId = widget.note!.id!;

                if (mounted) {
                  Navigator.pop(context, {
                    'action': 'delete_permanent',
                    'noteId': noteId,
                  });
                }
                await provider.deletePermanently(noteId);
              },
              child: const Text(
                'Hapus',
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  // ===========================================================================
  // Bottom Sheet Pemilihan Warna & Label
  // ===========================================================================

  void _showColorPicker() {
    if (_isTrashMode) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Warna Catatan',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 60,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: AppTheme.supportedColorNames.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final colorName = AppTheme.supportedColorNames[index];
                      final color = AppTheme.getNoteColor(colorName);
                      final isSelected = _selectedColor.toLowerCase() == colorName.toLowerCase();

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedColor = colorName;
                          });
                          Navigator.pop(ctx);
                        },
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colorName == 'default'
                                  ? const Color(0xFFC0C0C0)
                                  : (isSelected ? AppTheme.textPrimary : Colors.transparent),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check_rounded,
                                  color: AppTheme.textPrimary,
                                  size: 24,
                                )
                              : null,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showLabelSelector() {
    if (_isTrashMode) return;
    final newLabelCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final labelsProvider = context.watch<LabelsProvider>();
            final allLabels = labelsProvider.labels;
            final query = newLabelCtrl.text.trim();

            final filteredLabels = query.isEmpty
                ? allLabels
                : allLabels.where((l) => l.name.toLowerCase().contains(query.toLowerCase())).toList();

            final exactMatch = allLabels.any((l) => l.name.toLowerCase() == query.toLowerCase());

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 18,
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 12,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Beri label catatan',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Input pembuatan label baru / pencarian
                    TextField(
                      controller: newLabelCtrl,
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Cari atau buat label',
                        hintStyle: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                        prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppTheme.textSecondary),
                        isDense: true,
                        filled: true,
                        fillColor: const Color(0xFFF1F3F4),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      onChanged: (_) => setSheetState(() {}),
                    ),
                    const SizedBox(height: 12),

                    // Opsi Buat Label Baru jika query belum ada di database
                    if (query.isNotEmpty && !exactMatch)
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.add_rounded, color: AppTheme.primaryColor),
                        title: Text(
                          'Buat "$query"',
                          style: const TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onTap: () async {
                          final labelsProvider = context.read<LabelsProvider>();
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            final created = await labelsProvider.createLabel(query);
                            if (mounted) {
                              setState(() {
                                _selectedLabels.add(created);
                              });
                            }
                            newLabelCtrl.clear();
                            setSheetState(() {});
                          } catch (e) {
                            if (mounted) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(e.toString().replaceAll('Exception: ', '')),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            }
                          }
                        },
                      ),

                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(ctx).size.height * 0.4,
                      ),
                      child: filteredLabels.isEmpty && query.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20.0),
                              child: Center(
                                child: Text(
                                  'Belum ada label. Buat label baru di atas.',
                                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                                ),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: filteredLabels.length,
                              itemBuilder: (context, index) {
                                final label = filteredLabels[index];
                                final isChecked = _selectedLabels.any((l) => l.id == label.id);

                                return CheckboxListTile(
                                  value: isChecked,
                                  dense: true,
                                  title: Text(label.name, style: const TextStyle(fontSize: 14)),
                                  controlAffinity: ListTileControlAffinity.leading,
                                  contentPadding: EdgeInsets.zero,
                                  activeColor: AppTheme.primaryColor,
                                  onChanged: (val) {
                                    setState(() {
                                      if (val == true) {
                                        _selectedLabels.add(label);
                                      } else {
                                        _selectedLabels.removeWhere((l) => l.id == label.id);
                                      }
                                    });
                                    setSheetState(() {});
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ===========================================================================
  // UI Builder
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final uncheckedItems = _items.where((i) => !i.isChecked).toList();
    final checkedItems = _items.where((i) => i.isChecked).toList();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        await _saveNote();
        if (mounted) {
          nav.pop();
        }
      },
      child: Scaffold(
        backgroundColor: _backgroundColor,
        appBar: AppBar(
          backgroundColor: _backgroundColor,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
            tooltip: 'Kembali',
            onPressed: () async {
              final nav = Navigator.of(context);
              await _saveNote();
              if (mounted) {
                nav.pop();
              }
            },
          ),
          actions: [
            // Mode Sampah (Read-only): Aksi Pulihkan dan Hapus Permanen di AppBar
            if (_isTrashMode) ...[
              IconButton(
                icon: const Icon(Icons.restore_from_trash_outlined, color: AppTheme.textPrimary),
                tooltip: 'Pulihkan',
                onPressed: _handleRestoreFromTrash,
              ),
              IconButton(
                icon: const Icon(Icons.delete_forever_outlined, color: Colors.redAccent),
                tooltip: 'Hapus permanen',
                onPressed: _confirmDeletePermanently,
              ),
              const SizedBox(width: 8),
            ] else ...[
              // Mode Normal: Tombol Pin (jika bukan catatan arsip)
              if (!_isArchivedMode)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: IconButton(
                    icon: Icon(
                      _isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                      color: AppTheme.textPrimary,
                      size: 20,
                    ),
                    tooltip: _isPinned ? 'Lepas sematan' : 'Sematkan',
                    onPressed: () {
                      setState(() {
                        _isPinned = !_isPinned;
                      });
                    },
                  ),
                ),

              // Tombol Arsip / Keluarkan dari Arsip
              Container(
                margin: const EdgeInsets.only(right: 14),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: IconButton(
                  icon: Icon(
                    _isArchivedMode ? Icons.unarchive_outlined : Icons.archive_outlined,
                    color: AppTheme.textPrimary,
                    size: 20,
                  ),
                  tooltip: _isArchivedMode ? 'Keluarkan dari arsip' : 'Arsipkan',
                  onPressed: _handleArchiveOrUnarchive,
                ),
              ),
            ],
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Judul catatan besar tanpa garis bawah
                      TextField(
                        controller: _titleController,
                        readOnly: _isTrashMode,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                          height: 1.3,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Judul',
                          hintStyle: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textSecondary.withValues(alpha: 0.55),
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        maxLines: null,
                        textCapitalization: TextCapitalization.sentences,
                      ),

                      const SizedBox(height: 12),

                      // Tampilan Isi Catatan Mode Teks
                      if (_type == 'text')
                        TextField(
                          controller: _contentController,
                          focusNode: _contentFocusNode,
                          readOnly: _isTrashMode,
                          style: const TextStyle(
                            fontSize: 16,
                            color: AppTheme.textPrimary,
                            height: 1.45,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Catatan',
                            hintStyle: TextStyle(
                              fontSize: 16,
                              color: AppTheme.textSecondary.withValues(alpha: 0.55),
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                          maxLines: null,
                          keyboardType: TextInputType.multiline,
                        ),

                      // Tampilan Isi Catatan Mode Checklist
                      if (_type == 'checklist') ...[
                        ReorderableListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          buildDefaultDragHandles: false,
                          itemCount: uncheckedItems.length,
                          onReorderItem: (oldIndex, newIndex) {
                            if (_isTrashMode) return;
                            setState(() {
                              final movedItem = uncheckedItems.removeAt(oldIndex);
                              uncheckedItems.insert(newIndex, movedItem);

                              _items.remove(movedItem);
                              final targetIndex = newIndex < uncheckedItems.length - 1
                                  ? _items.indexOf(uncheckedItems[newIndex + 1])
                                  : _items.indexOf(uncheckedItems[newIndex]);
                              _items.insert(targetIndex, movedItem);
                            });
                          },
                          itemBuilder: (context, index) {
                            final item = uncheckedItems[index];
                            return KeyedSubtree(
                              key: ValueKey(item),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    if (!_isTrashMode)
                                      ReorderableDragStartListener(
                                        index: index,
                                        child: Container(
                                          padding: const EdgeInsets.only(right: 6),
                                          child: Icon(
                                            Icons.drag_indicator_rounded,
                                            size: 20,
                                            color: AppTheme.textSecondary.withValues(alpha: 0.4),
                                          ),
                                        ),
                                      ),

                                    Checkbox(
                                      value: item.isChecked,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      onChanged: _isTrashMode
                                          ? null
                                          : (val) {
                                              setState(() {
                                                item.isChecked = val ?? false;
                                              });
                                            },
                                    ),

                                    Expanded(
                                      child: Focus(
                                        onKeyEvent: (node, event) {
                                          if (!_isTrashMode &&
                                              event is KeyDownEvent &&
                                              event.logicalKey == LogicalKeyboardKey.backspace &&
                                              item.controller.text.isEmpty) {
                                            _removeItem(item);
                                            return KeyEventResult.handled;
                                          }
                                          return KeyEventResult.ignored;
                                        },
                                        child: TextField(
                                          controller: item.controller,
                                          focusNode: item.focusNode,
                                          readOnly: _isTrashMode,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            color: AppTheme.textPrimary,
                                          ),
                                          decoration: const InputDecoration(
                                            border: InputBorder.none,
                                            isDense: true,
                                            contentPadding: EdgeInsets.symmetric(vertical: 6),
                                          ),
                                          textInputAction: TextInputAction.next,
                                          onSubmitted: (_) {
                                            if (!_isTrashMode) {
                                              final currentIndex = _items.indexOf(item);
                                              _addItem(afterIndex: currentIndex);
                                            }
                                          },
                                        ),
                                      ),
                                    ),

                                    if (!_isTrashMode)
                                      IconButton(
                                        icon: const Icon(
                                          Icons.close_rounded,
                                          size: 18,
                                          color: AppTheme.textSecondary,
                                        ),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () => _removeItem(item),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),

                        if (!_isTrashMode)
                          InkWell(
                            onTap: () => _addItem(),
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 4.0),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.add_rounded,
                                    size: 20,
                                    color: AppTheme.textSecondary,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Item daftar',
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: AppTheme.textSecondary.withValues(alpha: 0.85),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        if (checkedItems.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const Divider(height: 1, color: Color(0xFFE0E0E0)),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10.0),
                            child: Text(
                              '${checkedItems.length} item tercentang',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ),
                          ...checkedItems.map((item) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    const SizedBox(width: 26),
                                    Checkbox(
                                      value: item.isChecked,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      onChanged: _isTrashMode
                                          ? null
                                          : (val) {
                                              setState(() {
                                                item.isChecked = val ?? false;
                                              });
                                            },
                                    ),
                                    Expanded(
                                      child: TextField(
                                        controller: item.controller,
                                        focusNode: item.focusNode,
                                        readOnly: _isTrashMode,
                                        style: TextStyle(
                                          fontSize: 15,
                                          color: AppTheme.textSecondary.withValues(alpha: 0.65),
                                          decoration: TextDecoration.lineThrough,
                                        ),
                                        decoration: const InputDecoration(
                                          border: InputBorder.none,
                                          isDense: true,
                                          contentPadding: EdgeInsets.symmetric(vertical: 6),
                                        ),
                                      ),
                                    ),
                                    if (!_isTrashMode)
                                      IconButton(
                                        icon: const Icon(
                                          Icons.close_rounded,
                                          size: 18,
                                          color: AppTheme.textSecondary,
                                        ),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () => _removeItem(item),
                                      ),
                                  ],
                                ),
                              )),
                        ],
                      ],

                      // =======================================================
                      // Chip Label Catatan pada Editor
                      // =======================================================
                      if (_selectedLabels.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _selectedLabels.map((lbl) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.black.withValues(alpha: 0.12),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    lbl.name,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textPrimary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (!_isTrashMode) ...[
                                    const SizedBox(width: 4),
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _selectedLabels.removeWhere((l) => l.id == lbl.id);
                                        });
                                      },
                                      child: const Icon(
                                        Icons.close_rounded,
                                        size: 15,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Bar Bawah
              if (_isTrashMode)
                // Bar Bawah Khusus Sampah: Aksi Pulihkan & Hapus Permanen
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: _backgroundColor,
                    border: Border(
                      top: BorderSide(
                        color: Colors.black.withValues(alpha: 0.08),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _handleRestoreFromTrash,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.restore_from_trash_outlined, size: 18),
                        label: const Text('Pulihkan'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _confirmDeletePermanently,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(color: Colors.redAccent),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        icon: const Icon(Icons.delete_forever_outlined, size: 18),
                        label: const Text('Hapus permanen'),
                      ),
                    ],
                  ),
                )
              else
                // Bar Bawah Normal (Palet, Diedit jam, Titik Tiga)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _backgroundColor,
                    border: Border(
                      top: BorderSide(
                        color: Colors.black.withValues(alpha: 0.06),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Ikon Palet untuk memilih warna
                      IconButton(
                        icon: const Icon(Icons.palette_outlined, color: AppTheme.textPrimary),
                        tooltip: 'Pilih warna',
                        onPressed: _showColorPicker,
                      ),

                      // Teks Tengah: "Diedit <jam>" (intl, locale Indonesia) pada catatan yang sudah ada
                      Expanded(
                        child: Center(
                          child: widget.note?.updatedAt != null
                              ? Text(
                                  'Diedit ${DateFormat('HH:mm').format(widget.note!.updatedAt!.toLocal())}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),

                      // Ikon Titik Tiga (Menu Opsi: Hapus, Label, dan Switch Checklist/Teks)
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert_rounded, color: AppTheme.textPrimary),
                        tooltip: 'Opsi lainnya',
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        onSelected: (value) {
                          if (value == 'trash') {
                            _handleTrash();
                          } else if (value == 'labels') {
                            _showLabelSelector();
                          } else if (value == 'toggle_checkbox') {
                            if (_type == 'checklist') {
                              _convertChecklistToText();
                            } else {
                              _convertTextToChecklist();
                            }
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'trash',
                            child: const Row(
                              children: [
                                Icon(Icons.delete_outline_rounded, size: 20, color: AppTheme.textPrimary),
                                SizedBox(width: 12),
                                Text('Hapus', style: TextStyle(color: AppTheme.textPrimary)),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'labels',
                            child: Row(
                              children: [
                                Icon(Icons.label_outline_rounded, size: 20, color: AppTheme.textPrimary),
                                SizedBox(width: 12),
                                Text('Label', style: TextStyle(color: AppTheme.textPrimary)),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'toggle_checkbox',
                            child: Row(
                              children: [
                                Icon(
                                  _type == 'checklist'
                                      ? Icons.check_box_outline_blank_rounded
                                      : Icons.check_box_outlined,
                                  size: 20,
                                  color: AppTheme.textPrimary,
                                ),
                                SizedBox(width: 12),
                                Text(
                                  _type == 'checklist'
                                      ? 'Sembunyikan kotak centang'
                                      : 'Tampilkan kotak centang',
                                  style: const TextStyle(color: AppTheme.textPrimary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
