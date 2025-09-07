class KitabVideoPart {
  final String id;
  final String kitabId;
  final String title;
  final String? description;
  final String youtubeVideoId;
  final String? youtubeVideoUrl;
  final String? thumbnailUrl;
  final int? durationMinutes;
  final int? durationSeconds;
  final int partNumber;
  final int sortOrder;
  final bool isActive;
  final bool isPreview;
  final DateTime createdAt;
  final DateTime updatedAt;

  const KitabVideoPart({
    required this.id,
    required this.kitabId,
    required this.title,
    this.description,
    required this.youtubeVideoId,
    this.youtubeVideoUrl,
    this.thumbnailUrl,
    this.durationMinutes,
    this.durationSeconds,
    required this.partNumber,
    required this.sortOrder,
    required this.isActive,
    required this.isPreview,
    required this.createdAt,
    required this.updatedAt,
  });

  factory KitabVideoPart.fromJson(Map<String, dynamic> json) {
    return KitabVideoPart(
      id: json['id'] as String,
      kitabId: json['kitab_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      youtubeVideoId: json['youtube_video_id'] as String,
      youtubeVideoUrl: json['youtube_video_url'] as String?,
      thumbnailUrl: json['thumbnail_url'] as String?,
      durationMinutes: json['duration_minutes'] as int?,
      durationSeconds: json['duration_seconds'] as int?,
      partNumber: json['part_number'] as int,
      sortOrder: json['sort_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      isPreview: json['is_preview'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
