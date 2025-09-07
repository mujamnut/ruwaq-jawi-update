class Bookmark {
  final String id;
  final String userId;
  final String kitabId;
  final String title;
  final String? description;
  final int videoPosition; // in seconds
  final int pdfPage;
  final String contentType; // 'video' or 'pdf'
  final DateTime createdAt;
  final DateTime updatedAt;

  const Bookmark({
    required this.id,
    required this.userId,
    required this.kitabId,
    required this.title,
    this.description,
    required this.videoPosition,
    required this.pdfPage,
    required this.contentType,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Bookmark.fromJson(Map<String, dynamic> json) {
    return Bookmark(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      kitabId: json['kitab_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      videoPosition: json['video_position'] as int? ?? 0,
      pdfPage: json['pdf_page'] as int? ?? 1,
      contentType: json['content_type'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'kitab_id': kitabId,
      'title': title,
      'description': description,
      'video_position': videoPosition,
      'pdf_page': pdfPage,
      'content_type': contentType,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Bookmark copyWith({
    String? id,
    String? userId,
    String? kitabId,
    String? title,
    String? description,
    int? videoPosition,
    int? pdfPage,
    String? contentType,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Bookmark(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      kitabId: kitabId ?? this.kitabId,
      title: title ?? this.title,
      description: description ?? this.description,
      videoPosition: videoPosition ?? this.videoPosition,
      pdfPage: pdfPage ?? this.pdfPage,
      contentType: contentType ?? this.contentType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Bookmark &&
        other.id == id &&
        other.userId == userId &&
        other.kitabId == kitabId;
  }

  @override
  int get hashCode {
    return id.hashCode ^ userId.hashCode ^ kitabId.hashCode;
  }

  @override
  String toString() {
    return 'Bookmark(id: $id, kitabId: $kitabId, title: $title, contentType: $contentType)';
  }
}
