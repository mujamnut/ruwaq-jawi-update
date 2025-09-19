import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';
import '../config/env_config.dart';
import '../models/user_profile.dart';
import '../models/category.dart';
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
    // Load configuration from environment
    final String supabaseUrl = EnvConfig.supabaseUrl;
    final String supabaseAnonKey = EnvConfig.supabaseAnonKey;

    if (kDebugMode) {
      EnvConfig.printConfig();
    }

    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      debug: AppConfig.isDevelopment,
    );

    _client = Supabase.instance.client;
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
    );
  }

  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  static Future<void> signOut() async {
    await client.auth.signOut();
  }

  static Future<void> resetPassword(String email) async {
    await client.auth.resetPasswordForEmail(
      email,
      redirectTo: 'ruwaqjawi://auth/reset-password',
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
  static Future<List<Category>> getActiveCategories() async {
    final response = await from(
      'categories',
    ).select().eq('is_active', true).order('sort_order');

    return (response as List).map((json) => Category.fromJson(json)).toList();
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

  // Transaction operations
  static Future<List<Transaction>> getUserTransactions() async {
    final user = currentUser;
    if (user == null) throw Exception('User not authenticated');

    final response = await from(
      'transactions',
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

    final response = await from('transactions')
        .insert({
          'user_id': user.id,
          'subscription_id': subscriptionId,
          'amount': amount,
          'currency': currency,
          'payment_method': paymentMethod,
          'metadata': metadata,
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
}
