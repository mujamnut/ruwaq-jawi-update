import 'package:supabase_flutter/supabase_flutter.dart';

class SubscriptionService {
  final SupabaseClient _supabase;

  SubscriptionService(this._supabase);

  Future<void> activateSubscription({
    required String userId,
    required String planType,
    required double amount,
    required String paymentMethod,
    required String transactionId,
  }) async {
    final now = DateTime.now().toUtc();
    int durationInDays;
    String subscriptionPlanId;

    // Set duration and plan ID based on plan type
    switch (planType) {
      case '1month':
        durationInDays = 30;
        subscriptionPlanId = amount <= 20 ? 'monthly_basic' : 'monthly_premium';
        break;
      case '3month':
        durationInDays = 90;
        subscriptionPlanId = 'quarterly_premium';
        break;
      case '6month':
        durationInDays = 180;
        subscriptionPlanId = 'semiannual_premium';
        break;
      case '12month':
        durationInDays = 365;
        subscriptionPlanId = 'yearly_premium';
        break;
      default:
        throw Exception('Invalid plan type');
    }

    try {
      // 1. Check if user already has an active subscription
      final existingSubscription = await _supabase
          .from('subscriptions')
          .select()
          .eq('user_id', userId)
          .eq('status', 'active')
          .gte('current_period_end', now.toIso8601String())  // ✅ FIXED: end_date → current_period_end
          .maybeSingle();

      DateTime endDate;
      String subscriptionId;
      
      if (existingSubscription != null) {
        // Extend existing subscription from current end date
        final currentEndDate = DateTime.parse(existingSubscription['current_period_end']); // ✅ FIXED: end_date → current_period_end
        endDate = currentEndDate.add(Duration(days: durationInDays));
        subscriptionId = existingSubscription['id'];
        
        // Update existing subscription
        await _supabase
            .from('subscriptions')
            .update({
              'current_period_end': endDate.toIso8601String(),  // ✅ FIXED: end_date → current_period_end
              'plan_id': subscriptionPlanId,                    // ✅ FIXED: plan_type → plan_id
              'amount': amount,
              'updated_at': now.toIso8601String(),
            })
            .eq('id', subscriptionId);
      } else {
        // Create new subscription
        endDate = now.add(Duration(days: durationInDays));
        
        // First, deactivate any existing subscriptions
        await _supabase
            .from('subscriptions')
            .update({'status': 'replaced'})
            .eq('user_id', userId)
            .eq('status', 'active');
        
        final subscriptionResponse = await _supabase
            .from('subscriptions')
            .insert({
              'user_id': userId,
              'plan_id': subscriptionPlanId,                    // ✅ FIXED: plan_type → plan_id
              'started_at': now.toIso8601String(),              // ✅ FIXED: start_date → started_at
              'current_period_start': now.toIso8601String(),    // ✅ NEW: Add period start
              'current_period_end': endDate.toIso8601String(),  // ✅ FIXED: end_date → current_period_end
              'status': 'active',
              'provider': paymentMethod,                        // ✅ FIXED: payment_method → provider
              'amount': amount,
              'currency': 'MYR',
              'auto_renew': false,
            })
            .select()
            .single();
        
        subscriptionId = subscriptionResponse['id'];
      }

      // 2. Create payment record (modern table)
      await _supabase.from('payments').insert({                     // ✅ FIXED: transactions → payments
        'user_id': userId,
        'subscription_id': subscriptionId,
        'amount_cents': (amount * 100).round(),                     // ✅ FIXED: amount → amount_cents
        'currency': 'MYR',
        'provider': paymentMethod,                                   // ✅ FIXED: payment_method → provider
        'provider_payment_id': transactionId,                       // ✅ FIXED: payment_reference → provider_payment_id
        'status': 'completed',
        'paid_at': now.toIso8601String(),                          // ✅ NEW: Add paid timestamp
      });

      // 3. Update user profile subscription status with end date
      await _supabase
          .from('profiles')
          .update({
            'subscription_status': 'active',
            'subscription_end_date': endDate.toIso8601String(),  // ✅ NEW: Add end date to profile
            'updated_at': now.toIso8601String(),
          })
          .eq('id', userId);
      
      print('Subscription activated successfully for user: $userId');
      print('Profile updated to active status for user: $userId');
      print('Subscription table updated (subscriptions)');
    } catch (e) {
      print('Failed to activate subscription: $e');
      throw Exception('Failed to activate subscription: $e');
    }
  }

