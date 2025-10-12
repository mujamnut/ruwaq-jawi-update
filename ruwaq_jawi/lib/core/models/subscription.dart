class Subscription {
  final String id;
  final String userId;
  final String userName;
  final String subscriptionPlanId;
  final String status;
  final DateTime startDate;
  final DateTime endDate;
  final String? paymentId;
  final double amount;
  final String currency;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? planName;
  final double? planPrice;
  final int? planDurationDays;

  Subscription({
    required this.id,
    required this.userId,
    required this.userName,
    required this.subscriptionPlanId,
    required this.status,
    required this.startDate,
    required this.endDate,
    this.paymentId,
    required this.amount,
    required this.currency,
    required this.createdAt,
    required this.updatedAt,
    this.planName,
    this.planPrice,
    this.planDurationDays,
  });

  factory Subscription.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic value) {
      if (value is DateTime) return value;
      if (value is String) return DateTime.parse(value);
      throw FormatException('Invalid date value: $value');
    }

    final subscriptionPlans = json['subscription_plans'] as Map<String, dynamic>?;

    return Subscription(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      userName: json['user_name'] as String? ?? 'Unknown',
      subscriptionPlanId: json['subscription_plan_id'] as String,
      status: json['status'] as String,
      startDate: parseDate(json['start_date']),
      endDate: parseDate(json['end_date']),
      paymentId: json['payment_id'] as String?,
      amount: double.tryParse(json['amount'].toString()) ?? 0.0,
      currency: json['currency'] as String? ?? 'MYR',
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
      planName: subscriptionPlans?['name'] as String?,
      planPrice: double.tryParse(subscriptionPlans?['price']?.toString() ?? '0'),
      planDurationDays: subscriptionPlans?['duration_days'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'user_name': userName,
      'subscription_plan_id': subscriptionPlanId,
      'status': status,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'payment_id': paymentId,
      'amount': amount,
      'currency': currency,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Subscription copyWith({
    String? id,
    String? userId,
    String? userName,
    String? subscriptionPlanId,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
    String? paymentId,
    double? amount,
    String? currency,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? planName,
    double? planPrice,
    int? planDurationDays,
  }) {
    return Subscription(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      subscriptionPlanId: subscriptionPlanId ?? this.subscriptionPlanId,
      status: status ?? this.status,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      paymentId: paymentId ?? this.paymentId,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      planName: planName ?? this.planName,
      planPrice: planPrice ?? this.planPrice,
      planDurationDays: planDurationDays ?? this.planDurationDays,
    );
  }

  bool get isActive => status == 'active' && endDate.isAfter(DateTime.now());
  bool get isExpired => endDate.isBefore(DateTime.now());
  bool get isPending => status == 'pending';
  bool get isCancelled => status == 'cancelled';

  int get daysRemaining {
    if (isExpired) return 0;
    return endDate.difference(DateTime.now()).inDays;
  }

  String get planDisplayName {
    return planName ?? subscriptionPlanId;
  }

  String get formattedAmount {
    return 'RM ${amount.toStringAsFixed(2)}';
  }
}
