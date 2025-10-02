import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/scheduler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';
import '../services/supabase_service.dart';
import '../services/enhanced_notification_service.dart';
import '../services/local_favorites_service.dart';

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
      if (kDebugMode) {
        print('AuthProvider: Checking subscription for user: ${_user!.id}');
      }

      final response = await SupabaseService.from('user_subscriptions')
          .select()
          .eq('user_id', _user!.id)
          .eq('status', 'active')
          .lte('start_date', now.toIso8601String())
          .gte('end_date', now.toIso8601String())
          .maybeSingle();

      final hasActive = response != null;
      if (kDebugMode) {
        print('AuthProvider: Active subscription found: $hasActive');
      }

      // Update profile status based on subscription
      if (hasActive) {
        final currentProfileStatus = _userProfile?.subscriptionStatus;
        if (currentProfileStatus != 'active') {
          if (kDebugMode) {
            print('AuthProvider: Updating profile status to active');
          }
          await _updateProfileSubscriptionStatus('active');
        }
      } else {
        // Check if subscription exists but is expired
        final expiredSub = await SupabaseService.from('user_subscriptions')
            .select()
            .eq('user_id', _user!.id)
            .lt('end_date', now.toIso8601String())
            .maybeSingle();

        if (expiredSub != null) {
          if (kDebugMode) {
            print(
              'AuthProvider: Found expired subscription, updating profile status',
            );
          }
          await _updateProfileSubscriptionStatus('expired');
        } else {
          // No subscription found at all
          await _updateProfileSubscriptionStatus('inactive');
        }
      }

      return hasActive;
    } catch (e) {
      if (kDebugMode) {
        print('AuthProvider: Error checking subscription: $e');
      }
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
      if (kDebugMode) {
        print('Error updating profile subscription status: $e');
      }
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
          // Check if email is confirmed before allowing sign in
          if (session.user.emailConfirmedAt == null) {
            if (kDebugMode) {
              print(
                'DEBUG: User signed in but email not confirmed, signing out',
              );
            }
            // Sign out immediately if email not confirmed
            SupabaseService.signOut();
            return;
          }

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
        // Check if email is confirmed
        if (currentUser.emailConfirmedAt == null) {
          if (kDebugMode) {
            print('DEBUG: User email not confirmed, signing out');
          }
          // Sign out unverified users
          await SupabaseService.signOut();
          _user = null;
          _userProfile = null;
          _scheduleStatus(AuthStatus.unauthenticated);
          return;
        }

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
        if (kDebugMode) {
          print('DEBUG: No user found, setting unauthenticated');
        }
        _scheduleStatus(AuthStatus.unauthenticated);
        return;
      }

      if (kDebugMode) {
        print('DEBUG: Loading profile for user: ${_user!.id}');
      }

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

      if (kDebugMode) {
        print('DEBUG: Profile loaded successfully');
      }
      _userProfile = UserProfile.fromJson(response);

      // Add email from auth user if not in profile
      if (_userProfile != null && _user != null && _userProfile!.email == null) {
        _userProfile = UserProfile(
          id: _userProfile!.id,
          fullName: _userProfile!.fullName,
          email: _user!.email,
          role: _userProfile!.role,
          subscriptionStatus: _userProfile!.subscriptionStatus,
          phoneNumber: _userProfile!.phoneNumber,
          avatarUrl: _userProfile!.avatarUrl,
          subscriptionEndDate: _userProfile!.subscriptionEndDate,
          createdAt: _userProfile!.createdAt,
          updatedAt: _userProfile!.updatedAt,
        );
      }

      _scheduleStatus(AuthStatus.authenticated);
    } catch (e) {
      if (kDebugMode) {
        print('DEBUG: Profile load error: $e');
      }

      // If profile doesn't exist, create it first
      if (e.toString().contains('No rows returned') ||
          e.toString().contains('PGRST116')) {
        if (kDebugMode) {
          print('DEBUG: Profile not found, creating new profile');
        }
        try {
          await _createUserProfile();
          return;
        } catch (createError) {
          if (kDebugMode) {
            print('DEBUG: Profile creation failed: $createError');
          }
          _setError('Failed to create user profile: ${createError.toString()}');
          return;
        }
      }

      if (kDebugMode) {
        print('DEBUG: Setting error and unauthenticated status');
      }
      _setError('Failed to load user profile: ${e.toString()}');
    }
  }

  Future<void> _createUserProfile() async {
    if (_user == null) return;

    try {
      if (kDebugMode) {
        print('DEBUG: Creating profile for user: ${_user!.id}');
      }

      // Get user metadata
      final fullName =
          _user!.userMetadata?['full_name'] as String? ??
          _user!.email?.split('@').first ??
          'User';

      if (kDebugMode) {
        print('DEBUG: Profile data - fullName: $fullName');
      }

      // Create profile
      await SupabaseService.from('profiles').insert({
        'id': _user!.id,
        'full_name': fullName,
        'role': 'student',
        'subscription_status': 'inactive',
      });

      if (kDebugMode) {
        print('DEBUG: Profile created, loading profile...');
      }

      // Load the newly created profile
      await _loadUserProfile();

      // Send welcome notification for new user
      if (_userProfile != null) {
        await _sendWelcomeNotification();
      }
    } catch (e) {
      if (kDebugMode) {
        print('DEBUG: Profile creation error: $e');
      }
      throw Exception('Profile creation failed: ${e.toString()}');
    }
  }

  Future<void> _sendWelcomeNotification() async {
    if (_user == null || _userProfile == null) return;

    try {
      if (kDebugMode) {
        print('🎉 Sending welcome notification to new user: ${_user!.id}');
      }

      final notificationSuccess =
          await EnhancedNotificationService.createPersonalNotification(
            userId: _user!.id,
            title: 'Selamat Datang ke Maktabah Ruwaq Jawi! 👋',
            message:
                'Terima kasih kerana menyertai kami, ${_userProfile!.fullName}! Jelajahi koleksi kitab, video pembelajaran dan banyak lagi. Mula pembelajaran Islam anda hari ini.',
            metadata: {
              'type': 'welcome',
              'sub_type': 'welcome',
              'icon': '👋',
              'priority': 'high',
              'action_url': '/home',
              'source': 'auth_provider',
              'user_registration_date': DateTime.now().toIso8601String(),
              'welcome_message': true,
            },
          );

      if (notificationSuccess) {
        if (kDebugMode) {
          print(
            '✅ Welcome notification sent successfully to ${_userProfile!.fullName}',
          );
        }
      } else {
        if (kDebugMode) {
          print('❌ Failed to send welcome notification to user: ${_user!.id}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error sending welcome notification: $e');
      }
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

      // Duplicate email will be caught by Supabase signUp AuthException
      // We'll handle it in the catch block below

      if (kDebugMode) {
        print('DEBUG: Starting signUp process for $email');
      }

      // First check if user already exists by trying a magic link with shouldCreateUser: false
      try {
        if (kDebugMode) {
          print('DEBUG: Checking if user already exists');
        }

        await SupabaseService.client.auth
            .signInWithOtp(
              email: email,
              shouldCreateUser: false, // Don't create if doesn't exist
            );

        // If we get here without exception, user exists
        if (kDebugMode) {
          print('DEBUG: User already exists, signup blocked');
        }
        _setError(
          'Email sudah terdaftar. Sila guna email lain atau log masuk.',
        );
        _scheduleStatus(AuthStatus.unauthenticated);
        return false;
      } on AuthException catch (e) {
        // Check if error indicates user doesn't exist
        if (e.message.toLowerCase().contains('user not found') ||
            e.message.toLowerCase().contains('invalid credentials') ||
            e.message.toLowerCase().contains('signup disabled') ||
            e.statusCode == '400') {
          // User doesn't exist, continue with signup
          if (kDebugMode) {
            print(
              'DEBUG: User does not exist, proceeding with signup: ${e.message}',
            );
          }
        } else {
          // Some other error, rethrow
          rethrow;
        }
      } catch (e) {
        // User doesn't exist, continue with signup
        if (kDebugMode) {
          print(
            'DEBUG: User does not exist (generic error), proceeding with signup: $e',
          );
        }
      }

      final response = await SupabaseService.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName},
      );

      if (kDebugMode) {
        print(
          'DEBUG: SignUp response - user: ${response.user?.id}, session: ${response.session?.accessToken != null}',
        );
      }

      if (response.user != null) {
        _user = response.user;

        // Check if this is actually a new user or existing user
        if (response.user!.emailConfirmedAt != null) {
          // User already exists and is confirmed - this shouldn't happen for new signups
          if (kDebugMode) {
            print(
              'DEBUG: User already exists and is confirmed - treating as duplicate',
            );
          }
          _setError(
            'Email sudah terdaftar. Sila guna email lain atau log masuk.',
          );
          _scheduleStatus(AuthStatus.unauthenticated);
          return false;
        }

        // Always require email verification - don't auto-login
        if (response.session != null) {
          // Sign out immediately to prevent auto-login
          await SupabaseService.signOut();
          _user = null;
        }

        // Always require email verification - return success for OTP sent
        _scheduleStatus(AuthStatus.unauthenticated);
        clearError(); // Clear error since this is successful registration
        return true;
      }

      _setError('Failed to create account');
      return false;
    } on AuthException catch (e) {
      if (kDebugMode) {
        print('DEBUG: AuthException in signUp: ${e.message}');
        print('DEBUG: AuthException status code: ${e.statusCode}');
      }

      // Handle specific auth errors like duplicate email
      final errorMessage = e.message.toLowerCase();
      if (errorMessage.contains('already registered') ||
          errorMessage.contains('user already registered') ||
          errorMessage.contains('already been registered') ||
          errorMessage.contains('email address already in use') ||
          errorMessage.contains('duplicate') ||
          errorMessage.contains('user with this email already exists') ||
          errorMessage.contains('email already exists') ||
          errorMessage.contains('email already taken') ||
          (errorMessage.contains('email') && errorMessage.contains('taken')) ||
          (errorMessage.contains('email') && errorMessage.contains('exists')) ||
          e.statusCode == '422' || // Unprocessable Entity for duplicate email
          e.statusCode == '409') {
        // Conflict for duplicate resources
        _setError(
          'Email sudah terdaftar. Sila guna email lain atau log masuk.',
        );
      } else {
        _setError('Pendaftaran gagal: ${e.message}');
      }
      _scheduleStatus(AuthStatus.unauthenticated);
      return false;
    } catch (e) {
      _setError('Sign up failed: ${e.toString()}');
      _scheduleStatus(AuthStatus.unauthenticated);
      return false;
    }
  }

  Future<bool> signIn({required String email, required String password}) async {
    try {
      _scheduleStatus(AuthStatus.loading);
      clearError();

      if (kDebugMode) {
        print('DEBUG: Starting sign in for $email');
      }

      final response = await SupabaseService.signIn(
        email: email,
        password: password,
      );

      if (kDebugMode) {
        print('DEBUG: Sign in response received, user: ${response.user?.id}');
      }

      if (response.user != null) {
        // Check if email is confirmed
        if (response.user!.emailConfirmedAt == null) {
          if (kDebugMode) {
            print('DEBUG: User email not confirmed during sign in');
          }
          await SupabaseService.signOut(); // Sign out unverified user
          _setError(
            'Sila sahkan email anda terlebih dahulu sebelum log masuk.',
          );
          return false;
        }

        _user = response.user;
        if (kDebugMode) {
          print('DEBUG: Loading user profile...');
        }
        await _loadUserProfile();

        // Check subscription after profile is loaded
        if (_userProfile != null) {
          await checkActiveSubscription();
        }

        // Migrate local favorites to Supabase (background, non-blocking)
        _migrateFavoritesToSupabase();

        if (kDebugMode) {
          print('DEBUG: Sign in completed successfully');
        }
        return true;
      } else {
        if (kDebugMode) {
          print('DEBUG: Sign in failed - no user returned');
        }
        _setError('Invalid email or password');
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('DEBUG: Sign in error: $e');
      }
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
    if (errorString.contains('too many requests') ||
        errorString.contains('rate limit')) {
      return 'Terlalu banyak percubaan. Sila tunggu sebentar sebelum cuba lagi.';
    }

    // Server errors
    if (errorString.contains('500') ||
        errorString.contains('internal server error')) {
      return 'Pelayan mengalami masalah. Sila cuba lagi dalam beberapa minit.';
    }

    // Timeout errors
    if (errorString.contains('timeout')) {
      return 'Permintaan mengambil masa terlalu lama. Sila cuba lagi.';
    }

    // Generic network error
    if (errorString.contains('clientexception') ||
        errorString.contains('httperror')) {
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

      // Clear any cached data to free memory
      _clearUserData();
    } catch (e) {
      _setError('Sign out failed: ${e.toString()}');
    }
  }

  /// Clear user data and notify providers to clear their caches
  void _clearUserData() {
    // Reset all user-related data
    _user = null;
    _userProfile = null;

    // Note: Provider caches should be cleared by listening to auth state changes
    if (kDebugMode) {
      print('🧹 Auth provider user data cleared');
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
        await SupabaseService.signIn(email: email, password: oldPassword);
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
      if (kDebugMode) {
        print('Change password error: $e');
      }
      if (e.toString().contains('Same password')) {
        _setError(
          'Kata laluan baru mestilah berbeza daripada kata laluan lama',
        );
      } else if (e.toString().contains('Password should be at least')) {
        _setError('Kata laluan mestilah sekurang-kurangnya 6 aksara');
      } else {
        _setError('Ralat menukar kata laluan: ${e.toString()}');
      }
      return false;
    }
  }

  // ==================== FAVORITES MIGRATION ====================

  /// Migrate local favorites to Supabase (background operation)
  void _migrateFavoritesToSupabase() {
    // Run in background, don't block sign in
    Future.delayed(const Duration(seconds: 2), () async {
      try {
        await LocalFavoritesService.migrateToSupabase();
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Favorites migration failed (non-critical): $e');
        }
      }
    });
  }
}
