import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminKitabService {
  final SupabaseClient _supabase;

  AdminKitabService(this._supabase);

  // =====================================================
  // KITAB MANAGEMENT
  // =====================================================

  /// Dapatkan kitab berdasarkan ID
  Future<Map<String, dynamic>> getKitabById(String kitabId) async {
    try {
      final response = await _supabase
          .from('kitab')
          .select('''
            *,
            categories!inner(id, name, icon_url),
            kitab_videos(id, title, part_number, duration_seconds, is_preview)
          ''')
          .eq('id', kitabId)
          .single();
      
      return response;
    } catch (e) {
      throw Exception('Ralat mendapatkan kitab: $e');
    }
  }

  /// Dapatkan semua kitab dengan search dan filter
  Future<List<Map<String, dynamic>>> getAllKitab({
    String? searchQuery,
    String? categoryId,
    bool? isPremium,
    bool? isActive,
    bool? hasEbook,
    bool? hasVideo,
    String orderBy = 'sort_order',
    bool ascending = true,
    int? limit,
    int? offset,
  }) async {
    try {
      var query = _supabase.from('kitab').select('''
            *,
            categories!inner(id, name, icon_url),
            kitab_videos(id, title, part_number, duration_seconds, is_preview)
          ''');

      // Search filter
      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query.or(
          'title.ilike.%$searchQuery%,author.ilike.%$searchQuery%,description.ilike.%$searchQuery%',
        );
      }

      // Category filter
      if (categoryId != null) {
        query = query.eq('category_id', categoryId);
      }

      // Premium filter
      if (isPremium != null) {
        query = query.eq('is_premium', isPremium);
      }

      // Active filter
      if (isActive != null) {
        query = query.eq('is_active', isActive);
      }

      // Ebook filter
      if (hasEbook != null) {
        query = query.eq('is_ebook_available', hasEbook);
      }

      // Video filter
      if (hasVideo != null) {
        query = query.eq('has_multiple_videos', hasVideo);
      }

      // Apply ordering first
      var orderedQuery = ascending
          ? query.order(orderBy)
          : query.order(orderBy, ascending: false);

      // Then apply pagination
      if (limit != null) {
        orderedQuery = orderedQuery.limit(limit);
      }
      if (offset != null) {
        orderedQuery = orderedQuery.range(offset, offset + (limit ?? 10) - 1);
      }

      final response = await orderedQuery;
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Ralat mendapatkan kitab: $e');
    }
  }

  /// Tambah kitab baru
  Future<Map<String, dynamic>> createKitab({
    required String title,
    String? author,
    String? description,
    String? categoryId,
    String? thumbnailUrl,
    bool isPremium = true,
    bool isActive = true,
    bool isEbookAvailable = false,
    int? totalPages,
    int? sortOrder,
    // Video data untuk single video kitab
    String? youtubeVideoId,
    String? youtubeVideoUrl,
    int? durationMinutes,
    // PDF data untuk ebook
    String? pdfUrl,
    String? pdfStoragePath,
    int? pdfFileSize,
  }) async {
    try {
      // Validasi title unik
      final existing = await _supabase
          .from('kitab')
          .select('id')
          .eq('title', title)
          .maybeSingle();

      if (existing != null) {
        throw Exception('Tajuk kitab sudah wujud');
      }

      // Validasi kategori exists jika diberikan
      if (categoryId != null) {
        final categoryExists = await _supabase
            .from('categories')
            .select('id')
            .eq('id', categoryId)
            .eq('is_active', true)
            .maybeSingle();

        if (categoryExists == null) {
          throw Exception('Kategori tidak dijumpai atau tidak aktif');
        }
      }

      // Dapatkan sort_order seterusnya jika tidak diberikan
      if (sortOrder == null) {
        final maxOrderResult = await _supabase
            .from('kitab')
            .select('sort_order')
            .order('sort_order', ascending: false)
            .limit(1)
            .maybeSingle();

        sortOrder = (maxOrderResult?['sort_order'] as int? ?? 0) + 1;
      }

      final kitabData = {
        'title': title,
        'author': author,
        'description': description,
        'category_id': categoryId,
        'thumbnail_url': thumbnailUrl,
        'is_premium': isPremium,
        'is_active': isActive,
        'sort_order': sortOrder,
        'is_ebook_available': isEbookAvailable,
        'total_pages': totalPages,
        'pdf_url': pdfUrl,
        'pdf_storage_path': pdfStoragePath,
        'pdf_file_size': pdfFileSize,
        'pdf_upload_date': pdfUrl != null
            ? DateTime.now().toIso8601String()
            : null,
        // Single video fields (legacy support)
        'youtube_video_id': youtubeVideoId,
        'youtube_video_url': youtubeVideoUrl,
        'duration_minutes': durationMinutes,
        // Multi-video fields
        'has_multiple_videos': false,
        'total_videos': youtubeVideoId != null ? 1 : 0,
        'total_duration_minutes': durationMinutes ?? 0,
      };

      final response = await _supabase
          .from('kitab')
          .insert(kitabData)
          .select()
          .single();

      return response;
    } catch (e) {
      throw Exception('Ralat menambah kitab: $e');
    }
  }

  /// Update kitab
  Future<Map<String, dynamic>> updateKitab({
    required String kitabId,
    String? title,
    String? author,
    String? description,
    String? categoryId,
    String? thumbnailUrl,
    bool? isPremium,
    bool? isActive,
    bool? isEbookAvailable,
    int? totalPages,
    int? sortOrder,
    String? youtubeVideoId,
    String? youtubeVideoUrl,
    int? durationMinutes,
    String? pdfUrl,
    String? pdfStoragePath,
    int? pdfFileSize,
  }) async {
    try {
      // Check kitab exists
      final existing = await _supabase
          .from('kitab')
          .select('id, title')
          .eq('id', kitabId)
          .maybeSingle();

      if (existing == null) {
        throw Exception('Kitab tidak dijumpai');
      }

      // Validasi title unik jika berubah
      if (title != null && title != existing['title']) {
        final titleCheck = await _supabase
            .from('kitab')
            .select('id')
            .eq('title', title)
            .neq('id', kitabId)
            .maybeSingle();

        if (titleCheck != null) {
          throw Exception('Tajuk kitab sudah wujud');
        }
      }

      // Validasi kategori exists jika berubah
      if (categoryId != null) {
        final categoryExists = await _supabase
            .from('categories')
            .select('id')
            .eq('id', categoryId)
            .eq('is_active', true)
            .maybeSingle();

        if (categoryExists == null) {
          throw Exception('Kategori tidak dijumpai atau tidak aktif');
        }
      }

      final updateData = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (title != null) updateData['title'] = title;
      if (author != null) updateData['author'] = author;
      if (description != null) updateData['description'] = description;
      if (categoryId != null) updateData['category_id'] = categoryId;
      if (thumbnailUrl != null) updateData['thumbnail_url'] = thumbnailUrl;
      if (isPremium != null) updateData['is_premium'] = isPremium;
      if (isActive != null) updateData['is_active'] = isActive;
      if (isEbookAvailable != null)
        updateData['is_ebook_available'] = isEbookAvailable;
      if (totalPages != null) updateData['total_pages'] = totalPages;
      if (sortOrder != null) updateData['sort_order'] = sortOrder;
      if (youtubeVideoId != null)
        updateData['youtube_video_id'] = youtubeVideoId;
      if (youtubeVideoUrl != null)
        updateData['youtube_video_url'] = youtubeVideoUrl;
      if (durationMinutes != null)
        updateData['duration_minutes'] = durationMinutes;
      if (pdfUrl != null) {
        updateData['pdf_url'] = pdfUrl;
        updateData['pdf_upload_date'] = DateTime.now().toIso8601String();
      }
      if (pdfStoragePath != null)
        updateData['pdf_storage_path'] = pdfStoragePath;
      if (pdfFileSize != null) updateData['pdf_file_size'] = pdfFileSize;

      final response = await _supabase
          .from('kitab')
          .update(updateData)
          .eq('id', kitabId)
          .select()
          .single();

      return response;
    } catch (e) {
      throw Exception('Ralat mengupdate kitab: $e');
    }
  }

  /// Padam kitab
  Future<void> deleteKitab(String kitabId) async {
    try {
      // Check jika ada users yang sedang membaca
      final readingProgressData = await _supabase
          .from('reading_progress')
          .select('id')
          .eq('kitab_id', kitabId);

      if (readingProgressData.isNotEmpty) {
        // Jangan padam, set inactive sahaja
        await _supabase
            .from('kitab')
            .update({
              'is_active': false,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', kitabId);
        return;
      }

      // Padam semua video episodes terlebih dahulu
      await _supabase.from('kitab_videos').delete().eq('kitab_id', kitabId);

      // Padam kitab
      await _supabase.from('kitab').delete().eq('id', kitabId);
    } catch (e) {
      throw Exception('Ralat memadam kitab: $e');
    }
  }

  /// Toggle status aktif kitab
  Future<Map<String, dynamic>> toggleKitabStatus(String kitabId) async {
    try {
      final kitab = await _supabase
          .from('kitab')
          .select('is_active')
          .eq('id', kitabId)
          .single();

      final newStatus = !(kitab['is_active'] as bool? ?? false);

      final response = await _supabase
          .from('kitab')
          .update({
            'is_active': newStatus,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', kitabId)
          .select()
          .single();

      return response;
    } catch (e) {
      throw Exception('Ralat menukar status kitab: $e');
    }
  }

  /// Upload PDF untuk ebook
  Future<String> uploadKitabPDF(File pdfFile, String kitabId) async {
    try {
      final fileExt = pdfFile.path.split('.').last.toLowerCase();
      if (fileExt != 'pdf') {
        throw Exception('Hanya fail PDF yang dibenarkan');
      }

      // Validate file size (max 50MB)
      final fileSize = await pdfFile.length();
      if (fileSize > 50 * 1024 * 1024) {
        throw Exception('Saiz fail terlalu besar. Maksimum 50MB');
      }

      final fileName =
          'kitab_${kitabId}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final filePath = 'kitab-pdfs/$fileName';

      // Upload to Supabase Storage
      await _supabase.storage
          .from('ebook-pdfs') // Private bucket untuk PDF
          .upload(filePath, pdfFile);

      // Update kitab dengan PDF info
      await _supabase
          .from('kitab')
          .update({
            'pdf_storage_path': filePath,
            'pdf_file_size': fileSize,
            'pdf_upload_date': DateTime.now().toIso8601String(),
            'is_ebook_available': true,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', kitabId);

      // Get signed URL untuk immediate access
      final signedUrl = await _supabase.storage
          .from('ebook-pdfs')
          .createSignedUrl(filePath, 3600); // 1 hour expiry

      return signedUrl;
    } catch (e) {
      throw Exception('Ralat upload PDF: $e');
    }
  }

  /// Upload thumbnail kitab
  Future<String> uploadKitabThumbnail(File imageFile, String kitabId) async {
    try {
      final fileExt = imageFile.path.split('.').last.toLowerCase();
      final fileName =
          'kitab_thumb_${kitabId}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = 'kitab-thumbnails/$fileName';

      // Validate file type
      if (!['jpg', 'jpeg', 'png', 'webp'].contains(fileExt)) {
        throw Exception(
          'Format fail tidak disokong. Gunakan JPG, PNG atau WebP',
        );
      }

      // Validate file size (max 10MB)
      final fileSize = await imageFile.length();
      if (fileSize > 10 * 1024 * 1024) {
        throw Exception('Saiz fail terlalu besar. Maksimum 10MB');
      }

      // Upload to Supabase Storage
      await _supabase.storage.from('public').upload(filePath, imageFile);

      // Get public URL
      final thumbnailUrl = _supabase.storage
          .from('public')
          .getPublicUrl(filePath);

      return thumbnailUrl;
    } catch (e) {
      throw Exception('Ralat upload thumbnail: $e');
    }
  }

  /// Reorder kitab dalam kategori
  Future<void> reorderKitab(List<String> kitabIds) async {
    try {
      final batch = <Map<String, dynamic>>[];

      for (int i = 0; i < kitabIds.length; i++) {
        batch.add({
          'id': kitabIds[i],
          'sort_order': i + 1,
          'updated_at': DateTime.now().toIso8601String(),
        });
      }

      await _supabase.from('kitab').upsert(batch);
    } catch (e) {
      throw Exception('Ralat menyusun semula kitab: $e');
    }
  }

  /// Dapatkan statistik kitab
  Future<Map<String, int>> getKitabStats() async {
    try {
      // Total kitab
      final totalData = await _supabase.from('kitab').select('id');

      // Kitab aktif
      final activeData = await _supabase
          .from('kitab')
          .select('id')
          .eq('is_active', true);

      // Kitab premium
      final premiumData = await _supabase
          .from('kitab')
          .select('id')
          .eq('is_premium', true)
          .eq('is_active', true);

      // Kitab dengan ebook
      final ebookData = await _supabase
          .from('kitab')
          .select('id')
          .eq('is_ebook_available', true)
          .eq('is_active', true);

      // Kitab dengan video
      final videoData = await _supabase
          .from('kitab')
          .select('id')
          .eq('has_multiple_videos', true)
          .eq('is_active', true);

      final totalCount = totalData.length;
      final activeCount = activeData.length;
      final premiumCount = premiumData.length;
      final ebookCount = ebookData.length;
      final videoCount = videoData.length;

      return {
        'total_kitab': totalCount,
        'active_kitab': activeCount,
        'inactive_kitab': totalCount - activeCount,
        'premium_kitab': premiumCount,
        'free_kitab': activeCount - premiumCount,
        'ebook_available': ebookCount,
        'video_available': videoCount,
      };
    } catch (e) {
      throw Exception('Ralat mendapatkan statistik kitab: $e');
    }
  }

  /// Duplicate kitab (untuk template)
  Future<Map<String, dynamic>> duplicateKitab(
    String kitabId,
    String newTitle,
  ) async {
    try {
      // Get original kitab
      final original = await _supabase
          .from('kitab')
          .select()
          .eq('id', kitabId)
          .single();

      // Prepare data untuk duplicate
      final duplicateData = Map<String, dynamic>.from(original);
      duplicateData.remove('id'); // Remove ID untuk auto-generate
      duplicateData['title'] = newTitle;
      duplicateData['created_at'] = DateTime.now().toIso8601String();
      duplicateData['updated_at'] = DateTime.now().toIso8601String();

      // Reset counters
      duplicateData['total_videos'] = 0;
      duplicateData['total_duration_minutes'] = 0;
      duplicateData['has_multiple_videos'] = false;

      // Clear video and PDF references
      duplicateData['youtube_video_id'] = null;
      duplicateData['youtube_video_url'] = null;
      duplicateData['pdf_url'] = null;
      duplicateData['pdf_storage_path'] = null;
      duplicateData['is_ebook_available'] = false;

      // Set sebagai inactive by default
      duplicateData['is_active'] = false;

      // Insert duplicate
      final response = await _supabase
          .from('kitab')
          .insert(duplicateData)
          .select()
          .single();

      return response;
    } catch (e) {
      throw Exception('Ralat menduplicate kitab: $e');
    }
  }
}
