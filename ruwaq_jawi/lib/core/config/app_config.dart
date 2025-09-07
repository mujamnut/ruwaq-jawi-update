import 'package:flutter/foundation.dart';
import '../constants/app_constants.dart';
import 'environment.dart';

class AppConfig {
  static Environment _environment = Environment.development;

  static Environment get environment => _environment;

  static void setEnvironment(Environment env) {
    _environment = env;
  }

  // App Configuration based on environment
  static String get appName {
    switch (_environment) {
      case Environment.development:
        return AppConstants.devAppName;
      case Environment.staging:
        return '${AppConstants.appName} Staging';
      case Environment.production:
        return AppConstants.prodAppName;
    }
  }

  static String get bundleId {
    switch (_environment) {
      case Environment.development:
        return AppConstants.devBundleId;
      case Environment.staging:
        return '${AppConstants.prodBundleId}.staging';
      case Environment.production:
        return AppConstants.prodBundleId;
    }
  }

  static String get supabaseUrl {
    switch (_environment) {
      case Environment.development:
        return AppConstants.devSupabaseUrl;
      case Environment.staging:
        return AppConstants.devSupabaseUrl; // Use dev for staging
      case Environment.production:
        return AppConstants.prodSupabaseUrl;
    }
  }

  static String get stripePublishableKey {
    switch (_environment) {
      case Environment.development:
        return AppConstants.devStripeKey;
      case Environment.staging:
        return AppConstants.devStripeKey;
      case Environment.production:
        return AppConstants.prodStripeKey;
    }
  }

  // Debug settings
  static bool get isDebug => kDebugMode;
  static bool get isProduction => _environment == Environment.production;
  static bool get isDevelopment => _environment == Environment.development;
}
