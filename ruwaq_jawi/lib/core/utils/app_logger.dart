import 'package:flutter/foundation.dart';

/// Secure logging utility that prevents sensitive data exposure in production
class AppLogger {
  static const String _tag = 'RuwaqJawi';

  /// Log info level messages (only in debug mode)
  static void info(String message, {String? tag}) {
    if (kDebugMode) {
      _log('INFO', message, tag: tag);
    }
  }

  /// Log warning level messages (only in debug mode)
  static void warning(String message, {String? tag}) {
    if (kDebugMode) {
      _log('WARNING', message, tag: tag);
    }
  }

  /// Log error level messages (only in debug mode, without sensitive data)
  static void error(String message, {Object? error, StackTrace? stackTrace, String? tag}) {
    if (kDebugMode) {
      _log('ERROR', message, tag: tag);
      if (error != null) {
        _log('ERROR', 'Error: ${_sanitizeError(error)}', tag: tag);
      }
      if (stackTrace != null) {
        _log('ERROR', 'StackTrace: $stackTrace', tag: tag);
      }
    }
  }

  /// Log debug level messages (only in debug mode)
  static void debug(String message, {String? tag}) {
    if (kDebugMode) {
      _log('DEBUG', message, tag: tag);
    }
  }

  /// Log security events (always logged, but sanitized in production)
  static void security(String message, {String? tag}) {
    final sanitizedMessage = _sanitizeForProduction(message);
    if (kDebugMode) {
      _log('SECURITY', message, tag: tag);
    } else {
      // In production, only log sanitized security messages
      _log('SECURITY', sanitizedMessage, tag: tag);
    }
  }

  /// Log performance metrics (only in debug mode)
  static void performance(String message, {String? tag}) {
    if (kDebugMode) {
      _log('PERFORMANCE', message, tag: tag);
    }
  }

  /// Internal logging method
  static void _log(String level, String message, {String? tag}) {
    final timestamp = DateTime.now().toIso8601String();
    final logTag = tag ?? _tag;
    final logMessage = '[$timestamp] [$level] [$logTag] $message';

    // Use print only in debug mode
    if (kDebugMode) {
      print(logMessage);
    }
  }

  /// Sanitize error messages to remove sensitive information
  static String _sanitizeError(Object error) {
    String errorString = error.toString();

    // Remove potential API keys, tokens, passwords
    final sanitized = errorString
        .replaceAllMapped(RegExp(r'(api[_-]?key|token|password|secret)[=:]\s*[^\s,}]+', caseSensitive: false), (match) => '${match.group(1)}: [REDACTED]')
        .replaceAllMapped(RegExp(r'(Bearer\s+)[A-Za-z0-9\-_\.]+', caseSensitive: false), (match) => '${match.group(1)}[REDACTED]')
        .replaceAll(RegExp(r'\b[A-Za-z0-9]{20,}\b'), '[REDACTED_LONG_STRING]');

    return sanitized;
  }

  /// Sanitize messages for production logging
  static String _sanitizeForProduction(String message) {
    // Remove any sensitive information patterns
    return message
        .replaceAllMapped(RegExp(r'(api[_-]?key|token|password|secret|auth|credential)[=:]\s*[^\s,}]+', caseSensitive: false), (match) => '${match.group(1)}: [REDACTED]')
        .replaceAllMapped(RegExp(r'(Bearer\s+)[A-Za-z0-9\-_\.]+', caseSensitive: false), (match) => '${match.group(1)}[REDACTED]')
        .replaceAll(RegExp(r'\b[A-Za-z0-9]{30,}\b'), '[REDACTED_LONG_STRING]')
        .replaceAllMapped(RegExp(r'email[:\s]+[^\s,}]+@[^\s,}]+', caseSensitive: false), (match) => 'email: [REDACTED]')
        .replaceAllMapped(RegExp(r'phone[:\s]+[\d\-\+\(\)\s]+', caseSensitive: false), (match) => 'phone: [REDACTED]');
  }

  /// Check if logging is enabled
  static bool get isLoggingEnabled => kDebugMode;

  /// Log network requests (sanitized)
  static void network(String method, String url, {int? statusCode, String? tag}) {
    if (kDebugMode) {
      final sanitizedUrl = _sanitizeUrl(url);
      _log('NETWORK', '$method $sanitizedUrl${statusCode != null ? ' -> $statusCode' : ''}', tag: tag);
    }
  }

  /// Sanitize URLs to remove sensitive query parameters
  static String _sanitizeUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return '[INVALID_URL]';

    final sanitizedQuery = <String, String>{};
    uri.queryParameters.forEach((key, value) {
      // Keep safe query parameters, redact sensitive ones
      if (_isSafeQueryParameter(key)) {
        sanitizedQuery[key] = value;
      } else {
        sanitizedQuery[key] = '[REDACTED]';
      }
    });

    final sanitizedUri = Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.port,
      path: uri.path,
      queryParameters: sanitizedQuery.isEmpty ? null : sanitizedQuery,
    );

    return sanitizedUri.toString();
  }

  /// Check if a query parameter is safe to log
  static bool _isSafeQueryParameter(String key) {
    final safeParameters = [
      'page', 'limit', 'offset', 'sort', 'order', 'filter', 'search',
      'category', 'type', 'status', 'format', 'version', 'lang'
    ];
    return safeParameters.contains(key.toLowerCase());
  }
}