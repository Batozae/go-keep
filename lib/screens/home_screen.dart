import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../providers/auth_provider.dart';

/// Layar Home Sementara (Placeholder Fase 4)
/// Menampilkan ucapan selamat datang untuk pengguna yang berhasil masuk
/// serta tombol Logout. Fitur catatan penuh akan diimplementasikan pada Fase 5.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Row(
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
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Go-Keep',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppTheme.textSecondary),
            tooltip: 'Logout',
            onPressed: () async {
              await context.read<AuthProvider>().logout();
              if (context.mounted) {
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Kartu Sambutan Pengguna
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.getNoteColor('yellow'),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFE5D865),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: AppTheme.primaryColor,
                          child: Text(
                            user != null && user.name.isNotEmpty
                                ? user.name[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Selamat datang, ${user?.name ?? 'Pengguna'}!',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                user?.email ?? '',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: Color(0xFFDED050)),
                    const SizedBox(height: 10),
                    const Text(
                      'Fase 4 (Flutter Fondasi) telah aktif: Autentikasi JWT, Dio Interceptor, Secure Storage, Model Catatan, dan Tema Google Keep siap digunakan.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF4A4520),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Kartu Informasi Milestone
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: Color(0xFFE0E0E0)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(
                            Icons.check_circle_rounded,
                            color: Colors.green,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Status Fondasi (Fase 4)',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildCheckItem('Material 3 & Google Keep Light Theme'),
                      _buildCheckItem('Model: User, Note, ChecklistItem, Label'),
                      _buildCheckItem('Dio API Client + Interceptor Bearer Token'),
                      _buildCheckItem('Auto-Login & Penanganan 401 Unauthorized'),
                      _buildCheckItem('Layar Splash, Login, & Register (Validasi Klien)'),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              // Tombol Keluar / Logout
              SizedBox(
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: auth.isLoading
                      ? null
                      : () async {
                          await auth.logout();
                          if (context.mounted) {
                            Navigator.pushNamedAndRemoveUntil(
                              context,
                              '/login',
                              (route) => false,
                            );
                          }
                        },
                  icon: const Icon(Icons.logout_rounded, color: Colors.red),
                  label: const Text(
                    'Keluar dari Akun (Logout)',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red, width: 1.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildCheckItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.done, size: 16, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF3C4043),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
