import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'package:hive_flutter/hive_flutter.dart';

class PdfCacheService {
  static const String _boxName = 'pdf_cache';
  static const String _metadataKey = 'pdf_metadata';

  static Box<dynamic>? _box;
  static Directory? _cacheDirectory;

  /// Initialize the PDF cache service
  static Future<void> initialize() async {
    try {
      _box = await Hive.openBox(_boxName);

      // Get cache directory
      final appDir = await getApplicationDocumentsDirectory();
      _cacheDirectory = Directory('${appDir.path}/pdf_cache');

      // Create cache directory if it doesn't exist
      if (!await _cacheDirectory!.exists()) {
        await _cacheDirectory!.create(recursive: true);
      }

      if (kDebugMode) {
        print('PDF Cache Service initialized at: ${_cacheDirectory!.path}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing PdfCacheService: $e');
      }
    }
  }

  /// Get the cache box
  static Box<dynamic> get _cacheBox {
    if (_box == null || !_box!.isOpen) {
      throw Exception(
        'PdfCacheService not initialized. Call initialize() first.',
      );
    }
    return _box!;
  }

  /// Generate a unique key for PDF URL
  static String _generateKey(String url) {
    final bytes = utf8.encode(url);
    final digest = md5.convert(bytes);
    return digest.toString();
  }

  /// Check if PDF is cached
  static bool isPdfCached(String pdfUrl) {
    try {
      if (_cacheDirectory == null) return false;

      final key = _generateKey(pdfUrl);
      final metadata =
          _cacheBox.get(_metadataKey, defaultValue: <String, dynamic>{}) as Map;

      if (!metadata.containsKey(key)) return false;

      final filePath = '${_cacheDirectory!.path}/$key.pdf';
      final file = File(filePath);

      return file.existsSync();
    } catch (e) {
      if (kDebugMode) {
        print('Error checking PDF cache: $e');
      }
      return false;
    }
  }

