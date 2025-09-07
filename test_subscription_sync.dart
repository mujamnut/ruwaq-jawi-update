// Test script to check and sync subscription data
// Run this to debug subscription issues

import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  // Initialize Supabase client
  final supabase = Supabase.instance.client;

  print('🔍 Testing subscription system...\n');

  // Test user ID - replace with actual user ID from your database
  const testUserId = 'a37deced-84a8-4033-b678-abe67ba6cd7f'; // mujam user

  await testSubscriptionStatus(supabase, testUserId);
  await testSyncSubscriptionTables(supabase, testUserId);
}

Future<void> testSubscriptionStatus(
  SupabaseClient supabase,
  String userId,
) async {
  print('📊 Checking subscription status for user: $userId');

  try {
    final now = DateTime.now().toUtc();

    // Check profile status
    final profile = await supabase
        .from('profiles')
        .select('full_name, subscription_status, updated_at')
        .eq('id', userId)
        .maybeSingle();

    print(
      '👤 Profile: ${profile?['full_name']} - Status: ${profile?['subscription_status']}',
    );

    // Check old subscriptions table
    final oldSubs = await supabase
        .from('subscriptions')
        .select('*')
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    print('📊 Old subscriptions table:');
    for (final sub in oldSubs) {
      final endDate = DateTime.parse(sub['end_date']);
      final isActive = sub['status'] == 'active' && endDate.isAfter(now);
      print(
        '  - ${sub['plan_type']} | ${sub['status']} | End: ${sub['end_date']} | Active: $isActive',
      );
    }

    // Check new user_subscriptions table
    final newSubs = await supabase
        .from('user_subscriptions')
        .select('*')
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    print('📊 New user_subscriptions table:');
    for (final sub in newSubs) {
      final endDate = DateTime.parse(sub['end_date']);
      final isActive = sub['status'] == 'active' && endDate.isAfter(now);
      print(
        '  - ${sub['subscription_plan_id']} | ${sub['status']} | End: ${sub['end_date']} | Active: $isActive',
      );
    }

    // Check payments
    final payments = await supabase
        .from('payments')
        .select('*')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(5);

    print('💳 Recent payments:');
    for (final payment in payments) {
      print(
        '  - ${payment['payment_id']} | ${payment['status']} | Amount: ${payment['amount']} | Date: ${payment['created_at']}',
      );
    }
  } catch (e) {
    print('❌ Error checking subscription status: $e');
  }

  print('');
}

Future<void> testSyncSubscriptionTables(
  SupabaseClient supabase,
  String userId,
) async {
  print('🔄 Testing subscription table sync...');

  try {
    final now = DateTime.now().toUtc();

    // Check for active subscription in old table
    final oldSubscription = await supabase
        .from('subscriptions')
        .select('*')
        .eq('user_id', userId)
        .eq('status', 'active')
        .gte('end_date', now.toIso8601String())
        .maybeSingle();

    if (oldSubscription != null) {
      print('✅ Found active subscription in old table');

      // Check if it exists in new table
      final newSubscription = await supabase
          .from('user_subscriptions')
          .select('*')
          .eq('user_id', userId)
          .eq('status', 'active')
          .maybeSingle();

      if (newSubscription == null) {
        print('⚠️ Missing subscription in new table - attempting sync...');

        // Get user name
        final profile = await supabase
            .from('profiles')
            .select('full_name')
            .eq('id', userId)
            .maybeSingle();

        // Sync to new table
        final planId = mapPlanTypeToId(
          oldSubscription['plan_type'],
          oldSubscription['amount'],
        );

        final syncResult = await supabase.from('user_subscriptions').insert({
          'user_id': userId,
          'user_name': profile?['full_name'],
          'subscription_plan_id': planId,
          'status': 'active',
          'start_date': oldSubscription['start_date'],
          'end_date': oldSubscription['end_date'],
          'amount': oldSubscription['amount'],
          'currency': oldSubscription['currency'],
          'created_at': oldSubscription['created_at'],
          'updated_at': now.toIso8601String(),
        });

        if (syncResult.error != null) {
          print('❌ Error syncing: ${syncResult.error}');
        } else {
          print('✅ Successfully synced subscription to new table');
        }
      } else {
        print('✅ Subscription already exists in new table');
      }
    } else {
      print('⚠️ No active subscription found in old table');
    }
  } catch (e) {
    print('❌ Error syncing subscription tables: $e');
  }
}

String mapPlanTypeToId(String planType, double amount) {
  switch (planType) {
    case '1month':
      return amount <= 20 ? 'monthly_basic' : 'monthly_premium';
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

/*
USAGE:

1. Replace testUserId with actual user ID from your database
2. Run this script to check current subscription status
3. If there are inconsistencies, the script will attempt to sync them
4. Use the output to identify where the payment flow is breaking

COMMON ISSUES TO LOOK FOR:
- Profile subscription_status stuck on 'inactive' despite active subscription
- Missing records in user_subscriptions table
- Mismatched plan IDs between tables
- Missing payment records
*/
