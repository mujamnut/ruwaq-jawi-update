class AppSettings {
  final String id;
  final String settingKey;
  final Map<String, dynamic>? settingValue;
  final String? description;
  final bool isPublic;
  final DateTime createdAt;
  final DateTime updatedAt;

  AppSettings({
    required this.id,
    required this.settingKey,
    this.settingValue,
    this.description,
    required this.isPublic,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      id: json['id'] as String,
      settingKey: json['setting_key'] as String,
      settingValue: json['setting_value'] as Map<String, dynamic>?,
      description: json['description'] as String?,
      isPublic: json['is_public'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'setting_key': settingKey,
      'setting_value': settingValue,
      'description': description,
      'is_public': isPublic,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  AppSettings copyWith({
    String? id,
    String? settingKey,
    Map<String, dynamic>? settingValue,
    String? description,
    bool? isPublic,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppSettings(
      id: id ?? this.id,
      settingKey: settingKey ?? this.settingKey,
      settingValue: settingValue ?? this.settingValue,
      description: description ?? this.description,
      isPublic: isPublic ?? this.isPublic,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get canStudentRead => isPublic;
  
  T? getValue<T>() {
    return settingValue?['value'] as T?;
  }
}