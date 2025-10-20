import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

/// Configuration service for notification settings
/// Manages visibility rules and filtering policies
class NotificationConfigService {
  static final _supabase = Supabase.instance.client;
  static DateTime? _cachedCutoffDate;
  static bool? _cachedHideLegacyEnabled;
  static bool? _cachedFilteringEnabled;
  static DateTime? _cacheExpiry;

  /// Get the cutoff date for legacy notifications
  static Future<DateTime> getLegacyCutoffDate() async {
    _checkCacheValidity();

    if (_cachedCutoffDate != null && _cacheExpiry!.isAfter(DateTime.now())) {
      return _cachedCutoffDate!;
    }

    try {
      final response = await _supabase
          .from('notification_settings')
          .select('value')
          .eq('key', 'legacy_cutoff_date')
          .single();

      final cutoffDate = DateTime.parse(response['value']).toUtc();
      _cachedCutoffDate = cutoffDate;
      _cacheExpiry = DateTime.now().add(const Duration(hours: 1)); // Cache for 1 hour

      if (kDebugMode) {
        print('🔧 NotificationConfig: Legacy cutoff date loaded: $cutoffDate');
      }

      return cutoffDate;
    } catch (e) {
      if (kDebugMode) {
        print('❌ NotificationConfig: Failed to load cutoff date, using default: $e');
      }
      // Fallback to default cutoff date
      final defaultDate = DateTime(2024, 1, 1).toUtc();
      _cachedCutoffDate = defaultDate;
      _cacheExpiry = DateTime.now().add(const Duration(hours: 1));
      return defaultDate;
    }
  }

  /// Check if legacy notifications should be hidden from new users
  static Future<bool> shouldHideLegacyFromNewUsers() async {
    _checkCacheValidity();

    if (_cachedHideLegacyEnabled != null && _cacheExpiry!.isAfter(DateTime.now())) {
      return _cachedHideLegacyEnabled!;
    }

    try {
      final response = await _supabase
          .from('notification_settings')
          .select('value')
          .eq('key', 'hide_legacy_from_new_users')
          .single();

      final shouldHide = response['value'].toString().toLowerCase() == 'true';
      _cachedHideLegacyEnabled = shouldHide;
      _cacheExpiry = DateTime.now().add(const Duration(hours: 1));

      if (kDebugMode) {
        print('🔧 NotificationConfig: Hide legacy from new users: $shouldHide');
      }

      return shouldHide;
    } catch (e) {
      if (kDebugMode) {
        print('❌ NotificationConfig: Failed to load hide legacy setting, using default: $e');
      }
      // Fallback to default (enabled)
      _cachedHideLegacyEnabled = true;
      _cacheExpiry = DateTime.now().add(const Duration(hours: 1));
      return true;
    }
  }

  /// Check if notification filtering is enabled
  static Future<bool> isFilteringEnabled() async {
    _checkCacheValidity();

    if (_cachedFilteringEnabled != null && _cacheExpiry!.isAfter(DateTime.now())) {
      return _cachedFilteringEnabled!;
    }

    try {
      final response = await _supabase
          .from('notification_settings')
          .select('value')
          .eq('key', 'notification_filtering_enabled')
          .single();

      final enabled = response['value'].toString().toLowerCase() == 'true';
      _cachedFilteringEnabled = enabled;
      _cacheExpiry = DateTime.now().add(const Duration(hours: 1));

      if (kDebugMode) {
        print('🔧 NotificationConfig: Filtering enabled: $enabled');
      }

      return enabled;
    } catch (e) {
      if (kDebugMode) {
        print('❌ NotificationConfig: Failed to load filtering setting, using default: $e');
      }
      // Fallback to default (enabled)
      _cachedFilteringEnabled = true;
      _cacheExpiry = DateTime.now().add(const Duration(hours: 1));
      return true;
    }
  }

