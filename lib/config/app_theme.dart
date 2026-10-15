import 'package:flutter/material.dart';

/// Tema terang bergaya Google Keep dan pemetaan warna catatan sesuai backend.
class AppTheme {
  // Warna aksen khas Google Keep
  static const Color primaryColor = Color(0xFFF4B400); // Amber Google Keep
  static const Color scaffoldBackground = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF202124);
  static const Color textSecondary = Color(0xFF5F6368);
  static const Color surfaceNeutral = Color(0xFFF1F3F4);
  static const Color dividerColor = Color(0xFFE0E0E0);

  /// Pemetaan warna catatan yang didukung oleh backend Go-Keep:
  /// default, red, orange, yellow, green, teal, blue, purple, pink, brown, gray
  static const Map<String, Color> noteColors = {
    'default': Color(0xFFFFFFFF),
    'red': Color(0xFFF28B82),
    'orange': Color(0xFFFBBC04),
    'yellow': Color(0xFFFFF475),
    'green': Color(0xFFCCFF90),
    'teal': Color(0xFFA7FFEB),
    'blue': Color(0xFFCBF0F8),
    'purple': Color(0xFFD7AEFB),
    'pink': Color(0xFFFDCFE8),
    'brown': Color(0xFFE6C9A8),
    'gray': Color(0xFFE8EAED),
  };

  /// Daftar nama warna catatan terurut untuk palette/selector
  static const List<String> supportedColorNames = [
    'default',
    'red',
    'orange',
    'yellow',
    'green',
    'teal',
    'blue',
    'purple',
    'pink',
    'brown',
    'gray',
  ];

  /// Mengambil objek [Color] berdasarkan string nama warna dari database/API.
  /// Jika tidak ditemukan atau null, mengembalikan warna 'default' (putih).
  static Color getNoteColor(String? colorName) {
    if (colorName == null) return noteColors['default']!;
    return noteColors[colorName.toLowerCase()] ?? noteColors['default']!;
  }

  /// Warna border kartu catatan (kartu putih membutuhkan border halus agar kontras)
  static Color getNoteBorderColor(String? colorName) {
    final key = colorName?.toLowerCase() ?? 'default';
    if (key == 'default') {
      return const Color(0xFFE0E0E0);
    }
    return Colors.transparent;
  }

  /// Definisi ThemeData terang Material 3 bergaya Google Keep
  static ThemeData get lightTheme {
    final baseColorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.light,
      primary: primaryColor,
      onPrimary: Colors.white,
      surface: scaffoldBackground,
      onSurface: textPrimary,
      surfaceContainerHighest: surfaceNeutral,
      outline: dividerColor,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: baseColorScheme,
      scaffoldBackgroundColor: scaffoldBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: scaffoldBackground,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.15,
        ),
        iconTheme: IconThemeData(color: textSecondary),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: noteColors['default'],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: dividerColor, width: 1),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceNeutral,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: textSecondary, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFFD97706),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: CircleBorder(),
      ),
      dividerTheme: const DividerThemeData(
        color: dividerColor,
        thickness: 0.8,
        space: 1,
      ),
    );
  }
}
