import 'package:flutter/material.dart';
import '../../../../../core/models/video_kitab.dart';
import '../../../../../core/services/pdf_cache_service.dart';
import '../services/notification_helper.dart';

class PdfManager {
  // PDF caching state
  bool _isPdfDownloading = false;
  double _downloadProgress = 0.0;
  String? _cachedPdfPath;

  // Callbacks
  final VoidCallback? onStateChanged;

  PdfManager({this.onStateChanged});

  // Getters
  bool get isPdfDownloading => _isPdfDownloading;
  double get downloadProgress => _downloadProgress;
  String? get cachedPdfPath => _cachedPdfPath;

  Future<void> checkPdfCache(VideoKitab? kitab) async {
    if (kitab?.pdfUrl != null && kitab!.pdfUrl!.isNotEmpty) {
      final cachedPath = PdfCacheService.getCachedPdfPath(kitab.pdfUrl!);
      if (cachedPath != null) {
        _cachedPdfPath = cachedPath;
        onStateChanged?.call();
        // Update last accessed time
        await PdfCacheService.updateLastAccessed(kitab.pdfUrl!);
      }
    }
  }

  Future<void> downloadPdfIfNeeded(BuildContext context, VideoKitab? kitab) async {
    if (kitab?.pdfUrl == null || kitab!.pdfUrl!.isEmpty) return;

    // Check if already cached
    if (PdfCacheService.isPdfCached(kitab.pdfUrl!)) {
      _cachedPdfPath = PdfCacheService.getCachedPdfPath(kitab.pdfUrl!);
      onStateChanged?.call();
      return;
    }

    // Download and cache PDF
    _isPdfDownloading = true;
    _downloadProgress = 0.0;
    onStateChanged?.call();

    try {
      final cachedPath = await PdfCacheService.downloadAndCachePdf(
        kitab.pdfUrl!,
        onProgress: (progress) {
          _downloadProgress = progress;
          onStateChanged?.call();
        },
      );

      if (cachedPath != null) {
        _cachedPdfPath = cachedPath;
        _isPdfDownloading = false;
        onStateChanged?.call();

        // Show success message
        if (context.mounted) {
          NotificationHelper.showPdfDownloadSuccess(context);
        }
      }
    } catch (e) {
      _isPdfDownloading = false;
      onStateChanged?.call();

      if (context.mounted) {
        NotificationHelper.showPdfDownloadError(context, e.toString());
      }
    }
  }

  void setCachedPath(String path) {
    _cachedPdfPath = path;
    onStateChanged?.call();
  }
}