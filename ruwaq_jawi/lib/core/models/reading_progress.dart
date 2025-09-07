class ReadingProgress {
  final String id;
  final String userId;
  final String kitabId;
  final int videoProgress; // seconds watched
  final int videoDuration; // total video duration in seconds
  final int pdfPage;
  final int? pdfTotalPages;
  final double completionPercentage;
  final DateTime lastAccessed;
  final DateTime createdAt;
  final DateTime updatedAt;
  // ✅ NEW: Add these properties for enhanced features
  final List<dynamic> bookmarks;     // JSON array for bookmarks
  final Map<String, dynamic> notes;  // JSON object for notes

  ReadingProgress({
    required this.id,
    required this.userId,
    required this.kitabId,
    required this.videoProgress,
    required this.videoDuration,
    required this.pdfPage,
    this.pdfTotalPages,
    required this.completionPercentage,
    required this.lastAccessed,
    required this.createdAt,
    required this.updatedAt,
    this.bookmarks = const [],       // ✅ NEW: Default empty list
    this.notes = const {},           // ✅ NEW: Default empty map
  });

  factory ReadingProgress.fromJson(Map<String, dynamic> json) {
    return ReadingProgress(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      kitabId: json['kitab_id'] as String,
      videoProgress: json['video_progress'] as int? ?? 0,
      videoDuration: json['video_duration'] as int? ?? 0,
      pdfPage: json['current_page'] as int? ?? 1,                    // ✅ CHANGE: pdf_page → current_page
      pdfTotalPages: json['total_pages'] as int?,                    // ✅ CHANGE: pdf_total_pages → total_pages
      completionPercentage: double.parse((json['progress_percentage'] ?? 0.0).toString()), // ✅ CHANGE: completion_percentage → progress_percentage
      lastAccessed: DateTime.parse(json['last_accessed'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      // ✅ NEW FEATURES AVAILABLE:
      bookmarks: json['bookmarks'] as List<dynamic>? ?? [],          // ✅ NEW: JSON bookmarks
      notes: json['notes'] as Map<String, dynamic>? ?? {},           // ✅ NEW: JSON notes
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'kitab_id': kitabId,
      'video_progress': videoProgress,
      'video_duration': videoDuration,
      'current_page': pdfPage,                         // ✅ CHANGE: pdf_page → current_page
      'total_pages': pdfTotalPages,                    // ✅ CHANGE: pdf_total_pages → total_pages
      'progress_percentage': completionPercentage,     // ✅ CHANGE: completion_percentage → progress_percentage
      'last_accessed': lastAccessed.toIso8601String(),
      'bookmarks': bookmarks,                          // ✅ NEW: Save bookmarks as JSON
      'notes': notes,                                  // ✅ NEW: Save notes as JSON
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  ReadingProgress copyWith({
    String? id,
    String? userId,
    String? kitabId,
    int? videoProgress,
    int? videoDuration,
    int? pdfPage,
    int? pdfTotalPages,
    double? completionPercentage,
    DateTime? lastAccessed,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<dynamic>? bookmarks,           // ✅ NEW: Add bookmarks parameter
    Map<String, dynamic>? notes,        // ✅ NEW: Add notes parameter
  }) {
    return ReadingProgress(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      kitabId: kitabId ?? this.kitabId,
      videoProgress: videoProgress ?? this.videoProgress,
      videoDuration: videoDuration ?? this.videoDuration,
      pdfPage: pdfPage ?? this.pdfPage,
      pdfTotalPages: pdfTotalPages ?? this.pdfTotalPages,
      completionPercentage: completionPercentage ?? this.completionPercentage,
      lastAccessed: lastAccessed ?? this.lastAccessed,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      bookmarks: bookmarks ?? this.bookmarks,     // ✅ NEW: Include bookmarks
      notes: notes ?? this.notes,                 // ✅ NEW: Include notes
    );
  }

  String get formattedVideoProgress {
    final hours = videoProgress ~/ 3600;
    final minutes = (videoProgress % 3600) ~/ 60;
    final seconds = videoProgress % 60;
    
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  double getVideoProgressPercentage() {
    if (videoDuration == 0) return 0.0;
    return (videoProgress / videoDuration).clamp(0.0, 1.0);
  }

  double getPdfProgressPercentage() {
    if (pdfTotalPages == null || pdfTotalPages! == 0) return 0.0;
    return (pdfPage / pdfTotalPages!).clamp(0.0, 1.0);
  }

  bool get hasVideoProgress => videoProgress > 0;
  bool get hasPdfProgress => pdfPage > 1;
  
  // ✅ NEW: Helper methods for bookmarks & notes
  void addBookmark(Map<String, dynamic> bookmark) {
    if (bookmarks is List<dynamic>) {
      (bookmarks as List<dynamic>).add(bookmark);
    }
  }
  
  void addNote(String key, dynamic value) {
    if (notes is Map<String, dynamic>) {
      (notes as Map<String, dynamic>)[key] = value;
    }
  }
  
  List<Map<String, dynamic>> get bookmarksList {
    return bookmarks.cast<Map<String, dynamic>>();
  }
  
  bool get hasBookmarks => bookmarks.isNotEmpty;
  bool get hasNotes => notes.isNotEmpty;
}