  /// Get cached PDF file path
  static String? getCachedPdfPath(String pdfUrl) {
    try {
      if (!isPdfCached(pdfUrl)) return null;

      final key = _generateKey(pdfUrl);
      final filePath = '${_cacheDirectory!.path}/$key.pdf';

      return filePath;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting cached PDF path: $e');
      }
      return null;
    }
  }

  /// Download and cache PDF
  static Future<String?> downloadAndCachePdf(
    String pdfUrl, {
    Function(double)? onProgress,
  }) async {
    try {
      if (_cacheDirectory == null) {
        throw Exception('Cache directory not initialized');
      }

      final key = _generateKey(pdfUrl);
      final filePath = '${_cacheDirectory!.path}/$key.pdf';
      final file = File(filePath);

      // Check if already cached
      if (file.existsSync()) {
        if (kDebugMode) {
          print('PDF already cached: $filePath');
        }
        return filePath;
      }

      if (kDebugMode) {
        print('Downloading PDF from: $pdfUrl');
      }

      // Download PDF
      final response = await http.get(Uri.parse(pdfUrl));

      if (response.statusCode == 200) {
        // Save to cache directory
        await file.writeAsBytes(response.bodyBytes);

        // Save metadata
        final metadata =
            _cacheBox.get(_metadataKey, defaultValue: <String, dynamic>{})
                as Map;
        final updatedMetadata = Map<String, dynamic>.from(metadata);

        updatedMetadata[key] = {
          'url': pdfUrl,
          'file_path': filePath,
          'file_size': response.bodyBytes.length,
          'cached_at': DateTime.now().toIso8601String(),
          'last_accessed': DateTime.now().toIso8601String(),
        };

        await _cacheBox.put(_metadataKey, updatedMetadata);

        if (kDebugMode) {
          print(
            'PDF cached successfully: $filePath (${response.bodyBytes.length} bytes)',
          );
        }

        return filePath;
      } else {
        throw Exception('Failed to download PDF: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error downloading and caching PDF: $e');
      }
      return null;
    }
  }

  /// Update last accessed time
  static Future<void> updateLastAccessed(String pdfUrl) async {
    try {
      final key = _generateKey(pdfUrl);
      final metadata =
          _cacheBox.get(_metadataKey, defaultValue: <String, dynamic>{}) as Map;

      if (metadata.containsKey(key)) {
        final updatedMetadata = Map<String, dynamic>.from(metadata);
        updatedMetadata[key]['last_accessed'] = DateTime.now()
            .toIso8601String();
        await _cacheBox.put(_metadataKey, updatedMetadata);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error updating last accessed: $e');
      }
    }
  }

  /// Get all cached PDFs info
  static Map<String, Map<String, dynamic>> getAllCachedPdfs() {
    try {
      final metadata =
          _cacheBox.get(_metadataKey, defaultValue: <String, dynamic>{}) as Map;
      return Map<String, Map<String, dynamic>>.from(metadata);
    } catch (e) {
      if (kDebugMode) {
        print('Error getting all cached PDFs: $e');
      }
      return {};
    }
  }

  /// Calculate total cache size
  static int getTotalCacheSize() {
    try {
      final metadata = getAllCachedPdfs();
      int totalSize = 0;

      for (final pdfInfo in metadata.values) {
        totalSize += (pdfInfo['file_size'] as int? ?? 0);
      }

      return totalSize;
    } catch (e) {
      if (kDebugMode) {
        print('Error calculating cache size: $e');
      }
      return 0;
    }
  }

  /// Format cache size to human readable
  static String formatCacheSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Remove specific PDF from cache
  static Future<bool> removePdfFromCache(String pdfUrl) async {
    try {
      final key = _generateKey(pdfUrl);
      final filePath = '${_cacheDirectory!.path}/$key.pdf';
      final file = File(filePath);

      // Remove file
      if (file.existsSync()) {
        await file.delete();
      }

      // Remove metadata
      final metadata =
          _cacheBox.get(_metadataKey, defaultValue: <String, dynamic>{}) as Map;
      final updatedMetadata = Map<String, dynamic>.from(metadata);
      updatedMetadata.remove(key);
      await _cacheBox.put(_metadataKey, updatedMetadata);

      if (kDebugMode) {
        print('PDF removed from cache: $pdfUrl');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error removing PDF from cache: $e');
      }
      return false;
    }
  }

  /// Clear all cached PDFs
  static Future<void> clearAllCache() async {
    try {
      if (_cacheDirectory != null && await _cacheDirectory!.exists()) {
        // Delete all PDF files
        final files = _cacheDirectory!.listSync();
        for (final file in files) {
          if (file is File && file.path.endsWith('.pdf')) {
            await file.delete();
          }
        }
      }

      // Clear metadata
      await _cacheBox.delete(_metadataKey);

      if (kDebugMode) {
        print('All PDF cache cleared');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing PDF cache: $e');
      }
    }
  }

  /// Clean old cache (remove PDFs not accessed for more than 30 days)
  static Future<void> cleanOldCache({int maxDays = 30}) async {
    try {
      final metadata = getAllCachedPdfs();
      final cutoffDate = DateTime.now().subtract(Duration(days: maxDays));
      final keysToRemove = <String>[];

      for (final entry in metadata.entries) {
        final key = entry.key;
        final pdfInfo = entry.value;

        final lastAccessedStr = pdfInfo['last_accessed'] as String?;
        if (lastAccessedStr != null) {
          final lastAccessed = DateTime.tryParse(lastAccessedStr);
          if (lastAccessed != null && lastAccessed.isBefore(cutoffDate)) {
            keysToRemove.add(key);

            // Delete file
            final filePath = '${_cacheDirectory!.path}/$key.pdf';
            final file = File(filePath);
            if (file.existsSync()) {
              await file.delete();
            }
          }
        }
      }

      // Remove metadata for deleted files
      if (keysToRemove.isNotEmpty) {
        final updatedMetadata = Map<String, dynamic>.from(metadata);
        for (final key in keysToRemove) {
          updatedMetadata.remove(key);
        }
        await _cacheBox.put(_metadataKey, updatedMetadata);

        if (kDebugMode) {
          print('Cleaned ${keysToRemove.length} old PDFs from cache');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error cleaning old cache: $e');
      }
    }
  }

  /// Close the cache service
  static Future<void> close() async {
    try {
      await _box?.close();
      _box = null;
      _cacheDirectory = null;
    } catch (e) {
      if (kDebugMode) {
        print('Error closing PdfCacheService: $e');
      }
    }
  }
}
