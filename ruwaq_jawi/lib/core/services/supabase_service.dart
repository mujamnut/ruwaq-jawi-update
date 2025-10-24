import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';
import '../config/env_config.dart';
import '../models/user_profile.dart';
import '../models/category.dart' as CategoryModel;
import '../models/kitab.dart';
import '../models/transaction.dart';
import '../models/saved_item.dart';
import '../models/reading_progress.dart';
import '../models/app_settings.dart';
import '../models/kitab_video_part.dart';

class SupabaseService {
  static SupabaseClient? _client;

  static SupabaseClient get client {
    if (_client == null) {
      throw Exception('Supabase not initialized. Call initialize() first.');
    }
    return _client!;
  }

  // Alias for client - commonly used in other parts of the app
  static SupabaseClient get supabase => client;

  static Future<void> initialize() async {
    try {
      // Load configuration from environment
      final String supabaseUrl = EnvConfig.supabaseUrl;
      final String supabaseAnonKey = EnvConfig.supabaseAnonKey;

      if (kDebugMode) {
        EnvConfig.printConfig();
        // Debug logging removed
      }

      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
        debug: AppConfig.isDevelopment,
        // Note: PKCE is the default flow on mobile in supabase_flutter >=2.
        // Keep authOptions default to avoid version mismatch errors.
      );

      _client = Supabase.instance.client;

      if (kDebugMode) {
        // Debug logging removed
      }
    } catch (e) {
      if (kDebugMode) {
        // Debug logging removed
      }
      throw Exception('Gagal menghubungkan ke pangkalan data: ${e.toString()}');
    }
  }

  // Authentication helpers
  static User? get currentUser => client.auth.currentUser;
  static bool get isAuthenticated => currentUser != null;

  // Database helpers
  static SupabaseQueryBuilder from(String table) => client.from(table);
  static SupabaseStorageClient get storage => client.storage;

  // Auth methods
  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    Map<String, dynamic>? data,
  }) async {
    return await client.auth.signUp(
      email: email,
      password: password,
      data: data,
      emailRedirectTo: 'ruwaqjawi://auth/confirm',
    ).timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        throw Exception('Masa pendaftaran terlalu lama. Sila semak sambungan internet anda.');
      },
    );
  }

  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    ).timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        throw Exception('Masa log masuk terlalu lama. Sila semak sambungan internet anda.');
      },
    );
  }

  // OAuth: Google Sign-In
  static Future<void> signInWithGoogle({String? redirectTo}) async {
    // Use a web bounce page by default to avoid transient 404 pages,
    // then deep-link back into the app via custom scheme inside that page.
    final String callback = redirectTo ?? 'https://ruwaqjawi.com/oauth-redirect';
    if (kIsWeb) {
      await client.auth
          .signInWithOAuth(OAuthProvider.google)
          .timeout(const Duration(seconds: 30), onTimeout: () {
        throw Exception('Masa log masuk Google terlalu lama. Cuba lagi.');
      });
    } else {
      await client.auth
          .signInWithOAuth(OAuthProvider.google, redirectTo: callback)
          .timeout(const Duration(seconds: 30), onTimeout: () {
        throw Exception('Masa log masuk Google terlalu lama. Cuba lagi.');
      });
    }
  }

  static Future<void> signOut() async {
    await client.auth.signOut();
  }

  static Future<void> resetPassword(String email) async {
    await client.auth.resetPasswordForEmail(
      email,
      redirectTo: 'ruwaqjawi://auth/reset-password',
    ).timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        throw Exception('Masa reset kata laluan terlalu lama. Sila semak sambungan internet anda.');
      },
    );
  }

  // Profile operations
  static Future<UserProfile?> getCurrentUserProfile() async {
    final user = currentUser;
    if (user == null) return null;

    final response = await from('profiles').select().eq('id', user.id).single();

    return UserProfile.fromJson(response);
  }

  static Future<void> updateProfile(UserProfile profile) async {
    await from('profiles').update(profile.toJson()).eq('id', profile.id);
  }

  // Category operations
  static Future<List<CategoryModel.Category>> getActiveCategories() async {
    final response = await from(
      'categories',
    ).select().eq('is_active', true).order('sort_order');

    return (response as List).map((json) => CategoryModel.Category.fromJson(json)).toList();
  }

  // Kitab operations
  static Future<List<Kitab>> getKitabByCategory(String? categoryId) async {
    var query = from('kitab').select().eq('is_active', true);

    if (categoryId != null) {
      query = query.eq('category_id', categoryId);
    }

    final response = await query.order('sort_order');

    return (response as List).map((json) => Kitab.fromJson(json)).toList();
  }

  static Future<List<Kitab>> searchKitab(String query) async {
    final response = await from('kitab')
        .select()
        .eq('is_active', true)
        .or(
          'title.ilike.%$query%,author.ilike.%$query%,description.ilike.%$query%',
        )
        .order('sort_order');

    return (response as List).map((json) => Kitab.fromJson(json)).toList();
  }

  static Future<Kitab?> getKitabById(String id) async {
    final response = await from('kitab').select().eq('id', id).single();

    return Kitab.fromJson(response);
  }

  // Subscription operations
  static Future<List<Map<String, dynamic>>> getUserSubscriptions() async {
    final user = currentUser;
    if (user == null) throw Exception('User not authenticated');

    final response = await from(
      'user_subscriptions',
    ).select().eq('user_id', user.id).order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  static Future<bool> hasActiveSubscription() async {
    final user = currentUser;
    if (user == null) return false;

    final now = DateTime.now().toIso8601String();
    final response = await from('user_subscriptions')
        .select()
        .eq('user_id', user.id)
        .eq('status', 'active')
        .gte('end_date', now)
        .lte('start_date', now)
        .limit(1);

    return response.isNotEmpty;
  }

  // Saved items operations
  static Future<List<SavedItem>> getUserSavedItems() async {
    final user = currentUser;
    if (user == null) throw Exception('User not authenticated');

    final response = await from(
      'saved_items',
    ).select().eq('user_id', user.id).order('created_at', ascending: false);

    return (response as List).map((json) => SavedItem.fromJson(json)).toList();
  }

  static Future<void> saveKitab(
    String kitabId, {
    String? folderName,
    String? notes,
  }) async {
    final user = currentUser;
    if (user == null) throw Exception('User not authenticated');

    await from('saved_items').insert({
      'user_id': user.id,
      'kitab_id': kitabId,
      'folder_name': folderName ?? 'Default',
      'notes': notes,
    });
  }

  static Future<void> removeSavedKitab(String kitabId) async {
    final user = currentUser;
    if (user == null) throw Exception('User not authenticated');

    await from(
      'saved_items',
    ).delete().eq('user_id', user.id).eq('kitab_id', kitabId);
  }

  // Reading progress operations
  static Future<ReadingProgress?> getReadingProgress(String kitabId) async {
    final user = currentUser;
    if (user == null) return null;

    try {
      final response = await from(
        'reading_progress',
      ).select().eq('user_id', user.id).eq('kitab_id', kitabId).single();

      return ReadingProgress.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  static Future<void> updateReadingProgress(ReadingProgress progress) async {
    final user = currentUser;
    if (user == null) throw Exception('User not authenticated');

    await from('reading_progress').upsert(progress.toJson());
  }

  // App settings operations
  static Future<List<AppSettings>> getPublicSettings() async {
    final response = await from('app_settings').select().eq('is_public', true);

    return (response as List)
        .map((json) => AppSettings.fromJson(json))
        .toList();
  }

  static Future<AppSettings?> getSetting(String key) async {
    try {
      final response = await from(
        'app_settings',
      ).select().eq('setting_key', key).single();

      return AppSettings.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  // Payment operations (using payments table instead of transactions)
  static Future<List<Transaction>> getUserTransactions() async {
    final user = currentUser;
    if (user == null) throw Exception('User not authenticated');

    final response = await from(
      'payments',
    ).select().eq('user_id', user.id).order('created_at', ascending: false);

    return (response as List)
        .map((json) => Transaction.fromJson(json))
        .toList();
  }

  static Future<Transaction> createTransaction({
    required String subscriptionId,
    required double amount,
    required String paymentMethod,
    String currency = 'MYR',
    Map<String, dynamic>? metadata,
  }) async {
    final user = currentUser;
    if (user == null) throw Exception('User not authenticated');

    final response = await from('payments')
        .insert({
          'user_id': user.id,
          'amount_cents': (amount * 100).round(), // Convert to cents
          'currency': currency,
          'status': 'pending',
          'provider': paymentMethod.toLowerCase().contains('toyyib') ? 'toyyibpay' : 'manual',
          'description': 'Subscription payment',
          'metadata': metadata ?? {},
          'plan_id': subscriptionId, // Map subscription_id to plan_id
        })
        .select()
        .single();

    return Transaction.fromJson(response);
  }

  // Kitab video parts operations
  static Future<List<KitabVideoPart>> getKitabVideoParts(String kitabId) async {
    final response = await from('kitab_videos')
        .select()
        .eq('kitab_id', kitabId)
        .eq('is_active', true)
        .order('sort_order')
        .order('part_number');

    return (response as List)
        .map((json) => KitabVideoPart.fromJson(json))
        .toList();
  }

  // Popup tracking operations
  static Future<Map<String, dynamic>?> getPopupTracking({
    required String userId,
    required String popupType,
  }) async {
    try {
      final response = await from('user_popup_tracking')
          .select()
          .eq('user_id', userId)
          .eq('popup_type', popupType)
          .maybeSingle();

      return response;
    } catch (e) {
      return null;
    }
  }

  static Future<void> upsertPopupTracking({
    required String userId,
    required String popupType,
  }) async {
    await from('user_popup_tracking').upsert(
      {
        'user_id': userId,
        'popup_type': popupType,
        'last_shown_at': DateTime.now().toIso8601String(),
        'show_count': 1, // This will be incremented by database trigger if record exists
      },
      onConflict: 'user_id,popup_type', // Specify the unique constraint columns
    );
  }

  static Future<void> dismissPopupPermanently({
    required String userId,
    required String popupType,
  }) async {
    await from('user_popup_tracking').upsert(
      {
        'user_id': userId,
        'popup_type': popupType,
        'dismissed_permanently': true,
        'last_shown_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'user_id,popup_type', // Specify the unique constraint columns
    );
  }

  static Future<void> resetPopupTracking({required String userId}) async {
    await from('user_popup_tracking').delete().eq('user_id', userId);
  }

  // Connectivity and health check methods
  static Future<bool> testConnection() async {
    try {
      if (kDebugMode) {
        // Debug logging removed
      }

      // Check if we have a valid session first
      final currentSession = client.auth.currentSession;
      if (currentSession == null) {
        if (kDebugMode) {
          // Debug logging removed
        }
        // Try unauthenticated connection instead
        await client
            .from('app_settings')
            .select('setting_key')
            .limit(1)
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                throw Exception('Connection timeout');
              },
            );
        return true;
      }

      // Simple query to test connection with current session
      await from('app_settings')
          .select('setting_key')
          .limit(1)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Connection timeout');
            },
          );

      if (kDebugMode) {
        // Debug logging removed
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        // Debug logging removed

        // If JWT expired, try to refresh the session
        if (e.toString().contains('JWT expired') || e.toString().contains('PGRST303')) {
          // Debug logging removed
          try {
            await client.auth.refreshSession();
            if (kDebugMode) {
              // Debug logging removed
            }
            return true;
          } catch (refreshError) {
            if (kDebugMode) {
              // Debug logging removed
            }
          }
        }
      }
      return false;
    }
  }

  static Future<bool> isHealthy() async {
    try {
      // Check if we have a valid client
      if (_client == null) {
        if (kDebugMode) {
          // Debug logging removed
        }
        return false;
      }

      // Check authentication state
      final user = currentUser;
      if (user == null) {
        if (kDebugMode) {
          // Debug logging removed
        }
        // This is not necessarily an error - some operations don't require auth
      }

      // Test basic connectivity
      return await testConnection();
    } catch (e) {
      if (kDebugMode) {
        // Debug logging removed
      }
      return false;
    }
  }

  static Future<T> retryOperation<T>(
    Future<T> Function() operation, {
    int maxRetries = 3,
    Duration delay = const Duration(seconds: 1),
    String? operationName,
  }) async {
    int attempts = 0;
    dynamic lastError;

    while (attempts < maxRetries) {
      try {
        if (kDebugMode && operationName != null) {
          // Debug logging removed
        }

        final result = await operation();

        if (kDebugMode && operationName != null) {
          // Debug logging removed
        }

        return result;
      } catch (e) {
        attempts++;
        lastError = e;

        if (kDebugMode && operationName != null) {
          // Debug logging removed
        }

        // If this is the last attempt, throw the error
        if (attempts >= maxRetries) {
          if (kDebugMode && operationName != null) {
            // Debug logging removed
          }
          rethrow;
        }

        // Wait before retrying (with exponential backoff)
        await Future.delayed(delay * attempts);
      }
    }

    throw lastError;
  }
}
