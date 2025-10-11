class EbookRating {
  final String id;
  final String ebookId;
  final String userId;
  final int rating; // 1-5 stars
  final String? reviewText;
  final DateTime createdAt;
  final DateTime updatedAt;

  const EbookRating({
    required this.id,
    required this.ebookId,
    required this.userId,
    required this.rating,
    this.reviewText,
    required this.createdAt,
    required this.updatedAt,
  });

  factory EbookRating.fromJson(Map<String, dynamic> json) {
    return EbookRating(
      id: json['id'] as String,
      ebookId: json['ebook_id'] as String,
      userId: json['user_id'] as String,
      rating: json['rating'] as int,
      reviewText: json['review_text'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ebook_id': ebookId,
      'user_id': userId,
      'rating': rating,
      'review_text': reviewText,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  EbookRating copyWith({
    String? id,
    String? ebookId,
    String? userId,
    int? rating,
    String? reviewText,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EbookRating(
      id: id ?? this.id,
      ebookId: ebookId ?? this.ebookId,
      userId: userId ?? this.userId,
      rating: rating ?? this.rating,
      reviewText: reviewText ?? this.reviewText,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'EbookRating{id: $id, ebookId: $ebookId, userId: $userId, rating: $rating}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EbookRating && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
