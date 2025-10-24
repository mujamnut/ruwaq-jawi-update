import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

class DeepLinkService {
  static GoRouter? _router;
  static StreamSubscription<AuthState>? _authSubscription;

  static void initialize(GoRouter router) {
    _router = router;
    _setupDeepLinkListener();
  }

  static void _setupDeepLinkListener() {
    // Listen to Supabase auth state changes to handle deep links
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) async {
        // Debug logging removed
        // Debug logging removed
        
        // Handle auth errors from deep links
        if (data.event == AuthChangeEvent.passwordRecovery) {
          // Password recovery deep link - extract token from session
          final token = data.session?.accessToken;
          if (token != null) {
            _router?.go('/auth/reset-password?token=$token');
          } else {
            _router?.go('/auth/reset-password');
          }
        } else if (data.event == AuthChangeEvent.signedIn) {
          // Only handle email confirmation from deep links, not normal login
          // Check if this is specifically from email confirmation deep link
          // We can detect this by checking if user was previously unauthenticated
          // and emailConfirmedAt was just updated
          // Debug logging removed
        }
      },
    );
  }

  // Removed custom MethodChannel handler to prevent conflicts with Supabase


  static Future<void> handleDeepLink(Uri uri) async {
    // Debug logging removed

    // Check for error parameters first
    final params = uri.queryParameters;
    if (params.containsKey('error')) {
      final error = params['error'];
      final errorDescription = params['error_description'];
      
      if (error == 'access_denied' && errorDescription?.contains('expired') == true) {
        _router?.go('/auth/login?error=link_expired');
        return;
      }
    }

    // Handle different deep link schemes
    if (uri.scheme == 'ruwaqjawi') {
      await _handleRuwaqJawiLink(uri);
    } else if (uri.scheme == 'io.supabase.flutterquickstart') {
      await _handleSupabaseAuthLink(uri);
    }
  }

  static Future<void> _handleRuwaqJawiLink(Uri uri) async {
    if (uri.host == 'auth') {
      if (uri.path.startsWith('/reset-password')) {
        await _handlePasswordReset(uri);
      } else if (uri.path.startsWith('/confirm')) {
        await _handleEmailConfirmation(uri);
      }
    } else if (uri.host == 'payment') {
      await _handlePaymentCallback(uri);
    }
  }

  static Future<void> _handleSupabaseAuthLink(Uri uri) async {
    // Handle Supabase auth callbacks
    final fragment = uri.fragment;
    if (fragment.isNotEmpty) {
      // Parse the fragment for auth tokens
      final params = Uri.splitQueryString(fragment);
      
      if (params.containsKey('access_token')) {
        // This is handled automatically by Supabase
        _router?.go('/home');
      }
    }
  }

  static Future<void> _handlePasswordReset(Uri uri) async {
    final params = uri.queryParameters;
    final token = params['token'];
    final type = params['type'];

    if (token != null && type == 'recovery') {
      // Navigate to password reset screen with token
      _router?.go('/auth/reset-password?token=$token');
    } else {
      // Invalid or missing token, navigate to login
      _router?.go('/auth/login');
    }
  }

  static Future<void> _handleEmailConfirmation(Uri uri) async {
    final params = uri.queryParameters;
    final token = params['token'];
    final type = params['type'];

    if (token != null && type == 'signup') {
      // Navigate to verification screen with token for manual confirmation
      // Do NOT auto-verify to prevent unauthorized access
      _router?.go('/auth/verify-email?token=$token&type=$type');
    } else {
      // Invalid or missing token
      _router?.go('/auth/login?error=invalid_token');
    }
  }

  static Future<void> _handlePaymentCallback(Uri uri) async {
    final params = uri.queryParameters;
    final status = params['status'];
    final paymentId = params['payment_id'];

    if (status == 'success' && paymentId != null) {
      _router?.go('/payment/success?payment_id=$paymentId');
    } else if (status == 'failed') {
      _router?.go('/payment/failed');
    } else {
      _router?.go('/payment/cancelled');
    }
  }

  // Removed _handleAuthCallback to prevent unauthorized auto-login
  // Auth state should be managed by AuthProvider only

  static void dispose() {
    _authSubscription?.cancel();
    _authSubscription = null;
  }

  // Helper method to generate deep link URLs for email templates
  static String generatePasswordResetUrl(String token) {
    return 'ruwaqjawi://auth/reset-password?token=$token&type=recovery';
  }

  static String generateEmailConfirmationUrl(String token) {
    return 'ruwaqjawi://auth/confirm?token=$token&type=signup';
  }

  // Web fallback URLs for email links
  static String generateWebPasswordResetUrl(String token) {
    return 'https://ruwaqjawi.com/auth/reset-password?token=$token&type=recovery';
  }

  static String generateWebEmailConfirmationUrl(String token) {
    return 'https://ruwaqjawi.com/auth/confirm?token=$token&type=signup';
  }
}