  /// Determine if a notification should be hidden from a user based on registration date
  static Future<bool> shouldHideNotificationFromUser({
    required DateTime notificationDate,
    required DateTime userRegistrationDate,
    String? source,
  }) async {
    // Don't hide if filtering is disabled
    final filteringEnabled = await isFilteringEnabled();
    if (!filteringEnabled) {
      return false;
    }

    // Quick rule: hide notifications created before the user's registration date
    // This prevents brand-new users from seeing older announcements
    if (notificationDate.isBefore(userRegistrationDate)) {
      if (kDebugMode) {
        print('🔎 NotificationFilter: Hiding because notification < registration');
      }
      return true;
    }

    // Don't hide if hide legacy is disabled
    final hideLegacyEnabled = await shouldHideLegacyFromNewUsers();
    if (!hideLegacyEnabled) {
      return false;
    }

    // Get cutoff date
    final cutoffDate = await getLegacyCutoffDate();

    // Hide if notification is before cutoff AND user registered after cutoff
    final isNotificationLegacy = notificationDate.isBefore(cutoffDate);
    final isUserNew = userRegistrationDate.isAfter(cutoffDate);

    if (kDebugMode) {
      print('🔍 NotificationFilter Check:');
      print('  Notification date: $notificationDate');
      print('  User registration: $userRegistrationDate');
      print('  Cutoff date: $cutoffDate');
      print('  Is notification legacy: $isNotificationLegacy');
      print('  Is user new: $isUserNew');
      print('  Should hide: ${isNotificationLegacy && isUserNew}');
    }

    return isNotificationLegacy && isUserNew;
  }

  /// Update configuration settings (admin only)
  static Future<bool> updateConfig({
    String? legacyCutoffDate,
    bool? hideLegacyFromNewUsers,
    bool? filteringEnabled,
  }) async {
    try {
      final updates = <String, String>{};

      if (legacyCutoffDate != null) {
        updates['legacy_cutoff_date'] = legacyCutoffDate;
      }
      if (hideLegacyFromNewUsers != null) {
        updates['hide_legacy_from_new_users'] = hideLegacyFromNewUsers.toString();
      }
      if (filteringEnabled != null) {
        updates['notification_filtering_enabled'] = filteringEnabled.toString();
      }

      if (updates.isEmpty) return true;

      // Update each setting
      for (final entry in updates.entries) {
        await _supabase
            .from('notification_settings')
            .update({'value': entry.value, 'updated_at': DateTime.now().toIso8601String()})
            .eq('key', entry.key);
      }

      // Clear cache to force refresh
      _clearCache();

      if (kDebugMode) {
        print('✅ NotificationConfig: Updated configuration: $updates');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ NotificationConfig: Failed to update configuration: $e');
      }
      return false;
    }
  }

  /// Clear cached configuration
  static void _clearCache() {
    _cachedCutoffDate = null;
    _cachedHideLegacyEnabled = null;
    _cachedFilteringEnabled = null;
    _cacheExpiry = null;
  }

  /// Check if cache is still valid
  static void _checkCacheValidity() {
    if (_cacheExpiry != null && _cacheExpiry!.isBefore(DateTime.now())) {
      _clearCache();
    }
  }

  /// Get current configuration as a map
  static Future<Map<String, dynamic>> getCurrentConfig() async {
    try {
      final cutoffDate = await getLegacyCutoffDate();
      final hideLegacy = await shouldHideLegacyFromNewUsers();
      final filteringEnabled = await isFilteringEnabled();

      return {
        'legacy_cutoff_date': cutoffDate.toIso8601String(),
        'hide_legacy_from_new_users': hideLegacy,
        'notification_filtering_enabled': filteringEnabled,
        'cache_status': _cacheExpiry != null ? 'cached' : 'not_cached',
        'cache_expiry': _cacheExpiry?.toIso8601String(),
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ NotificationConfig: Failed to get current config: $e');
      }
      return {};
    }
  }

  /// Initialize default settings if they don't exist
  static Future<bool> initializeDefaults() async {
    try {
      final defaultSettings = {
        'legacy_cutoff_date': '2024-01-01T00:00:00Z',
        'hide_legacy_from_new_users': 'true',
        'notification_filtering_enabled': 'true',
      };

      for (final entry in defaultSettings.entries) {
        await _supabase
            .from('notification_settings')
            .upsert({
              'key': entry.key,
              'value': entry.value,
              'description': _getDefaultDescription(entry.key),
            }, onConflict: 'key');
      }

      // Clear cache to reload new defaults
      _clearCache();

      if (kDebugMode) {
        print('✅ NotificationConfig: Default settings initialized');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ NotificationConfig: Failed to initialize defaults: $e');
      }
      return false;
    }
  }

  /// Get default description for settings
  static String _getDefaultDescription(String key) {
    switch (key) {
      case 'legacy_cutoff_date':
        return 'Cut-off date for legacy notifications';
      case 'hide_legacy_from_new_users':
        return 'Whether to hide legacy notifications from new users';
      case 'notification_filtering_enabled':
        return 'Whether notification filtering is enabled';
      default:
        return 'System setting';
    }
  }
}
