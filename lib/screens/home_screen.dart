import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../models/label.dart';
import '../models/note.dart';
import '../providers/auth_provider.dart';
import '../providers/labels_provider.dart';
import '../providers/notes_provider.dart';
import '../widgets/app_drawer.dart';
import '../widgets/note_card.dart';
import 'note_editor_screen.dart';

/// Layar Utama (Home) Go-Keep dengan integrasi Navigation Drawer,
/// Tampilan Arsip, Sampah, Label, dan Fitur Polishing Google Keep.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  HomeViewType _currentView = HomeViewType.notes;
  Label? _currentLabel;

  bool _isSearchFocused = false;
  bool _isGrid = true;
  bool _isSpeedDialOpen = false;

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(() {
      setState(() {
        _isSearchFocused = _searchFocusNode.hasFocus;
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotesProvider>().fetchNotes();
      context.read<LabelsProvider>().fetchLabels();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _closeSearch() {
    _searchFocusNode.unfocus();
    _searchController.clear();
    context.read<NotesProvider>().clearSearch();
  }

  void _onSelectDrawerItem(HomeViewType view, Label? label) {
    setState(() {
      _currentView = view;
      _currentLabel = label;
      _isSpeedDialOpen = false;
    });

    _closeSearch();

    final notesProvider = context.read<NotesProvider>();
    switch (view) {
      case HomeViewType.notes:
        notesProvider.setFilter(status: 'active', labelId: null);
        break;
      case HomeViewType.label:
        notesProvider.setFilter(status: 'active', labelId: label?.id);
        break;
      case HomeViewType.archive:
        notesProvider.setFilter(status: 'archived', labelId: null);
        break;
      case HomeViewType.trash:
        notesProvider.setFilter(status: 'trash', labelId: null);
        break;
    }
  }

  Future<void> _openEditor({Note? note, String initialType = 'text'}) async {
    setState(() {
      _isSpeedDialOpen = false;
    });

    final isReadOnly = _currentView == HomeViewType.trash || (note != null && note.isTrash);
    final initialLabels = _currentLabel != null ? [_currentLabel!] : null;

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => NoteEditorScreen(
          note: note,
          initialType: initialType,
          isReadOnly: isReadOnly,
          initialLabels: initialLabels,
        ),
      ),
    );

    if (!mounted || result == null) return;

    final action = result['action'];
    final noteId = result['noteId'] as int?;
    if (noteId == null) return;

    final notesProvider = context.read<NotesProvider>();

    if (action == 'archive') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Catatan diarsipkan'),
          action: SnackBarAction(
            label: 'Urungkan',
            onPressed: () {
              notesProvider.unarchive(noteId);
            },
          ),
        ),
      );
    } else if (action == 'unarchive') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Catatan dikeluarkan dari arsip'),
          action: SnackBarAction(
            label: 'Urungkan',
            onPressed: () {
              notesProvider.archive(noteId);
            },
          ),
        ),
      );
    } else if (action == 'trash') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Catatan dipindahkan ke sampah'),
          action: SnackBarAction(
            label: 'Urungkan',
            onPressed: () {
              notesProvider.restore(noteId);
            },
          ),
        ),
      );
    } else if (action == 'restore') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Catatan dipulihkan'),
          action: SnackBarAction(
            label: 'Urungkan',
            onPressed: () {
              notesProvider.trash(noteId);
            },
          ),
        ),
      );
    } else if (action == 'delete_permanent') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Catatan berhasil dihapus secara permanen'),
        ),
      );
    }
  }

  void _showUserMenu() {
    final user = context.read<AuthProvider>().user;
    final initial = (user != null && user.name.isNotEmpty) ? user.name[0].toUpperCase() : 'U';

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: const Color(0xFF1A73E8),
                  child: Text(
                    initial,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  user?.name ?? 'Pengguna',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  user?.email ?? '',
                  style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 20),
                const Divider(height: 1, color: Color(0xFFE0E0E0)),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                  title: const Text(
                    'Keluar',
                    style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await context.read<AuthProvider>().logout();
                    if (mounted) {
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/login',
                        (route) => false,
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // Aksi Khusus: Sampah & Label
  // ===========================================================================

  void _confirmEmptyTrash() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Kosongkan sampah?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          content: const Text(
            'Semua catatan di tempat sampah akan dihapus secara permanen.',
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
                try {
                  await context.read<NotesProvider>().emptyTrash();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Tempat sampah berhasil dikosongkan')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.toString())),
                    );
                  }
                }
              },
              child: const Text('Kosongkan', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showRenameLabelDialog() {
    if (_currentLabel == null) return;
    final controller = TextEditingController(text: _currentLabel!.name);
    String? errorText;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Ganti nama label', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              content: TextField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Nama label',
                  errorText: errorText,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Batal', style: TextStyle(color: AppTheme.textSecondary)),
                ),
                TextButton(
                  onPressed: () async {
                    final newName = controller.text.trim();
                    if (newName.isEmpty) {
                      setDialogState(() => errorText = 'Nama label tidak boleh kosong.');
                      return;
                    }
                    try {
                      final updated = await context.read<LabelsProvider>().renameLabel(_currentLabel!.id, newName);
                      setState(() {
                        _currentLabel = updated;
                      });
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                      }
                    } catch (e) {
                      setDialogState(() {
                        errorText = e.toString().replaceAll('Exception: ', '');
                      });
                    }
                  },
                  child: const Text('Simpan', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDeleteCurrentLabel() {
    if (_currentLabel == null) return;
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Hapus label?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
                final labelId = _currentLabel!.id;
                try {
                  await context.read<LabelsProvider>().deleteLabel(labelId);
                  _onSelectDrawerItem(HomeViewType.notes, null);
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

  // ===========================================================================
  // Widget Top Bar
  // ===========================================================================

  Widget _buildTopBar(String userInitial) {
    final notesProvider = context.watch<NotesProvider>();
    final isSearching = notesProvider.isSearching;

    // Jika pada tampilan Catatan aktif: tampilkan kapsul pencarian penuh
    if (_currentView == HomeViewType.notes) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            if (_isSearchFocused || isSearching)
              IconButton(
                icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
                tooltip: 'Tutup pencarian',
                onPressed: _closeSearch,
              )
            else
              IconButton(
                icon: const Icon(Icons.menu, color: AppTheme.textPrimary),
                tooltip: 'Menu utama',
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),

            Expanded(
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F3F4),
                  borderRadius: BorderRadius.circular(28),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        onChanged: (query) => notesProvider.search(query),
                        style: const TextStyle(fontSize: 15, color: AppTheme.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Cari di Go-Keep',
                          hintStyle: TextStyle(
                            color: AppTheme.textSecondary.withValues(alpha: 0.8),
                            fontSize: 15,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20, color: AppTheme.textSecondary),
                        tooltip: 'Hapus teks',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          _searchController.clear();
                          notesProvider.search('');
                        },
                      ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        _isGrid ? Icons.view_agenda_outlined : Icons.grid_view_outlined,
                        size: 21,
                        color: AppTheme.textSecondary,
                      ),
                      tooltip: _isGrid ? 'Tampilan baris' : 'Tampilan kisi',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => setState(() => _isGrid = !_isGrid),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 10),

            GestureDetector(
              onTap: _showUserMenu,
              child: CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF1A73E8),
                child: Text(
                  userInitial,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Tampilan Arsip, Sampah, atau Label: AppBar bersih bergaya Keep
    String titleText = 'Go-Keep';
    if (_currentView == HomeViewType.archive) titleText = 'Arsip';
    if (_currentView == HomeViewType.trash) titleText = 'Sampah';
    if (_currentView == HomeViewType.label) titleText = _currentLabel?.name ?? 'Label';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.menu, color: AppTheme.textPrimary),
            tooltip: 'Menu utama',
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              titleText,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              _isGrid ? Icons.view_agenda_outlined : Icons.grid_view_outlined,
              size: 21,
              color: AppTheme.textSecondary,
            ),
            tooltip: _isGrid ? 'Tampilan baris' : 'Tampilan kisi',
            onPressed: () => setState(() => _isGrid = !_isGrid),
          ),

          // Menu titik tiga khusus Sampah
          if (_currentView == HomeViewType.trash)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: AppTheme.textPrimary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (val) {
                if (val == 'empty_trash') _confirmEmptyTrash();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'empty_trash',
                  child: Text('Kosongkan sampah'),
                ),
              ],
            ),

          // Menu titik tiga khusus Label (Ganti nama dan Hapus label)
          if (_currentView == HomeViewType.label)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: AppTheme.textPrimary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (val) {
                if (val == 'rename') _showRenameLabelDialog();
                if (val == 'delete') _confirmDeleteCurrentLabel();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'rename',
                  child: Text('Ganti nama label'),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Hapus label'),
                ),
              ],
            ),

          const SizedBox(width: 4),

          GestureDetector(
            onTap: _showUserMenu,
            child: CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF1A73E8),
              child: Text(
                userInitial,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Widget Catatan & Empty State
  // ===========================================================================

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 6.0, top: 8.0, bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppTheme.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildNotesGrid(List<Note> notes) {
    return MasonryGridView.count(
      crossAxisCount: _isGrid ? 2 : 1,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: notes.length,
      itemBuilder: (context, index) {
        final note = notes[index];
        return NoteCard(
          note: note,
          onTap: () => _openEditor(note: note),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    IconData icon;
    String message;

    switch (_currentView) {
      case HomeViewType.archive:
        icon = Icons.archive_outlined;
        message = 'Catatan yang diarsipkan akan muncul di sini';
        break;
      case HomeViewType.trash:
        icon = Icons.delete_outline_rounded;
        message = 'Tidak ada catatan di tempat sampah';
        break;
      case HomeViewType.label:
        icon = Icons.label_outline_rounded;
        message = 'Belum ada catatan dengan label "${_currentLabel?.name ?? ''}"';
        break;
      case HomeViewType.notes:
        icon = Icons.lightbulb_outline_rounded;
        message = 'Catatan yang Anda tambahkan akan muncul di sini';
        break;
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.65,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 96,
                  color: _currentView == HomeViewType.notes
                      ? AppTheme.primaryColor
                      : AppTheme.textSecondary.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notesProvider = context.watch<NotesProvider>();
    final user = context.watch<AuthProvider>().user;
    final userInitial = (user != null && user.name.isNotEmpty) ? user.name[0].toUpperCase() : 'U';

    final isSearching = notesProvider.isSearching;
    final pinnedNotes = notesProvider.pinnedNotes;
    final unpinnedNotes = notesProvider.unpinnedNotes;
    final allNotes = notesProvider.notes;

    final isInitialLoading = notesProvider.isLoading && allNotes.isEmpty;
    final hasError = notesProvider.errorMessage != null && allNotes.isEmpty;

    final showFab = _currentView == HomeViewType.notes || _currentView == HomeViewType.label;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      drawer: AppDrawer(
        currentView: _currentView,
        currentLabel: _currentLabel,
        onSelectView: _onSelectDrawerItem,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildTopBar(userInitial),
                Expanded(
                  child: RefreshIndicator(
                    color: AppTheme.primaryColor,
                    onRefresh: () => notesProvider.fetchNotes(silent: true),
                    child: Builder(
                      builder: (context) {
                        if (isInitialLoading) {
                          return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
                        }

                        if (hasError) {
                          return SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: SizedBox(
                              height: MediaQuery.of(context).size.height * 0.7,
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24.0),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.error_outline_rounded, size: 54, color: Colors.redAccent),
                                      const SizedBox(height: 16),
                                      Text(
                                        notesProvider.errorMessage ?? 'Gagal memuat catatan.',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
                                      ),
                                      const SizedBox(height: 20),
                                      ElevatedButton.icon(
                                        onPressed: () => notesProvider.fetchNotes(),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.primaryColor,
                                          foregroundColor: Colors.black,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                        icon: const Icon(Icons.refresh_rounded),
                                        label: const Text('Coba Lagi'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }

                        if (isSearching && allNotes.isEmpty) {
                          return SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: SizedBox(
                              height: MediaQuery.of(context).size.height * 0.65,
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.search_off_rounded, size: 72, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
                                    const SizedBox(height: 16),
                                    const Text('Tidak ada catatan yang cocok', style: TextStyle(fontSize: 15, color: AppTheme.textSecondary)),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }

                        if (allNotes.isEmpty) {
                          return _buildEmptyState();
                        }

                        if (isSearching) {
                          return SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            child: _buildNotesGrid(allNotes),
                          );
                        }

                        // Jika pada layar Arsip atau Sampah: tampilkan langsung seluruh catatan
                        if (_currentView == HomeViewType.archive || _currentView == HomeViewType.trash) {
                          return SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildNotesGrid(allNotes),
                                const SizedBox(height: 80),
                              ],
                            ),
                          );
                        }

                        // Layar Catatan Aktif & Label: tampilkan bagian Disematkan & Lainnya
                        final hasPinned = pinnedNotes.isNotEmpty;
                        final hasUnpinned = unpinnedNotes.isNotEmpty;

                        return SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (hasPinned) ...[
                                _buildSectionHeader('DISEMATKAN'),
                                _buildNotesGrid(pinnedNotes),
                              ],
                              if (hasPinned && hasUnpinned) ...[
                                const SizedBox(height: 16),
                                _buildSectionHeader('LAINNYA'),
                                _buildNotesGrid(unpinnedNotes),
                              ] else if (!hasPinned && hasUnpinned) ...[
                                _buildNotesGrid(unpinnedNotes),
                              ],
                              const SizedBox(height: 80),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),

            // Speed Dial Scrim Latar
            if (_isSpeedDialOpen)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _isSpeedDialOpen = false),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.35),
                  ),
                ),
              ),

            // Speed Dial FAB (Hanya tampil di tampilan Catatan dan Label)
            if (showFab)
              Positioned(
                bottom: 20,
                right: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isSpeedDialOpen) ...[
                      // Tombol Pil Atas: "Daftar"
                      GestureDetector(
                        onTap: () => _openEditor(initialType: 'checklist'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.18),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_box_outlined, size: 20, color: Color(0xFF001D35)),
                              SizedBox(width: 8),
                              Text('Daftar', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.textPrimary)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Tombol Pil Bawah: "Teks"
                      GestureDetector(
                        onTap: () => _openEditor(initialType: 'text'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.18),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.text_fields_rounded, size: 20, color: Color(0xFF001D35)),
                              SizedBox(width: 8),
                              Text('Teks', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.textPrimary)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    Material(
                      color: const Color(0xFFC2E7FF),
                      elevation: _isSpeedDialOpen ? 6 : 3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => setState(() => _isSpeedDialOpen = !_isSpeedDialOpen),
                        child: SizedBox(
                          width: 56,
                          height: 56,
                          child: Icon(
                            _isSpeedDialOpen ? Icons.close_rounded : Icons.add_rounded,
                            size: 28,
                            color: const Color(0xFF001D35),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
