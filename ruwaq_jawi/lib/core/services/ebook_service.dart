import '../models/ebook.dart';
import 'supabase_service.dart';

class EbookService {
  static const String _tableName = 'ebooks';

  // Get all ebooks with optional filters
  static Future<List<Ebook>> getEbooks({
    String? categoryId,
    bool? isPremium,
    bool? isActive,
    String? searchQuery,
    int? limit,
    int? offset,
    String orderBy = 'created_at',
    bool ascending = false,
  }) async {
    try {
      // Build base query
      dynamic query = SupabaseService.from(_tableName)
          .select('''
            id, title, author, description, category_id, pdf_url,
            pdf_storage_path, pdf_file_size, thumbnail_url, total_pages,
            is_premium, sort_order, is_active, views_count, downloads_count,
            created_at, updated_at,
            categories(id, name)
          ''');

      // Apply filters conditionally
      if (categoryId != null && isPremium != null && isActive != null) {
        query = SupabaseService.from(_tableName)
            .select('''
              id, title, author, description, category_id, pdf_url,
              pdf_storage_path, pdf_file_size, thumbnail_url, total_pages,
              is_premium, sort_order, is_active, views_count, downloads_count,
              created_at, updated_at,
              categories(id, name)
            ''')
            .eq('category_id', categoryId)
            .eq('is_premium', isPremium)
            .eq('is_active', isActive);
      } else if (categoryId != null && isPremium != null) {
        query = SupabaseService.from(_tableName)
            .select('''
              id, title, author, description, category_id, pdf_url,
              pdf_storage_path, pdf_file_size, thumbnail_url, total_pages,
              is_premium, sort_order, is_active, views_count, downloads_count,
              created_at, updated_at,
              categories(id, name)
            ''')
            .eq('category_id', categoryId)
            .eq('is_premium', isPremium);
      } else if (categoryId != null && isActive != null) {
        query = SupabaseService.from(_tableName)
            .select('''
              id, title, author, description, category_id, pdf_url,
              pdf_storage_path, pdf_file_size, thumbnail_url, total_pages,
              is_premium, sort_order, is_active, views_count, downloads_count,
              created_at, updated_at,
              categories(id, name)
            ''')
            .eq('category_id', categoryId)
            .eq('is_active', isActive);
      } else if (isPremium != null && isActive != null) {
        query = SupabaseService.from(_tableName)
            .select('''
              id, title, author, description, category_id, pdf_url,
              pdf_storage_path, pdf_file_size, thumbnail_url, total_pages,
              is_premium, sort_order, is_active, views_count, downloads_count,
              created_at, updated_at,
              categories(id, name)
            ''')
            .eq('is_premium', isPremium)
            .eq('is_active', isActive);
      } else if (categoryId != null) {
        query = SupabaseService.from(_tableName)
            .select('''
              id, title, author, description, category_id, pdf_url,
              pdf_storage_path, pdf_file_size, thumbnail_url, total_pages,
              is_premium, sort_order, is_active, views_count, downloads_count,
              created_at, updated_at,
              categories(id, name)
            ''')
            .eq('category_id', categoryId);
      } else if (isPremium != null) {
        query = SupabaseService.from(_tableName)
            .select('''
              id, title, author, description, category_id, pdf_url,
              pdf_storage_path, pdf_file_size, thumbnail_url, total_pages,
              is_premium, sort_order, is_active, views_count, downloads_count,
              created_at, updated_at,
              categories(id, name)
            ''')
            .eq('is_premium', isPremium);
      } else if (isActive != null) {
        query = SupabaseService.from(_tableName)
            .select('''
              id, title, author, description, category_id, pdf_url,
              pdf_storage_path, pdf_file_size, thumbnail_url, total_pages,
              is_premium, sort_order, is_active, views_count, downloads_count,
              created_at, updated_at,
              categories(id, name)
            ''')
            .eq('is_active', isActive);
      }

      // Apply search filter
      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        // For search, rebuild query from scratch to avoid conflicts
        final baseQuery = SupabaseService.from(_tableName)
            .select('''
              id, title, author, description, category_id, pdf_url,
              pdf_storage_path, pdf_file_size, thumbnail_url, total_pages,
              is_premium, sort_order, is_active, views_count, downloads_count,
              created_at, updated_at,
              categories(id, name)
            ''')
            .or('title.ilike.%$searchQuery%,author.ilike.%$searchQuery%');
        
        // Apply additional filters to search query
        if (categoryId != null) {
          query = baseQuery.eq('category_id', categoryId);
        } else if (isPremium != null) {
          query = baseQuery.eq('is_premium', isPremium);
        } else if (isActive != null) {
          query = baseQuery.eq('is_active', isActive);
        } else {
          query = baseQuery;
        }
      }

      // Execute with ordering and pagination
      final response = await query
          .order(orderBy, ascending: ascending)
          .limit(limit ?? 50)
          .range(offset ?? 0, (offset ?? 0) + (limit ?? 50) - 1);
      
      return List<Map<String, dynamic>>.from(response)
          .map((json) => Ebook.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch ebooks: $e');
    }
  }

