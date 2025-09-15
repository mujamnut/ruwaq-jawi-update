class PaymentConfig {
  // Toyyibpay Configuration
  static const bool isProduction = bool.fromEnvironment(
    'PAYMENT_PRODUCTION',
    defaultValue: false, // BACK TO DEVELOPMENT FOR TESTING
  );

  // Toyyibpay Credentials
  static const String userSecretKey = 'j82mer37-15g3-zezd-nmq3-hcha3n8gt3xz';
  static const String categoryCode = 'tcgm3rrx';

  // URLs - Toyyibpay API endpoints
  static const String baseUrl = isProduction
      ? 'https://toyyibpay.com'
      : 'https://dev.toyyibpay.com';

  static const String createBillUrl = '$baseUrl/index.php/api/createBill';
  static const String getBillUrl = '$baseUrl/index.php/api/getBillTransactions';

  // Debug info
  static void printConfig() {
    print('Toyyibpay Configuration:');
    print('Environment: ${isProduction ? 'Production' : 'Development'}');
    print('Base URL: $baseUrl');
    print('Create Bill URL: $createBillUrl');
    print('Category Code: $categoryCode');
    print('Success URL: $paymentSuccessUrl');
    print('Webhook URL: $webhookUrl');
  }

  // Return URLs
  static const String paymentSuccessUrl =
      'https://ckgxglvozrsognqqkpkk.supabase.co/functions/v1/payment-redirect?status=success';
  static const String paymentFailedUrl =
      'https://ckgxglvozrsognqqkpkk.supabase.co/functions/v1/payment-redirect?status=failed';
  static const String webhookUrl =
      'https://ckgxglvozrsognqqkpkk.supabase.co/functions/v1/payment-webhook';

  // Default currency (Toyyibpay only supports MYR)
  static const String defaultCurrency = 'MYR';

  // Helper method to check if configuration is valid
  static bool get isConfigured =>
      userSecretKey.isNotEmpty && categoryCode.isNotEmpty;
}
