import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import 'auth_utils.dart';

/// Utility class for common database query patterns
class DatabaseUtils {
  /// Execute a query that requires authentication
  static Future<T> withAuth<T>(
    Future<T> Function(User user) callback,
  ) async {
    return await AuthUtils.withRequiredUserAsync(callback);
  }

  /// Get all records from a table with optional filters
  static Future<List<Map<String, dynamic>>> getAll(
    String tableName, {
    Map<String, dynamic>? filters,
    String? orderBy,
    bool ascending = true,
    int? limit,
    String select = '*',
  }) async {
    var query = SupabaseService.from(tableName).select(select);

    // Apply filters
    if (filters != null) {
      for (final entry in filters.entries) {
        query = query.eq(entry.key, entry.value);
      }
    }

    // Apply ordering
    if (orderBy != null) {
      query = query.order(orderBy, ascending: ascending) as PostgrestFilterBuilder<List<Map<String, dynamic>>>;
    }

    // Apply limit
    if (limit != null) {
      query = query.limit(limit) as PostgrestFilterBuilder<List<Map<String, dynamic>>>;
    }

    final response = await query;
    return List<Map<String, dynamic>>.from(response);
  }

  /// Get active records from a table
  static Future<List<Map<String, dynamic>>> getActive(
    String tableName, {
    String? orderBy,
    bool ascending = true,
    int? limit,
    String select = '*',
  }) async {
    return await getAll(
      tableName,
      filters: {'is_active': true},
      orderBy: orderBy,
      ascending: ascending,
      limit: limit,
      select: select,
    );
  }

  /// Get user-specific records
  static Future<List<Map<String, dynamic>>> getUserRecords(
    String tableName, {
    String userIdColumn = 'user_id',
    Map<String, dynamic>? additionalFilters,
    String? orderBy,
    bool ascending = false,
    int? limit,
    String select = '*',
  }) async {
    return await withAuth<List<Map<String, dynamic>>>((user) async {
      final filters = {userIdColumn: user.id};
      if (additionalFilters != null) {
        for (final entry in additionalFilters.entries) {
          filters[entry.key] = entry.value;
        }
      }

      return await getAll(
        tableName,
        filters: filters,
        orderBy: orderBy ?? 'created_at',
        ascending: ascending,
        limit: limit,
        select: select,
      );
    });
  }

  /// Get single record by ID
  static Future<Map<String, dynamic>?> getById(
    String tableName,
    String id, {
    String idColumn = 'id',
    String select = '*',
  }) async {
    try {
      final response = await SupabaseService.from(tableName)
          .select(select)
          .eq(idColumn, id)
          .single();
      return response;
    } catch (e) {
      return null;
    }
  }

  /// Check if record exists
  static Future<bool> exists(
    String tableName,
    String id, {
    String idColumn = 'id',
  }) async {
    try {
      await SupabaseService.from(tableName)
          .select('id')
          .eq(idColumn, id)
          .single();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Insert record
  static Future<Map<String, dynamic>> insert(
    String tableName,
    Map<String, dynamic> data,
  ) async {
    final response = await SupabaseService.from(tableName)
        .insert(data)
        .select()
        .single();
    return response;
  }

  /// Update record
  static Future<Map<String, dynamic>> update(
    String tableName,
    String id,
    Map<String, dynamic> data, {
    String idColumn = 'id',
  }) async {
    final response = await SupabaseService.from(tableName)
        .update(data)
        .eq(idColumn, id)
        .select()
        .single();
    return response;
  }

  /// Delete record
  static Future<void> delete(
    String tableName,
    String id, {
    String idColumn = 'id',
  }) async {
    await SupabaseService.from(tableName)
        .delete()
        .eq(idColumn, id);
  }

  /// Upsert (insert or update) record
  static Future<Map<String, dynamic>> upsert(
    String tableName,
    Map<String, dynamic> data,
  ) async {
    final response = await SupabaseService.from(tableName)
        .upsert(data)
        .select()
        .single();
    return response;
  }

  /// Get count of records
  static Future<int> getCount(
    String tableName, {
    Map<String, dynamic>? filters,
  }) async {
    var query = SupabaseService.from(tableName)
        .select('*');

    // Apply filters
    if (filters != null) {
      for (final entry in filters.entries) {
        query = query.eq(entry.key, entry.value);
      }
    }

    final response = await query;
    return (response as List).length;
  }

  /// Search records using text search
  static Future<List<Map<String, dynamic>>> search(
    String tableName,
    String query,
    List<String> searchColumns, {
    Map<String, dynamic>? filters,
    String? orderBy,
    bool ascending = true,
    int? limit,
    String select = '*',
  }) async {
    var searchQuery = SupabaseService.from(tableName).select(select);

    // Apply filters first
    if (filters != null) {
      for (final entry in filters.entries) {
        searchQuery = searchQuery.eq(entry.key, entry.value);
      }
    }

    // Build OR condition for text search
    final searchConditions = searchColumns
        .map((column) => '$column.ilike.%$query%')
        .join(',');

    searchQuery = searchQuery.or(searchConditions);

    // Apply ordering
    if (orderBy != null) {
      searchQuery = searchQuery.order(orderBy, ascending: ascending) as PostgrestFilterBuilder<List<Map<String, dynamic>>>;
    }

    // Apply limit
    if (limit != null) {
      searchQuery = searchQuery.limit(limit) as PostgrestFilterBuilder<List<Map<String, dynamic>>>;
    }

    final response = await searchQuery;
    return List<Map<String, dynamic>>.from(response);
  }

  /// Get records by date range
  static Future<List<Map<String, dynamic>>> getByDateRange(
    String tableName,
    DateTime startDate,
    DateTime endDate, {
    String dateColumn = 'created_at',
    Map<String, dynamic>? additionalFilters,
    String? orderBy,
    bool ascending = false,
    String select = '*',
  }) async {
    var query = SupabaseService.from(tableName)
        .select(select)
        .gte(dateColumn, startDate.toIso8601String())
        .lte(dateColumn, endDate.toIso8601String());

    // Apply additional filters
    if (additionalFilters != null) {
      for (final entry in additionalFilters.entries) {
        query = query.eq(entry.key, entry.value);
      }
    }

    // Apply ordering
    if (orderBy != null) {
      query = query.order(orderBy, ascending: ascending) as PostgrestFilterBuilder<List<Map<String, dynamic>>>;
    }

    final response = await query;
    return List<Map<String, dynamic>>.from(response);
  }
}