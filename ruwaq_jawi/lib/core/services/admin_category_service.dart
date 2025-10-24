import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminCategoryService {
  final SupabaseClient _supabase;

  AdminCategoryService(this._supabase);

  // =====================================================
  // KATEGORI MANAGEMENT
  // =====================================================

  /// Dapatkan semua kategori dengan search dan filter
  Future<List<Map<String, dynamic>>> getAllCategories({
    String? searchQuery,
    bool? isActive,
    String orderBy = 'sort_order',
    bool ascending = true,
  }) async {
    try {
      var query = _supabase
          .from('categories')
          .select();

      // Search filter
      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query.or('name.ilike.%$searchQuery%,description.ilike.%$searchQuery%');
      }

      // Active filter
      if (isActive != null) {
        query = query.eq('is_active', isActive);
      }

      // Apply ordering dan execute query
      final response = ascending 
          ? await query.order(orderBy)
          : await query.order(orderBy, ascending: false);
          
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Ralat mendapatkan kategori: $e');
    }
  }

  /// Tambah kategori baru
  Future<Map<String, dynamic>> createCategory({
    required String name,
    String? description,
    String? iconUrl,
    int? sortOrder,
    bool isActive = true,
  }) async {
    try {
      // Validasi nama kategori unik
      final existing = await _supabase
          .from('categories')
          .select('id')
          .eq('name', name)
          .maybeSingle();

      if (existing != null) {
        throw Exception('Nama kategori sudah wujud');
      }

      // Dapatkan sort_order seterusnya jika tidak diberikan
      if (sortOrder == null) {
        final maxOrderResult = await _supabase
            .from('categories')
            .select('sort_order')
            .order('sort_order', ascending: false)
            .limit(1)
            .maybeSingle();
        
        sortOrder = (maxOrderResult?['sort_order'] as int? ?? 0) + 1;
      }

      final response = await _supabase
          .from('categories')
          .insert({
            'name': name,
            'description': description,
            'icon_url': iconUrl,
            'sort_order': sortOrder,
            'is_active': isActive,
          })
          .select()
          .single();

      return response;
    } catch (e) {
      throw Exception('Ralat menambah kategori: $e');
    }
  }

  /// Update kategori
  Future<Map<String, dynamic>> updateCategory({
    required String categoryId,
    String? name,
    String? description,
    String? iconUrl,
    int? sortOrder,
    bool? isActive,
  }) async {
    try {
      // Check kategori exists
      final existing = await _supabase
          .from('categories')
          .select('id, name')
          .eq('id', categoryId)
          .maybeSingle();

      if (existing == null) {
        throw Exception('Kategori tidak dijumpai');
      }

      // Validasi nama unik jika nama berubah
      if (name != null && name != existing['name']) {
        final nameCheck = await _supabase
            .from('categories')
            .select('id')
            .eq('name', name)
            .neq('id', categoryId)
            .maybeSingle();

        if (nameCheck != null) {
          throw Exception('Nama kategori sudah wujud');
        }
      }

      final updateData = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (name != null) updateData['name'] = name;
      if (description != null) updateData['description'] = description;
      if (iconUrl != null) updateData['icon_url'] = iconUrl;
      if (sortOrder != null) updateData['sort_order'] = sortOrder;
      if (isActive != null) updateData['is_active'] = isActive;

      final response = await _supabase
          .from('categories')
          .update(updateData)
          .eq('id', categoryId)
          .select()
          .single();

      return response;
    } catch (e) {
      throw Exception('Ralat mengupdate kategori: $e');
    }
  }

  /// Padam kategori
  Future<void> deleteCategory(String categoryId) async {
    try {
      // Check jika kategori mempunyai kitab
      final kitabData = await _supabase
          .from('kitab')
          .select('id')
          .eq('category_id', categoryId);

      if (kitabData.isNotEmpty) {
        throw Exception('Kategori tidak boleh dipadam kerana masih mempunyai kitab');
      }

      await _supabase
          .from('categories')
          .delete()
          .eq('id', categoryId);
    } catch (e) {
      throw Exception('Ralat memadam kategori: $e');
    }
  }

  /// Tukar status aktif kategori
  Future<Map<String, dynamic>> toggleCategoryStatus(String categoryId) async {
    try {
      final category = await _supabase
          .from('categories')
          .select('is_active')
          .eq('id', categoryId)
          .single();

      final newStatus = !(category['is_active'] as bool? ?? false);

      final response = await _supabase
          .from('categories')
          .update({
            'is_active': newStatus,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', categoryId)
          .select()
          .single();

      return response;
    } catch (e) {
      throw Exception('Ralat menukar status kategori: $e');
    }
  }

  /// Reorder kategori (drag & drop)
  Future<void> reorderCategories(List<String> categoryIds) async {
    try {
      final batch = <Map<String, dynamic>>[];
      
      for (int i = 0; i < categoryIds.length; i++) {
        batch.add({
          'id': categoryIds[i],
          'sort_order': i + 1,
          'updated_at': DateTime.now().toIso8601String(),
        });
      }

      await _supabase
          .from('categories')
          .upsert(batch);
    } catch (e) {
      throw Exception('Ralat menyusun semula kategori: $e');
    }
  }

  /// Dapatkan statistik kategori
  Future<Map<String, int>> getCategoryStats() async {
    try {
      // Total kategori
      final totalData = await _supabase
          .from('categories')
          .select('id');

      // Kategori aktif
      final activeData = await _supabase
          .from('categories')
          .select('id')
          .eq('is_active', true);

      // Kategori dengan kitab (optional - fallback jika RPC tak wujud)
      int categoriesWithKitab = 0;
      try {
        final withKitabResponse = await _supabase.rpc('get_categories_with_kitab_count');
        categoriesWithKitab = withKitabResponse?.length ?? 0;
      } catch (e) {
        // Fallback calculation
        final categoriesWithKitabData = await _supabase
            .from('categories')
            .select('id')
            .neq('id', 'null'); // Just to get structure, akan filter dalam app
        categoriesWithKitab = categoriesWithKitabData.length;
      }

      final totalCount = totalData.length;
      final activeCount = activeData.length;

      return {
        'total_categories': totalCount,
        'active_categories': activeCount,
        'inactive_categories': totalCount - activeCount,
        'categories_with_kitab': categoriesWithKitab,
      };
    } catch (e) {
      throw Exception('Ralat mendapatkan statistik kategori: $e');
    }
  }

  /// Upload icon kategori
  Future<String> uploadCategoryIcon(File imageFile, String categoryId) async {
    try {
      final fileExt = imageFile.path.split('.').last.toLowerCase();
      final fileName = 'category_${categoryId}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = 'category-icons/$fileName';

      // Validate file type
      if (!['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(fileExt)) {
        throw Exception('Format fail tidak disokong. Gunakan JPG, PNG, GIF atau WebP');
      }

      // Validate file size (max 5MB)
      final fileSize = await imageFile.length();
      if (fileSize > 5 * 1024 * 1024) {
        throw Exception('Saiz fail terlalu besar. Maksimum 5MB');
      }

      // Upload to Supabase Storage
      await _supabase.storage
          .from('public')
          .upload(filePath, imageFile);

      // Get public URL
      final iconUrl = _supabase.storage
          .from('public')
          .getPublicUrl(filePath);

      return iconUrl;
    } catch (e) {
      throw Exception('Ralat upload icon: $e');
    }
  }

  /// Padam icon kategori lama dari storage
  Future<void> deleteOldIcon(String? iconUrl) async {
    if (iconUrl == null || iconUrl.isEmpty) return;

    try {
      // Extract file path dari URL
      final uri = Uri.parse(iconUrl);
      final pathSegments = uri.pathSegments;
      
      // Cari path selepas 'public'
      int publicIndex = pathSegments.indexOf('public');
      if (publicIndex != -1 && publicIndex < pathSegments.length - 1) {
        final filePath = pathSegments.sublist(publicIndex + 1).join('/');
        
        await _supabase.storage
            .from('public')
            .remove([filePath]);
      }
    } catch (e) {
      // Log error tapi jangan throw - ini bukan critical
      // Debug logging removed
    }
  }
}
