class VideoEpisode {
  final String id;
  final String videoKitabId;
  final String title;
  final String? description;
  final String youtubeVideoId;
  final String? youtubeVideoUrl;
  final String? thumbnailUrl;
  final int partNumber;
  final int durationMinutes;
  final int? durationSeconds;
  final int sortOrder;
  final bool isActive;
  final bool isPremium;
  final DateTime createdAt;
  final DateTime updatedAt;

  const VideoEpisode({
    required this.id,
    required this.videoKitabId,
    required this.title,
    this.description,
    required this.youtubeVideoId,
    this.youtubeVideoUrl,
    this.thumbnailUrl,
    required this.partNumber,
    this.durationMinutes = 0,
    this.durationSeconds,
    this.sortOrder = 0,
    this.isActive = true,
    this.isPremium = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory VideoEpisode.fromJson(Map<String, dynamic> json) {
    // Handle both video_kitab_id (new) and kitab_id (old) field names
    final videoKitabId = json['video_kitab_id'] as String? ?? 
                        json['kitab_id'] as String? ?? 
                        '';
    
    if (videoKitabId.isEmpty) {
      throw Exception('Missing video kitab ID in episode data: ${json.keys.join(', ')}');
    }
    
    return VideoEpisode(
      id: json['id'] as String,
      videoKitabId: videoKitabId,
      title: json['title'] as String,
      description: json['description'] as String?,
      youtubeVideoId: json['youtube_video_id'] as String,
      youtubeVideoUrl: json['youtube_video_url'] as String?,
      thumbnailUrl: json['thumbnail_url'] as String?,
      partNumber: json['part_number'] as int? ?? 0,
      durationMinutes: json['duration_minutes'] as int? ?? 0,
      durationSeconds: json['duration_seconds'] as int?,
      sortOrder: json['sort_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      isPremium: json['is_premium'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'video_kitab_id': videoKitabId,
      'title': title,
      'description': description,
      'youtube_video_id': youtubeVideoId,
      'youtube_video_url': youtubeVideoUrl,
      'thumbnail_url': thumbnailUrl,
      'part_number': partNumber,
      'duration_minutes': durationMinutes,
      'duration_seconds': durationSeconds,
      'sort_order': sortOrder,
      'is_active': isActive,
      'is_premium': isPremium,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Format duration to readable string (e.g., "5 minit", "1 jam 30 minit")
  String get formattedDuration {
    if (durationMinutes <= 0) return '0 minit';
    
    final hours = durationMinutes ~/ 60;
    final minutes = durationMinutes % 60;
    
    if (hours > 0) {
      if (minutes > 0) {
        return '$hours jam $minutes minit';
      }
      return '$hours jam';
    }
    
    return '$minutes minit';
  }

  VideoEpisode copyWith({
    String? title,
    String? description,
    String? youtubeVideoId,
    String? youtubeVideoUrl,
    String? thumbnailUrl,
    int? partNumber,
    int? durationMinutes,
    int? durationSeconds,
    int? sortOrder,
    bool? isActive,
    bool? isPremium,
  }) {
    return VideoEpisode(
      id: id,
      videoKitabId: videoKitabId,
      title: title ?? this.title,
      description: description ?? this.description,
      youtubeVideoId: youtubeVideoId ?? this.youtubeVideoId,
      youtubeVideoUrl: youtubeVideoUrl ?? this.youtubeVideoUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      partNumber: partNumber ?? this.partNumber,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
      isPremium: isPremium ?? this.isPremium,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  // Helper getters
  String get displayTitle => title.isNotEmpty ? title : 'Episode $partNumber';
  String get displayDuration {
    if (durationMinutes <= 0) return '0 min';

    final hours = durationMinutes ~/ 60;
    final minutes = durationMinutes % 60;

    if (hours > 0) {
      return minutes > 0 ? '${hours}j ${minutes}m' : '${hours}j';
    }
    return '${minutes}m';
  }

  /// Get duration as Duration object
  Duration? get duration {
    if (durationMinutes <= 0 && (durationSeconds == null || durationSeconds! <= 0)) {
      return null;
    }
    final totalSeconds = (durationMinutes * 60) + (durationSeconds ?? 0);
    return Duration(seconds: totalSeconds);
  }

  String get statusBadge => isActive ? 'Aktif' : 'Tidak Aktif';
  String get typeBadge => 'Penuh';
  
  // YouTube helpers
  String get youtubeWatchUrl => 'https://www.youtube.com/watch?v=$youtubeVideoId';
  String get defaultThumbnailUrl => 'https://img.youtube.com/vi/$youtubeVideoId/hqdefault.jpg';
  String get actualThumbnailUrl => thumbnailUrl?.isNotEmpty == true ? thumbnailUrl! : defaultThumbnailUrl;

  @override
  String toString() {
    return 'VideoEpisode{id: $id, title: $title, partNumber: $partNumber, duration: $durationMinutes min, isActive: $isActive}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VideoEpisode && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
