import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  bool _isLoading = false;
  String? _error;

  // App Info
  String _appName = 'Ruwaq Jawi';
  String _appVersion = '1.0.0';
  String _supportEmail = 'support@ruwaqjawi.com';

  // Subscription Settings
  bool _enablePremiumSubscription = true;
  double _monthlyPrice = 29.90;
  double _yearlyPrice = 299.00;
  bool _enableFreeTrial = true;

  // Content Settings
  bool _autoApproveContent = false;
  bool _enableDownloads = true;
  int _maxFileSize = 50; // MB
  bool _enableWatermark = true;

  // Notification Settings
  bool _enablePushNotifications = true;
  bool _enableEmailNotifications = true;
  bool _notifyNewContent = true;

  // Security Settings
  bool _requireTwoFactor = false;
  bool _enableSessionTimeout = true;
  int _sessionTimeoutMinutes = 30;
  bool _enableAuditLogging = true;

  // Legal Documents
  String _privacyPolicy = '';
  String _termsOfService = '';
  String _aboutApp = '';

  // System Settings
  bool _maintenanceMode = false;
  bool _debugMode = false;
  bool _autoBackup = true;

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get appName => _appName;
  String get appVersion => _appVersion;
  String get supportEmail => _supportEmail;
  bool get enablePremiumSubscription => _enablePremiumSubscription;
  double get monthlyPrice => _monthlyPrice;
  double get yearlyPrice => _yearlyPrice;
  bool get enableFreeTrial => _enableFreeTrial;
  bool get autoApproveContent => _autoApproveContent;
  bool get enableDownloads => _enableDownloads;
  int get maxFileSize => _maxFileSize;
  bool get enableWatermark => _enableWatermark;
  bool get enablePushNotifications => _enablePushNotifications;
  bool get enableEmailNotifications => _enableEmailNotifications;
  bool get notifyNewContent => _notifyNewContent;
  bool get requireTwoFactor => _requireTwoFactor;
  bool get enableSessionTimeout => _enableSessionTimeout;
  int get sessionTimeoutMinutes => _sessionTimeoutMinutes;
  bool get enableAuditLogging => _enableAuditLogging;
  String get privacyPolicy => _privacyPolicy;
  String get termsOfService => _termsOfService;
  String get aboutApp => _aboutApp;
  bool get maintenanceMode => _maintenanceMode;
  bool get debugMode => _debugMode;
  bool get autoBackup => _autoBackup;

  Future<void> loadSettings() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Try to load from Supabase first
      await _loadFromSupabase();
      
      // Fallback to SharedPreferences
      await _loadFromLocalStorage();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadFromSupabase() async {
    try {
      final Map<String, dynamic> response = await _supabase
          .from('app_settings')
          .select()
          .single();
      _appName = response['app_name'] ?? _appName;
      _appVersion = response['app_version'] ?? _appVersion;
      _supportEmail = response['support_email'] ?? _supportEmail;
      _enablePremiumSubscription = response['enable_premium_subscription'] ?? _enablePremiumSubscription;
      _monthlyPrice = (response['monthly_price'] ?? _monthlyPrice).toDouble();
      _yearlyPrice = (response['yearly_price'] ?? _yearlyPrice).toDouble();
      _enableFreeTrial = response['enable_free_trial'] ?? _enableFreeTrial;
      _autoApproveContent = response['auto_approve_content'] ?? _autoApproveContent;
      _enableDownloads = response['enable_downloads'] ?? _enableDownloads;
      _maxFileSize = response['max_file_size'] ?? _maxFileSize;
      _enableWatermark = response['enable_watermark'] ?? _enableWatermark;
      _enablePushNotifications = response['enable_push_notifications'] ?? _enablePushNotifications;
      _enableEmailNotifications = response['enable_email_notifications'] ?? _enableEmailNotifications;
      _notifyNewContent = response['notify_new_content'] ?? _notifyNewContent;
      _requireTwoFactor = response['require_two_factor'] ?? _requireTwoFactor;
      _enableSessionTimeout = response['enable_session_timeout'] ?? _enableSessionTimeout;
      _sessionTimeoutMinutes = response['session_timeout_minutes'] ?? _sessionTimeoutMinutes;
      _enableAuditLogging = response['enable_audit_logging'] ?? _enableAuditLogging;
      _privacyPolicy = response['privacy_policy'] ?? _privacyPolicy;
      _termsOfService = response['terms_of_service'] ?? _termsOfService;
      _aboutApp = response['about_app'] ?? _aboutApp;
      _maintenanceMode = response['maintenance_mode'] ?? _maintenanceMode;
      _debugMode = response['debug_mode'] ?? _debugMode;
      _autoBackup = response['auto_backup'] ?? _autoBackup;
    } catch (e) {
      print('Settings not found in Supabase, using defaults: $e');
    }
  }

  Future<void> _loadFromLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      _appName = prefs.getString('app_name') ?? _appName;
      _appVersion = prefs.getString('app_version') ?? _appVersion;
      _supportEmail = prefs.getString('support_email') ?? _supportEmail;
      _enablePremiumSubscription = prefs.getBool('enable_premium_subscription') ?? _enablePremiumSubscription;
      _monthlyPrice = prefs.getDouble('monthly_price') ?? _monthlyPrice;
      _yearlyPrice = prefs.getDouble('yearly_price') ?? _yearlyPrice;
      _enableFreeTrial = prefs.getBool('enable_free_trial') ?? _enableFreeTrial;
      _autoApproveContent = prefs.getBool('auto_approve_content') ?? _autoApproveContent;
      _enableDownloads = prefs.getBool('enable_downloads') ?? _enableDownloads;
      _maxFileSize = prefs.getInt('max_file_size') ?? _maxFileSize;
      _enableWatermark = prefs.getBool('enable_watermark') ?? _enableWatermark;
      _enablePushNotifications = prefs.getBool('enable_push_notifications') ?? _enablePushNotifications;
      _enableEmailNotifications = prefs.getBool('enable_email_notifications') ?? _enableEmailNotifications;
      _notifyNewContent = prefs.getBool('notify_new_content') ?? _notifyNewContent;
      _requireTwoFactor = prefs.getBool('require_two_factor') ?? _requireTwoFactor;
      _enableSessionTimeout = prefs.getBool('enable_session_timeout') ?? _enableSessionTimeout;
      _sessionTimeoutMinutes = prefs.getInt('session_timeout_minutes') ?? _sessionTimeoutMinutes;
      _enableAuditLogging = prefs.getBool('enable_audit_logging') ?? _enableAuditLogging;
      _privacyPolicy = prefs.getString('privacy_policy') ?? _privacyPolicy;
      _termsOfService = prefs.getString('terms_of_service') ?? _termsOfService;
      _aboutApp = prefs.getString('about_app') ?? _aboutApp;
      _maintenanceMode = prefs.getBool('maintenance_mode') ?? _maintenanceMode;
      _debugMode = prefs.getBool('debug_mode') ?? _debugMode;
      _autoBackup = prefs.getBool('auto_backup') ?? _autoBackup;
    } catch (e) {
      print('Error loading from local storage: $e');
    }
  }

  Future<void> saveSettings() async {
    try {
      // Save to Supabase
      await _saveToSupabase();
      
      // Save to local storage as backup
      await _saveToLocalStorage();
      
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> _saveToSupabase() async {
    try {
      final settingsData = {
        'app_name': _appName,
        'app_version': _appVersion,
        'support_email': _supportEmail,
        'enable_premium_subscription': _enablePremiumSubscription,
        'monthly_price': _monthlyPrice,
        'yearly_price': _yearlyPrice,
        'enable_free_trial': _enableFreeTrial,
        'auto_approve_content': _autoApproveContent,
        'enable_downloads': _enableDownloads,
        'max_file_size': _maxFileSize,
        'enable_watermark': _enableWatermark,
        'enable_push_notifications': _enablePushNotifications,
        'enable_email_notifications': _enableEmailNotifications,
        'notify_new_content': _notifyNewContent,
        'require_two_factor': _requireTwoFactor,
        'enable_session_timeout': _enableSessionTimeout,
        'session_timeout_minutes': _sessionTimeoutMinutes,
        'enable_audit_logging': _enableAuditLogging,
        'privacy_policy': _privacyPolicy,
        'terms_of_service': _termsOfService,
        'about_app': _aboutApp,
        'maintenance_mode': _maintenanceMode,
        'debug_mode': _debugMode,
        'auto_backup': _autoBackup,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _supabase
          .from('app_settings')
          .upsert(settingsData);
    } catch (e) {
      print('Error saving to Supabase: $e');
    }
  }

  Future<void> _saveToLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setString('app_name', _appName);
      await prefs.setString('app_version', _appVersion);
      await prefs.setString('support_email', _supportEmail);
      await prefs.setBool('enable_premium_subscription', _enablePremiumSubscription);
      await prefs.setDouble('monthly_price', _monthlyPrice);
      await prefs.setDouble('yearly_price', _yearlyPrice);
      await prefs.setBool('enable_free_trial', _enableFreeTrial);
      await prefs.setBool('auto_approve_content', _autoApproveContent);
      await prefs.setBool('enable_downloads', _enableDownloads);
      await prefs.setInt('max_file_size', _maxFileSize);
      await prefs.setBool('enable_watermark', _enableWatermark);
      await prefs.setBool('enable_push_notifications', _enablePushNotifications);
      await prefs.setBool('enable_email_notifications', _enableEmailNotifications);
      await prefs.setBool('notify_new_content', _notifyNewContent);
      await prefs.setBool('require_two_factor', _requireTwoFactor);
      await prefs.setBool('enable_session_timeout', _enableSessionTimeout);
      await prefs.setInt('session_timeout_minutes', _sessionTimeoutMinutes);
      await prefs.setBool('enable_audit_logging', _enableAuditLogging);
      await prefs.setString('privacy_policy', _privacyPolicy);
      await prefs.setString('terms_of_service', _termsOfService);
      await prefs.setString('about_app', _aboutApp);
      await prefs.setBool('maintenance_mode', _maintenanceMode);
      await prefs.setBool('debug_mode', _debugMode);
      await prefs.setBool('auto_backup', _autoBackup);
    } catch (e) {
      print('Error saving to local storage: $e');
    }
  }

  // Update methods
  void updateAppInfo(String name, String version, String email) {
    _appName = name;
    _appVersion = version;
    _supportEmail = email;
    notifyListeners();
  }

  void updatePremiumSubscription(bool enabled) {
    _enablePremiumSubscription = enabled;
    notifyListeners();
  }

  void updateMonthlyPrice(double price) {
    _monthlyPrice = price;
    notifyListeners();
  }

  void updateYearlyPrice(double price) {
    _yearlyPrice = price;
    notifyListeners();
  }

  void updateFreeTrial(bool enabled) {
    _enableFreeTrial = enabled;
    notifyListeners();
  }

  void updateAutoApproveContent(bool enabled) {
    _autoApproveContent = enabled;
    notifyListeners();
  }

  void updateDownloads(bool enabled) {
    _enableDownloads = enabled;
    notifyListeners();
  }

  void updateMaxFileSize(int size) {
    _maxFileSize = size;
    notifyListeners();
  }

  void updateWatermark(bool enabled) {
    _enableWatermark = enabled;
    notifyListeners();
  }

  void updatePushNotifications(bool enabled) {
    _enablePushNotifications = enabled;
    notifyListeners();
  }

  void updateEmailNotifications(bool enabled) {
    _enableEmailNotifications = enabled;
    notifyListeners();
  }

  void updateNewContentNotification(bool enabled) {
    _notifyNewContent = enabled;
    notifyListeners();
  }

  void updateTwoFactor(bool enabled) {
    _requireTwoFactor = enabled;
    notifyListeners();
  }

  void updateSessionTimeout(bool enabled) {
    _enableSessionTimeout = enabled;
    notifyListeners();
  }

  void updateSessionTimeoutMinutes(int minutes) {
    _sessionTimeoutMinutes = minutes;
    notifyListeners();
  }

  void updateAuditLogging(bool enabled) {
    _enableAuditLogging = enabled;
    notifyListeners();
  }

  void updateLegalDocuments(String privacy, String terms, String about) {
    _privacyPolicy = privacy;
    _termsOfService = terms;
    _aboutApp = about;
    notifyListeners();
  }

  void updateMaintenanceMode(bool enabled) {
    _maintenanceMode = enabled;
    notifyListeners();
  }

  void updateDebugMode(bool enabled) {
    _debugMode = enabled;
    notifyListeners();
  }

  void updateAutoBackup(bool enabled) {
    _autoBackup = enabled;
    notifyListeners();
  }

  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      
      // Clear other caches here (images, files, etc.)
      
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> resetSettings() async {
    try {
      // Reset to default values
      _appName = 'Ruwaq Jawi';
      _appVersion = '1.0.0';
      _supportEmail = 'support@ruwaqjawi.com';
      _enablePremiumSubscription = true;
      _monthlyPrice = 29.90;
      _yearlyPrice = 299.00;
      _enableFreeTrial = true;
      _autoApproveContent = false;
      _enableDownloads = true;
      _maxFileSize = 50;
      _enableWatermark = true;
      _enablePushNotifications = true;
      _enableEmailNotifications = true;
      _notifyNewContent = true;
      _requireTwoFactor = false;
      _enableSessionTimeout = true;
      _sessionTimeoutMinutes = 30;
      _enableAuditLogging = true;
      _privacyPolicy = '';
      _termsOfService = '';
      _aboutApp = '';
      _maintenanceMode = false;
      _debugMode = false;
      _autoBackup = true;

      await saveSettings();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> createBackup() async {
    try {
      // Create backup logic here
      // This could export settings to a file or cloud storage
      
      print('Creating backup...');
      await Future.delayed(const Duration(seconds: 2)); // Simulate backup process
      print('Backup created successfully');
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
