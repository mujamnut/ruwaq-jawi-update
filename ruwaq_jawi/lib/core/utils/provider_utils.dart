import 'package:flutter/foundation.dart';

/// Mixin for common provider state management patterns
mixin ProviderStateMixin on ChangeNotifier {
  bool _isLoading = false;
  String? _errorMessage;

  /// Current loading state
  bool get isLoading => _isLoading;

  /// Current error message
  String? get errorMessage => _errorMessage;

  /// Whether there is an error
  bool get hasError => _errorMessage != null;

  /// Set loading state and notify listeners
  void setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  /// Set error message and notify listeners
  void setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  /// Clear error message
  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  /// Execute async function with loading state management
  Future<T?> withLoading<T>(Future<T> Function() callback) async {
    try {
      setLoading(true);
      clearError();
      final result = await callback();
      return result;
    } catch (e) {
      setError(e.toString());
      if (kDebugMode) {
        print('Error in $runtimeType: $e');
      }
      return null;
    } finally {
      setLoading(false);
    }
  }

  /// Execute async function with loading state management and rethrow errors
  Future<T> withLoadingAndRethrow<T>(Future<T> Function() callback) async {
    try {
      setLoading(true);
      clearError();
      final result = await callback();
      return result;
    } catch (e) {
      setError(e.toString());
      if (kDebugMode) {
        print('Error in $runtimeType: $e');
      }
      rethrow;
    } finally {
      setLoading(false);
    }
  }

  /// Safe async execution that catches errors and logs them
  Future<void> safeExecute(Future<void> Function() callback) async {
    try {
      await callback();
    } catch (e) {
      setError(e.toString());
      if (kDebugMode) {
        print('Error in $runtimeType: $e');
      }
    }
  }

  /// Reset provider state
  void resetState() {
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }
}

/// Utility class for common error handling patterns
class ErrorUtils {
  /// Get user-friendly error message in Malay
  static String getUserFriendlyError(dynamic error) {
    final errorString = error.toString().toLowerCase();

    // Connection related errors
    if (errorString.contains('socketexception') ||
        errorString.contains('failed host lookup') ||
        errorString.contains('no address associated with hostname') ||
        errorString.contains('network is unreachable') ||
        errorString.contains('connection refused') ||
        errorString.contains('connection timed out')) {
      return 'Tiada sambungan internet. Sila semak sambungan anda dan cuba lagi.';
    }

    // Authentication specific errors
    if (errorString.contains('invalid_grant') ||
        errorString.contains('invalid credentials') ||
        errorString.contains('email not confirmed') ||
        errorString.contains('invalid login credentials')) {
      return 'Email atau kata laluan tidak sah. Sila semak dan cuba lagi.';
    }

    // Rate limiting
    if (errorString.contains('too many requests') ||
        errorString.contains('rate limit')) {
      return 'Terlalu banyak percubaan. Sila tunggu sebentar sebelum cuba lagi.';
    }

    // Server errors
    if (errorString.contains('500') ||
        errorString.contains('internal server error')) {
      return 'Pelayan mengalami masalah. Sila cuba lagi dalam beberapa minit.';
    }

    // Timeout errors
    if (errorString.contains('timeout')) {
      return 'Permintaan mengambil masa terlalu lama. Sila cuba lagi.';
    }

    // Generic network error
    if (errorString.contains('clientexception') ||
        errorString.contains('httperror')) {
      return 'Masalah sambungan rangkaian. Sila semak sambungan internet anda.';
    }

    // User not authenticated
    if (errorString.contains('user not authenticated')) {
      return 'Sila log masuk untuk menggunakan ciri ini.';
    }

    // No data found
    if (errorString.contains('no rows returned') ||
        errorString.contains('pgrst116')) {
      return 'Tiada data ditemui.';
    }

    // Default fallback
    return 'Ralat tidak dijangka. Sila cuba lagi.';
  }
}

/// Base class for providers with common functionality
abstract class BaseProvider extends ChangeNotifier with ProviderStateMixin {
  /// Clear all provider data
  void clear() {
    resetState();
  }

  /// Refresh provider data
  Future<void> refresh();
}
