import 'package:flutter/widgets.dart';
import 'package:flutter/scheduler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';
import '../services/supabase_service.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthProvider extends ChangeNotifier {
  AuthStatus _status = AuthStatus.initial;
  UserProfile? _userProfile;
  String? _errorMessage;
  User? _user;

  AuthStatus get status => _status;
  UserProfile? get userProfile => _userProfile;
  String? get errorMessage => _errorMessage;
  User? get user => _user;
  String? get currentUserId => _user?.id;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isAdmin => _userProfile?.isAdmin ?? false;
  bool get hasActiveSubscription =>
      _userProfile?.hasActiveSubscription ?? false;

  // Check subscription from database and update profile status
  Future<bool> checkActiveSubscription() async {
    if (_user == null) return false;
    
    try {
      final now = DateTime.now().toUtc();
      print('AuthProvider: Checking subscription for user: ${_user!.id}');
      
      final response = await SupabaseService.from('subscriptions')
          .select()
          .eq('user_id', _user!.id)
          .eq('status', 'active')
          .lte('current_period_start', now.toIso8601String())
          .gte('current_period_end', now.toIso8601String())
          .maybeSingle();
      
      final hasActive = response != null;
      print('AuthProvider: Active subscription found: $hasActive');
      
      // Update profile status based on subscription
      if (hasActive) {
        final currentProfileStatus = _userProfile?.subscriptionStatus;
        if (currentProfileStatus != 'active') {
          print('AuthProvider: Updating profile status to active');
          await _updateProfileSubscriptionStatus('active');
        }
      } else {
        // Check if subscription exists but is expired
        final expiredSub = await SupabaseService.from('subscriptions')
            .select()
            .eq('user_id', _user!.id)
            .lt('current_period_end', now.toIso8601String())
            .maybeSingle();
            
        if (expiredSub != null) {
          print('AuthProvider: Found expired subscription, updating profile status');
          await _updateProfileSubscriptionStatus('expired');
        } else {
          // No subscription found at all
          await _updateProfileSubscriptionStatus('inactive');
        }
      }
      
      return hasActive;
    } catch (e) {
      print('AuthProvider: Error checking subscription: $e');
      return false;
    }
  }
  
  Future<void> _updateProfileSubscriptionStatus(String status) async {
    if (_user == null) return;
    
    try {
      await SupabaseService.from('profiles')
          .update({
            'subscription_status': status,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', _user!.id);
      
      // Update local profile without causing infinite loop
      if (_userProfile != null) {
        _userProfile = _userProfile!.copyWith(subscriptionStatus: status);
        notifyListeners();
      }
    } catch (e) {
      print('Error updating profile subscription status: $e');
    }
  }

  void _setStatus(AuthStatus status) {
    _status = status;
    notifyListeners();
  }

  void resetToInitial() {
    _status = AuthStatus.initial;
    _errorMessage = null;
    notifyListeners();
  }

  void _scheduleStatus(AuthStatus status) {
    // Jika sedang dalam fasa build/scheduler, tangguh ke selepas frame.
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle) {
      _setStatus(status);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _setStatus(status);
      });
    }
  }

  void _setError(String message) {
    _errorMessage = message;
    _scheduleStatus(AuthStatus.unauthenticated);
  }

  void clearError() {
    _errorMessage = null;
    // Gunakan _scheduleStatus untuk konsisten
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  Future<void> initialize() async {
    try {
      // Check if Supabase client is available
      if (!_isSupabaseReady()) {
        throw Exception('Supabase client not initialized');
      }

      // Listen to auth state changes
      SupabaseService.client.auth.onAuthStateChange.listen((data) {
        final AuthChangeEvent event = data.event;
        final Session? session = data.session;

        if (event == AuthChangeEvent.signedIn && session != null) {
          _user = session.user;
          _loadUserProfile().then((_) {
            // Check subscription after profile is loaded
            if (_userProfile != null) {
              checkActiveSubscription();
            }
          });
        } else if (event == AuthChangeEvent.signedOut) {
          _user = null;
          _userProfile = null;
          _scheduleStatus(AuthStatus.unauthenticated);
        }
      });

      // Check current user (nullable) to determine auth state
      final currentUser = SupabaseService.client.auth.currentUser;
      if (currentUser != null) {
        _user = currentUser;
        await _loadUserProfile();
        
        // Check subscription after profile is loaded
        if (_userProfile != null) {
          await checkActiveSubscription();
        }
      } else {
        _scheduleStatus(AuthStatus.unauthenticated);
      }
    } catch (e) {
      _setError('Failed to initialize authentication: ${e.toString()}');
    }
  }

  bool _isSupabaseReady() {
    try {
      // Accessing the client will throw if Supabase wasn't initialized
      SupabaseService.client;
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      if (_user == null) {
        print('DEBUG: No user found, setting unauthenticated');
        _scheduleStatus(AuthStatus.unauthenticated);
        return;
      }

      print('DEBUG: Loading profile for user: ${_user!.id}');

      final response = await SupabaseService.from('profiles')
          .select()
          .eq('id', _user!.id)
          .single()
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Timeout loading user profile');
            },
          );

      print('DEBUG: Profile loaded successfully');
      _userProfile = UserProfile.fromJson(response);
      
      _scheduleStatus(AuthStatus.authenticated);
    } catch (e) {
      print('DEBUG: Profile load error: $e');
      
      // If profile doesn't exist, create it first
      if (e.toString().contains('No rows returned') || 
          e.toString().contains('PGRST116')) {
        print('DEBUG: Profile not found, creating new profile');
        try {
          await _createUserProfile();
          return;
        } catch (createError) {
          print('DEBUG: Profile creation failed: $createError');
          _setError('Failed to create user profile: ${createError.toString()}');
          return;
        }
      }
      
      print('DEBUG: Setting error and unauthenticated status');
      _setError('Failed to load user profile: ${e.toString()}');
    }
  }

  Future<void> _createUserProfile() async {
    if (_user == null) return;
    
    try {
      print('DEBUG: Creating profile for user: ${_user!.id}');
      
      // Get user metadata
      final fullName = _user!.userMetadata?['full_name'] as String? ?? 
                      _user!.email?.split('@').first ?? 'User';
      
      print('DEBUG: Profile data - fullName: $fullName');
      
      // Create profile
      await SupabaseService.from('profiles').insert({
        'id': _user!.id,
        'full_name': fullName,
        'role': 'student',
        'subscription_status': 'inactive',
      });
      
      print('DEBUG: Profile created, loading profile...');
      
      // Load the newly created profile
      await _loadUserProfile();
    } catch (e) {
      print('DEBUG: Profile creation error: $e');
      throw Exception('Profile creation failed: ${e.toString()}');
    }
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      _scheduleStatus(AuthStatus.loading);
      clearError();

      final response = await SupabaseService.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName},
      );

      if (response.user != null) {
        _user = response.user;

        // Always require email verification - don't auto-login
        if (response.session != null) {
          // Sign out immediately to prevent auto-login
          await SupabaseService.signOut();
          _user = null;
        }

        // Always require email verification
        _scheduleStatus(AuthStatus.unauthenticated);
        _setError(
          'Pautan pengesahan telah dihantar ke e-mel anda. Sila sahkan untuk log masuk.',
        );
        return true;
      }

      _setError('Failed to create account');
      return false;
    } catch (e) {
      _setError('Sign up failed: ${e.toString()}');
      return false;
    }
  }

  Future<bool> signIn({required String email, required String password}) async {
    try {
      _scheduleStatus(AuthStatus.loading);
      clearError();

      print('DEBUG: Starting sign in for $email');

      final response = await SupabaseService.signIn(
        email: email,
        password: password,
      );

      print('DEBUG: Sign in response received, user: ${response.user?.id}');

      if (response.user != null) {
        _user = response.user;
        print('DEBUG: Loading user profile...');
        await _loadUserProfile();
        
        // Check subscription after profile is loaded
        if (_userProfile != null) {
          await checkActiveSubscription();
        }
        
        print('DEBUG: Sign in completed successfully');
        return true;
      } else {
        print('DEBUG: Sign in failed - no user returned');
        _setError('Invalid email or password');
        return false;
      }
    } catch (e) {
      print('DEBUG: Sign in error: $e');
      _setError(_getSignInErrorMessage(e));
      return false;
    }
  }

  String _getSignInErrorMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();
    
    // Connection related errors
    if (errorString.contains('socketexception') || 
        errorString.contains('failed host lookup') ||
        errorString.contains('no address associated with hostname') ||
        errorString.contains('network is unreachable') ||
        errorString.contains('connection refused') ||
        errorString.contains('connection timed out')) {
      return 'Tiada sambungan internet. Sila semak sambungan anda dan cuba lagi.';
    }
    
    // Authentication specific errors
    if (errorString.contains('invalid_grant') ||
        errorString.contains('invalid credentials') ||
        errorString.contains('email not confirmed') ||
        errorString.contains('invalid login credentials')) {
      return 'Email atau kata laluan tidak sah. Sila semak dan cuba lagi.';
    }
    
    // Rate limiting
    if (errorString.contains('too many requests') || errorString.contains('rate limit')) {
      return 'Terlalu banyak percubaan. Sila tunggu sebentar sebelum cuba lagi.';
    }
    
    // Server errors
    if (errorString.contains('500') || errorString.contains('internal server error')) {
      return 'Pelayan mengalami masalah. Sila cuba lagi dalam beberapa minit.';
    }
    
    // Timeout errors
    if (errorString.contains('timeout')) {
      return 'Permintaan mengambil masa terlalu lama. Sila cuba lagi.';
    }
    
    // Generic network error
    if (errorString.contains('clientexception') || errorString.contains('httperror')) {
      return 'Masalah sambungan rangkaian. Sila semak sambungan internet anda.';
    }
    
    // Default fallback
    return 'Ralat log masuk. Sila semak maklumat anda dan cuba lagi.';
  }

  Future<bool> resetPassword(String email) async {
    try {
      clearError();
      await SupabaseService.resetPassword(email);
      return true;
    } catch (e) {
      _setError(_getSignInErrorMessage(e));
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      await SupabaseService.signOut();
      _user = null;
      _userProfile = null;
      _scheduleStatus(AuthStatus.unauthenticated);
    } catch (e) {
      _setError('Sign out failed: ${e.toString()}');
    }
  }

  Future<bool> updateProfile({String? fullName}) async {
    try {
      if (_user == null || _userProfile == null) return false;

      clearError();

      final updates = <String, dynamic>{};
      if (fullName != null) updates['full_name'] = fullName;

      if (updates.isNotEmpty) {
        updates['updated_at'] = DateTime.now().toIso8601String();

        await SupabaseService.from(
          'profiles',
        ).update(updates).eq('id', _user!.id);

        await _loadUserProfile();
      }

      return true;
    } catch (e) {
      _setError('Profile update failed: ${e.toString()}');
      return false;
    }
  }
  
  // Force refresh subscription status
  Future<void> refreshSubscriptionStatus() async {
    if (_user != null) {
      await checkActiveSubscription();
    }
  }
  
  // Change user password
  Future<bool> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      if (_user == null) {
        _setError('User not authenticated');
        return false;
      }
      
      clearError();
      
      // First verify the old password by attempting to sign in
      final email = _user!.email;
      if (email == null) {
        _setError('User email not found');
        return false;
      }
      
      try {
        // Verify old password by attempting sign in
        await SupabaseService.signIn(
          email: email,
          password: oldPassword,
        );
      } catch (e) {
        _setError('Kata laluan lama tidak betul');
        return false;
      }
      
      // Update password using Supabase auth
      await SupabaseService.client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      
      return true;
    } catch (e) {
      print('Change password error: $e');
      if (e.toString().contains('Same password')) {
        _setError('Kata laluan baru mestilah berbeza daripada kata laluan lama');
      } else if (e.toString().contains('Password should be at least')) {
        _setError('Kata laluan mestilah sekurang-kurangnya 6 aksara');
      } else {
        _setError('Ralat menukar kata laluan: ${e.toString()}');
      }
      return false;
    }
  }
}
