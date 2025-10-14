import 'package:flutter/foundation.dart';
import '../utils/app_logger.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Payment configuration file
/// Centralizes all payment-related URLs and settings
class PaymentConfig {
  static bool _isInitialized = false;

  // Cached environment variables
  static String _cachedUserSecretKey = '';
  static String _cachedCategoryCode = '';
  static String _cachedSupabaseProjectUrl = '';
  static bool _cachedIsProduction = false;

  // Initialize environment variables
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await dotenv.load(fileName: ".env");

      // Cache environment variables to avoid repeated dotenv.env calls
      _cachedUserSecretKey = dotenv.env['TOYYIBPAY_SECRET_KEY'] ??
          (kDebugMode ? 'j82mer37-15g3-zezd-nmq3-hcha3n8gt3xz' : '');
      _cachedCategoryCode = dotenv.env['TOYYIBPAY_CATEGORY_CODE'] ??
          (kDebugMode ? 'tcgm3rrx' : '');
      _cachedSupabaseProjectUrl = dotenv.env['SUPABASE_PROJECT_URL'] ??
          (kDebugMode ? 'ckgxglvozrsognqqkpkk.supabase.co' : '');
      _cachedIsProduction = dotenv.env['PAYMENT_PRODUCTION'] == 'true';

      _isInitialized = true;
      AppLogger.info('Environment variables loaded and cached successfully', tag: 'PaymentConfig');

