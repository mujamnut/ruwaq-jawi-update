import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_text_field.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String? token;

  const ResetPasswordScreen({
    super.key,
    this.token,
  });

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _tokenExpired = false;
  bool _tokenUsed = false;
  bool _isValidating = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkBasicTokenValidity();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _checkBasicTokenValidity() async {
    // Only do basic validation without consuming the token
    if (widget.token == null || widget.token!.isEmpty) {
      setState(() {
        _isValidating = false;
        _tokenExpired = true;
        _errorMessage = 'Link reset password tidak valid. Sila minta link baharu.';
      });
      return;
    }

    // Check if there's already an active session (user might be logged in)
    final currentSession = Supabase.instance.client.auth.currentSession;
    if (currentSession != null) {
      // Sign out any existing session first
      await Supabase.instance.client.auth.signOut();
    }

    // Just show the form - we'll validate the token when user actually submits
    setState(() {
      _isValidating = false;
    });
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    if (_tokenExpired || _tokenUsed) {
      _showErrorSnackBar('Link tidak sah. Sila minta link reset password baharu.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // First verify the token and get a session (this consumes the token)
      final verifyResponse = await Supabase.instance.client.auth.verifyOTP(
        token: widget.token!,
        type: OtpType.recovery,
      );

      if (verifyResponse.session == null) {
        setState(() {
          _tokenExpired = true;
          _errorMessage = 'Link telah tamat tempoh atau tidak sah. Sila minta link baharu.';
        });
        _showErrorSnackBar(_errorMessage!);
        return;
      }

      // Now update the password with the authenticated session
      final updateResponse = await Supabase.instance.client.auth.updateUser(
        UserAttributes(
          password: _passwordController.text,
        ),
      );

      if (updateResponse.user != null) {
        _showSuccessSnackBar('Password berjaya direset!');

        // Mark token as used to prevent resubmission
        setState(() {
          _tokenUsed = true;
        });

        // Sign out to force user to login with new password
        await Supabase.instance.client.auth.signOut();

        // Delay navigation to show success message
        await Future.delayed(const Duration(seconds: 2));

        if (mounted) {
          context.go('/auth/login');
        }
      } else {
        _showErrorSnackBar('Gagal mengemas kini password. Sila cuba lagi.');
      }
    } on AuthException catch (e) {
      if (e.message.contains('expired') ||
          e.message.contains('invalid') ||
          e.message.contains('used') ||
          e.message.contains('token')) {
        setState(() {
          _tokenExpired = true;
          _errorMessage = 'Link telah tamat tempoh atau telah digunakan. Sila minta link reset password baharu.';
        });
        _showErrorSnackBar(_errorMessage!);
      } else {
        _showErrorSnackBar('Ralat: ${e.message}');
      }
    } catch (e) {
      _showErrorSnackBar('Terjadi kesalahan. Silakan coba lagi.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _requestNewResetLink() {
    context.go('/auth/forgot-password');
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedAlert01,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.red[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.green[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedArrowLeft01,
              color: AppTheme.textPrimaryColor,
              size: 20,
            ),
          ),
          onPressed: () => context.go('/auth/login'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: _isValidating
              ? _buildLoadingState()
              : (_tokenExpired || _tokenUsed)
                  ? _buildErrorState()
                  : _buildResetForm(),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 120),
        const Center(
          child: CircularProgressIndicator(),
        ),
        const SizedBox(height: 24),
        Text(
          'Mengesahkan link reset password...',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppTheme.textSecondaryColor,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 60),

        // Error Icon
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.red[100]!,
                Colors.red[50]!,
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Center(
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedAlert01,
              color: Colors.red[600] ?? Colors.red,
              size: 60,
            ),
          ),
        ),

        const SizedBox(height: 32),

        // Error Title
        Text(
          _tokenUsed ? 'Link Telah Digunakan' : 'Link Tidak Sah',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimaryColor,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 16),

        // Error Message
        Text(
          _errorMessage ?? 'Link reset password tidak sah atau telah tamat tempoh.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppTheme.textSecondaryColor,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 32),

        // Request New Link Button
        CustomButton(
          text: 'Minta Link Baharu',
          onPressed: _requestNewResetLink,
        ),

        const SizedBox(height: 16),

        // Back to Login Button
        TextButton(
          onPressed: () => context.go('/auth/login'),
          child: Text(
            'Kembali ke Login',
            style: TextStyle(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResetForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 40),

          // Success Icon
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primaryColor.withValues(alpha: 0.1),
                  AppTheme.primaryColor.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Center(
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedLockPassword,
                color: AppTheme.primaryColor,
                size: 60,
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Title
          Text(
            'Reset Password',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryColor,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 12),

          // Subtitle
          Text(
            'Masukkan password baharu anda',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppTheme.textSecondaryColor,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 40),

          // New Password Field
          CustomTextField(
            label: 'Password Baharu',
            controller: _passwordController,
            obscureText: _obscurePassword,
            prefixIcon: HugeIcon(
              icon: HugeIcons.strokeRoundedLockPassword,
              color: AppTheme.textSecondaryColor,
              size: 20,
            ),
            suffixIcon: IconButton(
              icon: HugeIcon(
                icon: _obscurePassword
                    ? HugeIcons.strokeRoundedView
                    : HugeIcons.strokeRoundedViewOff,
                color: AppTheme.textSecondaryColor,
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
                return 'Sila masukkan password baharu';
              }
              if (value.length < 6) {
                return 'Password mesti sekurang-kurangnya 6 aksara';
              }
              return null;
            },
          ),

          const SizedBox(height: 20),

          // Confirm Password Field
          CustomTextField(
            label: 'Sahkan Password',
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            prefixIcon: HugeIcon(
              icon: HugeIcons.strokeRoundedLockPassword,
              color: AppTheme.textSecondaryColor,
              size: 20,
            ),
            suffixIcon: IconButton(
              icon: HugeIcon(
                icon: _obscureConfirmPassword
                    ? HugeIcons.strokeRoundedView
                    : HugeIcons.strokeRoundedViewOff,
                color: AppTheme.textSecondaryColor,
                size: 20,
              ),
              onPressed: () {
                setState(() {
                  _obscureConfirmPassword = !_obscureConfirmPassword;
                });
              },
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Sila sahkan password anda';
              }
              if (value != _passwordController.text) {
                return 'Password tidak sama';
              }
              return null;
            },
          ),

          const SizedBox(height: 48),

          // Reset Button
          CustomButton(
            text: 'Reset Password',
            onPressed: _isLoading ? null : _resetPassword,
            isLoading: _isLoading,
          ),

          const SizedBox(height: 16),

          // Back to Login
          TextButton(
            onPressed: () => context.go('/auth/login'),
            child: Text(
              'Kembali ke Login',
              style: TextStyle(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // Add extra space for keyboard
          SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 24),
        ],
      ),
    );
  }
}