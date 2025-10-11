class Ebook {
  final String id;
  final String title;
  final String? author;
  final String? description;
  final String? categoryId;
  final String? categoryName;
  final String pdfUrl;
  final String? pdfStoragePath;
  final int? pdfFileSize;
  final String? thumbnailUrl;
  final int? totalPages;
  final bool isPremium;
  final int sortOrder;
  final bool isActive;
  final int viewsCount;
  final int downloadsCount;
  final double averageRating;
  final int totalRatings;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Ebook({
    required this.id,
    required this.title,
    this.author,
    this.description,
    this.categoryId,
    this.categoryName,
    required this.pdfUrl,
    this.pdfStoragePath,
    this.pdfFileSize,
    this.thumbnailUrl,
    this.totalPages,
    this.isPremium = true,
    this.sortOrder = 0,
    this.isActive = true,
    this.viewsCount = 0,
    this.downloadsCount = 0,
    this.averageRating = 0.0,
    this.totalRatings = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Ebook.fromJson(Map<String, dynamic> json) {
    return Ebook(
      id: json['id'] as String,
      title: json['title'] as String,
      author: json['author'] as String?,
      description: json['description'] as String?,
      categoryId: json['category_id'] as String?,
      categoryName: json['categories']?['name'] as String? ?? 
                   json['category_name'] as String?,
      pdfUrl: json['pdf_url'] as String,
      pdfStoragePath: json['pdf_storage_path'] as String?,
      pdfFileSize: json['pdf_file_size'] as int?,
      thumbnailUrl: json['thumbnail_url'] as String?,
      totalPages: json['total_pages'] as int?,
      isPremium: json['is_premium'] as bool? ?? true,
      sortOrder: json['sort_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      viewsCount: json['views_count'] as int? ?? 0,
      downloadsCount: json['downloads_count'] as int? ?? 0,
      averageRating: (json['average_rating'] as num?)?.toDouble() ?? 0.0,
      totalRatings: json['total_ratings'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'description': description,
      'category_id': categoryId,
      'pdf_url': pdfUrl,
      'pdf_storage_path': pdfStoragePath,
      'pdf_file_size': pdfFileSize,
      'thumbnail_url': thumbnailUrl,
      'total_pages': totalPages,
      'is_premium': isPremium,
      'sort_order': sortOrder,
      'is_active': isActive,
      'views_count': viewsCount,
      'downloads_count': downloadsCount,
      'average_rating': averageRating,
      'total_ratings': totalRatings,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Ebook copyWith({
    String? title,
    String? author,
    String? description,
    String? categoryId,
    String? pdfUrl,
    String? pdfStoragePath,
    int? pdfFileSize,
    String? thumbnailUrl,
    int? totalPages,
    bool? isPremium,
    int? sortOrder,
    bool? isActive,
    int? viewsCount,
    int? downloadsCount,
    double? averageRating,
    int? totalRatings,
  }) {
    return Ebook(
      id: id,
      title: title ?? this.title,
      author: author ?? this.author,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      pdfUrl: pdfUrl ?? this.pdfUrl,
      pdfStoragePath: pdfStoragePath ?? this.pdfStoragePath,
      pdfFileSize: pdfFileSize ?? this.pdfFileSize,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      totalPages: totalPages ?? this.totalPages,
      isPremium: isPremium ?? this.isPremium,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
      viewsCount: viewsCount ?? this.viewsCount,
      downloadsCount: downloadsCount ?? this.downloadsCount,
      averageRating: averageRating ?? this.averageRating,
      totalRatings: totalRatings ?? this.totalRatings,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  // Helper getters
  String get displayTitle => title.isNotEmpty ? title : 'Tanpa Tajuk';
  String get displayAuthor => author?.isNotEmpty == true ? 'Oleh: $author' : '';
  String get displayPages => totalPages != null ? '$totalPages muka surat' : '';
  String get premiumBadge => isPremium ? 'Premium' : 'Percuma';
  String get statusBadge => isActive ? 'Aktif' : 'Tidak Aktif';

  // Rating helpers
  String get displayRating => averageRating > 0 ? averageRating.toStringAsFixed(1) : 'Belum ada rating';
  String get displayRatingCount {
    if (totalRatings == 0) return 'Belum ada rating';
    if (totalRatings == 1) return '1 rating';
    return '$totalRatings rating';
  }
  bool get hasRating => totalRatings > 0;

  // File size formatting
  String get formattedFileSize {
    if (pdfFileSize == null) return '';

    final bytes = pdfFileSize!;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  String toString() {
    return 'Ebook{id: $id, title: $title, author: $author, isPremium: $isPremium, isActive: $isActive}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Ebook && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
