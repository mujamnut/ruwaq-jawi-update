class UserProfile {
  final String id;
  final String? fullName;
  final String? email;
  final String role;
  final String subscriptionStatus;
  final String? phoneNumber;
  final String? avatarUrl;
  final DateTime? lastSeenAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserProfile({
    required this.id,
    this.fullName,
    this.email,
    required this.role,
    required this.subscriptionStatus,
    this.phoneNumber,
    this.avatarUrl,
    this.lastSeenAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic value) {
      if (value is DateTime) return value;
      if (value is String) return DateTime.parse(value);
      throw FormatException('Invalid date value: $value');
    }

    DateTime? parseNullableDate(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      if (value is String && value.isNotEmpty) {
        return DateTime.parse(value);
      }
      return null;
    }

    final role = (json['role'] as String?)?.isNotEmpty == true
        ? json['role'] as String
        : 'student';
    final subscriptionStatus =
        (json['subscription_status'] as String?)?.isNotEmpty == true
            ? json['subscription_status'] as String
            : 'inactive';

    return UserProfile(
      id: json['id'] as String,
      fullName: json['full_name'] as String?,
      email: json['email'] as String?,
      role: role,
      subscriptionStatus: subscriptionStatus,
      phoneNumber: json['phone_number'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      lastSeenAt: parseNullableDate(json['last_seen_at']),
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'email': email,
      'role': role,
      'subscription_status': subscriptionStatus,
      'phone_number': phoneNumber,
      'avatar_url': avatarUrl,
      'last_seen_at': lastSeenAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  UserProfile copyWith({
    String? id,
    String? fullName,
    String? email,
    String? role,
    String? subscriptionStatus,
    String? phoneNumber,
    String? avatarUrl,
    DateTime? lastSeenAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      role: role ?? this.role,
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isAdmin => role == 'admin';
  bool get isStudent => role == 'student';
  bool get hasActiveSubscription => subscriptionStatus == 'active';

  // Helper methods for last seen
  bool get hasLastSeen => lastSeenAt != null;
  String get formattedLastSeen {
    if (lastSeenAt == null) return 'Tidak pernah online';

    final now = DateTime.now();
    final lastSeen = lastSeenAt!;
    final difference = now.difference(lastSeen);

    if (difference.inDays > 0) {
      return '${difference.inDays} hari lalu';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} jam lalu';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minit lalu';
    } else {
      return 'Baru sahaja';
    }
  }

  String get displayName {
    if (fullName != null && fullName!.isNotEmpty) {
      return fullName!;
    } else if (email != null && email!.isNotEmpty) {
      return email!;
    } else {
      return 'Unknown User';
    }
  }

  bool get isOnline {
    if (lastSeenAt == null) return false;
    final difference = DateTime.now().difference(lastSeenAt!);
    return difference.inMinutes < 5; // Consider online if last seen within 5 minutes
  }
}
