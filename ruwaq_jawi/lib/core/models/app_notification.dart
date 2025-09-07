import 'dart:convert';

class AppNotification {
  final String id;
  final String title;
  final String body;
  final String type; // 'app' | 'email' | 'push'
  final Map<String, dynamic>? data; // optional payload
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.data,
    required this.createdAt,
  });

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    return AppNotification(
      id: map['id'] as String,
      title: map['title'] as String,
      body: map['body'] as String,
      type: (map['type'] ?? 'app') as String,
      data: _parseJsonField(map['data']),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  static Map<String, dynamic>? _parseJsonField(dynamic value) {
    if (value == null) return null;
    if (value is Map<String, dynamic>) return value;
    if (value is String) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {}
    }
    return null;
  }
}
