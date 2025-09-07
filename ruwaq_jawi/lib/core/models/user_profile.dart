class UserProfile {
  final String id;
  final String? fullName;
  final String? email;
  final String role;
  final String subscriptionStatus;
  final String? phoneNumber;
  final String? avatarUrl;
  final DateTime? subscriptionEndDate;  // ✅ NEW: Add subscription end date
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
    this.subscriptionEndDate,           // ✅ NEW: Add subscription end date parameter
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      fullName: json['full_name'] as String?,
      email: json['email'] as String?,
      role: json['role'] as String,
      subscriptionStatus: json['subscription_status'] as String,
      phoneNumber: json['phone_number'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      subscriptionEndDate: json['subscription_end_date'] != null      // ✅ NEW: Parse subscription end date
          ? DateTime.parse(json['subscription_end_date'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
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
      'subscription_end_date': subscriptionEndDate?.toIso8601String(), // ✅ NEW: Include subscription end date
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
    DateTime? subscriptionEndDate,      // ✅ NEW: Add subscription end date parameter
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
      subscriptionEndDate: subscriptionEndDate ?? this.subscriptionEndDate, // ✅ NEW: Include subscription end date
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isAdmin => role == 'admin';
  bool get isStudent => role == 'student';
  bool get hasActiveSubscription => subscriptionStatus == 'active';
  
  // ✅ NEW: Helper methods for subscription end date
  bool get hasSubscriptionEndDate => subscriptionEndDate != null;
  bool get isSubscriptionExpired => subscriptionEndDate != null && subscriptionEndDate!.isBefore(DateTime.now());
  int get daysUntilExpiration {
    if (subscriptionEndDate == null) return 0;
    final difference = subscriptionEndDate!.difference(DateTime.now());
    return difference.inDays.clamp(0, double.infinity).toInt();
  }
  
  String get formattedSubscriptionEndDate {
    if (subscriptionEndDate == null) return 'Tiada';
    final now = DateTime.now();
    final endDate = subscriptionEndDate!;
    
    if (endDate.isBefore(now)) {
      return 'Tamat tempoh';
    }
    
    final difference = endDate.difference(now);
    if (difference.inDays > 0) {
      return '${difference.inDays} hari lagi';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} jam lagi';
    } else {
      return 'Akan tamat hari ini';
    }
  }
}
