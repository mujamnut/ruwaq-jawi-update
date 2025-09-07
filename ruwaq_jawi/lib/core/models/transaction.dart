class Transaction {
  final String id;
  final String userId;
  final String? subscriptionId;
  final double amount;
  final String currency;
  final String paymentMethod;
  final String? gatewayTransactionId;
  final String? gatewayReference;
  final String status;
  final String? failureReason;
  final Map<String, dynamic>? metadata;
  final DateTime? processedAt;
  final DateTime createdAt;

  Transaction({
    required this.id,
    required this.userId,
    this.subscriptionId,
    required this.amount,
    required this.currency,
    required this.paymentMethod,
    this.gatewayTransactionId,
    this.gatewayReference,
    required this.status,
    this.failureReason,
    this.metadata,
    this.processedAt,
    required this.createdAt,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      subscriptionId: json['subscription_id'] as String?,
      amount: (json['amount_cents'] as int) / 100.0,              // ✅ CHANGE: amount → amount_cents / 100
      currency: json['currency'] as String,
      paymentMethod: json['provider'] as String,                  // ✅ CHANGE: payment_method → provider
      gatewayTransactionId: json['provider_payment_id'] as String?, // ✅ CHANGE: gateway_transaction_id → provider_payment_id
      gatewayReference: json['reference_number'] as String?,        // ✅ CHANGE: gateway_reference → reference_number
      status: json['status'] as String,
      failureReason: json['description'] as String?,               // ✅ NEW: Use description for failure reason
      metadata: json['metadata'] as Map<String, dynamic>?,
      processedAt: json['paid_at'] != null ? DateTime.parse(json['paid_at'] as String) : null, // ✅ CHANGE: processed_at → paid_at
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'subscription_id': subscriptionId,
      'amount_cents': (amount * 100).round(),      // ✅ CHANGE: amount → amount_cents * 100
      'currency': currency,
      'provider': paymentMethod,                   // ✅ CHANGE: payment_method → provider
      'provider_payment_id': gatewayTransactionId, // ✅ CHANGE: gateway_transaction_id → provider_payment_id
      'reference_number': gatewayReference,        // ✅ CHANGE: gateway_reference → reference_number
      'status': status,
      'description': failureReason,                // ✅ NEW: Map failure_reason to description
      'metadata': metadata,
      'paid_at': processedAt?.toIso8601String(),   // ✅ CHANGE: processed_at → paid_at
      'created_at': createdAt.toIso8601String(),
    };
  }

  Transaction copyWith({
    String? id,
    String? userId,
    String? subscriptionId,
    double? amount,
    String? currency,
    String? paymentMethod,
    String? gatewayTransactionId,
    String? gatewayReference,
    String? status,
    String? failureReason,
    Map<String, dynamic>? metadata,
    DateTime? processedAt,
    DateTime? createdAt,
  }) {
    return Transaction(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      subscriptionId: subscriptionId ?? this.subscriptionId,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      gatewayTransactionId: gatewayTransactionId ?? this.gatewayTransactionId,
      gatewayReference: gatewayReference ?? this.gatewayReference,
      status: status ?? this.status,
      failureReason: failureReason ?? this.failureReason,
      metadata: metadata ?? this.metadata,
      processedAt: processedAt ?? this.processedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  bool get isPending => status == 'pending';
  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';
  bool get isRefunded => status == 'refunded';
  bool get isCancelled => status == 'cancelled';

  String get formattedAmount => 'RM ${amount.toStringAsFixed(2)}';
  
  String get statusDisplayName {
    switch (status) {
      case 'pending':
        return 'Menunggu';
      case 'completed':
        return 'Selesai';
      case 'failed':
        return 'Gagal';
      case 'refunded':
        return 'Dikembalikan';
      case 'cancelled':
        return 'Dibatalkan';
      default:
        return status;
    }
  }
}
