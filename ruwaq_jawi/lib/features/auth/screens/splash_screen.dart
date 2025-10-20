import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  String _status = 'Memulakan aplikasi...';
  bool _hasError = false;
  bool _fadeOut = false;

  // Animation controllers
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _loadingController;
  late AnimationController _fadeOutController;

  // Animations
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _logoGlow;
  late Animation<Offset> _appNameSlide;
  late Animation<double> _appNameOpacity;
  late Animation<Offset> _arabicSlide;
  late Animation<double> _arabicOpacity;
  late Animation<double> _fadeOutAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAnimations();
      _initializeApp();
    });
  }

  void _setupAnimations() {
    // Logo animations (1.5s)
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _logoScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _logoGlow = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.6, 1.0, curve: Curves.easeInOut),
      ),
    );

    // Text animations (1.2s, start after logo)
    _textController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _appNameSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _textController,
            curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
          ),
        );

    _appNameOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _arabicSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _textController,
            curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
          ),
        );

    _arabicOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.4, 1.0, curve: Curves.easeIn),
      ),
    );

    // Loading indicator (continuous)
    _loadingController = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    )..repeat();

    // Fade out animation (for smooth exit)
    _fadeOutController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _fadeOutAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _fadeOutController, curve: Curves.easeIn),
    );
  }

  void _startAnimations() {
    _logoController.forward();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _textController.forward();
    });
  }

  Future<void> _navigateWithFadeOut(String route) async {
    setState(() {
      _fadeOut = true;
    });
    await _fadeOutController.forward();
    if (mounted) context.go(route);
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _loadingController.dispose();
    _fadeOutController.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    try {
      final authProvider = context.read<AuthProvider>();

      // Update status with smooth transition
      await _updateStatus('Menyambung...');

      // Initialize authentication with timeout
      await authProvider.initialize().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Timeout connecting to server');
        },
      );

      // Update status
      await _updateStatus('Menyediakan aplikasi...');

      // Wait for a minimum splash duration
      await Future.delayed(const Duration(seconds: 1));

      // Ensure profile is loaded before deciding route (avoid racing on role)
      // Wait up to a short timeout if authenticated but profile not yet ready
      const profileWait = Duration(seconds: 5);
      final start = DateTime.now();
      while (authProvider.status == AuthStatus.authenticated &&
          authProvider.userProfile == null &&
          DateTime.now().difference(start) < profileWait) {
        await Future.delayed(const Duration(milliseconds: 120));
      }

      if (mounted) {
        // Navigate based on authentication status
        if (authProvider.status == AuthStatus.error) {
          setState(() {
            _status = 'Ralat: ${authProvider.errorMessage ?? 'Unknown error'}';
            _hasError = true;
          });

          // Wait a bit then go to login anyway
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) await _navigateWithFadeOut('/login');
        } else if (authProvider.isAuthenticated) {
          if (authProvider.isAdmin) {
            await _navigateWithFadeOut('/admin');
          } else {
            await _navigateWithFadeOut('/home');
          }
        } else {
          await _navigateWithFadeOut('/login');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = e.toString().replaceAll('Exception: ', '');
          _hasError = true;
        });

        // Wait a bit then go to login anyway
        await Future.delayed(const Duration(seconds: 3));
        if (mounted) await _navigateWithFadeOut('/login');
      }
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    if (mounted) {
      setState(() {
        _status = newStatus;
      });
      await Future.delayed(const Duration(milliseconds: 300));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _fadeOutAnimation,
        builder: (context, child) {
          return Opacity(opacity: _fadeOutAnimation.value, child: child);
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppTheme.backgroundColor,
                Colors.white,
                AppTheme.backgroundColor,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated Logo with Glow
                  AnimatedBuilder(
                    animation: _logoController,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _logoOpacity.value,
                        child: Transform.scale(
                          scale: _logoScale.value,
                          child: Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryColor.withValues(
                                    alpha: 0.15 * _logoGlow.value,
                                  ),
                                  blurRadius: 30 * _logoGlow.value,
                                  spreadRadius: 10 * _logoGlow.value,
                                ),
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(20),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.asset(
                                'assets/images/app_logo.png',
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    Icons.book_rounded,
                                    size: 70,
                                    color: AppTheme.primaryColor,
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 48),

                  // Animated App Name
                  SlideTransition(
                    position: _appNameSlide,
                    child: FadeTransition(
                      opacity: _appNameOpacity,
                      child: Text(
                        'Maktabah Ruwaq Jawi',
                        style: Theme.of(context).textTheme.displayMedium
                            ?.copyWith(
                              color: AppTheme.textPrimaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 28,
                              letterSpacing: -0.5,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Animated Arabic Text
                  SlideTransition(
                    position: _arabicSlide,
                    child: FadeTransition(
                      opacity: _arabicOpacity,
                      child: Text(
                        'مكتبة الرواق الجاوي',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppTheme.textSecondaryColor,
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Lottie wave loading
                  if (!_hasError)
                    Lottie.asset(
                      'assets/animations/material_wave_loading.json',
                      width: 140,
                      height: 140,
                      repeat: true,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                          const SizedBox(
                            width: 32,
                            height: 32,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                    ),

                  // Error Icon Animation
                  if (_hasError)
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.elasticOut,
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: value,
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: AppTheme.errorColor.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.error_outline_rounded,
                              size: 32,
                              color: AppTheme.errorColor,
                            ),
                          ),
                        );
                      },
                    ),

                  const SizedBox(height: 12),

                  // Animated Status Message
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.1),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: Text(
                      _status,
                      key: ValueKey<String>(_status),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: _hasError
                            ? AppTheme.errorColor
                            : AppTheme.textSecondaryColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Retry Button (show on error)
                  if (_hasError)
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.elasticOut,
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: value,
                          child: ElevatedButton(
                            onPressed: () async {
                              await _navigateWithFadeOut('/login');
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Cuba Lagi'),
                          ),
                        );
                      },
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
