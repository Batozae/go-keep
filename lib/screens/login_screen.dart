import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/error_banner.dart';

/// Layar Login untuk autentikasi pengguna ke Go-Keep
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    // Sembunyikan keyboard
    FocusScope.of(context).unfocus();

    // Validasi form sisi klien
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;

    if (success) {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo & Judul
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lightbulb_outline_rounded,
                        size: 40,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Center(
                    child: Text(
                      'Go-Keep',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Center(
                    child: Text(
                      'Masuk ke akun Anda untuk mengakses catatan',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Tampilkan banner error dari backend jika ada
                  if (auth.errorMessage != null)
                    ErrorBanner(
                      message: auth.errorMessage!,
                      onDismiss: () => auth.clearError(),
                    ),

                  // Input Email
                  CustomTextField(
                    controller: _emailController,
                    label: 'Email',
                    hintText: 'nama@domain.com',
                    prefixIcon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    enabled: !auth.isLoading,
                    onChanged: (_) {
                      if (auth.errorMessage != null) auth.clearError();
                    },
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Email wajib diisi';
                      }
                      final emailRegex =
                          RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                      if (!emailRegex.hasMatch(value.trim())) {
                        return 'Format email tidak valid';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),

                  // Input Password
                  CustomTextField(
                    controller: _passwordController,
                    label: 'Password',
                    hintText: 'Minimal 6 karakter',
                    prefixIcon: Icons.lock_outline_rounded,
                    obscureText: _obscurePassword,
                    enabled: !auth.isLoading,
                    onChanged: (_) {
                      if (auth.errorMessage != null) auth.clearError();
                    },
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: const Color(0xFF5F6368),
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Password wajib diisi';
                      }
                      if (value.length < 6) {
                        return 'Password minimal 6 karakter';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 28),

                  // Tombol Masuk (Nonaktif saat loading)
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: auth.isLoading ? null : _handleLogin,
                      child: auth.isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Masuk',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Link menuju halaman Register
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Belum punya akun?',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      TextButton(
                        onPressed: auth.isLoading
                            ? null
                            : () {
                                auth.clearError();
                                Navigator.pushNamed(context, '/register');
                              },
                        child: const Text('Daftar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
