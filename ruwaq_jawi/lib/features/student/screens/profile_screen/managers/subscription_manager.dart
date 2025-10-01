import 'package:flutter/material.dart';
import '../../../../../core/services/supabase_service.dart';

class SubscriptionManager {
  final VoidCallback onStateChanged;
  Map<String, dynamic>? currentSubscription;
  bool isLoadingSubscription = true;

  SubscriptionManager({required this.onStateChanged});

  Future<void> loadCurrentSubscription() async {
    try {
      final user = SupabaseService.currentUser;
      if (user != null) {
        final response = await SupabaseService.from('user_subscriptions')
            .select('*, subscription_plans(*)')
            .eq('user_id', user.id)
            .eq('status', 'active')
            .gte('end_date', DateTime.now().toIso8601String())
            .order('end_date', ascending: false)
            .limit(1)
            .maybeSingle();

        currentSubscription = response;
        isLoadingSubscription = false;
        onStateChanged();
      } else {
        currentSubscription = null;
        isLoadingSubscription = false;
        onStateChanged();
      }
    } catch (e) {
      debugPrint('Error loading subscription: $e');
      currentSubscription = null;
      isLoadingSubscription = false;
      onStateChanged();
    }
  }
}