import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../models/label.dart';
import '../providers/labels_provider.dart';
import '../screens/edit_labels_screen.dart';

/// Jenis tampilan utama di HomeScreen
enum HomeViewType {
  notes, // Catatan aktif
  label, // Catatan berlabel tertentu
  archive, // Arsip
  trash, // Sampah
}

/// Dialog "Buat label baru"
Future<Label?> showCreateLabelDialog(BuildContext context) async {
  final controller = TextEditingController();
  String? errorMessage;

  return showDialog<Label>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text(
              'Buat label baru',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            content: TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Nama label',
                errorText: errorMessage,
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) async {
                final text = controller.text.trim();
                if (text.isEmpty) {
                  setState(() => errorMessage = 'Nama label tidak boleh kosong.');
                  return;
                }
                try {
                  final newLabel = await context.read<LabelsProvider>().createLabel(text);
                  if (ctx.mounted) {
                    Navigator.pop(ctx, newLabel);
                  }
                } catch (e) {
                  setState(() {
                    errorMessage = e.toString().replaceAll('Exception: ', '');
                  });
                }
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal', style: TextStyle(color: AppTheme.textSecondary)),
              ),
              TextButton(
                onPressed: () async {
                  final text = controller.text.trim();
                  if (text.isEmpty) {
                    setState(() => errorMessage = 'Nama label tidak boleh kosong.');
                    return;
                  }
                  try {
                    final newLabel = await context.read<LabelsProvider>().createLabel(text);
                    if (ctx.mounted) {
                      Navigator.pop(ctx, newLabel);
                    }
                  } catch (e) {
                    setState(() {
                      errorMessage = e.toString().replaceAll('Exception: ', '');
                    });
                  }
                },
                child: const Text(
                  'Buat',
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

/// Navigation Drawer Go-Keep bergaya Google Keep
class AppDrawer extends StatelessWidget {
  final HomeViewType currentView;
  final Label? currentLabel;
  final void Function(HomeViewType view, Label? label) onSelectView;

  const AppDrawer({
    super.key,
    required this.currentView,
    this.currentLabel,
    required this.onSelectView,
  });

  Widget _buildDrawerItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return Container(
      margin: const EdgeInsets.only(right: 12, top: 2, bottom: 2),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFC2E7FF) : Colors.transparent,
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(28)),
      ),
      child: ListTile(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(right: Radius.circular(28)),
        ),
        leading: Icon(
          icon,
          color: isSelected ? const Color(0xFF001D35) : AppTheme.textSecondary,
          size: 22,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? const Color(0xFF001D35) : AppTheme.textPrimary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 14,
          ),
        ),
        trailing: trailing,
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final labelsProvider = context.watch<LabelsProvider>();
    final labels = labelsProvider.labels;

    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Header Drawer "Go-Keep"
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lightbulb_outline_rounded,
                      color: AppTheme.primaryColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Go-Keep',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 6),

            // 1. Item: "Catatan" (ikon bohlam)
            _buildDrawerItem(
              context: context,
              icon: Icons.lightbulb_outline_rounded,
              title: 'Catatan',
              isSelected: currentView == HomeViewType.notes,
              onTap: () {
                Navigator.pop(context);
                onSelectView(HomeViewType.notes, null);
              },
            ),

            const SizedBox(height: 8),
            const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFE0E0E0)),
            const SizedBox(height: 8),

            // Header Bagian Label + Tombol "Edit"
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'LABEL',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                      letterSpacing: 0.8,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const EditLabelsScreen()),
                      );
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Edit',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 2. Daftar Label dari Backend
            ...labels.map((label) {
              final isSelected = currentView == HomeViewType.label && currentLabel?.id == label.id;
              return _buildDrawerItem(
                context: context,
                icon: Icons.label_outline_rounded,
                title: label.name,
                isSelected: isSelected,
                trailing: label.notesCount > 0
                    ? Text(
                        '${label.notesCount}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isSelected ? const Color(0xFF001D35) : AppTheme.textSecondary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      )
                    : null,
                onTap: () {
                  Navigator.pop(context);
                  onSelectView(HomeViewType.label, label);
                },
              );
            }),

            // 3. Item: "Buat label baru" (ikon plus)
            _buildDrawerItem(
              context: context,
              icon: Icons.add_rounded,
              title: 'Buat label baru',
              isSelected: false,
              onTap: () async {
                Navigator.pop(context);
                final created = await showCreateLabelDialog(context);
                if (created != null) {
                  onSelectView(HomeViewType.label, created);
                }
              },
            ),

            const SizedBox(height: 8),
            const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFE0E0E0)),
            const SizedBox(height: 8),

            // 4. Item: "Arsip" (ikon arsip)
            _buildDrawerItem(
              context: context,
              icon: Icons.archive_outlined,
              title: 'Arsip',
              isSelected: currentView == HomeViewType.archive,
              onTap: () {
                Navigator.pop(context);
                onSelectView(HomeViewType.archive, null);
              },
            ),

            // 5. Item: "Sampah" (ikon tempat sampah)
            _buildDrawerItem(
              context: context,
              icon: Icons.delete_outline_rounded,
              title: 'Sampah',
              isSelected: currentView == HomeViewType.trash,
              onTap: () {
                Navigator.pop(context);
                onSelectView(HomeViewType.trash, null);
              },
            ),
          ],
        ),
      ),
    );
  }
}

