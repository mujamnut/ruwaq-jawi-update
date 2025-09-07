class SavedItem {
  final String id;
  final String userId;
  final String? kitabId;
  final String folderName;
  final String itemType; // 'kitab' or 'video'
  final String? videoId; // null for kitabs, videoId for videos
  final String? videoTitle;
  final String? videoUrl;
  final DateTime createdAt;

  SavedItem({
    required this.id,
    required this.userId,
    this.kitabId,
    required this.folderName,
    required this.itemType,
    this.videoId,
    this.videoTitle,
    this.videoUrl,
    required this.createdAt,
  });

  factory SavedItem.fromJson(Map<String, dynamic> json) {
    return SavedItem(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      kitabId: json['kitab_id'] as String?,
      folderName: json['folder_name'] as String,
      itemType: json['item_type'] as String,
      videoId: json['video_id'] as String?,
      videoTitle: json['video_title'] as String?,
      videoUrl: json['video_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'kitab_id': kitabId,
      'folder_name': folderName,
      'item_type': itemType,
      'video_id': videoId,
      'video_title': videoTitle,
      'video_url': videoUrl,
      'created_at': createdAt.toIso8601String(),
    };
  }

  SavedItem copyWith({
    String? id,
    String? userId,
    String? kitabId,
    String? folderName,
    String? itemType,
    String? videoId,
    String? videoTitle,
    String? videoUrl,
    DateTime? createdAt,
  }) {
    return SavedItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      kitabId: kitabId ?? this.kitabId,
      folderName: folderName ?? this.folderName,
      itemType: itemType ?? this.itemType,
      videoId: videoId ?? this.videoId,
      videoTitle: videoTitle ?? this.videoTitle,
      videoUrl: videoUrl ?? this.videoUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