  // Get single ebook by ID
  static Future<Ebook?> getEbookById(String id) async {
    try {
      final response = await SupabaseService.from(_tableName)
          .select('''
            id, title, author, description, category_id, pdf_url,
            pdf_storage_path, pdf_file_size, thumbnail_url, total_pages,
            is_premium, sort_order, is_active, views_count, downloads_count,
            created_at, updated_at,
            categories(id, name)
          ''')
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;
      return Ebook.fromJson(response);
    } catch (e) {
      throw Exception('Failed to fetch ebook: $e');
    }
  }

  // Create new ebook
  static Future<Ebook> createEbook(Map<String, dynamic> ebookData) async {
    try {
      // Ensure required fields and set defaults
      final data = {
        ...ebookData,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'is_active': ebookData['is_active'] ?? true,
        'is_premium': ebookData['is_premium'] ?? true,
        'sort_order': ebookData['sort_order'] ?? 0,
        'views_count': 0,
        'downloads_count': 0,
      };

      final response = await SupabaseService.from(_tableName)
          .insert(data)
          .select('''
            id, title, author, description, category_id, pdf_url,
            pdf_storage_path, pdf_file_size, thumbnail_url, total_pages,
            is_premium, sort_order, is_active, views_count, downloads_count,
            created_at, updated_at,
            categories(id, name)
          ''')
          .single();

      return Ebook.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create ebook: $e');
    }
  }

