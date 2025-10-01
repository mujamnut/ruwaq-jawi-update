import 'package:supabase_flutter/supabase_flutter.dart';

class ContentService {
  final SupabaseClient _supabase;
  final String _userId;

  ContentService(this._supabase, this._userId);

  Future<bool> canAccessPremiumContent() async {
    try {
      final now = DateTime.now().toUtc();
      
      // Check from user_subscriptions table for accurate status
      final response = await _supabase
          .from('user_subscriptions')
          .select()
          .eq('user_id', _userId)
          .eq('status', 'active')
          .lte('start_date', now.toIso8601String())
          .gte('end_date', now.toIso8601String())
          .maybeSingle();

      final hasActive = response != null;
      
      // Also update profile status to keep it in sync
      if (hasActive) {
        await _updateProfileStatus('active');
      } else {
        await _updateProfileStatus('inactive');
      }
      
      return hasActive;
    } catch (e) {
      print('Error checking premium access: $e');
      return false;
    }
  }
  
  Future<void> _updateProfileStatus(String status) async {
    try {
      await _supabase
          .from('profiles')
          .update({
            'subscription_status': status,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', _userId);
    } catch (e) {
      print('Error updating profile status: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getAccessibleKitab() async {
    final hasAccess = await canAccessPremiumContent();

    // For video kitabs, we now show all kitabs regardless of premium status
    // Access control is handled at the episode level
    var query = _supabase
        .from('video_kitab')
        .select('''
      id,
      title,
      author,
      description,
      category_id,
      pdf_url,
      thumbnail_url,
      is_premium,
      total_videos,
      total_duration_minutes,
      total_pages,
      youtube_playlist_id,
      youtube_playlist_url
    ''')
        .eq('is_active', true);

    final response = await query.order('title');
    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>?> getKitabDetails(String kitabId) async {
    try {
      final response = await _supabase
          .from('video_kitab')
          .select()
          .eq('id', kitabId)
          .single();

      // For video kitabs, always return full details
      // Episode-level access control is handled separately
      return response;
    } catch (e) {
      print('Error fetching kitab details: $e');
      return null;
    }
  }

  // New method to check episode access
  Future<bool> canAccessEpisode(String episodeId) async {
    try {
      final hasActiveSubscription = await canAccessPremiumContent();

      final episodeData = await _supabase
          .from('video_episodes')
          .select('is_premium, is_active')
          .eq('id', episodeId)
          .single();

      final isPremium = episodeData['is_premium'] ?? false;
      final isActive = episodeData['is_active'] ?? false;

      // Episode can be accessed if:
      // 1. Episode is active AND
      // 2. Episode is not premium OR user has active subscription
      return isActive && (!isPremium || hasActiveSubscription);
    } catch (e) {
      print('Error checking episode access: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> getSubscriptionDetails() async {
    try {
      final now = DateTime.now().toUtc();
      final response = await _supabase
          .from('user_subscriptions')
          .select()
          .eq('user_id', _userId)
          .eq('status', 'active')
          .gte('end_date', now.toIso8601String())
          .order('end_date', ascending: false)
          .maybeSingle();

      if (response == null) {
        return {'hasSubscription': false, 'endDate': null, 'planType': null};
      }

      return {
        'hasSubscription': true,
        'endDate': DateTime.parse(response['end_date']),
        'planType': response['subscription_plan_id'],
        'planName': response['subscription_plan_id'], // Can be mapped to display name if needed
      };
    } catch (e) {
      print('Error getting subscription details: $e');
      return {'hasSubscription': false, 'endDate': null, 'planType': null};
    }
  }
}