  Future<bool> hasActiveSubscription(String userId) async {
    final now = DateTime.now().toUtc();
    
    try {
      print('Checking subscription for user: $userId at time: ${now.toIso8601String()}');
      
      final response = await _supabase
          .from('subscriptions')
          .select()
          .eq('user_id', userId)
          .eq('status', 'active')
          .lte('started_at', now.toIso8601String())
          .gte('current_period_end', now.toIso8601String())
          .maybeSingle();

      final hasActive = response != null;
      print('Active subscription found: $hasActive');
      if (response != null) {
        print('Subscription details: start=${response['start_date']}, end=${response['end_date']}');
      }
      
      // Update profile status based on subscription
      if (hasActive) {
        print('Setting profile status to active');
        await _updateProfileSubscriptionStatus(userId, 'active');
      } else {
        // Check if there are any subscriptions at all
        final anySubscription = await _supabase
            .from('subscriptions')
            .select()
            .eq('user_id', userId)
            .maybeSingle();
            
        if (anySubscription != null) {
          print('Found subscription but checking if expired: ${anySubscription['current_period_end']}');
          final endDate = DateTime.parse(anySubscription['current_period_end']);
          
          if (endDate.isBefore(now) && anySubscription['status'] == 'active') {
            print('Marking subscription as expired');
            // Mark as expired if it actually expired
            await _supabase
                .from('subscriptions')
                .update({'status': 'expired', 'updated_at': now.toIso8601String()})
                .eq('id', anySubscription['id']);
            
            await _updateProfileSubscriptionStatus(userId, 'expired');
          }
        } else {
          print('No subscriptions found for user');
          await _updateProfileSubscriptionStatus(userId, 'inactive');
        }
      }
      
      return hasActive;
    } catch (e) {
      print('Error checking subscription: $e');
      return false;
    }
  }

  Future<DateTime?> getSubscriptionEndDate(String userId) async {
    try {
      final response = await _supabase
          .from('subscriptions')
          .select('current_period_end')
          .eq('user_id', userId)
          .eq('status', 'active')
          .gte('current_period_end', DateTime.now().toUtc().toIso8601String())
          .order('current_period_end', ascending: false)
          .maybeSingle();

      if (response != null && response['current_period_end'] != null) {
        return DateTime.parse(response['current_period_end']);
      }
      return null;
    } catch (e) {
      print('Error getting subscription end date: $e');
      return null;
    }
  }
  
  Future<void> _updateProfileSubscriptionStatus(String userId, String status) async {
    try {
      await _supabase
          .from('profiles')
          .update({
            'subscription_status': status,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', userId);
    } catch (e) {
      print('Error updating profile subscription status: $e');
    }
  }
  
  Future<Map<String, dynamic>?> getUserActiveSubscription(String userId) async {
    try {
      final now = DateTime.now().toUtc();
      
      // Check user_subscriptions table only
      final subscription = await _supabase
          .from('user_subscriptions')
          .select()
          .eq('user_id', userId)
          .eq('status', 'active')
          .lte('start_date', now.toIso8601String())
          .gte('end_date', now.toIso8601String())
          .order('end_date', ascending: false)
          .maybeSingle();
          
      return subscription;
    } catch (e) {
      print('Error getting user subscription: $e');
      return null;
    }
  }
  
  /// Get user profile name for subscription records
  Future<String?> _getUserName(String userId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('full_name')
          .eq('id', userId)
          .maybeSingle();
      return response?['full_name'] as String?;
    } catch (e) {
      print('Error getting user name: $e');
      return null;
    }
  }

  /// Check if subscription is properly synced across both tables
  Future<void> syncSubscriptionTables(String userId) async {
    try {
      final now = DateTime.now().toUtc();
      
      // Check for active subscription in old table
      final oldSubscription = await _supabase
          .from('subscriptions')
          .select('*')
          .eq('user_id', userId)
          .eq('status', 'active')
          .gte('end_date', now.toIso8601String())
          .maybeSingle();

      if (oldSubscription != null) {
        // Check if it exists in new table
        final newSubscription = await _supabase
            .from('user_subscriptions')
            .select('*')
            .eq('user_id', userId)
            .eq('status', 'active')
            .maybeSingle();

        if (newSubscription == null) {
          // Sync to new table
          final userName = await _getUserName(userId);
          await _supabase.from('user_subscriptions').insert({
            'user_id': userId,
            'user_name': userName,
            'subscription_plan_id': _mapPlanTypeToId(oldSubscription['plan_type']),
            'status': 'active',
            'start_date': oldSubscription['start_date'],
            'end_date': oldSubscription['end_date'],
            'amount': oldSubscription['amount'],
            'currency': oldSubscription['currency'],
            'created_at': oldSubscription['created_at'],
            'updated_at': now.toIso8601String()
          });
          print('Synced subscription from old to new table for user: $userId');
        }
      }
    } catch (e) {
      print('Error syncing subscription tables: $e');
    }
  }

  String _mapPlanTypeToId(String planType) {
    switch (planType) {
      case '1month':
        return 'monthly_premium';  // Default to premium for existing users
      case '3month':
        return 'quarterly_premium';
      case '6month':
        return 'semiannual_premium';
      case '12month':
        return 'yearly_premium';
      default:
        return 'monthly_premium';
    }
  }
}
