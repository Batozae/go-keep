import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/error_banner.dart';

/// Layar Registrasi akun baru pengguna Go-Keep
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    FocusScope.of(context).unfocus();

    // Validasi form sisi klien: nama wajib, email valid, password min 6
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.register(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;

    if (success) {
      // Registrasi berhasil, langsung masuk ke Home
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            auth.clearError();
            Navigator.pop(context);
          },
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Judul & Subjudul
                  const Text(
                    'Daftar Akun Baru',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Mulai mencatat dan mengorganisir ide Anda di Go-Keep',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Tampilkan error jika ada respon gagal dari backend (misal: email duplikat 409)
                  if (auth.errorMessage != null)
                    ErrorBanner(
                      message: auth.errorMessage!,
                      onDismiss: () => auth.clearError(),
                    ),

                  // Input Nama Lengkap (Wajib)
                  CustomTextField(
                    controller: _nameController,
                    label: 'Nama Lengkap',
                    hintText: 'Masukkan nama Anda',
                    prefixIcon: Icons.person_outline_rounded,
                    enabled: !auth.isLoading,
                    onChanged: (_) {
                      if (auth.errorMessage != null) auth.clearError();
                    },
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Nama wajib diisi';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),

                  // Input Email (Wajib & Valid)
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

                  // Input Password (Wajib & Minimal 6 Karakter)
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

                  // Tombol Daftar (Nonaktif saat loading)
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: auth.isLoading ? null : _handleRegister,
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
                              'Daftar Sekarang',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Link kembali ke Login
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Sudah punya akun?',
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
                                Navigator.pop(context);
                              },
                        child: const Text('Masuk'),
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

