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
      // Get user name for subscription record
      final userName = await _getUserName(userId);

      // Calculate end date
      final endDate = now.add(Duration(days: durationInDays));

      // 1. Create/Update subscription in old table (for backward compatibility)
      final existingOldSubscription = await _supabase
          .from('subscriptions')
          .select()
          .eq('user_id', userId)
          .eq('status', 'active')
          .gte('end_date', now.toIso8601String())
          .maybeSingle();

      String subscriptionId;
      
      if (existingOldSubscription != null) {
        // Extend existing subscription
        final currentEndDate = DateTime.parse(existingOldSubscription['end_date']);
        final newEndDate = currentEndDate.add(Duration(days: durationInDays));
        subscriptionId = existingOldSubscription['id'];
        
        await _supabase
            .from('subscriptions')
            .update({
              'end_date': newEndDate.toIso8601String(),
              'plan_type': planType,
              'amount': amount,
              'updated_at': now.toIso8601String(),
            })
            .eq('id', subscriptionId);
      } else {
        // Deactivate existing subscriptions
        await _supabase
            .from('subscriptions')
            .update({'status': 'replaced'})
            .eq('user_id', userId)
            .eq('status', 'active');
        
        // Create new subscription
        final subscriptionResponse = await _supabase
            .from('subscriptions')
            .insert({
              'user_id': userId,
              'plan_type': planType,
              'start_date': now.toIso8601String(),
              'end_date': endDate.toIso8601String(),
              'status': 'active',
              'payment_method': paymentMethod,
              'amount': amount,
              'currency': 'MYR',
              'auto_renew': false,
            })
            .select()
            .single();
        
        subscriptionId = subscriptionResponse['id'];
      }

      // 2. Create/Update subscription in new table (for edge functions)
      await _supabase.from('user_subscriptions').upsert({
        'user_id': userId,
        'user_name': userName,
        'subscription_plan_id': subscriptionPlanId,
        'status': 'active',
        'start_date': now.toIso8601String(),
        'end_date': endDate.toIso8601String(),
        'payment_id': transactionId,
        'amount': amount,
        'currency': 'MYR',
        'updated_at': now.toIso8601String()
      });

      // 3. Create transaction record
      await _supabase.from('transactions').insert({
        'user_id': userId,
        'subscription_id': subscriptionId,
        'amount': amount,
        'currency': 'MYR',
        'payment_method': paymentMethod,
        'status': 'completed',
        'gateway_transaction_id': transactionId,
      });

      // 4. Update profile subscription status
      await _supabase
          .from('profiles')
          .update({
            'subscription_status': 'active',
            'updated_at': now.toIso8601String(),
          })
          .eq('id', userId);
      
      print('✅ Subscription activated successfully for user: $userId');
      print('✅ Profile updated to active status');
      print('✅ Both subscription tables updated');
      print('✅ Transaction record created');
      
    } catch (e) {
      print('❌ Failed to activate subscription: $e');
      throw Exception('Failed to activate subscription: $e');
    }
  }

  Future<bool> hasActiveSubscription(String userId) async {
    final now = DateTime.now().toUtc();
    
    try {
      print('Checking subscription for user: $userId');
      
      // Check both old and new subscription tables
      final oldSubscription = await _supabase
          .from('subscriptions')
          .select()
          .eq('user_id', userId)
          .eq('status', 'active')
          .lte('start_date', now.toIso8601String())
          .gte('end_date', now.toIso8601String())
          .maybeSingle();

      final newSubscription = await _supabase
          .from('user_subscriptions')
          .select()
          .eq('user_id', userId)
          .eq('status', 'active')
          .lte('start_date', now.toIso8601String())
          .gte('end_date', now.toIso8601String())
          .maybeSingle();

      final hasActive = oldSubscription != null || newSubscription != null;
      print('Active subscription found: $hasActive');
      
      if (hasActive) {
        await _updateProfileSubscriptionStatus(userId, 'active');
      } else {
        // Check for expired subscriptions
        await _checkAndUpdateExpiredSubscriptions(userId);
      }
      
      return hasActive;
    } catch (e) {
      print('Error checking subscription: $e');
      return false;
    }
  }

  Future<DateTime?> getSubscriptionEndDate(String userId) async {
    try {
      // Check both tables and return the latest end date
      final oldSub = await _supabase
          .from('subscriptions')
          .select('end_date')
          .eq('user_id', userId)
          .eq('status', 'active')
          .order('end_date', ascending: false)
          .maybeSingle();

      final newSub = await _supabase
          .from('user_subscriptions')
          .select('end_date')
          .eq('user_id', userId)
          .eq('status', 'active')
          .order('end_date', ascending: false)
          .maybeSingle();

      DateTime? oldEndDate = oldSub != null ? DateTime.parse(oldSub['end_date']) : null;
      DateTime? newEndDate = newSub != null ? DateTime.parse(newSub['end_date']) : null;

      if (oldEndDate != null && newEndDate != null) {
        return oldEndDate.isAfter(newEndDate) ? oldEndDate : newEndDate;
      }
      return oldEndDate ?? newEndDate;
    } catch (e) {
      print('Error getting subscription end date: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getUserActiveSubscription(String userId) async {
    try {
      final now = DateTime.now().toUtc();
      
      // Check both tables for active subscriptions
      final oldSubscription = await _supabase
          .from('subscriptions')
          .select()
          .eq('user_id', userId)
          .eq('status', 'active')
          .lte('start_date', now.toIso8601String())
          .gte('end_date', now.toIso8601String())
          .order('end_date', ascending: false)
          .maybeSingle();
          
      final newSubscription = await _supabase
          .from('user_subscriptions')
          .select()
          .eq('user_id', userId)
          .eq('status', 'active')
          .lte('start_date', now.toIso8601String())
          .gte('end_date', now.toIso8601String())
          .order('end_date', ascending: false)
          .maybeSingle();
          
      // Return the most recent one or the old one if new doesn't exist
      return newSubscription ?? oldSubscription;
    } catch (e) {
      print('Error getting user subscription: $e');
      return null;
    }
  }

  /// Sync subscription data between old and new tables
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
          print('✅ Synced subscription from old to new table for user: $userId');
        }
      }
    } catch (e) {
      print('❌ Error syncing subscription tables: $e');
    }
  }

  Future<void> _checkAndUpdateExpiredSubscriptions(String userId) async {
    final now = DateTime.now().toUtc();
    
    try {
      // Check old table
      final expiredOldSubs = await _supabase
          .from('subscriptions')
          .select()
          .eq('user_id', userId)
          .eq('status', 'active')
          .lt('end_date', now.toIso8601String());

      for (final sub in expiredOldSubs) {
        await _supabase
            .from('subscriptions')
            .update({'status': 'expired'})
            .eq('id', sub['id']);
      }

      // Check new table
      final expiredNewSubs = await _supabase
          .from('user_subscriptions')
          .select()
          .eq('user_id', userId)
          .eq('status', 'active')
          .lt('end_date', now.toIso8601String());

      for (final sub in expiredNewSubs) {
        await _supabase
            .from('user_subscriptions')
            .update({'status': 'expired'})
            .eq('id', sub['id']);
      }

      // Update profile if no active subscriptions
      if (expiredOldSubs.isNotEmpty || expiredNewSubs.isNotEmpty) {
        await _updateProfileSubscriptionStatus(userId, 'expired');
      }
    } catch (e) {
      print('Error checking expired subscriptions: $e');
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
      print('Profile subscription_status updated to: $status');
    } catch (e) {
      print('Error updating profile subscription status: $e');
    }
  }
  
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
