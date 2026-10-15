import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/app_constants.dart';
import '../models/user.dart';

/// Exception khusus yang memuat pesan ramah dalam Bahasa Indonesia
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// Service HTTP berbasis Dio dengan interceptor autentikasi dan error handling
class ApiService {
  late final Dio _dio;
  final FlutterSecureStorage _storage;

  /// Callback opsional yang dipanggil jika menerima 401 di luar endpoint auth
  void Function()? onUnauthorized;

  ApiService({
    Dio? dio,
    FlutterSecureStorage? storage,
    this.onUnauthorized,
  }) : _storage = storage ?? const FlutterSecureStorage() {
    _dio = dio ??
        Dio(
          BaseOptions(
            baseUrl: AppConstants.baseUrl,
            connectTimeout: AppConstants.connectTimeout,
            receiveTimeout: AppConstants.receiveTimeout,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          ),
        );

    _setupInterceptors();
  }

  Dio get dio => _dio;

  /// Konfigurasi Interceptor Dio
  void _setupInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Jangan tambahkan header Authorization pada request login atau register
          final isAuthEndpoint = options.path.contains('/auth/login') ||
              options.path.contains('/auth/register');

          if (!isAuthEndpoint) {
            final token = await _storage.read(key: AppConstants.tokenKey);
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }

          return handler.next(options);
        },
        onError: (DioException error, handler) async {
          final isAuthEndpoint =
              error.requestOptions.path.contains('/auth/login') ||
                  error.requestOptions.path.contains('/auth/register');

          // Jika menerima status 401 pada endpoint selain login/register
          if (error.response?.statusCode == 401 && !isAuthEndpoint) {
            // 1. Hapus token dari secure storage
            await _storage.delete(key: AppConstants.tokenKey);

            // 2. Trigger callback jika ada
            onUnauthorized?.call();

            // 3. Arahkan kembali ke halaman Login secara global
            AppConstants.navigatorKey.currentState?.pushNamedAndRemoveUntil(
              '/login',
              (route) => false,
            );
          }

          return handler.next(error);
        },
      ),
    );
  }

  /// Mengubah DioException menjadi pesan Bahasa Indonesia yang ramah
  ApiException _handleDioError(dynamic error) {
    if (error is ApiException) {
      return error;
    }

    if (error is DioException) {
      final statusCode = error.response?.statusCode;

      // Cek apakah ada pesan error dari backend Express: { message: "..." }
      if (error.response?.data != null && error.response?.data is Map) {
        final data = error.response?.data as Map;
        if (data.containsKey('message') && data['message'] != null) {
          return ApiException(
            data['message'].toString(),
            statusCode: statusCode,
          );
        }
      }

      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return ApiException(
            'Koneksi batas waktu habis (timeout). Silakan periksa jaringan Anda dan coba lagi.',
            statusCode: statusCode,
          );
        case DioExceptionType.connectionError:
          return ApiException(
            'Tidak dapat terhubung ke server. Pastikan backend aktif dan jaringan terhubung.',
            statusCode: statusCode,
          );
        case DioExceptionType.badResponse:
          switch (statusCode) {
            case 400:
              return ApiException(
                'Permintaan tidak valid. Silakan periksa kembali input Anda.',
                statusCode: statusCode,
              );
            case 401:
              return ApiException(
                'Email atau password salah, atau sesi Anda telah berakhir.',
                statusCode: statusCode,
              );
            case 403:
              return ApiException(
                'Akses ditolak. Anda tidak memiliki izin untuk tindakan ini.',
                statusCode: statusCode,
              );
            case 404:
              return ApiException(
                'Data atau endpoint yang diminta tidak ditemukan.',
                statusCode: statusCode,
              );
            case 409:
              return ApiException(
                'Data sudah terdaftar atau terjadi konflik.',
                statusCode: statusCode,
              );
            case 500:
              return ApiException(
                'Terjadi kesalahan internal pada server. Silakan coba beberapa saat lagi.',
                statusCode: statusCode,
              );
            default:
              return ApiException(
                'Terjadi kesalahan pada server (kode status: $statusCode).',
                statusCode: statusCode,
              );
          }
        case DioExceptionType.cancel:
          return ApiException('Permintaan dibatalkan.', statusCode: statusCode);
        default:
          return ApiException(
            'Terjadi kendala jaringan. Pastikan koneksi internet aktif.',
            statusCode: statusCode,
          );
      }
    }

    return ApiException(error?.toString() ?? 'Terjadi kesalahan yang tidak terduga.');
  }

  // ===========================================================================
  // Manajemen Token Secure Storage
  // ===========================================================================

  Future<void> saveToken(String token) async {
    await _storage.write(key: AppConstants.tokenKey, value: token);
  }

  Future<String?> getToken() async {
    return await _storage.read(key: AppConstants.tokenKey);
  }

  Future<void> deleteToken() async {
    await _storage.delete(key: AppConstants.tokenKey);
  }

  // ===========================================================================
  // Endpoint Autentikasi
  // ===========================================================================

  /// POST /api/auth/register
  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/register',
        data: {
          'name': name,
          'email': email,
          'password': password,
        },
      );

      final data = response.data as Map<String, dynamic>;
      final token = data['token'] as String;
      final user = User.fromJson(data['user'] as Map<String, dynamic>);

      return {
        'token': token,
        'user': user,
        'message': data['message'] ?? 'Registrasi berhasil.',
      };
    } catch (e) {
      throw _handleDioError(e);
    }
  }

  /// POST /api/auth/login
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/login',
        data: {
          'email': email,
          'password': password,
        },
      );

      final data = response.data as Map<String, dynamic>;
      final token = data['token'] as String;
      final user = User.fromJson(data['user'] as Map<String, dynamic>);

      return {
        'token': token,
        'user': user,
      };
    } catch (e) {
      throw _handleDioError(e);
    }
  }

  /// GET /api/auth/me
  Future<User> getMe() async {
    try {
      final response = await _dio.get('/auth/me');
      final data = response.data as Map<String, dynamic>;
      return User.fromJson(data['user'] as Map<String, dynamic>);
    } catch (e) {
      throw _handleDioError(e);
    }
  }
}

