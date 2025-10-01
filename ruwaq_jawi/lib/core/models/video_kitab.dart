class VideoKitab {
  final String id;
  final String title;
  final String? author;
  final String? description;
  final String? categoryId;
  final String? categoryName;
  final String? pdfUrl;
  final String? pdfStoragePath;
  final int? pdfFileSize;
  final String? thumbnailUrl;
  final int? totalPages;
  final int totalVideos;
  final int totalDurationMinutes;
  final int sortOrder;
  final bool isPremium;
  final bool isActive;
  final int viewsCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? youtubePlaylistId;
  final String? youtubePlaylistUrl;
  final bool autoSyncEnabled;
  final DateTime? lastSyncedAt;

  const VideoKitab({
    required this.id,
    required this.title,
    this.author,
    this.description,
    this.categoryId,
    this.categoryName,
    this.pdfUrl,
    this.pdfStoragePath,
    this.pdfFileSize,
    this.thumbnailUrl,
    this.totalPages,
    this.totalVideos = 0,
    this.totalDurationMinutes = 0,
    this.sortOrder = 0,
    this.isPremium = true,
    this.isActive = true,
    this.viewsCount = 0,
    required this.createdAt,
    required this.updatedAt,
    this.youtubePlaylistId,
    this.youtubePlaylistUrl,
    this.autoSyncEnabled = true,
    this.lastSyncedAt,
  });

  factory VideoKitab.fromJson(Map<String, dynamic> json) {
    return VideoKitab(
      id: json['id'] as String,
      title: json['title'] as String,
      author: json['author'] as String?,
      description: json['description'] as String?,
      categoryId: json['category_id'] as String?,
      categoryName: json['categories']?['name'] as String? ?? 
                   json['category_name'] as String?,
      pdfUrl: json['pdf_url'] as String?,
      pdfStoragePath: json['pdf_storage_path'] as String?,
      pdfFileSize: json['pdf_file_size'] as int?,
      thumbnailUrl: json['thumbnail_url'] as String?,
      totalPages: json['total_pages'] as int?,
      totalVideos: json['total_videos'] as int? ?? 0,
      totalDurationMinutes: json['total_duration_minutes'] as int? ?? 0,
      sortOrder: json['sort_order'] as int? ?? 0,
      isPremium: json['is_premium'] as bool? ?? true,
      isActive: json['is_active'] as bool? ?? true,
      viewsCount: json['views_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      youtubePlaylistId: json['youtube_playlist_id'] as String?,
      youtubePlaylistUrl: json['youtube_playlist_url'] as String?,
      autoSyncEnabled: json['auto_sync_enabled'] as bool? ?? true,
      lastSyncedAt: json['last_synced_at'] != null ? DateTime.parse(json['last_synced_at'] as String) : null,
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
      'total_videos': totalVideos,
      'total_duration_minutes': totalDurationMinutes,
      'sort_order': sortOrder,
      'is_premium': isPremium,
      'is_active': isActive,
      'views_count': viewsCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'youtube_playlist_id': youtubePlaylistId,
      'youtube_playlist_url': youtubePlaylistUrl,
      'auto_sync_enabled': autoSyncEnabled,
      'last_synced_at': lastSyncedAt?.toIso8601String(),
    };
  }


  VideoKitab copyWith({
    String? title,
    String? author,
    String? description,
    String? categoryId,
    String? pdfUrl,
    String? pdfStoragePath,
    int? pdfFileSize,
    String? thumbnailUrl,
    int? totalPages,
    int? totalVideos,
    int? totalDurationMinutes,
    int? sortOrder,
    bool? isPremium,
    bool? isActive,
    int? viewsCount,
    String? youtubePlaylistId,
    String? youtubePlaylistUrl,
    bool? autoSyncEnabled,
    DateTime? lastSyncedAt,
  }) {
    return VideoKitab(
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
      totalVideos: totalVideos ?? this.totalVideos,
      totalDurationMinutes: totalDurationMinutes ?? this.totalDurationMinutes,
      sortOrder: sortOrder ?? this.sortOrder,
      isPremium: isPremium ?? this.isPremium,
      isActive: isActive ?? this.isActive,
      viewsCount: viewsCount ?? this.viewsCount,
      youtubePlaylistId: youtubePlaylistId ?? this.youtubePlaylistId,
      youtubePlaylistUrl: youtubePlaylistUrl ?? this.youtubePlaylistUrl,
      autoSyncEnabled: autoSyncEnabled ?? this.autoSyncEnabled,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
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
  
  // Video-specific helpers
  bool get hasVideos => totalVideos > 0;
  bool get hasPdf => pdfUrl?.isNotEmpty == true;
  bool get hasContent => hasVideos || hasPdf;

  // YouTube sync helpers
  bool get hasYouTubePlaylist => youtubePlaylistId?.isNotEmpty == true;
  bool get isAutoSyncEnabled => autoSyncEnabled && hasYouTubePlaylist;
  String get youtubePlaylistWatchUrl => hasYouTubePlaylist
      ? 'https://www.youtube.com/playlist?list=$youtubePlaylistId'
      : '';

  String get lastSyncDisplay {
    if (lastSyncedAt == null) return 'Belum pernah sync';
    final now = DateTime.now();
    final difference = now.difference(lastSyncedAt!);

    if (difference.inMinutes < 1) return 'Baru sahaja';
    if (difference.inHours < 1) return '${difference.inMinutes} minit yang lalu';
    if (difference.inDays < 1) return '${difference.inHours} jam yang lalu';
    return '${difference.inDays} hari yang lalu';
  }
  
  String get formattedDuration {
    if (totalDurationMinutes <= 0) return '0 min';
    
    final hours = totalDurationMinutes ~/ 60;
    final minutes = totalDurationMinutes % 60;
    
    if (hours > 0) {
      return minutes > 0 ? '${hours}j ${minutes}m' : '${hours}j';
    }
    return '${minutes}m';
  }
  
  String get videoInfo {
    if (totalVideos <= 0) return 'Tiada video';
    return '$totalVideos video • $formattedDuration';
  }
  
  String get pdfInfo {
    if (!hasPdf) return 'Tiada PDF';
    return totalPages != null ? '$totalPages muka surat' : 'PDF tersedia';
  }
  
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
    return 'VideoKitab{id: $id, title: $title, totalVideos: $totalVideos, isPremium: $isPremium, isActive: $isActive}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VideoKitab && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
