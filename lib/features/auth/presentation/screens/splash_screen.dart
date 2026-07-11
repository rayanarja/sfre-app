import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../features/auth/data/auth_service.dart';


class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }
  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final authService = AuthService();
    final isLoggedIn = await authService.isLoggedIn();

    if (!mounted) return;

    if (isLoggedIn) {
      final user = await authService.getSavedUser();
      if (!mounted) return;
      if (user?.isDriver == true) {
        context.go('/driver');
      } else {
        context.go('/passenger');
      }
    } else {
      context.go('/login');
    }
  } 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
textDirection: TextDirection.rtl,
          children: [
            Icon(
              Icons.directions_bus_rounded,
              size: 100,
              color: Theme.of(context).cardColor,
            ),
            SizedBox(height: 24),
            Text(
              'Bus Tracker',
              style: TextStyle(
                color: Theme.of(context).cardColor,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'نظام تتبع الباصات ',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 16,
              ),
            ),
            SizedBox(height: 48),
            CircularProgressIndicator(
              color: Theme.of(context).cardColor,
            ),
          ],
        ),
      ),
    );
  }
}