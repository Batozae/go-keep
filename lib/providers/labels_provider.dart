import 'package:flutter/foundation.dart';
import '../models/label.dart';
import '../models/note.dart';
import '../services/api_service.dart';

/// Provider pengelola status label, CRUD label, dan penautan label pada catatan
class LabelsProvider with ChangeNotifier {
  final ApiService _apiService;

  List<Label> _labels = [];
  bool _isLoading = false;
  String? _errorMessage;

  LabelsProvider(this._apiService);

  List<Label> get labels => List.unmodifiable(_labels);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  /// Mengambil daftar semua label dari backend (GET /labels)
  Future<void> fetchLabels() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final fetched = await _apiService.getLabels();
      _labels = fetched;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Membuat label baru (POST /labels)
  Future<Label> createLabel(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ApiException('Nama label tidak boleh kosong.');
    }

    try {
      final newLabel = await _apiService.createLabel(trimmed);
      _labels.add(newLabel);
      _labels.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      notifyListeners();
      return newLabel;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Mengubah nama label (PUT /labels/:id)
  Future<Label> renameLabel(int id, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) {
      throw ApiException('Nama label tidak boleh kosong.');
    }

    final index = _labels.indexWhere((l) => l.id == id);
    Label? oldLabel;
    if (index != -1) {
      oldLabel = _labels[index];
    }

    try {
      final updated = await _apiService.updateLabel(id, trimmed);
      if (index != -1) {
        _labels[index] = updated;
        _labels.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        notifyListeners();
      }
      return updated;
    } catch (e) {
      if (index != -1 && oldLabel != null) {
        _labels[index] = oldLabel;
        notifyListeners();
      }
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Menghapus label (DELETE /labels/:id)
  Future<void> deleteLabel(int id) async {
    final index = _labels.indexWhere((l) => l.id == id);
    Label? oldLabel;
    if (index != -1) {
      oldLabel = _labels[index];
      _labels.removeAt(index);
      notifyListeners();
    }

    try {
      await _apiService.deleteLabel(id);
    } catch (e) {
      if (oldLabel != null) {
        _labels.insert(index <= _labels.length ? index : _labels.length, oldLabel);
        notifyListeners();
      }
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Menautkan label ke catatan (POST /notes/:id/labels/:labelId)
  Future<Note> addLabelToNote(int noteId, int labelId) async {
    try {
      final updatedNote = await _apiService.addLabelToNote(noteId, labelId);
      // Perbarui notes_count pada label jika ada
      final idx = _labels.indexWhere((l) => l.id == labelId);
      if (idx != -1) {
        _labels[idx] = _labels[idx].copyWith(notesCount: _labels[idx].notesCount + 1);
        notifyListeners();
      }
      return updatedNote;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Melepas label dari catatan (DELETE /notes/:id/labels/:labelId)
  Future<Note> removeLabelFromNote(int noteId, int labelId) async {
    try {
      final updatedNote = await _apiService.removeLabelFromNote(noteId, labelId);
      final idx = _labels.indexWhere((l) => l.id == labelId);
      if (idx != -1 && _labels[idx].notesCount > 0) {
        _labels[idx] = _labels[idx].copyWith(notesCount: _labels[idx].notesCount - 1);
        notifyListeners();
      }
      return updatedNote;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }
}

