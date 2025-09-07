import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/services/supabase_service.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String? email;
  final String? message;
  final String? token;
  final String? type;

  const EmailVerificationScreen({
    super.key,
    this.email,
    this.message,
    this.token,
    this.type,
  });

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _isResending = false;
  bool _isVerifying = false;
  bool _isVerified = false;

  @override
  void initState() {
    super.initState();
    // If token is provided, show verification option
    if (widget.token != null && widget.type == 'signup') {
      // Don't auto-verify, let user click to verify
    }
  }

  Future<void> _resendVerificationEmail() async {
    if (widget.email == null) return;

    setState(() => _isResending = true);

    try {
      await SupabaseService.client.auth.resend(
        type: OtpType.signup,
        email: widget.email!,
        emailRedirectTo: 'ruwaqjawi://auth/confirm',
      );

      _showSuccessSnackBar('Email verifikasi telah dikirim ulang!');
    } on AuthException catch (e) {
      _showErrorSnackBar(e.message);
    } catch (e) {
      _showErrorSnackBar('Terjadi kesalahan. Silakan coba lagi.');
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _verifyEmailToken() async {
    if (widget.token == null) return;

    setState(() => _isVerifying = true);

    try {
      final response = await SupabaseService.client.auth.verifyOTP(
        token: widget.token!,
        type: OtpType.signup,
      );

      if (response.user != null) {
        setState(() => _isVerified = true);
        _showSuccessSnackBar('Email berjaya disahkan!');
        
        // Sign out to prevent auto-login and force proper login
        await SupabaseService.client.auth.signOut();
        
        // Wait a bit then navigate to login with success message
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          context.go('/auth/login?message=email_confirmed');
        }
      } else {
        _showErrorSnackBar('Token tidak sah atau telah tamat tempoh.');
      }
    } on AuthException catch (e) {
      _showErrorSnackBar(e.message);
    } catch (e) {
      _showErrorSnackBar('Terjadi kesalahan. Silakan coba lagi.');
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verifikasi Email'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              Icon(
                Icons.mark_email_read,
                size: 80,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(height: 24),
              Text(
                'Periksa Email Anda',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              if (widget.email != null) ...[
                Text(
                  'Kami telah mengirim link verifikasi ke:',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  widget.email!,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 16),
              if (widget.message != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Text(
                    widget.message!,
                    style: TextStyle(color: Colors.blue[800]),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Text(
                'Klik link di email untuk mengaktifkan akun Anda. Jika tidak menerima email, periksa folder spam atau kirim ulang.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              if (widget.token != null && widget.type == 'signup' && !_isVerified) ...[
                CustomButton(
                  text: 'Sahkan Email Sekarang',
                  onPressed: !_isVerifying ? _verifyEmailToken : null,
                  isLoading: _isVerifying,
                ),
                const SizedBox(height: 16),
              ] else if (!_isVerified) ...[
                CustomButton(
                  text: 'Kirim Ulang Email',
                  onPressed: widget.email != null && !_isResending ? _resendVerificationEmail : null,
                  isLoading: _isResending,
                ),
              ],
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.go('/auth/login'),
                child: const Text('Kembali ke Login'),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.grey[600],
                      size: 20,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Pastikan untuk mengklik link verifikasi dari perangkat yang sama dengan aplikasi ini untuk aktivasi otomatis.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