      // Log configuration after successful initialization
      logConfiguration();
    } catch (e) {
      AppLogger.error('Failed to load environment variables', error: e, tag: 'PaymentConfig');
      // Set default values for development if .env file is missing
      _setDevelopmentDefaults();
      _isInitialized = true; // Mark as initialized even with defaults
    }
  }

  // Set development defaults (only for local development)
  static void _setDevelopmentDefaults() {
    // These are only for local development - never for production
    if (kDebugMode) {
      AppLogger.warning('Using development defaults - ensure .env file is configured for production', tag: 'PaymentConfig');

      // Set cached defaults for development
      _cachedUserSecretKey = 'j82mer37-15g3-zezd-nmq3-hcha3n8gt3xz';
      _cachedCategoryCode = 'tcgm3rrx';
      _cachedSupabaseProjectUrl = 'ckgxglvozrsognqqkpkk.supabase.co';
      _cachedIsProduction = false;
    }
  }

  // Toyyibpay Configuration - Using cached values to prevent NotInitializedError
  static bool get isProduction => _cachedIsProduction;

  // Toyyibpay Credentials - Using cached values to prevent NotInitializedError
  static String get userSecretKey => _cachedUserSecretKey;

  static String get categoryCode => _cachedCategoryCode;

  // URLs - Toyyibpay API endpoints
  static String get baseUrl => isProduction
      ? 'https://toyyibpay.com'
      : 'https://dev.toyyibpay.com';

  static String get createBillUrl => '$baseUrl/index.php/api/createBill';
  static String get getBillUrl => '$baseUrl/index.php/api/getBillTransactions';

  // Supabase Edge Function URLs - Using cached values to prevent NotInitializedError
  static String get supabaseProjectUrl => _cachedSupabaseProjectUrl;

  static String get _supabaseFunctionsUrl => 'https://$supabaseProjectUrl/functions/v1';

  // Edge Function URLs
  static String get verifyPaymentUrl => '$_supabaseFunctionsUrl/verify-payment';
  static String get extendSubscriptionUrl => '$_supabaseFunctionsUrl/extend-subscription';
  static String get activateSubscriptionUrl => '$_supabaseFunctionsUrl/activate-subscription';
  static String get paymentRedirectUrl => '$_supabaseFunctionsUrl/payment-redirect';
  static String get toyyibpayWebhookUrl => '$_supabaseFunctionsUrl/toyyibpay-webhook-final';

  // Return URLs
  static String get paymentSuccessUrl => '$_supabaseFunctionsUrl/payment-redirect?status=success';
  static String get paymentFailedUrl => '$_supabaseFunctionsUrl/payment-redirect?status=failed';
  static String get webhookUrl => '$_supabaseFunctionsUrl/toyyibpay-webhook-final';

  // Payment processing settings
  static const Duration verificationTimeout = Duration(seconds: 30);
  static const int maxRetries = 3;
  static const Duration baseRetryDelay = Duration(seconds: 2);
  static const Duration autoNavigateDelay = Duration(seconds: 3);

  // ToyyibPay redirect success indicators
  static const String redirectSuccessStatus = 'success';
  static const String redirectSuccessStatusId = '1';
  static const String redirectFailedStatus = 'failed';
  static const String redirectCancelledStatus = 'cancel';
  static const String redirectCancelledStatusAlt = 'cancelled';

  // Payment status codes
  static const Map<String, String> paymentStatusCodes = {
    '1': 'success',
    '2': 'pending',
    '3': 'failed',
    'x': 'cancelled',
  };

  // Default currency (Toyyibpay only supports MYR)
  static const String defaultCurrency = 'MYR';
  static const String defaultPaymentProvider = 'toyyibpay';

  // Database table names
  static const String paymentsTable = 'payments';
  static const String subscriptionsTable = 'user_subscriptions';
  static const String pendingPaymentsTable = 'pending_payments';
  static const String webhookEventsTable = 'webhook_events';
  static const String subscriptionPlansTable = 'subscription_plans';
  static const String profilesTable = 'profiles';

  // Navigation routes
  static const String successNavigationRoute = '/subscription';
  static const String homeNavigationRoute = '/home';

  // Debug info (using secure logger)
  static void logConfiguration() {
    AppLogger.info('Toyyibpay Configuration:', tag: 'PaymentConfig');
    AppLogger.info('Environment: ${isProduction ? 'Production' : 'Development'}', tag: 'PaymentConfig');
    AppLogger.info('Base URL: $baseUrl', tag: 'PaymentConfig');
    AppLogger.info('Create Bill URL: $createBillUrl', tag: 'PaymentConfig');
    AppLogger.info('Category Code: ${isProduction ? '[REDACTED]' : categoryCode}', tag: 'PaymentConfig');
    AppLogger.info('Success URL: $paymentSuccessUrl', tag: 'PaymentConfig');
    AppLogger.info('Webhook URL: $webhookUrl', tag: 'PaymentConfig');
    AppLogger.info('Edge Functions:', tag: 'PaymentConfig');
    AppLogger.info('  - Verify Payment: $verifyPaymentUrl', tag: 'PaymentConfig');
    AppLogger.info('  - Extend Subscription: $extendSubscriptionUrl', tag: 'PaymentConfig');
    AppLogger.info('  - Activate Subscription: $activateSubscriptionUrl', tag: 'PaymentConfig');
  }

  // Helper method to check if configuration is valid
  static bool get isConfigured {
    // Environment variables are now REQUIRED for security
    if (userSecretKey.isEmpty || categoryCode.isEmpty || supabaseProjectUrl.isEmpty) {
      final missingVars = [
        if (userSecretKey.isEmpty) 'TOYYIBPAY_SECRET_KEY',
        if (categoryCode.isEmpty) 'TOYYIBPAY_CATEGORY_CODE',
        if (supabaseProjectUrl.isEmpty) 'SUPABASE_PROJECT_URL'
      ].join(', ');

      AppLogger.security('🚨 SECURITY ERROR: Required environment variables not set! Missing: $missingVars', tag: 'PaymentConfig');
      return false;
    }

    // In production, add additional validation
    if (isProduction) {
      if (userSecretKey.length < 10 || categoryCode.length < 3) {
        AppLogger.security('🚨 SECURITY ERROR: Invalid credentials format for production!', tag: 'PaymentConfig');
        return false;
      }
    }

    return true;
  }

  // Get secure configuration status
  static String get configStatus {
    if (!isConfigured) {
      if (userSecretKey.isEmpty || categoryCode.isEmpty || supabaseProjectUrl.isEmpty) {
        return 'SECURITY ERROR: Environment variables required';
      }
      if (isProduction) {
        return 'Production mode - invalid credentials format';
      }
      return 'Configuration incomplete';
    }
    return 'Configuration valid';
  }

  // Get payment status from code
  static PaymentStatus getPaymentStatusFromCode(String? statusCode) {
    if (statusCode == null) return PaymentStatus.unknown;

    switch (statusCode.toLowerCase()) {
      case '1':
      case 'success':
        return PaymentStatus.success;
      case '2':
      case 'pending':
        return PaymentStatus.pending;
      case '3':
      case 'failed':
        return PaymentStatus.failed;
      case 'x':
      case 'cancel':
      case 'cancelled':
        return PaymentStatus.cancelled;
      default:
        return PaymentStatus.unknown;
    }
  }

  // Retry delay calculation with exponential backoff
  static Duration getRetryDelay(int attempt) {
    return Duration(seconds: baseRetryDelay.inSeconds * attempt);
  }

  // Get formatted amount for display
  static String formatAmount(double amount) {
    return 'RM${amount.toStringAsFixed(2)}';
  }

  // Generate payment reference number
  static String generatePaymentReference(String userId, String planId) {
    return '${userId}_${planId}_${DateTime.now().millisecondsSinceEpoch}';
  }

  // Get transaction ID prefix based on source
  static String getTransactionIdPrefix(PaymentSource source) {
    switch (source) {
      case PaymentSource.redirect:
        return 'redirect';
      case PaymentSource.webhook:
        return 'webhook';
      case PaymentSource.manual:
        return 'manual';
    }
  }
}

// Payment status enum
enum PaymentStatus {
  success,
  failed,
  pending,
  cancelled,
  unknown,
  error,
}

// Payment source enum
enum PaymentSource {
  redirect,
  webhook,
  manual,
}
