import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/checklist_item.dart';
import '../models/note.dart';
import '../services/api_service.dart';

/// Provider pengelola status catatan aktif, arsip, sampah, dan label,
/// serta operasi CRUD catatan dengan Optimistic UI & rollback.
class NotesProvider with ChangeNotifier {
  final ApiService _apiService;

  List<Note> _notes = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _searchQuery = '';
  Timer? _debounceTimer;

  // Filter tampilan saat ini: 'active', 'archived', 'trash'
  String _currentStatus = 'active';
  // Filter label saat ini (opsional)
  int? _currentLabelId;

  // Cache catatan yang baru diarsipkan / dibuang ke tempat sampah / dipulihkan untuk aksi Urungkan
  final Map<int, Note> _recentRemovedNotes = {};

  NotesProvider(this._apiService);

  // ===========================================================================
  // Getters
  // ===========================================================================

  List<Note> get notes => List.unmodifiable(_notes);
  List<Note> get pinnedNotes => _notes.where((n) => n.isPinned).toList();
  List<Note> get unpinnedNotes => _notes.where((n) => !n.isPinned).toList();
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  bool get isSearching => _searchQuery.trim().isNotEmpty;

  String get currentStatus => _currentStatus;
  int? get currentLabelId => _currentLabelId;

  /// Membersihkan pesan error
  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  /// Mengatur filter status dan label tampilan
  void setFilter({String status = 'active', int? labelId, bool fetch = true}) {
    _currentStatus = status;
    _currentLabelId = labelId;
    _searchQuery = '';
    _debounceTimer?.cancel();
    if (fetch) {
      fetchNotes(silent: false);
    } else {
      notifyListeners();
    }
  }

