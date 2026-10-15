import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/api_service.dart';

/// Provider pengelola status autentikasi pengguna
class AuthProvider with ChangeNotifier {
  final ApiService _apiService;

  User? _user;
  String? _token;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isInitialized = false;

  AuthProvider(this._apiService) {
    // Sinkronkan callback jika interceptor mendeteksi 401
    _apiService.onUnauthorized = _handleUnauthorized;
  }

  // ===========================================================================
  // Getters
  // ===========================================================================

  User? get user => _user;
  String? get token => _token;
  bool get isAuthenticated => _token != null && _user != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isInitialized => _isInitialized;

  void _handleUnauthorized() {
    _token = null;
    _user = null;
    _errorMessage = 'Sesi Anda telah berakhir. Silakan masuk kembali.';
    notifyListeners();
  }

  /// Menghapus pesan error dari state (misal saat berpindah layar atau input berubah)
  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  // ===========================================================================
  // Alur Autentikasi
  // ===========================================================================

  /// Auto-login saat aplikasi pertama kali dibuka (Splash screen).
  /// Memeriksa keberadaan token di secure storage, lalu memverifikasi ke GET /auth/me.
  Future<bool> checkAuth() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final savedToken = await _apiService.getToken();

      if (savedToken == null || savedToken.isEmpty) {
        _user = null;
        _token = null;
        _isLoading = false;
        _isInitialized = true;
        notifyListeners();
        return false;
      }

      // Token tersimpan ditemukan, verifikasi validitas token dengan mengambil profil user
      final user = await _apiService.getMe();
      _user = user;
      _token = savedToken;
      _isLoading = false;
      _isInitialized = true;
      notifyListeners();
      return true;
    } catch (_) {
      // Token tidak valid atau kedaluwarsa
      await _apiService.deleteToken();
      _user = null;
      _token = null;
      _isLoading = false;
      _isInitialized = true;
      notifyListeners();
      return false;
    }
  }

  /// Registrasi akun baru (POST /auth/register)
  Future<bool> register({
    required String name,
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _apiService.register(
        name: name,
        email: email,
        password: password,
      );

      final token = res['token'] as String;
      final user = res['user'] as User;

      // Simpan token ke storage
      await _apiService.saveToken(token);

      _token = token;
      _user = user;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Login akun pengguna (POST /auth/login)
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _apiService.login(
        email: email,
        password: password,
      );

      final token = res['token'] as String;
      final user = res['user'] as User;

      // Simpan token ke storage
      await _apiService.saveToken(token);

      _token = token;
      _user = user;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Logout akun pengguna (Hapus token & bersihkan sesi)
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _apiService.deleteToken();
    } finally {
      _token = null;
      _user = null;
      _errorMessage = null;
      _isLoading = false;
      notifyListeners();
    }
  }
}

