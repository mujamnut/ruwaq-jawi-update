/// Preview content models for unified preview system
class PreviewContent {
  final String id;
  final PreviewContentType contentType;
  final String contentId;
  final PreviewType previewType;
  final int? previewDurationSeconds;
  final int? previewPages;
  final String? previewDescription;
  final int sortOrder;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Populated when using joined queries
  final String? contentTitle;
  final String? contentThumbnailUrl;
  final String? categoryName;

  PreviewContent({
    required this.id,
    required this.contentType,
    required this.contentId,
    required this.previewType,
    this.previewDurationSeconds,
    this.previewPages,
    this.previewDescription,
    this.sortOrder = 0,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.contentTitle,
    this.contentThumbnailUrl,
    this.categoryName,
  });

  factory PreviewContent.fromJson(Map<String, dynamic> json) {
    return PreviewContent(
      id: json['id'],
      contentType: PreviewContentType.fromString(json['content_type']),
      contentId: json['content_id'],
      previewType: PreviewType.fromString(json['preview_type']),
      previewDurationSeconds: json['preview_duration_seconds'],
      previewPages: json['preview_pages'],
      previewDescription: json['preview_description'],
      sortOrder: json['sort_order'] ?? 0,
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      contentTitle: json['content_title'],
      contentThumbnailUrl: json['content_thumbnail_url'],
      categoryName: json['category_name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content_type': contentType.value,
      'content_id': contentId,
      'preview_type': previewType.value,
      'preview_duration_seconds': previewDurationSeconds,
      'preview_pages': previewPages,
      'preview_description': previewDescription,
      'sort_order': sortOrder,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Check if this preview is for video content
  bool get isVideoPreview => contentType == PreviewContentType.videoEpisode ||
                           contentType == PreviewContentType.videoKitab;

  /// Check if this preview is for text/PDF content
  bool get isTextPreview => contentType == PreviewContentType.ebook;

  /// Get formatted preview duration for display
  String? get formattedDuration {
    if (previewDurationSeconds == null) return null;

    final minutes = previewDurationSeconds! ~/ 60;
    final seconds = previewDurationSeconds! % 60;

    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  /// Get formatted preview pages for display
  String? get formattedPages {
    if (previewPages == null) return null;
    return '$previewPages pages';
  }

  /// Get preview display text based on type
  String get previewDisplayText {
    switch (previewType) {
      case PreviewType.freeTrial:
        if (isVideoPreview && previewDurationSeconds != null) {
          return 'Free preview: $formattedDuration';
        } else if (isTextPreview && previewPages != null) {
          return 'Free preview: $formattedPages';
        }
        return 'Free preview available';

      case PreviewType.teaser:
        return 'Teaser preview';

      case PreviewType.demo:
        return 'Demo available';

      case PreviewType.sample:
        return 'Sample content';
    }
  }
}

/// Content types supported in preview system
enum PreviewContentType {
  videoEpisode('video_episode'),
  ebook('ebook'),
  videoKitab('video_kitab');

  const PreviewContentType(this.value);
  final String value;

  static PreviewContentType fromString(String value) {
    return PreviewContentType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => throw ArgumentError('Invalid content type: $value'),
    );
  }

  String get displayName {
    switch (this) {
      case PreviewContentType.videoEpisode:
        return 'Video Episode';
      case PreviewContentType.ebook:
        return 'Ebook';
      case PreviewContentType.videoKitab:
        return 'Video Kitab';
    }
  }

  String get icon {
    switch (this) {
      case PreviewContentType.videoEpisode:
        return '🎬';
      case PreviewContentType.ebook:
        return '📖';
      case PreviewContentType.videoKitab:
        return '📹';
    }
  }
}

/// Preview types available
enum PreviewType {
  freeTrial('free_trial'),
  teaser('teaser'),
  demo('demo'),
  sample('sample');

  const PreviewType(this.value);
  final String value;

  static PreviewType fromString(String value) {
    return PreviewType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => throw ArgumentError('Invalid preview type: $value'),
    );
  }

  String get displayName {
    switch (this) {
      case PreviewType.freeTrial:
        return 'Free Trial';
      case PreviewType.teaser:
        return 'Teaser';
      case PreviewType.demo:
        return 'Demo';
      case PreviewType.sample:
        return 'Sample';
    }
  }

  String get description {
    switch (this) {
      case PreviewType.freeTrial:
        return 'Limited time or content free access';
      case PreviewType.teaser:
        return 'Short preview to generate interest';
      case PreviewType.demo:
        return 'Demonstration of features/content';
      case PreviewType.sample:
        return 'Sample portion of full content';
    }
  }
}

/// Preview configuration for creating new previews
class PreviewConfig {
  final PreviewContentType contentType;
  final String contentId;
  final PreviewType previewType;
  final int? previewDurationSeconds;
  final int? previewPages;
  final String? previewDescription;
  final bool isActive;

  PreviewConfig({
    required this.contentType,
    required this.contentId,
    this.previewType = PreviewType.freeTrial,
    this.previewDurationSeconds,
    this.previewPages,
    this.previewDescription,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'content_type': contentType.value,
      'content_id': contentId,
      'preview_type': previewType.value,
      'preview_duration_seconds': previewDurationSeconds,
      'preview_pages': previewPages,
      'preview_description': previewDescription,
      'is_active': isActive,
    };
  }
}

/// Preview query filters
class PreviewQueryFilter {
  final PreviewContentType? contentType;
  final PreviewType? previewType;
  final bool? isActive;
  final String? contentId;

  PreviewQueryFilter({
    this.contentType,
    this.previewType,
    this.isActive,
    this.contentId,
  });

  Map<String, dynamic> toQueryParams() {
    final params = <String, dynamic>{};

    if (contentType != null) {
      params['content_type'] = contentType!.value;
    }
    if (previewType != null) {
      params['preview_type'] = previewType!.value;
    }
    if (isActive != null) {
      params['is_active'] = isActive!;
    }
    if (contentId != null) {
      params['content_id'] = contentId!;
    }

    return params;
  }
}

/// Response for preview operations
class PreviewOperationResult {
  final bool success;
  final String? message;
  final PreviewContent? previewContent;
  final String? error;

  PreviewOperationResult({
    required this.success,
    this.message,
    this.previewContent,
    this.error,
  });

  factory PreviewOperationResult.success({
    String? message,
    PreviewContent? previewContent,
  }) {
    return PreviewOperationResult(
      success: true,
      message: message,
      previewContent: previewContent,
    );
  }

  factory PreviewOperationResult.failure({
    required String error,
  }) {
    return PreviewOperationResult(
      success: false,
      error: error,
    );
  }
}