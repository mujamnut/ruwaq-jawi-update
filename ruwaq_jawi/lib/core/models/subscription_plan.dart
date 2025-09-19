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
    this.isActive = true,
  });

  String get durationText {
    if (durationDays >= 365) {
      final years = (durationDays / 365).floor();
      return years == 1 ? 'year' : '$years years';
    } else if (durationDays >= 30) {
      final months = (durationDays / 30).floor();
      return months == 1 ? 'month' : '$months months';
    } else {
      return '$durationDays days';
    }
  }

  String get formattedPrice {
    return 'RM ${price.toStringAsFixed(2)}';
  }
}
