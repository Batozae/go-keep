import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Konstanta aplikasi Go-Keep
class AppConstants {
  /// Base URL API:
  /// - Android Emulator: http://10.0.2.2:3000/api (IP alias host machine untuk emulator Android)
  /// - Windows Desktop / Web: http://127.0.0.1:3000/api (localhost mesin pengembang)
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:3000/api';
    }
    try {
      if (Platform.isAndroid) {
        return 'http://10.0.2.2:3000/api';
      }
    } catch (_) {}
    return 'http://127.0.0.1:3000/api';
  }

  // Kunci penyimpanan token JWT di FlutterSecureStorage
  static const String tokenKey = 'gokeep_jwt_token';

  // Durasi timeout request jaringan
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 10);

  // Global Navigator Key untuk navigasi global (misal redirect 401)
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
}
