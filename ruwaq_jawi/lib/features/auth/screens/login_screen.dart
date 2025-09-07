import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/auth_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    // Check for success message from query parameters
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uri = GoRouterState.of(context).uri;
      final message = uri.queryParameters['message'];
      if (message == 'email_confirmed') {
        setState(() {
          _successMessage = 'Email berjaya disahkan! Sila log masuk dengan akaun anda.';
        });
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    
    try {
      final success = await authProvider.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (success && mounted) {
        // Navigate based on user role
        if (authProvider.isAdmin) {
          context.go('/admin');
        } else {
          context.go('/home');
        }
      }
    } catch (e) {
      // Error handling is done in AuthProvider
      if (mounted) {
        // Force UI update to stop loading
        setState(() {});
      }
    }
  }

  IconData _getLoginErrorIcon(String error) {
    if (error.contains('sambungan internet') || error.contains('sambungan rangkaian')) {
      return Icons.wifi_off;
    } else if (error.contains('email atau kata laluan') || error.contains('invalid')) {
      return Icons.lock_outline;
    } else if (error.contains('pelayan') || error.contains('server')) {
      return Icons.dns_outlined;
    } else if (error.contains('masa terlalu lama') || error.contains('timeout')) {
      return Icons.access_time;
    } else if (error.contains('terlalu banyak') || error.contains('rate limit')) {
      return Icons.block;
    }
    return Icons.error_outline;
  }

  String _getLoginErrorTitle(String error) {
    if (error.contains('sambungan internet') || error.contains('sambungan rangkaian')) {
      return 'Tiada Sambungan Internet';
    } else if (error.contains('email atau kata laluan') || error.contains('invalid')) {
      return 'Maklumat Log Masuk Salah';
    } else if (error.contains('pelayan') || error.contains('server')) {
      return 'Masalah Pelayan';
    } else if (error.contains('masa terlalu lama') || error.contains('timeout')) {
      return 'Sambungan Terputus';
    } else if (error.contains('terlalu banyak') || error.contains('rate limit')) {
      return 'Terlalu Banyak Percubaan';
    }
    return 'Ralat Log Masuk';
  }

  bool _shouldShowRetryButton(String error) {
    // Show retry button for connection issues, timeouts, and server errors
    return error.contains('sambungan') || 
           error.contains('timeout') || 
           error.contains('pelayan') ||
           error.contains('server') ||
           error.contains('masa terlalu lama');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 60),
                
                // Logo and Title
                Column(
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.book,
                        size: 60,
                        color: AppTheme.textLightColor,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Maktabah',
                      style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Platform Pendidikan Islam',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 48),
                
                // Success message
                if (_successMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          color: Colors.green[700],
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _successMessage!,
                            style: TextStyle(
                              color: Colors.green[700],
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                // Login Form
                AuthTextField(
                  controller: _emailController,
                  label: 'Email',
                  hintText: 'Masukkan email anda',
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: Icons.email_outlined,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Email diperlukan';
                    }
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                      return 'Format email tidak sah';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 16),
                
                AuthTextField(
                  controller: _passwordController,
                  label: 'Kata Laluan',
                  hintText: 'Masukkan kata laluan anda',
                  obscureText: !_isPasswordVisible,
                  prefixIcon: Icons.lock_outline,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                      color: AppTheme.textSecondaryColor,
                    ),
                    onPressed: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Kata laluan diperlukan';
                    }
                    if (value.length < 6) {
                      return 'Kata laluan mestilah sekurang-kurangnya 6 aksara';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 8),
                
                // Forgot Password
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => context.push('/forgot-password'),
                    child: Text(
                      'Lupa kata laluan?',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Login Button
                Consumer<AuthProvider>(
                  builder: (context, authProvider, child) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AuthButton(
                          text: 'Log Masuk',
                          onPressed: authProvider.status == AuthStatus.loading 
                              ? null 
                              : _handleLogin,
                          isLoading: authProvider.status == AuthStatus.loading,
                        ),
                        
                        if (authProvider.errorMessage != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.errorColor.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.errorColor.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppTheme.errorColor.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        _getLoginErrorIcon(authProvider.errorMessage!),
                                        color: AppTheme.errorColor,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _getLoginErrorTitle(authProvider.errorMessage!),
                                            style: TextStyle(
                                              color: AppTheme.errorColor,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            authProvider.errorMessage!,
                                            style: TextStyle(
                                              color: AppTheme.errorColor.withOpacity(0.8),
                                              fontSize: 13,
                                              height: 1.4,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                if (_shouldShowRetryButton(authProvider.errorMessage!)) ...[
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        authProvider.clearError();
                                        _handleLogin();
                                      },
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppTheme.errorColor,
                                        side: BorderSide(color: AppTheme.errorColor.withOpacity(0.3)),
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      icon: const Icon(Icons.refresh, size: 16),
                                      label: const Text('Cuba Lagi', style: TextStyle(fontSize: 13)),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
                
                const SizedBox(height: 32),
                
                // Sign Up Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Belum ada akaun? ',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.push('/register'),
                      child: Text(
                        'Daftar Sekarang',
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
