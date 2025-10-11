import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../core/models/subscription.dart';
import '../../../../../core/models/user_profile.dart';
import '../../../../../core/services/supabase_service.dart';

class AdminUsersData {
  AdminUsersData({
    required this.users,
    required this.userSubscriptions,
  });

  final List<UserProfile> users;
  final Map<String, Subscription?> userSubscriptions;
}

class AdminUsersDataManager {
  static const _usersCacheKey = 'cached_admin_users';
  static const _subscriptionsCacheKey = 'cached_user_subscriptions';

  Future<bool> isUserAdmin(String userId) async {
    try {
      final profile = await SupabaseService.from('profiles')
          .select('role')
          .eq('id', userId)
          .maybeSingle();

      return profile != null && profile['role'] == 'admin';
    } catch (_) {
      return false;
    }
  }

  Future<AdminUsersData?> loadCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedUsers = prefs.getString(_usersCacheKey);
      final cachedSubscriptions = prefs.getString(_subscriptionsCacheKey);

      if (cachedUsers == null || cachedSubscriptions == null) {
        return null;
      }

      final usersJson = jsonDecode(cachedUsers) as List<dynamic>;
      final subscriptionsJson = jsonDecode(cachedSubscriptions) as Map<String, dynamic>;

      final users = usersJson
          .map((json) => UserProfile.fromJson(json as Map<String, dynamic>))
          .toList();

      final subscriptions = <String, Subscription?>{};
      subscriptionsJson.forEach((key, value) {
        subscriptions[key] = value != null
            ? Subscription.fromJson(value as Map<String, dynamic>)
            : null;
      });

      return AdminUsersData(users: users, userSubscriptions: subscriptions);
    } catch (_) {
      return null;
    }
  }

  Future<void> cacheData(AdminUsersData data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final usersJson = data.users.map((user) => user.toJson()).toList();
      final subscriptionsJson = <String, dynamic>{};

      data.userSubscriptions.forEach((key, value) {
        subscriptionsJson[key] = value?.toJson();
      });

      await prefs.setString(_usersCacheKey, jsonEncode(usersJson));
      await prefs.setString(_subscriptionsCacheKey, jsonEncode(subscriptionsJson));
    } catch (_) {
      // Best effort caching
    }
  }

  Future<AdminUsersData> fetchUsersData() async {
    List<dynamic> usersResponse = const [];
    try {
      final dynamic rpcResponse =
          await SupabaseService.client.rpc('get_all_profiles_with_email');

      final dynamic payload = rpcResponse is List
          ? rpcResponse
          : (rpcResponse?.data ?? rpcResponse);

      if (payload is List) {
        usersResponse = payload;
      } else {
        throw const FormatException('Invalid RPC response format');
      }
    } catch (e) {
      final profilesResponse = await SupabaseService.from('profiles')
          .select()
          .order('created_at', ascending: false);

      usersResponse = (profilesResponse as List).map((json) {
        final updatedJson =
            Map<String, dynamic>.from(json as Map<String, dynamic>);
        updatedJson['email'] =
            '${json['full_name']?.toString().toLowerCase().replaceAll(' ', '')}@domain.com';
        return updatedJson;
      }).toList();
    }

    final users = usersResponse
        .map((json) => UserProfile.fromJson(Map<String, dynamic>.from(
            json as Map<String, dynamic>)))
        .toList();

    final subscriptionsResponse = await SupabaseService.from('user_subscriptions')
        .select('*, subscription_plans!inner(name, price, duration_days)')
        .eq('status', 'active')
        .gt('end_date', DateTime.now().toUtc().toIso8601String());

    final subscriptions = (subscriptionsResponse as List)
        .map((json) => Subscription.fromJson(
            Map<String, dynamic>.from(json as Map<String, dynamic>)))
        .toList();

    final userSubscriptionMap = <String, Subscription?>{};
    for (final user in users) {
      Subscription? matched;
      for (final subscription in subscriptions) {
        if (subscription.userId == user.id) {
          matched = subscription;
          break;
        }
      }
      userSubscriptionMap[user.id] = matched;
    }

    return AdminUsersData(
      users: users,
      userSubscriptions: userSubscriptionMap,
    );
  }
}
