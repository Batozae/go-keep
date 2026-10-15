import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../models/label.dart';
import '../providers/labels_provider.dart';
import '../providers/notes_provider.dart';

/// Layar "Edit label" untuk mengelola semua label (tambah baru, ganti nama, hapus)
class EditLabelsScreen extends StatefulWidget {
  const EditLabelsScreen({super.key});

  @override
  State<EditLabelsScreen> createState() => _EditLabelsScreenState();
}

class _EditLabelsScreenState extends State<EditLabelsScreen> {
  final TextEditingController _newLabelController = TextEditingController();
  final FocusNode _newLabelFocusNode = FocusNode();
  final Map<int, TextEditingController> _renameControllers = {};
  final Map<int, FocusNode> _renameFocusNodes = {};

  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LabelsProvider>().fetchLabels();
    });
  }

  @override
  void dispose() {
    _newLabelController.dispose();
    _newLabelFocusNode.dispose();
    for (final c in _renameControllers.values) {
      c.dispose();
    }
    for (final f in _renameFocusNodes.values) {
      f.dispose();
    }
    super.dispose();
  }

  TextEditingController _getRenameController(Label label) {
    if (!_renameControllers.containsKey(label.id)) {
      _renameControllers[label.id] = TextEditingController(text: label.name);
    }
    return _renameControllers[label.id]!;
  }

  FocusNode _getRenameFocusNode(Label label) {
    if (!_renameFocusNodes.containsKey(label.id)) {
      _renameFocusNodes[label.id] = FocusNode();
    }
    return _renameFocusNodes[label.id]!;
  }

  Future<void> _handleCreateLabel() async {
    final name = _newLabelController.text.trim();
    if (name.isEmpty) return;

    setState(() => _isCreating = true);
    final provider = context.read<LabelsProvider>();

    try {
      await provider.createLabel(name);
      _newLabelController.clear();
      _newLabelFocusNode.unfocus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  Future<void> _handleRenameLabel(Label label) async {
    final controller = _renameControllers[label.id];
    if (controller == null) return;

    final newName = controller.text.trim();
    if (newName.isEmpty) {
      controller.text = label.name;
      return;
    }
    if (newName == label.name) return;

    final provider = context.read<LabelsProvider>();
    try {
      await provider.renameLabel(label.id, newName);
      if (mounted) {
        _renameFocusNodes[label.id]?.unfocus();
      }
    } catch (e) {
      if (mounted) {
        controller.text = label.name;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _confirmDeleteLabel(Label label) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Hapus label?',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: const Text(
            'Label ini akan dihapus dan dilepaskan dari semua catatan Anda. Catatan tidak akan dihapus.',
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
                final labelsProvider = context.read<LabelsProvider>();
                final notesProvider = context.read<NotesProvider>();
                try {
                  await labelsProvider.deleteLabel(label.id);
                  // Jika saat ini sedang memfilter label yang dihapus, reset ke catatan aktif
                  if (notesProvider.currentLabelId == label.id) {
                    notesProvider.setFilter(status: 'active', labelId: null);
                  } else {
                    notesProvider.fetchNotes(silent: true);
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.toString())),
                    );
                  }
                }
              },
              child: const Text('Hapus', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final labelsProvider = context.watch<LabelsProvider>();
    final labels = labelsProvider.labels;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Edit label',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            // Baris Tambah Label Baru di Bagian Atas
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.add_rounded, color: AppTheme.textSecondary),
                  onPressed: () => _newLabelFocusNode.requestFocus(),
                ),
                Expanded(
                  child: TextField(
                    controller: _newLabelController,
                    focusNode: _newLabelFocusNode,
                    style: const TextStyle(fontSize: 15, color: AppTheme.textPrimary),
                    decoration: const InputDecoration(
                      hintText: 'Buat label baru',
                      hintStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _handleCreateLabel(),
                  ),
                ),
                if (_isCreating)
                  const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor),
                    ),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.check_rounded, color: AppTheme.primaryColor),
                    tooltip: 'Simpan label baru',
                    onPressed: _handleCreateLabel,
                  ),
              ],
            ),

            const Divider(height: 1, color: Color(0xFFE0E0E0)),
            const SizedBox(height: 8),

            // Daftar Semua Label yang Ada
            ...labels.map((label) {
              final controller = _getRenameController(label);
              final focusNode = _getRenameFocusNode(label);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.textSecondary),
                      tooltip: 'Hapus label',
                      onPressed: () => _confirmDeleteLabel(label),
                    ),
                    Expanded(
                      child: TextField(
                        controller: controller,
                        focusNode: focusNode,
                        style: const TextStyle(fontSize: 15, color: AppTheme.textPrimary),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                        ),
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _handleRenameLabel(label),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20, color: AppTheme.textSecondary),
                      tooltip: 'Ganti nama',
                      onPressed: () {
                        focusNode.requestFocus();
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.check_rounded, color: AppTheme.primaryColor),
                      tooltip: 'Simpan perubahan',
                      onPressed: () => _handleRenameLabel(label),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

