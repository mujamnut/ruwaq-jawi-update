class Kitab {
  final String id;
  final String title;
  final String? author;
  final String? description;
  final String? categoryId;
  final String? pdfUrl;
  final String? youtubeVideoId; // DEPRECATED: Use kitab_videos table instead  
  final String? youtubeVideoUrl; // DEPRECATED: Use kitab_videos table instead
  final String? thumbnailUrl;
  final bool isPremium;
  final int? durationMinutes; // DEPRECATED: Use total_duration_minutes instead
  final int? totalPages;
  // NEW: Multiple episodes support
  final bool hasMultipleVideos;
  final int totalVideos; 
  final int totalDurationMinutes;
  final int sortOrder;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // New e-book fields from migration 010
  final String? pdfStoragePath;
  final int? pdfFileSize;
  final DateTime? pdfUploadDate;
  final bool isEbookAvailable;

  Kitab({
    required this.id,
    required this.title,
    this.author,
    this.description,
    this.categoryId,
    this.pdfUrl,
    this.youtubeVideoId,
    this.youtubeVideoUrl,
    this.thumbnailUrl,
    required this.isPremium,
    this.durationMinutes,
    this.totalPages,
    // NEW: Multiple episodes support
    this.hasMultipleVideos = false,
    this.totalVideos = 0,
    this.totalDurationMinutes = 0,
    required this.sortOrder,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    // New e-book fields
    this.pdfStoragePath,
    this.pdfFileSize,
    this.pdfUploadDate,
    this.isEbookAvailable = false,
  });

  factory Kitab.fromJson(Map<String, dynamic> json) {
    return Kitab(
      id: json['id'] as String,
      title: json['title'] as String,
      author: json['author'] as String?,
      description: json['description'] as String?,
      categoryId: json['category_id'] as String?,
      pdfUrl: json['pdf_url'] as String?,
      youtubeVideoId: json['youtube_video_id'] as String?,
      youtubeVideoUrl: json['youtube_video_url'] as String?,
      thumbnailUrl: json['thumbnail_url'] as String?,
      isPremium: json['is_premium'] as bool? ?? true,
      durationMinutes: json['duration_minutes'] as int?,
      totalPages: json['total_pages'] as int?,
      // NEW: Multiple episodes support
      hasMultipleVideos: json['has_multiple_videos'] as bool? ?? false,
      totalVideos: json['total_videos'] as int? ?? 0,
      totalDurationMinutes: json['total_duration_minutes'] as int? ?? 0,
      sortOrder: json['sort_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      // New e-book fields
      pdfStoragePath: json['pdf_storage_path'] as String?,
      pdfFileSize: json['pdf_file_size'] as int?,
      pdfUploadDate: json['pdf_upload_date'] != null 
          ? DateTime.parse(json['pdf_upload_date'] as String) 
          : null,
      isEbookAvailable: json['is_ebook_available'] as bool? ?? false,
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
      'youtube_video_id': youtubeVideoId,
      'youtube_video_url': youtubeVideoUrl,
      'thumbnail_url': thumbnailUrl,
      'is_premium': isPremium,
      'duration_minutes': durationMinutes,
      'total_pages': totalPages,
      // NEW: Multiple episodes support
      'has_multiple_videos': hasMultipleVideos,
      'total_videos': totalVideos,
      'total_duration_minutes': totalDurationMinutes,
      'sort_order': sortOrder,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      // New e-book fields
      'pdf_storage_path': pdfStoragePath,
      'pdf_file_size': pdfFileSize,
      'pdf_upload_date': pdfUploadDate?.toIso8601String(),
      'is_ebook_available': isEbookAvailable,
    };
  }

  Kitab copyWith({
    String? id,
    String? title,
    String? author,
    String? description,
    String? categoryId,
    String? pdfUrl,
    String? youtubeVideoId,
    String? youtubeVideoUrl,
    String? thumbnailUrl,
    bool? isPremium,
    int? durationMinutes,
    int? totalPages,
    // NEW: Multiple episodes support
    bool? hasMultipleVideos,
    int? totalVideos,
    int? totalDurationMinutes,
    int? sortOrder,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    // New e-book fields
    String? pdfStoragePath,
    int? pdfFileSize,
    DateTime? pdfUploadDate,
    bool? isEbookAvailable,
  }) {
    return Kitab(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      pdfUrl: pdfUrl ?? this.pdfUrl,
      youtubeVideoId: youtubeVideoId ?? this.youtubeVideoId,
      youtubeVideoUrl: youtubeVideoUrl ?? this.youtubeVideoUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      isPremium: isPremium ?? this.isPremium,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      totalPages: totalPages ?? this.totalPages,
      // NEW: Multiple episodes support
      hasMultipleVideos: hasMultipleVideos ?? this.hasMultipleVideos,
      totalVideos: totalVideos ?? this.totalVideos,
      totalDurationMinutes: totalDurationMinutes ?? this.totalDurationMinutes,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      // New e-book fields
      pdfStoragePath: pdfStoragePath ?? this.pdfStoragePath,
      pdfFileSize: pdfFileSize ?? this.pdfFileSize,
      pdfUploadDate: pdfUploadDate ?? this.pdfUploadDate,
      isEbookAvailable: isEbookAvailable ?? this.isEbookAvailable,
    );
  }

  bool get hasVideo => hasMultipleVideos || (youtubeVideoId != null && youtubeVideoId!.isNotEmpty);
  bool get hasPdf => isEbookAvailable || (pdfUrl != null && pdfUrl!.isNotEmpty);
  bool get isComplete => hasVideo && hasPdf;
  
  String get formattedDuration {
    // Use totalDurationMinutes for multi-episode kitab, fallback to durationMinutes for single episode
    final duration = hasMultipleVideos ? totalDurationMinutes : (durationMinutes ?? 0);
    if (duration == 0) return '';
    final hours = duration ~/ 60;
    final minutes = duration % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
}
