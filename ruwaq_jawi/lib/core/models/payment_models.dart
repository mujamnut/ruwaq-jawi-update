
class PaymentRequest {
  final String amount;
  final String currency;
  final String email;
  final String name;
  final String phone;
  final String purpose;
  final String redirectUrl;
  final String webhookUrl;
  final String referenceNumber;
  final List<String> paymentMethods;
  final Map<String, dynamic>? metadata;

  PaymentRequest({
    required this.amount,
    required this.currency,
    required this.email,
    required this.name,
    required this.phone,
    required this.purpose,
    required this.redirectUrl,
    required this.webhookUrl,
    required this.referenceNumber,
    required this.paymentMethods,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'amount': amount,
      'currency': currency.toUpperCase(),
      'email': email,
      'name': name,
      'purpose': purpose,
      'redirect_url': redirectUrl,
      'webhook': webhookUrl,
      'reference_number': referenceNumber,
      'payment_methods': paymentMethods,
    };
    
    // Optional fields
    if (phone.isNotEmpty) {
      map['phone'] = phone;
    }
    
    return map;
  }
}

class PaymentResponse {
  final String id;
  final String url;
  final String status;
  final String referenceNumber;
  final String amount;
  final String currency;
  final DateTime createdAt;

  PaymentResponse({
    required this.id,
    required this.url,
    required this.status,
    required this.referenceNumber,
    required this.amount,
    required this.currency,
    required this.createdAt,
  });

  factory PaymentResponse.fromJson(Map<String, dynamic> json) {
    return PaymentResponse(
      id: json['id'] ?? '',
      url: json['url'] ?? '',
      status: json['status'] ?? '',
      referenceNumber: json['reference_number'] ?? '',
      amount: json['amount']?.toString() ?? '0',
      currency: json['currency'] ?? 'MYR',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }
}

class PaymentStatus {
  final String id;
  final String status;
  final String referenceNumber;
  final String amount;
  final String currency;
  final String paymentId;
  final DateTime? paidAt;
  final Map<String, dynamic>? metadata;

  PaymentStatus({
    required this.id,
    required this.status,
    required this.referenceNumber,
    required this.amount,
    required this.currency,
    required this.paymentId,
    this.paidAt,
    this.metadata,
  });

  factory PaymentStatus.fromJson(Map<String, dynamic> json) {
    return PaymentStatus(
      id: json['id'] ?? '',
      status: json['status'] ?? '',
      referenceNumber: json['reference_number'] ?? '',
      amount: json['amount']?.toString() ?? '0',
      currency: json['currency'] ?? 'MYR',
      paymentId: json['payment_id'] ?? '',
      paidAt: json['paid_at'] != null ? DateTime.tryParse(json['paid_at']) : null,
      metadata: json['metadata'],
    );
  }

  bool get isPaid => status.toLowerCase() == 'completed' || status.toLowerCase() == 'paid';
  bool get isPending => status.toLowerCase() == 'pending';
  bool get isFailed => status.toLowerCase() == 'failed' || status.toLowerCase() == 'cancelled';
}

class SubscriptionPlan {
  final String id;
  final String name;
  final String description;
  final double price;
  final String currency;
  final int durationDays;
  final List<String> features;
  final bool isActive;

  SubscriptionPlan({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.currency,
    required this.durationDays,
    required this.features,
    required this.isActive,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      currency: json['currency'] ?? 'MYR',
      durationDays: json['duration_days'] ?? 30,
      features: List<String>.from(json['features'] ?? []),
      isActive: json['is_active'] ?? true,
    );
  }

  String get formattedPrice => '$currency ${price.toStringAsFixed(2)}';
  String get durationText {
    if (durationDays == 30) return '1 Month';
    if (durationDays == 365) return '1 Year';
    return '$durationDays Days';
  }
}
