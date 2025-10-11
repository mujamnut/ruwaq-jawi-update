import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ebook_rating.dart';

class EbookRatingService {
  static final _supabase = Supabase.instance.client;

  /// Get current user's rating for a specific ebook
  /// Returns null if user hasn't rated yet
  static Future<EbookRating?> getUserRating(String ebookId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        debugPrint('❌ User not authenticated');
        return null;
      }

      debugPrint('📊 Fetching user rating for ebook: $ebookId');

      final response = await _supabase
          .from('ebook_ratings')
          .select()
          .eq('ebook_id', ebookId)
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) {
        debugPrint('ℹ️ No rating found for user');
        return null;
      }

      final rating = EbookRating.fromJson(response);
      debugPrint('✅ Found user rating: ${rating.rating} stars');
      return rating;
    } catch (e) {
      debugPrint('❌ Error fetching user rating: $e');
      return null;
    }
  }

  /// Submit or update a rating for an ebook
  /// If user already rated, this will update the existing rating
  /// Returns true if successful
  static Future<bool> submitRating(
    String ebookId,
    int rating, {
    String? reviewText,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        debugPrint('❌ User not authenticated');
        return false;
      }

      if (rating < 1 || rating > 5) {
        debugPrint('❌ Invalid rating value: $rating (must be 1-5)');
        return false;
      }

      debugPrint('⭐ Submitting rating for ebook $ebookId: $rating stars');

      // Use upsert to insert or update
      await _supabase.from('ebook_ratings').upsert(
        {
          'ebook_id': ebookId,
          'user_id': userId,
          'rating': rating,
          'review_text': reviewText,
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'ebook_id,user_id', // Unique constraint columns
      );

      debugPrint('✅ Rating submitted successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Error submitting rating: $e');
      return false;
    }
  }

  /// Delete user's rating for an ebook
  /// Returns true if successful
  static Future<bool> deleteRating(String ebookId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        debugPrint('❌ User not authenticated');
        return false;
      }

      debugPrint('🗑️ Deleting rating for ebook: $ebookId');

      await _supabase
          .from('ebook_ratings')
          .delete()
          .eq('ebook_id', ebookId)
          .eq('user_id', userId);

      debugPrint('✅ Rating deleted successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting rating: $e');
      return false;
    }
  }

  /// Get all ratings for a specific ebook with pagination
  /// Returns list of ratings ordered by most recent first
  static Future<List<EbookRating>> getEbookRatings(
    String ebookId, {
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      debugPrint('📋 Fetching ratings for ebook: $ebookId (limit: $limit, offset: $offset)');

      final response = await _supabase
          .from('ebook_ratings')
          .select()
          .eq('ebook_id', ebookId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final ratings = (response as List)
          .map((json) => EbookRating.fromJson(json))
          .toList();

      debugPrint('✅ Fetched ${ratings.length} ratings');
      return ratings;
    } catch (e) {
      debugPrint('❌ Error fetching ebook ratings: $e');
      return [];
    }
  }

  /// Get rating statistics for an ebook
  /// Returns map with breakdown by star rating (1-5)
  static Future<Map<int, int>> getRatingDistribution(String ebookId) async {
    try {
      debugPrint('📊 Fetching rating distribution for ebook: $ebookId');

      final response = await _supabase
          .from('ebook_ratings')
          .select('rating')
          .eq('ebook_id', ebookId);

      // Initialize distribution map
      final distribution = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};

      // Count ratings
      for (final row in response as List) {
        final rating = row['rating'] as int;
        distribution[rating] = (distribution[rating] ?? 0) + 1;
      }

      debugPrint('✅ Rating distribution: $distribution');
      return distribution;
    } catch (e) {
      debugPrint('❌ Error fetching rating distribution: $e');
      return {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    }
  }

  /// Check if current user has rated an ebook
  /// Returns true if user has rated
  static Future<bool> hasUserRated(String ebookId) async {
    final rating = await getUserRating(ebookId);
    return rating != null;
  }
}
