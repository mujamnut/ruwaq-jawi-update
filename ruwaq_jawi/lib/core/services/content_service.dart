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

    var query = _supabase
        .from('kitab')
        .select('''
      id,
      title,
      author,
      description,
      category_id,
      pdf_url,
      youtube_video_id,
      youtube_video_url,
      thumbnail_url,
      is_premium,
      duration_minutes,
      total_pages
    ''')
        .eq('is_active', true);

    if (!hasAccess) {
      // If user doesn't have premium access, only return non-premium content
      query = query.eq('is_premium', false);
    }

    final response = await query.order('sort_order');
    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>?> getKitabDetails(String kitabId) async {
    final hasAccess = await canAccessPremiumContent();

    try {
      final response = await _supabase
          .from('kitab')
          .select()
          .eq('id', kitabId)
          .single();

      final isPremium = response['is_premium'] ?? false;
      if (isPremium && !hasAccess) {
        // Return basic info without sensitive URLs for premium content
        return {
          ...response,
          'pdf_url': null,
          'youtube_video_url': null,
          'requires_subscription': true,
        };
      }

      return response;
    } catch (e) {
      print('Error fetching kitab details: $e');
      return null;
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