  /// Mengurutkan catatan lokal: disematkan di atas, lalu updated_at terbaru
  void _sortNotes() {
    _notes.sort((a, b) {
      if (a.isPinned != b.isPinned) {
        return a.isPinned ? -1 : 1;
      }
      final aDate = a.updatedAt ?? a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.updatedAt ?? b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
  }

  // ===========================================================================
  // Operasi Fetch & Search
  // ===========================================================================

  /// Mengambil daftar catatan dari backend (GET /notes?status=&q=&label_id=)
  Future<void> fetchNotes({bool silent = false, String? status, int? labelId}) async {
    if (status != null) _currentStatus = status;
    if (labelId != null) _currentLabelId = labelId;

    if (!silent) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final fetched = await _apiService.getNotes(
        status: _currentStatus,
        query: _searchQuery.trim().isNotEmpty ? _searchQuery.trim() : null,
        labelId: _currentLabelId,
      );
      _notes = fetched;
      _sortNotes();
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Pencarian dengan debounce 400 ms memanggil GET /notes?q=
  void search(String query) {
    _searchQuery = query;
    _debounceTimer?.cancel();

    if (query.trim().isEmpty) {
      fetchNotes(silent: false);
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      fetchNotes(silent: false);
    });
  }

  /// Menutup/membersihkan pencarian secara instan
  void clearSearch() {
    _debounceTimer?.cancel();
    if (_searchQuery.isNotEmpty) {
      _searchQuery = '';
      fetchNotes(silent: false);
    }
  }

  // ===========================================================================
  // Operasi CRUD dengan Pembaruan State Lokal (Optimistic UI) & Rollback
  // ===========================================================================

  /// Membuat catatan baru (POST /notes)
  Future<Note> createNote({
    required String title,
    String? content,
    String type = 'text',
    String color = 'default',
    bool isPinned = false,
    bool isArchived = false,
    List<ChecklistItem>? checklistItems,
    List<int>? labelIds,
  }) async {
    try {
      final itemsPayload = checklistItems?.map((item) => {
        'text': item.text,
        'is_checked': item.isChecked,
        'position': item.position,
      }).toList();

      // Jika sedang berada di layar label tertentu dan belum ada di labelIds, tambahkan otomatis
      final effectiveLabelIds = List<int>.from(labelIds ?? const []);
      if (_currentLabelId != null && !effectiveLabelIds.contains(_currentLabelId!)) {
        effectiveLabelIds.add(_currentLabelId!);
      }

      final newNote = await _apiService.createNote(
        title: title,
        content: content,
        type: type,
        color: color,
        isPinned: isPinned,
        isArchived: isArchived,
        checklistItems: itemsPayload,
        labelIds: effectiveLabelIds.isNotEmpty ? effectiveLabelIds : null,
      );

      // Tambahkan ke daftar jika sesuai dengan filter tampilan saat ini
      final shouldDisplay = (_currentStatus == 'active' && !newNote.isArchived) ||
          (_currentStatus == 'archived' && newNote.isArchived);

      if (shouldDisplay) {
        _notes.insert(0, newNote);
        _sortNotes();
        notifyListeners();
      }

      return newNote;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Memperbarui catatan (PUT /notes/:id) dengan optimistic update & rollback
  Future<Note> updateNote({
    required int id,
    String? title,
    String? content,
    String? type,
    String? color,
    bool? isPinned,
    bool? isArchived,
    List<ChecklistItem>? checklistItems,
    List<int>? labelIds,
  }) async {
    final index = _notes.indexWhere((n) => n.id == id);
    Note? backupNote;

    if (index != -1) {
      backupNote = _notes[index];
      // Optimistic update lokal
      _notes[index] = backupNote.copyWith(
        title: title ?? backupNote.title,
        content: content ?? backupNote.content,
        type: type ?? backupNote.type,
        color: color ?? backupNote.color,
        isPinned: isPinned ?? backupNote.isPinned,
        isArchived: isArchived ?? backupNote.isArchived,
        checklistItems: checklistItems ?? backupNote.checklistItems,
        updatedAt: DateTime.now(),
      );
      _sortNotes();
      notifyListeners();
    }

    try {
      final itemsPayload = checklistItems?.asMap().entries.map((entry) => {
        'text': entry.value.text,
        'is_checked': entry.value.isChecked,
        'position': entry.key,
      }).toList();

      final updated = await _apiService.updateNote(
        id,
        title: title,
        content: content,
        type: type,
        color: color,
        isPinned: isPinned,
        isArchived: isArchived,
        checklistItems: itemsPayload,
        labelIds: labelIds,
      );

      final curIndex = _notes.indexWhere((n) => n.id == id);
      if (curIndex != -1) {
        _notes[curIndex] = updated;
        _sortNotes();
        notifyListeners();
      }

      return updated;
    } catch (e) {
      // Rollback jika request API gagal
      if (index != -1 && backupNote != null) {
        final curIndex = _notes.indexWhere((n) => n.id == id);
        if (curIndex != -1) {
          _notes[curIndex] = backupNote;
        } else {
          _notes.insert(index, backupNote);
        }
        _sortNotes();
      }
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Toggle pin catatan (PATCH /notes/:id/pin) dengan optimistic update & rollback
  Future<void> togglePin(int noteId) async {
    final index = _notes.indexWhere((n) => n.id == noteId);
    if (index == -1) return;

    final backupNote = _notes[index];
    final targetPinned = !backupNote.isPinned;

    _notes[index] = backupNote.copyWith(isPinned: targetPinned);
    _sortNotes();
    notifyListeners();

    try {
      final updated = await _apiService.togglePin(noteId);
      final curIndex = _notes.indexWhere((n) => n.id == noteId);
      if (curIndex != -1) {
        _notes[curIndex] = updated;
        _sortNotes();
        notifyListeners();
      }
    } catch (e) {
      final curIndex = _notes.indexWhere((n) => n.id == noteId);
      if (curIndex != -1) {
        _notes[curIndex] = backupNote;
        _sortNotes();
      }
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Arsipkan catatan (PATCH /notes/:id/archive)
  Future<void> archive(int noteId) async {
    final index = _notes.indexWhere((n) => n.id == noteId);
    Note? backupNote;
    if (index != -1) {
      backupNote = _notes[index];
      _recentRemovedNotes[noteId] = backupNote.copyWith(
        isPinned: false,
        isArchived: true,
      );
      // Jika di layar aktif atau label, arsipkan mengeluarkan catatan dari daftar aktif
      if (_currentStatus == 'active') {
        _notes.removeAt(index);
        notifyListeners();
      }
    }

    try {
      final updated = await _apiService.toggleArchive(noteId);
      // Jika saat ini di layar arsip, catatan yang diarsipkan muncul di sini
      if (_currentStatus == 'archived') {
        final curIndex = _notes.indexWhere((n) => n.id == noteId);
        if (curIndex == -1) {
          _notes.insert(0, updated);
          _sortNotes();
          notifyListeners();
        }
      }
    } catch (e) {
      if (index != -1 && backupNote != null && _currentStatus == 'active') {
        final insertIndex = index <= _notes.length ? index : _notes.length;
        _notes.insert(insertIndex, backupNote);
        _sortNotes();
      }
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Batalkan arsip (Keluarkan dari arsip = toggle archive kembali)
  Future<void> unarchive(int noteId) async {
    final index = _notes.indexWhere((n) => n.id == noteId);
    Note? backupNote;

    if (index != -1) {
      backupNote = _notes[index];
    }

    final cached = _recentRemovedNotes[noteId];
    final restoredOptimistic = (cached ?? backupNote ?? Note(
      id: noteId,
      userId: 0,
      title: '',
    )).copyWith(
      isPinned: false,
      isArchived: false,
    );

    _recentRemovedNotes[noteId] = restoredOptimistic;

    // Jika di layar arsip, mengeluarkan dari arsip menghapus dari daftar arsip
    if (_currentStatus == 'archived' && index != -1) {
      _notes.removeAt(index);
      notifyListeners();
    } else if (_currentStatus == 'active') {
      // Jika di layar aktif (Urungkan arsip), masukkan kembali
      _notes.insert(0, restoredOptimistic);
      _sortNotes();
      notifyListeners();
    }

    try {
      final updated = await _apiService.toggleArchive(noteId);
      if (_currentStatus == 'active') {
        final curIndex = _notes.indexWhere((n) => n.id == noteId);
        if (curIndex != -1) {
          _notes[curIndex] = updated.copyWith(isPinned: false);
        } else {
          _notes.insert(0, updated.copyWith(isPinned: false));
        }
        _sortNotes();
        notifyListeners();
      }
    } catch (e) {
      if (backupNote != null && _currentStatus == 'archived') {
        _notes.insert(index <= _notes.length ? index : _notes.length, backupNote);
        _sortNotes();
      } else if (_currentStatus == 'active') {
        _notes.removeWhere((n) => n.id == noteId);
      }
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Pindahkan catatan ke tempat sampah (PATCH /notes/:id/trash)
  Future<void> trash(int noteId) async {
    final index = _notes.indexWhere((n) => n.id == noteId);
    Note? backupNote;
    if (index != -1) {
      backupNote = _notes[index];
      _recentRemovedNotes[noteId] = backupNote.copyWith(
        isPinned: false,
        deletedAt: DateTime.now(),
      );
      // Hapus dari layar aktif, arsip, atau label
      _notes.removeAt(index);
      notifyListeners();
    }

    try {
      await _apiService.moveToTrash(noteId);
    } catch (e) {
      if (index != -1 && backupNote != null) {
        final insertIndex = index <= _notes.length ? index : _notes.length;
        _notes.insert(insertIndex, backupNote);
        _sortNotes();
      }
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Memulihkan catatan dari tempat sampah (PATCH /notes/:id/restore)
  Future<void> restore(int noteId) async {
    final index = _notes.indexWhere((n) => n.id == noteId);
    Note? backupNote;

    if (index != -1) {
      backupNote = _notes[index];
    }

    final cached = _recentRemovedNotes[noteId];
    final restoredOptimistic = (cached ?? backupNote ?? Note(
      id: noteId,
      userId: 0,
      title: '',
    )).copyWith(
      isPinned: false,
      deletedAt: null,
    );

    // Jika sedang di layar Sampah, pulihkan menghapus dari daftar sampah
    if (_currentStatus == 'trash' && index != -1) {
      _notes.removeAt(index);
      notifyListeners();
    } else if (_currentStatus == 'active') {
      // Jika di layar aktif (misal Urungkan hapus), tambahkan kembali
      _notes.insert(0, restoredOptimistic);
      _sortNotes();
      notifyListeners();
    }

    try {
      final updated = await _apiService.restoreFromTrash(noteId);
      if (_currentStatus == 'active') {
        final curIndex = _notes.indexWhere((n) => n.id == noteId);
        if (curIndex != -1) {
          _notes[curIndex] = updated.copyWith(isPinned: false);
        } else {
          _notes.insert(0, updated.copyWith(isPinned: false));
        }
        _sortNotes();
        notifyListeners();
      }
    } catch (e) {
      if (backupNote != null && _currentStatus == 'trash') {
        _notes.insert(index <= _notes.length ? index : _notes.length, backupNote);
        _sortNotes();
      } else if (_currentStatus == 'active') {
        _notes.removeWhere((n) => n.id == noteId);
      }
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Hapus catatan secara permanen (DELETE /notes/:id)
  Future<void> deletePermanently(int noteId) async {
    final index = _notes.indexWhere((n) => n.id == noteId);
    Note? backupNote;
    if (index != -1) {
      backupNote = _notes[index];
      _notes.removeAt(index);
      notifyListeners();
    }

    try {
      await _apiService.deleteNotePermanently(noteId);
    } catch (e) {
      if (backupNote != null) {
        _notes.insert(index <= _notes.length ? index : _notes.length, backupNote);
        notifyListeners();
      }
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Kosongkan seluruh tempat sampah (DELETE /notes/trash/empty)
  Future<void> emptyTrash() async {
    final backup = List<Note>.from(_notes);
    _notes.clear();
    notifyListeners();

    try {
      await _apiService.emptyTrash();
    } catch (e) {
      _notes.addAll(backup);
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Perbarui referensi objek Note tertentu di dalam state lokal jika ada
  void updateLocalNote(Note note) {
    final index = _notes.indexWhere((n) => n.id == note.id);
    if (index != -1) {
      _notes[index] = note;
      _sortNotes();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
