import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/app_constants.dart';
import '../models/label.dart';
import '../models/note.dart';
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

  // ===========================================================================
  // Endpoint Notes
  // ===========================================================================

  /// GET /api/notes?status=active|archived|trash&q=&label_id=
  Future<List<Note>> getNotes({
    String status = 'active',
    String? query,
    int? labelId,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'status': status,
      };
      if (query != null && query.trim().isNotEmpty) {
        queryParams['q'] = query.trim();
      }
      if (labelId != null) {
        queryParams['label_id'] = labelId;
      }

      final response = await _dio.get('/notes', queryParameters: queryParams);
      final list = response.data as List<dynamic>;
      return list.map((item) => Note.fromJson(item as Map<String, dynamic>)).toList();
    } catch (e) {
      throw _handleDioError(e);
    }
  }

  /// GET /api/notes/:id
  Future<Note> getNoteById(int id) async {
    try {
      final response = await _dio.get('/notes/$id');
      return Note.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw _handleDioError(e);
    }
  }

  /// POST /api/notes
  Future<Note> createNote({
    required String title,
    String? content,
    String type = 'text',
    String color = 'default',
    bool isPinned = false,
    bool isArchived = false,
    List<Map<String, dynamic>>? checklistItems,
    List<int>? labelIds,
  }) async {
    try {
      final payload = <String, dynamic>{
        'title': title,
        'type': type,
        'color': color,
        'is_pinned': isPinned,
        'is_archived': isArchived,
      };
      if (content != null) {
        payload['content'] = content;
      }
      if (checklistItems != null) {
        payload['checklist_items'] = checklistItems;
      }
      if (labelIds != null) {
        payload['label_ids'] = labelIds;
      }

      final response = await _dio.post('/notes', data: payload);
      return Note.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw _handleDioError(e);
    }
  }

  /// PUT /api/notes/:id
  Future<Note> updateNote(
    int id, {
    String? title,
    String? content,
    String? type,
    String? color,
    bool? isPinned,
    bool? isArchived,
    List<Map<String, dynamic>>? checklistItems,
    List<int>? labelIds,
  }) async {
    try {
      final payload = <String, dynamic>{};
      if (title != null) payload['title'] = title;
      if (content != null) payload['content'] = content;
      if (type != null) payload['type'] = type;
      if (color != null) payload['color'] = color;
      if (isPinned != null) payload['is_pinned'] = isPinned;
      if (isArchived != null) payload['is_archived'] = isArchived;
      if (checklistItems != null) payload['checklist_items'] = checklistItems;
      if (labelIds != null) payload['label_ids'] = labelIds;

      final response = await _dio.put('/notes/$id', data: payload);
      return Note.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw _handleDioError(e);
    }
  }

  /// PATCH /api/notes/:id/pin
  Future<Note> togglePin(int id) async {
    try {
      final response = await _dio.patch('/notes/$id/pin');
      return Note.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw _handleDioError(e);
    }
  }

  /// PATCH /api/notes/:id/archive
  Future<Note> toggleArchive(int id) async {
    try {
      final response = await _dio.patch('/notes/$id/archive');
      return Note.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw _handleDioError(e);
    }
  }

  /// PATCH /api/notes/:id/trash
  Future<Note> moveToTrash(int id) async {
    try {
      final response = await _dio.patch('/notes/$id/trash');
      return Note.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw _handleDioError(e);
    }
  }

  /// PATCH /api/notes/:id/restore
  Future<Note> restoreFromTrash(int id) async {
    try {
      final response = await _dio.patch('/notes/$id/restore');
      return Note.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw _handleDioError(e);
    }
  }

  /// DELETE /api/notes/:id (Hapus permanen)
  Future<void> deleteNotePermanently(int id) async {
    try {
      await _dio.delete('/notes/$id');
    } catch (e) {
      throw _handleDioError(e);
    }
  }

  /// DELETE /api/notes/trash/empty (Kosongkan sampah)
  Future<void> emptyTrash() async {
    try {
      await _dio.delete('/notes/trash/empty');
    } catch (e) {
      throw _handleDioError(e);
    }
  }

  /// POST /api/notes/:id/labels/:labelId (Tautkan label ke catatan)
  Future<Note> addLabelToNote(int noteId, int labelId) async {
    try {
      final response = await _dio.post('/notes/$noteId/labels/$labelId');
      return Note.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw _handleDioError(e);
    }
  }

  /// DELETE /api/notes/:id/labels/:labelId (Lepas label dari catatan)
  Future<Note> removeLabelFromNote(int noteId, int labelId) async {
    try {
      final response = await _dio.delete('/notes/$noteId/labels/$labelId');
      return Note.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw _handleDioError(e);
    }
  }

  // ===========================================================================
  // Endpoint Labels
  // ===========================================================================

  /// GET /api/labels
  Future<List<Label>> getLabels() async {
    try {
      final response = await _dio.get('/labels');
      final list = response.data as List<dynamic>;
      return list.map((item) => Label.fromJson(item as Map<String, dynamic>)).toList();
    } catch (e) {
      throw _handleDioError(e);
    }
  }

  /// POST /api/labels
  Future<Label> createLabel(String name) async {
    try {
      final response = await _dio.post('/labels', data: {'name': name});
      return Label.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw _handleDioError(e);
    }
  }

  /// PUT /api/labels/:id
  Future<Label> updateLabel(int id, String name) async {
    try {
      final response = await _dio.put('/labels/$id', data: {'name': name});
      return Label.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw _handleDioError(e);
    }
  }

  /// DELETE /api/labels/:id
  Future<void> deleteLabel(int id) async {
    try {
      await _dio.delete('/labels/$id');
    } catch (e) {
      throw _handleDioError(e);
    }
  }
}

