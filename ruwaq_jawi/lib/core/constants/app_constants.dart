class AppConstants {
  // App Information
  static const String appName = 'Maktabah';
  static const String appVersion = '1.0.0';
  static const String appDescription = 'Islamic Educational Content Platform';

  // Build Configurations
  static const String devAppName = 'Maktabah Dev';
  static const String prodAppName = 'Maktabah';
  
  // Bundle IDs
  static const String devBundleId = 'com.maktabah.dev';
  static const String prodBundleId = 'com.maktabah.app';

  // API Endpoints
  static const String devSupabaseUrl = 'https://ckgxglvozrsognqqkpkk.supabase.co';
  static const String prodSupabaseUrl = 'https://ckgxglvozrsognqqkpkk.supabase.co';
  
  // Fallback IP addresses (for DNS issues)
  static const String devSupabaseUrlIP = 'https://104.18.38.10';
  static const String prodSupabaseUrlIP = 'https://172.64.149.246';

  // Payment Gateway Keys (will be configured later)
  static const String devStripeKey = 'pk_test_...';
  static const String prodStripeKey = 'pk_live_...';

  // Feature Flags
  static const bool enableOfflineDownload = true;
  static const bool enableVideoQualitySelection = true;
  static const bool enablePushNotifications = true;
  static const bool enableAnalytics = true;
  static const bool enableCrashReporting = true;

  // Subscription Plans
  static const List<String> subscriptionPlans = [
    '1month',
    '3month', 
    '6month',
    '12month'
  ];

  // User Roles
  static const String studentRole = 'student';
  static const String adminRole = 'admin';

  // Storage Keys
  static const String userTokenKey = 'user_token';
  static const String userRoleKey = 'user_role';
  static const String subscriptionStatusKey = 'subscription_status';
}
