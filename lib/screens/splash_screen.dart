import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../providers/auth_provider.dart';

/// Layar Splash: Memeriksa auto-login (token di secure storage + GET /auth/me)
/// lalu mengarahkan ke Home atau Login.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthentication();
    });
  }

  Future<void> _checkAuthentication() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Beri jeda minimal agar logo terlihat dengan halus
    await Future.delayed(const Duration(milliseconds: 600));

    final isAuthenticated = await authProvider.checkAuth();

    if (!mounted) return;

    if (isAuthenticated) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Ikon khas Google Keep
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lightbulb_outline_rounded,
                  size: 52,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Go-Keep',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Catat setiap ide dengan cepat & mudah',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 48),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.8,
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