  // Update ebook
  static Future<Ebook> updateEbook(String id, Map<String, dynamic> updates) async {
    try {
      final data = {
        ...updates,
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response = await SupabaseService.from(_tableName)
          .update(data)
          .eq('id', id)
          .select('''
            id, title, author, description, category_id, pdf_url,
            pdf_storage_path, pdf_file_size, thumbnail_url, total_pages,
            is_premium, sort_order, is_active, views_count, downloads_count,
            created_at, updated_at,
            categories(id, name)
          ''')
          .single();

      return Ebook.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update ebook: $e');
    }
  }

  // Delete ebook
  static Future<void> deleteEbook(String id) async {
    try {
      await SupabaseService.from(_tableName).delete().eq('id', id);
    } catch (e) {
      throw Exception('Failed to delete ebook: $e');
    }
  }

  // Toggle ebook active status
  static Future<Ebook> toggleEbookStatus(String id, bool isActive) async {
    try {
      return await updateEbook(id, {'is_active': isActive});
    } catch (e) {
      throw Exception('Failed to toggle ebook status: $e');
    }
  }

  // Get ebook statistics
  static Future<Map<String, int>> getEbookStats({String? categoryId}) async {
    try {
      // Use direct table query since ebook_stats view might not exist yet
      dynamic query = SupabaseService.from(_tableName)
          .select('id, is_active, is_premium, views_count, downloads_count');
      
      if (categoryId != null) {
        query = SupabaseService.from(_tableName)
            .select('id, is_active, is_premium, views_count, downloads_count')
            .eq('category_id', categoryId);
      }

      final response = await query;
      final stats = List<Map<String, dynamic>>.from(response);

      int totalEbooks = stats.length;
      int activeEbooks = stats.where((s) => s['is_active'] == true).length;
      int premiumEbooks = stats.where((s) => s['is_premium'] == true).length;
      int freeEbooks = stats.where((s) => s['is_premium'] == false).length;
      int totalViews = stats.fold(0, (sum, s) => sum + (s['views_count'] as int? ?? 0));
      int totalDownloads = stats.fold(0, (sum, s) => sum + (s['downloads_count'] as int? ?? 0));

      return {
        'total_ebooks': totalEbooks,
        'active_ebooks': activeEbooks,
        'inactive_ebooks': totalEbooks - activeEbooks,
        'premium_ebooks': premiumEbooks,
        'free_ebooks': freeEbooks,
        'total_views': totalViews,
        'total_downloads': totalDownloads,
      };
    } catch (e) {
      throw Exception('Failed to get ebook statistics: $e');
    }
  }

  // Get popular ebooks (by views)
  static Future<List<Ebook>> getPopularEbooks({int limit = 10}) async {
    try {
      return await getEbooks(
        limit: limit,
        orderBy: 'views_count',
        ascending: false,
        isActive: true,
      );
    } catch (e) {
      throw Exception('Failed to get popular ebooks: $e');
    }
  }

  // Get recent ebooks
  static Future<List<Ebook>> getRecentEbooks({int limit = 10}) async {
    try {
      return await getEbooks(
        limit: limit,
        orderBy: 'created_at',
        ascending: false,
        isActive: true,
      );
    } catch (e) {
      throw Exception('Failed to get recent ebooks: $e');
    }
  }

  // Search ebooks
  static Future<List<Ebook>> searchEbooks(String query, {int limit = 50}) async {
    try {
      if (query.trim().isEmpty) {
        return await getEbooks(limit: limit, isActive: true);
      }

      return await getEbooks(
        searchQuery: query.trim(),
        limit: limit,
        isActive: true,
      );
    } catch (e) {
      throw Exception('Failed to search ebooks: $e');
    }
  }

  // Get ebooks by category
  static Future<List<Ebook>> getEbooksByCategory(String categoryId, {int limit = 50}) async {
    try {
      return await getEbooks(
        categoryId: categoryId,
        limit: limit,
        isActive: true,
      );
    } catch (e) {
      throw Exception('Failed to get ebooks by category: $e');
    }
  }

  // Increment view count
  static Future<void> incrementViewCount(String id) async {
    try {
      // Get current count first, then increment
      final current = await SupabaseService.from(_tableName)
          .select('views_count')
          .eq('id', id)
          .single();
      
      final newCount = (current['views_count'] as int? ?? 0) + 1;
      
      await SupabaseService.from(_tableName)
          .update({'views_count': newCount})
          .eq('id', id);
    } catch (e) {
      throw Exception('Failed to increment view count: $e');
    }
  }

  // Increment download count
  static Future<void> incrementDownloadCount(String id) async {
    try {
      // Get current count first, then increment
      final current = await SupabaseService.from(_tableName)
          .select('downloads_count')
          .eq('id', id)
          .single();
      
      final newCount = (current['downloads_count'] as int? ?? 0) + 1;
      
      await SupabaseService.from(_tableName)
          .update({'downloads_count': newCount})
          .eq('id', id);
    } catch (e) {
      throw Exception('Failed to increment download count: $e');
    }
  }

  // Batch operations
  static Future<List<Ebook>> createMultipleEbooks(List<Map<String, dynamic>> ebooksData) async {
    try {
      final data = ebooksData.map((ebook) => {
        ...ebook,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'is_active': ebook['is_active'] ?? true,
        'is_premium': ebook['is_premium'] ?? true,
        'sort_order': ebook['sort_order'] ?? 0,
        'views_count': 0,
        'downloads_count': 0,
      }).toList();

      final response = await SupabaseService.from(_tableName)
          .insert(data)
          .select('''
            id, title, author, description, category_id, pdf_url,
            pdf_storage_path, pdf_file_size, thumbnail_url, total_pages,
            is_premium, sort_order, is_active, views_count, downloads_count,
            created_at, updated_at,
            categories(id, name)
          ''');

      return List<Map<String, dynamic>>.from(response)
          .map((json) => Ebook.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to create multiple ebooks: $e');
    }
  }

  // Delete multiple ebooks
  static Future<void> deleteMultipleEbooks(List<String> ids) async {
    try {
      for (String id in ids) {
        await SupabaseService.from(_tableName).delete().eq('id', id);
      }
    } catch (e) {
      throw Exception('Failed to delete multiple ebooks: $e');
    }
  }

  // Update multiple ebooks
  static Future<void> updateMultipleEbooks(List<String> ids, Map<String, dynamic> updates) async {
    try {
      final data = {
        ...updates,
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      for (String id in ids) {
        await SupabaseService.from(_tableName)
            .update(data)
            .eq('id', id);
      }
    } catch (e) {
      throw Exception('Failed to update multiple ebooks: $e');
    }
  }
}
