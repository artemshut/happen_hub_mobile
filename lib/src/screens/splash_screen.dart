import 'dart:async';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/api_client.dart';
import 'login.dart';
import 'main_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;

  final AuthService _authService = AuthService();
  final ApiClient _apiClient = ApiClient();

  @override
  void initState() {
    super.initState();

    // 🎨 Animation setup
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    _controller.forward();

    // ⏳ After delay, check auth
    Future.delayed(const Duration(seconds: 3), _checkAuth);
  }

  Future<void> _checkAuth() async {
    final token = await _authService.getToken();

    if (!mounted) return;

    if (token != null) {
      try {
        // Call /me to validate token
        final response = await _apiClient.get("/me");
        if (response.statusCode == 200) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MainScreen()),
          );
          return;
        }
      } catch (_) {
        // handled inside ApiClient with logout+snackbar
      }
    }

    // if no token or failed validation → go to login
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: FadeTransition(
        opacity: _fadeIn,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [cs.primary, cs.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 🖼 Your logo
                Image.asset(
                  "assets/images/logo_white.png",
                  width: 120,
                  height: 120,
                ),
                const SizedBox(height: 20),
                Text(
                  "HappenHub",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: cs.onPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}