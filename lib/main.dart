import 'package:flutter/material.dart';
import 'services/supabase_service.dart';

import 'pages/seeker/seeker_dashboard.dart';
import 'pages/employee/employee_dashboard.dart';
import 'pages/auth/login_page.dart';
import 'pages/auth/signup_page.dart';
import 'pages/auth/reset_password_page.dart';
import 'pages/home_page.dart';
import 'services/theme_service.dart';
import 'pages/about_page.dart';
import 'pages/services_page.dart';
import 'theme/app_colors.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_web_plugins/url_strategy.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Use clean URLs on web so /reset-password is recognized as a route
  // instead of default hash-based URLs.
  if (kIsWeb) {
    setUrlStrategy(PathUrlStrategy());
  }
  try {
    await SupabaseService.init();
  } catch (e) {
    // If Supabase isn't configured locally, continue in demo/mock mode.
    // Log the error so the developer knows to provide keys.
    // ignore: avoid_print
    print('Supabase init skipped: $e');
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, mode, _) {
        bool _hasRecoveryParams(Uri uri) {
          try {
            final type = uri.queryParameters['type'] ?? '';
            if (type.toLowerCase() == 'recovery') return true;
            if (uri.fragment.isNotEmpty) {
              final frag = Uri.splitQueryString(uri.fragment);
              final fType = (frag['type'] ?? '').toLowerCase();
              if (fType == 'recovery') return true;
            }
          } catch (_) {}
          return false;
        }

        final initialRoute = _hasRecoveryParams(Uri.base) ? '/reset-password' : '/';

        return MaterialApp(
          title: 'Dashboard Demo',
          debugShowCheckedModeBanner: false,
          theme: ThemeData.light(
            useMaterial3: true,
          ).copyWith(
            scaffoldBackgroundColor: AppColors.secondary,
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.accent,
              primary: AppColors.accent,
              surface: AppColors.secondary,
              onSurface: AppColors.primary,
            ),
            appBarTheme: const AppBarTheme(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style:
                  OutlinedButton.styleFrom(foregroundColor: AppColors.accent),
            ),
            textTheme: const TextTheme(
              bodyLarge: TextStyle(color: Color(0xFF333333)),
              bodyMedium: TextStyle(color: Color(0xFF333333)),
              titleLarge: TextStyle(color: Color(0xFF333333)),
            ),
          ),
          darkTheme: ThemeData.dark(
            useMaterial3: true,
          ).copyWith(
            scaffoldBackgroundColor: const Color(0xFF121212),
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.accent,
              brightness: Brightness.dark,
            ),
            appBarTheme: AppBarTheme(
                backgroundColor: AppColors.accent.withValues(alpha: 0.9)),
          ),
          themeMode: mode,
          initialRoute: initialRoute,
          routes: {
            '/': (_) => const HomePage(),
            '/seeker': (_) => const SeekerDashboard(),
            '/employee': (_) => const EmployeeDashboard(),
            '/about': (_) => const AboutPage(),
            '/services': (_) => const ServicesPage(),
            '/login': (_) => const LoginPage(),
            '/signup': (_) => const SignupPage(),
            '/reset-password': (_) => const ResetPasswordPage(),
          },
        );
      },
    );
  }
}

class DashboardHome extends StatelessWidget {
  const DashboardHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard Home')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Choose dashboard to open',
                  style: TextStyle(fontSize: 18)),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      final uid = SupabaseService.client.auth.currentUser?.id;
                      if (uid == null) {
                        Navigator.pushNamed(context, '/login',
                            arguments: '/seeker');
                      } else {
                        Navigator.pushNamed(context, '/seeker');
                      }
                    },
                    child: const Text('Job Seeker'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () {
                      final uid = SupabaseService.client.auth.currentUser?.id;
                      if (uid == null) {
                        Navigator.pushNamed(context, '/login',
                            arguments: '/employee');
                      } else {
                        Navigator.pushNamed(context, '/employee');
                      }
                    },
                    child: const Text('Employee'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
