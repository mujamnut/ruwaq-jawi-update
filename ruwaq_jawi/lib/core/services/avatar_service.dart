import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';

/// Service for managing user avatars with multiple fallback options
///
/// Fallback strategy:
/// 1. Gravatar (if user has registered with same email)
/// 2. UI-Avatars API (generated with initials)
/// 3. Generated initials avatar (local fallback)
class AvatarService {
  static const String _gravatarBaseUrl = 'https://www.gravatar.com/avatar';
  static const String _uiAvatarsBaseUrl = 'https://ui-avatars.com/api';

  // Cache for avatar URLs to avoid repeated API calls
  static final Map<String, String> _avatarCache = {};

  /// Get avatar URL for a user's email with fallbacks
  ///
  /// [email] User's email address
  /// [name] User's display name (for initials fallback)
  /// [size] Avatar size in pixels (default: 80)
  /// [forceRefresh] If true, bypasses cache and fetches fresh avatar
  ///
  /// Returns URL string for the avatar image
  static Future<String> getAvatarUrl({
    required String email,
    String? name,
    int size = 80,
    bool forceRefresh = false,
  }) async {
    if (kDebugMode) {
      print('AvatarService: getAvatarUrl called for email: $email, name: $name, size: $size, forceRefresh: $forceRefresh');
    }

    if (email.isEmpty) {
      if (kDebugMode) {
        print('AvatarService: Email is empty, returning initials avatar');
      }
      return _getInitialsAvatarUrl(name, size);
    }

    final cacheKey = '${email.toLowerCase()}_$size';

    // Return cached URL if available and not forcing refresh
    if (!forceRefresh && _avatarCache.containsKey(cacheKey)) {
      final cachedUrl = _avatarCache[cacheKey]!;
      if (kDebugMode) {
        print('AvatarService: Returning cached URL for $email: $cachedUrl');
      }
      return cachedUrl;
    }

    // Try Gravatar first
    try {
      final gravatarUrl = _getGravatarUrl(email, size);
      if (kDebugMode) {
        print('AvatarService: Trying Gravatar URL: $gravatarUrl');
      }

      final isValid = await _isValidImageUrl(gravatarUrl);
      if (kDebugMode) {
        print('AvatarService: Gravatar URL validation result: $isValid');
      }

      if (isValid) {
        _avatarCache[cacheKey] = gravatarUrl;
        if (kDebugMode) {
          print('AvatarService: Gravatar is valid, caching and returning: $gravatarUrl');
        }
        return gravatarUrl;
      } else {
        if (kDebugMode) {
          print('AvatarService: Gravatar URL is not valid or no image found');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('AvatarService: Gravatar fetch failed for $email: $e');
      }
    }

    // Fallback to UI-Avatars API
    try {
      final uiAvatarUrl = _getUIAvatarUrl(name ?? email, size);
      if (kDebugMode) {
        print('AvatarService: Trying UI-Avatars API URL: $uiAvatarUrl');
      }

      _avatarCache[cacheKey] = uiAvatarUrl;
      if (kDebugMode) {
        print('AvatarService: UI-Avatars API successful, caching and returning: $uiAvatarUrl');
      }
      return uiAvatarUrl;
    } catch (e) {
      if (kDebugMode) {
        print('AvatarService: UI-Avatars API failed for $email: $e');
      }
    }

    // Final fallback to generated initials avatar
    final initialsUrl = _getInitialsAvatarUrl(name, size);
    _avatarCache[cacheKey] = initialsUrl;
    if (kDebugMode) {
      print('AvatarService: Using initials fallback: $initialsUrl');
    }
    return initialsUrl;
  }

  /// Generate Gravatar URL from email
  static String _getGravatarUrl(String email, int size) {
    final normalizedEmail = email.toLowerCase().trim();
    final bytes = utf8.encode(normalizedEmail);
    final digest = md5.convert(bytes);

    return '$_gravatarBaseUrl/${digest.toString()}?s=$size&d=404&r=g';
  }

  /// Generate UI-Avatars API URL
  static String _getUIAvatarUrl(String name, int size) {
    final nameParam = Uri.encodeComponent(name);
    return '$_uiAvatarsBaseUrl/?name=$nameParam&size=$size&background=random&color=fff&font-size=0.5&bold=true';
  }

  /// Generate placeholder URL for initials-based avatar
  static String _getInitialsAvatarUrl(String? name, int size) {
    // This won't actually generate an image URL, but indicates to the widget
    // that it should generate a local initials avatar
    return 'initials://${name?.isNotEmpty == true ? name!.trim() : 'User'}?size=$size';
  }

  /// Extract initials from name
  static String getInitials(String? name) {
    if (name == null || name.trim().isEmpty) {
      return 'U';
    }

    final parts = name.trim().split(' ');
    if (parts.length == 1) {
      return parts[0].substring(0, 1).toUpperCase();
    }

    // Take first letter of first two words
    return '${parts[0].substring(0, 1)}${parts[1].substring(0, 1)}'.toUpperCase();
  }

  /// Check if URL returns a valid image
  static Future<bool> _isValidImageUrl(String url) async {
    try {
      // Skip check for initials:// URLs
      if (url.startsWith('initials://')) {
        return false;
      }

      final response = await http.head(
        Uri.parse(url),
      ).timeout(const Duration(seconds: 5));

      // Check if response is successful and content type is image
      return response.statusCode == 200 &&
             response.headers['content-type']?.startsWith('image/') == true;
    } catch (e) {
      if (kDebugMode) {
        print('AvatarService: Error checking image validity: $e');
      }
      return false;
    }
  }

  /// Clear avatar cache for a specific email or all cache
  static void clearCache({String? email}) {
    if (email != null) {
      // Clear specific email entries from cache
      _avatarCache.removeWhere((key, value) => key.startsWith(email.toLowerCase()));
    } else {
      // Clear all cache
      _avatarCache.clear();
    }
  }

  /// Get cached avatar URL for an email (if exists)
  static String? getCachedAvatarUrl(String email, {int size = 80}) {
    final cacheKey = '${email.toLowerCase()}_$size';
    return _avatarCache[cacheKey];
  }

  /// Preload avatar for a user to improve UI performance
  static Future<void> preloadAvatar({
    required String email,
    String? name,
    int size = 80,
  }) async {
    try {
      await getAvatarUrl(email: email, name: name, size: size);
    } catch (e) {
      if (kDebugMode) {
        print('AvatarService: Failed to preload avatar for $email: $e');
      }
    }
  }

  /// Get avatar source information
  static Future<AvatarSource> getAvatarSource({
    required String email,
    String? name,
    int size = 80,
  }) async {
    if (email.isEmpty) {
      return AvatarSource.initials;
    }

    try {
      final gravatarUrl = _getGravatarUrl(email, size);
      if (await _isValidImageUrl(gravatarUrl)) {
        return AvatarSource.gravatar;
      }
    } catch (e) {
      // Continue to next check
    }

    // If Gravatar fails, check if UI-Avatars would be used
    final initialsUrl = _getInitialsAvatarUrl(name, size);
    return initialsUrl.startsWith('initials://') ? AvatarSource.initials : AvatarSource.uiAvatars;
  }
}

/// Enum representing the source of the avatar
enum AvatarSource {
  gravatar,
  uiAvatars,
  initials,
  custom,
}