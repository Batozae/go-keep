import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/app_constants.dart';
import 'config/app_theme.dart';
import 'providers/auth_provider.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/splash_screen.dart';
import 'services/api_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi ApiService
  final apiService = ApiService();

  runApp(
    MultiProvider(
      providers: [
        Provider<ApiService>.value(value: apiService),
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(apiService),
        ),
      ],
      child: const GoKeepApp(),
    ),
  );
}

/// Root widget aplikasi Go-Keep
class GoKeepApp extends StatelessWidget {
  const GoKeepApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Go-Keep',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      navigatorKey: AppConstants.navigatorKey,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const HomeScreen(),
      },
    );
  }
}
