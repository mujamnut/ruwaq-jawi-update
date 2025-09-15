class Subscription {
  final String id;
  final String userId;
  final String planType;
  final DateTime startDate;
  final DateTime endDate;
  final String status;
  final String? paymentMethod;
  final double amount;
  final String currency;
  final bool autoRenew;
  final DateTime createdAt;
  final DateTime updatedAt;

  Subscription({
    required this.id,
    required this.userId,
    required this.planType,
    required this.startDate,
    required this.endDate,
    required this.status,
    this.paymentMethod,
    required this.amount,
    required this.currency,
    required this.autoRenew,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      planType: json['plan_id'] as String,                    // ✅ CHANGE: plan_type → plan_id
      startDate: DateTime.parse(json['started_at'] as String), // ✅ CHANGE: start_date → started_at
      endDate: DateTime.parse(json['current_period_end'] as String), // ✅ CHANGE: end_date → current_period_end
      status: json['status'] as String,
      paymentMethod: json['provider'] as String?,             // ✅ CHANGE: payment_method → provider
      amount: double.parse(json['amount'].toString()),
      currency: json['currency'] as String,
      autoRenew: json['auto_renew'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'plan_id': planType,                    // ✅ CHANGE: plan_type → plan_id
      'started_at': startDate.toIso8601String(), // ✅ CHANGE: start_date → started_at
      'current_period_end': endDate.toIso8601String(), // ✅ CHANGE: end_date → current_period_end
      'status': status,
      'provider': paymentMethod,              // ✅ CHANGE: payment_method → provider
      'amount': amount,
      'currency': currency,
      'auto_renew': autoRenew,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Subscription copyWith({
    String? id,
    String? userId,
    String? planType,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    String? paymentMethod,
    double? amount,
    String? currency,
    bool? autoRenew,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Subscription(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      planType: planType ?? this.planType,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      autoRenew: autoRenew ?? this.autoRenew,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
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
    switch (planType) {
      case 'monthly_basic':
        return '1 Bulan Basic';
      case 'monthly_premium':
        return '6 Bulan Premium';
      case 'quarterly_pr':
        return '3 Bulan Premium';
      case 'yearly_premium':
        return '1 Tahun Premium';
      case '1month':
        return '1 Bulan';
      case '3month':
        return '3 Bulan';
      case '6month':
        return '6 Bulan';
      case '12month':
        return '12 Bulan';
      default:
        return planType;
    }
  }

  String get formattedAmount {
    return 'RM ${amount.toStringAsFixed(2)}';
  }
}
