class KitabVideo {
  final String id;
  final String kitabId;
  final String title;
  final String? description;
  final String youtubeVideoId;
  final String? youtubeVideoUrl;
  final String? thumbnailUrl;
  final int durationMinutes;
  final int durationSeconds;
  final int partNumber;
  final int sortOrder;
  final bool isActive;
  final bool isPreview;
  final DateTime createdAt;
  final DateTime updatedAt;

  KitabVideo({
    required this.id,
    required this.kitabId,
    required this.title,
    this.description,
    required this.youtubeVideoId,
    this.youtubeVideoUrl,
    this.thumbnailUrl,
    this.durationMinutes = 0,
    this.durationSeconds = 0,
    required this.partNumber,
    this.sortOrder = 0,
    this.isActive = true,
    this.isPreview = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory KitabVideo.fromJson(Map<String, dynamic> json) {
    return KitabVideo(
      id: json['id'] as String,
      kitabId: json['kitab_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      youtubeVideoId: json['youtube_video_id'] as String,
      youtubeVideoUrl: json['youtube_video_url'] as String?,
      thumbnailUrl: json['thumbnail_url'] as String?,
      durationMinutes: json['duration_minutes'] as int? ?? 0,
      durationSeconds: json['duration_seconds'] as int? ?? 0,
      partNumber: json['part_number'] as int,
      sortOrder: json['sort_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      isPreview: json['is_preview'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'kitab_id': kitabId,
      'title': title,
      'description': description,
      'youtube_video_id': youtubeVideoId,
      'youtube_video_url': youtubeVideoUrl,
      'thumbnail_url': thumbnailUrl,
      'duration_minutes': durationMinutes,
      'duration_seconds': durationSeconds,
      'part_number': partNumber,
      'sort_order': sortOrder,
      'is_active': isActive,
      'is_preview': isPreview,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  KitabVideo copyWith({
    String? id,
    String? kitabId,
    String? title,
    String? description,
    String? youtubeVideoId,
    String? youtubeVideoUrl,
    String? thumbnailUrl,
    int? durationMinutes,
    int? durationSeconds,
    int? partNumber,
    int? sortOrder,
    bool? isActive,
    bool? isPreview,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return KitabVideo(
      id: id ?? this.id,
      kitabId: kitabId ?? this.kitabId,
      title: title ?? this.title,
      description: description ?? this.description,
      youtubeVideoId: youtubeVideoId ?? this.youtubeVideoId,
      youtubeVideoUrl: youtubeVideoUrl ?? this.youtubeVideoUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      partNumber: partNumber ?? this.partNumber,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
      isPreview: isPreview ?? this.isPreview,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get formattedDuration {
    if (durationMinutes == 0 && durationSeconds == 0) return '';
    final hours = durationMinutes ~/ 60;
    final minutes = durationMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return durationMinutes > 0 ? '${minutes}m' : '${durationSeconds}s';
  }

  // Convenience getter for YouTube embed URL
  String get youtubeEmbedUrl => 'https://www.youtube.com/embed/$youtubeVideoId';
  
  // Convenience getter for YouTube watch URL  
  String get youtubeWatchUrl => 'https://www.youtube.com/watch?v=$youtubeVideoId';
}
