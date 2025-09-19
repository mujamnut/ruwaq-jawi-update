import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

/// Utility class for common authentication patterns
class AuthUtils {
  /// Check if user is authenticated and return user, throw exception if not
  static User requireUser() {
    final user = SupabaseService.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    return user;
  }

  /// Get current user or return null if not authenticated
  static User? getCurrentUser() {
    return SupabaseService.currentUser;
  }

  /// Check if user is authenticated and return user or null
  static User? getUserOrNull() {
    return SupabaseService.currentUser;
  }

  /// Execute function with user if authenticated, otherwise return null
  static T? withUser<T>(T Function(User user) callback) {
    final user = getCurrentUser();
    return user != null ? callback(user) : null;
  }

  /// Execute async function with user if authenticated, otherwise return null
  static Future<T?> withUserAsync<T>(Future<T> Function(User user) callback) async {
    final user = getCurrentUser();
    return user != null ? await callback(user) : null;
  }

  /// Execute function with user if authenticated, otherwise throw exception
  static T withRequiredUser<T>(T Function(User user) callback) {
    final user = requireUser();
    return callback(user);
  }

  /// Execute async function with user if authenticated, otherwise throw exception
  static Future<T> withRequiredUserAsync<T>(Future<T> Function(User user) callback) async {
    final user = requireUser();
    return await callback(user);
  }
}