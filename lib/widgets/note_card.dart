import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../models/note.dart';

/// Widget kartu catatan bergaya Google Keep
/// Menampilkan judul, isi teks, atau item checklist yang belum tercentang
class NoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback? onTap;

  const NoteCard({
    super.key,
    required this.note,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasTitle = note.title.trim().isNotEmpty;
    final isChecklist = note.type == 'checklist';
    final hasTextContent = !isChecklist && (note.content != null && note.content!.trim().isNotEmpty);

    final uncheckedItems = isChecklist
        ? note.checklistItems.where((i) => !i.isChecked).toList()
        : null;
    final checkedCount = isChecklist
        ? note.checklistItems.where((i) => i.isChecked).length
        : 0;
    final hasChecklistContent = isChecklist &&
        ((uncheckedItems != null && uncheckedItems.isNotEmpty) || checkedCount > 0);

    return Material(
      color: AppTheme.getNoteColor(note.color),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: AppTheme.getNoteBorderColor(note.color),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Judul catatan (jika ada)
              if (hasTitle)
                Text(
                  note.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                    height: 1.25,
                  ),
                ),

              // Jarak antara judul dan isi bila keduanya ada
              if (hasTitle && (hasTextContent || hasChecklistContent))
                const SizedBox(height: 8),

              // Isi catatan mode teks: dibatasi maksimal 10 baris dengan ellipsis
              if (hasTextContent)
                Text(
                  note.content!,
                  maxLines: 10,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textPrimary,
                    height: 1.35,
                  ),
                ),

              // Isi catatan mode checklist
              if (isChecklist && uncheckedItems != null) ...[
                // Item belum tercentang, maksimal 8 item
                ...uncheckedItems.take(8).map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 5.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.check_box_outline_blank_rounded,
                            size: 15,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item.text,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.textPrimary,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),

                // Tanda "…" jika item belum tercentang lebih dari 8
                if (uncheckedItems.length > 8)
                  const Padding(
                    padding: EdgeInsets.only(left: 23.0, bottom: 4.0),
                    child: Text(
                      '…',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                // Baris kecil abu-abu untuk jumlah item yang sudah tercentang
                if (checkedCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      '+ $checkedCount item tercentang',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
              ],

              // Chip Label (maksimal 2 chip, sisanya "+N")
              if (note.labels.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    ...note.labels.take(2).map((label) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.black.withValues(alpha: 0.1),
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            label.name,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        )),
                    if (note.labels.length > 2)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.black.withValues(alpha: 0.1),
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          '+${note.labels.length - 2}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

