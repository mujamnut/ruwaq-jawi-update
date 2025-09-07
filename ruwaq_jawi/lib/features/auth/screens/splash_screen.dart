import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _status = 'Memulakan aplikasi...';
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  Future<void> _initializeApp() async {
    try {
      final authProvider = context.read<AuthProvider>();

      // Update status
      setState(() {
        _status = 'Menyambung ke pelayan...';
      });

      // Initialize authentication with timeout
      await authProvider.initialize().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Timeout connecting to server');
        },
      );

      // Update status
      setState(() {
        _status = 'Menyediakan aplikasi...';
      });

      // Wait for a minimum splash duration
      await Future.delayed(const Duration(seconds: 1));

      if (mounted) {
        // Navigate based on authentication status
        if (authProvider.status == AuthStatus.error) {
          setState(() {
            _status = 'Ralat: ${authProvider.errorMessage ?? 'Unknown error'}';
          });
          
          // Wait a bit then go to login anyway
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) context.go('/login');
        } else if (authProvider.isAuthenticated) {
          if (authProvider.isAdmin) {
            context.go('/admin');
          } else {
            context.go('/home');
          }
        } else {
          context.go('/login');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = 'Ralat: ${e.toString()}';
        });
        
        // Wait a bit then go to login anyway
        await Future.delayed(const Duration(seconds: 3));
        if (mounted) context.go('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App Logo
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppTheme.textLightColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  'assets/images/app_logo.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(Icons.book, size: 60, color: AppTheme.primaryColor);
                  },
                ),
              ),
            ),

            const SizedBox(height: 32),

            // App Name
            Text(
              'Maktabah Ruwaq Jawi',
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                color: AppTheme.textLightColor,
                fontWeight: FontWeight.bold,
                fontSize: 28,
              ),
            ),

            const SizedBox(height: 8),

            // Tagline
            Text(
              'مكتبة الرواق الجاوي',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppTheme.textLightColor.withOpacity(0.8),
                fontSize: 18,
              ),
            ),

            const SizedBox(height: 48),

            // Loading Indicator
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                AppTheme.textLightColor,
              ),
            ),

            const SizedBox(height: 24),

            // Status Message
            Text(
              _status,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textLightColor.withOpacity(0.8),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
