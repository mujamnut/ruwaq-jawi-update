import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/auth_provider.dart';

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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  SizedBox(height: constraints.maxHeight * 0.1),
                  Image.network(
                    "https://i.postimg.cc/nz0YBQcH/Logo-light.png",
                    height: 100,
                  ),
                  SizedBox(height: constraints.maxHeight * 0.1),
                  Text(
                    "Sign In",
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall!
                        .copyWith(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: constraints.maxHeight * 0.05),
                  
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
                  
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            hintText: 'Email',
                            filled: true,
                            fillColor: Color(0xFFF5FCF9),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 16.0 * 1.5, vertical: 16.0),
                            border: OutlineInputBorder(
                              borderSide: BorderSide.none,
                              borderRadius:
                                  BorderRadius.all(Radius.circular(50)),
                            ),
                          ),
                          keyboardType: TextInputType.emailAddress,
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
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          child: TextFormField(
                            controller: _passwordController,
                            obscureText: !_isPasswordVisible,
                            decoration: InputDecoration(
                              hintText: 'Password',
                              filled: true,
                              fillColor: const Color(0xFFF5FCF9),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16.0 * 1.5, vertical: 16.0),
                              border: const OutlineInputBorder(
                                borderSide: BorderSide.none,
                                borderRadius:
                                    BorderRadius.all(Radius.circular(50)),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                                  color: Colors.grey,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isPasswordVisible = !_isPasswordVisible;
                                  });
                                },
                              ),
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
                        ),
                        
                        // Login Button with error handling
                        Consumer<AuthProvider>(
                          builder: (context, authProvider, child) {
                            return Column(
                              children: [
                                ElevatedButton(
                                  onPressed: authProvider.status == AuthStatus.loading 
                                      ? null 
                                      : () {
                                          if (_formKey.currentState!.validate()) {
                                            _handleLogin();
                                          }
                                        },
                                  style: ElevatedButton.styleFrom(
                                    elevation: 0,
                                    backgroundColor: const Color(0xFF00BF6D),
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(double.infinity, 48),
                                    shape: const StadiumBorder(),
                                  ),
                                  child: authProvider.status == AuthStatus.loading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        )
                                      : const Text("Sign in"),
                                ),
                                
                                // Error display
                                if (authProvider.errorMessage != null) ...[
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.red.withOpacity(0.2),
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
                                                color: Colors.red.withOpacity(0.1),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                _getLoginErrorIcon(authProvider.errorMessage!),
                                                color: Colors.red,
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
                                                    style: const TextStyle(
                                                      color: Colors.red,
                                                      fontSize: 15,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    authProvider.errorMessage!,
                                                    style: TextStyle(
                                                      color: Colors.red.withOpacity(0.8),
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
                                                foregroundColor: Colors.red,
                                                side: BorderSide(color: Colors.red.withOpacity(0.3)),
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
                        
                        const SizedBox(height: 16.0),
                        TextButton(
                          onPressed: () => context.push('/forgot-password'),
                          child: Text(
                            'Forgot Password?',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium!
                                .copyWith(
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodyLarge!
                                      .color!
                                      .withOpacity(0.64),
                                ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.push('/register'),
                          child: Text.rich(
                            const TextSpan(
                              text: "Don't have an account? ",
                              children: [
                                TextSpan(
                                  text: "Sign Up",
                                  style: TextStyle(color: Color(0xFF00BF6D)),
                                ),
                              ],
                            ),
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium!
                                .copyWith(
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodyLarge!
                                      .color!
                                      .withOpacity(0.64),
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
