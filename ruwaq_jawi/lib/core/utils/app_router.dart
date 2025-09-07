import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/auth/screens/profile_screen.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/reset_password_screen.dart';
import '../../features/auth/screens/email_verification_screen.dart';
import '../../features/auth/screens/welcome_screen.dart';
import '../../features/student/screens/student_home_screen.dart';
import '../../features/student/screens/kitab_list_screen.dart';
import '../../features/student/screens/kitab_detail_screen.dart';
import '../../features/student/screens/saved_items_screen.dart';
import '../../features/student/screens/subscription_screen.dart';
import '../../features/student/screens/video_player_screen.dart';
import '../../features/student/screens/search_screen.dart';
import '../../features/student/screens/content_player_screen.dart';
import '../../features/student/screens/ebook_screen.dart';
import '../../features/student/screens/preview_video_player_screen.dart';
import '../../features/admin/screens/admin_dashboard_screen.dart';
import '../../features/admin/screens/admin_content_enhanced.dart';
import '../../features/admin/screens/admin_search_screen.dart';
import '../../features/admin/screens/admin_users_screen.dart';
import '../../features/admin/screens/admin_user_detail_screen.dart';
import '../../features/admin/screens/admin_video_kitab_form_screen.dart';
import '../../features/admin/screens/admin_analytics_real_screen.dart';
import '../../features/admin/screens/admin_payments_screen.dart';
import '../../features/admin/screens/admin_subscriptions_screen.dart';
import '../../features/admin/screens/admin_profile_screen.dart';
import '../../features/admin/screens/pdf_viewer_screen.dart';
import '../../features/student/screens/payment_screen.dart';
import '../models/payment_models.dart';
import '../../features/admin/screens/admin_settings_screen.dart';
import '../../features/admin/screens/admin_ebook_list_screen.dart';
import '../../features/admin/screens/kitab_detail_screen.dart' as admin_kitab;
import '../../screens/payment_callback_page.dart';

class AppRouter {
  static GoRouter createRouter() {
    return GoRouter(
      initialLocation: '/',
      routes: [
        // Splash Screen Route
        GoRoute(
          path: '/',
          name: 'splash',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: const SplashScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation.drive(CurveTween(curve: Curves.easeInOut)),
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 400),
          ),
        ),

        // Authentication Routes
        GoRoute(
          path: '/login',
          name: 'login',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: const LoginScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return SlideTransition(
                position: animation.drive(
                  Tween(begin: const Offset(1.0, 0.0), end: Offset.zero).chain(
                    CurveTween(curve: Curves.easeInOutCubic),
                  ),
                ),
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 300),
          ),
        ),
        GoRoute(
          path: '/register',
          name: 'register',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: const RegisterScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return SlideTransition(
                position: animation.drive(
                  Tween(begin: const Offset(1.0, 0.0), end: Offset.zero).chain(
                    CurveTween(curve: Curves.easeInOutCubic),
                  ),
                ),
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 300),
          ),
        ),
        GoRoute(
          path: '/forgot-password',
          name: 'forgot-password',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: const ForgotPasswordScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return SlideTransition(
                position: animation.drive(
                  Tween(begin: const Offset(1.0, 0.0), end: Offset.zero).chain(
                    CurveTween(curve: Curves.easeInOutCubic),
                  ),
                ),
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 300),
          ),
        ),
        
        // Deep link auth routes
        GoRoute(
          path: '/auth/reset-password',
          name: 'reset-password',
          pageBuilder: (context, state) {
            final token = state.uri.queryParameters['token'];
            return CustomTransitionPage(
              key: state.pageKey,
              child: ResetPasswordScreen(token: token),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return SlideTransition(
                  position: animation.drive(
                    Tween(begin: const Offset(1.0, 0.0), end: Offset.zero).chain(
                      CurveTween(curve: Curves.easeInOutCubic),
                    ),
                  ),
                  child: child,
                );
              },
              transitionDuration: const Duration(milliseconds: 300),
            );
          },
        ),
        GoRoute(
          path: '/auth/verify-email',
          name: 'verify-email',
          pageBuilder: (context, state) {
            final email = state.uri.queryParameters['email'];
            final message = state.uri.queryParameters['message'];
            final token = state.uri.queryParameters['token'];
            final type = state.uri.queryParameters['type'];
            return CustomTransitionPage(
              key: state.pageKey,
              child: EmailVerificationScreen(
                email: email,
                message: message,
                token: token,
                type: type,
              ),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return SlideTransition(
                  position: animation.drive(
                    Tween(begin: const Offset(1.0, 0.0), end: Offset.zero).chain(
                      CurveTween(curve: Curves.easeInOutCubic),
                    ),
                  ),
                  child: child,
                );
              },
              transitionDuration: const Duration(milliseconds: 300),
            );
          },
        ),
        GoRoute(
          path: '/auth/welcome',
          name: 'welcome',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: const WelcomeScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return SlideTransition(
                position: animation.drive(
                  Tween(begin: const Offset(1.0, 0.0), end: Offset.zero).chain(
                    CurveTween(curve: Curves.easeInOutCubic),
                  ),
                ),
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 300),
          ),
        ),
        GoRoute(
          path: '/auth/login',
          name: 'auth-login',
          pageBuilder: (context, state) {
            return CustomTransitionPage(
              key: state.pageKey,
              child: const LoginScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return SlideTransition(
                  position: animation.drive(
                    Tween(begin: const Offset(1.0, 0.0), end: Offset.zero).chain(
                      CurveTween(curve: Curves.easeInOutCubic),
                    ),
                  ),
                  child: child,
                );
              },
              transitionDuration: const Duration(milliseconds: 300),
            );
          },
        ),

        // Student App Routes
        GoRoute(
          path: '/home',
          name: 'home',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: const StudentHomeScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return SlideTransition(
                position: animation.drive(
                  Tween(begin: const Offset(1.0, 0.0), end: Offset.zero).chain(
                    CurveTween(curve: Curves.easeInOutCubic),
                  ),
                ),
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 300),
          ),
        ),
        GoRoute(
          path: '/kitab',
          name: 'kitab-list',
          pageBuilder: (context, state) {
            final category = state.uri.queryParameters['category'];
            final sort = state.uri.queryParameters['sort'];
            return CustomTransitionPage(
              key: state.pageKey,
              child: KitabListScreen(
                initialCategory: category,
                initialSort: sort,
              ),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return SlideTransition(
                  position: animation.drive(
                    Tween(begin: const Offset(1.0, 0.0), end: Offset.zero).chain(
                      CurveTween(curve: Curves.easeInOutCubic),
                    ),
                  ),
                  child: child,
                );
              },
              transitionDuration: const Duration(milliseconds: 300),
            );
          },
        ),
        GoRoute(
          path: '/kitab/:id',
          name: 'kitab-detail',
          builder: (context, state) {
            final kitabId = state.pathParameters['id']!;
            return KitabDetailScreen(kitabId: kitabId);
          },
        ),
        GoRoute(
          path: '/player/:id',
          name: 'content-player',
          builder: (context, state) {
            final kitabId = state.pathParameters['id']!;
            final episodeId = state.uri.queryParameters['episode'];
            return ContentPlayerScreen(
              kitabId: kitabId,
              episodeId: episodeId,
            );
          },
        ),
        GoRoute(
          path: '/video/:id',
          name: 'video-only-player',
          builder: (context, state) {
            final kitabId = state.pathParameters['id']!;
            final episodeId = state.uri.queryParameters['episode'];
            return VideoPlayerScreen(
              kitabId: kitabId,
              episodeId: episodeId,
            );
          },
        ),
        GoRoute(
          path: '/preview/:id',
          name: 'preview-video-player',
          builder: (context, state) {
            final kitabId = state.pathParameters['id']!;
            final videoId = state.uri.queryParameters['video'];
            return PreviewVideoPlayerScreen(
              kitabId: kitabId,
              videoId: videoId,
            );
          },
        ),
        GoRoute(
          path: '/ebook',
          name: 'ebook',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: const EbookScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return SlideTransition(
                position: animation.drive(
                  Tween(begin: const Offset(1.0, 0.0), end: Offset.zero).chain(
                    CurveTween(curve: Curves.easeInOutCubic),
                  ),
                ),
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 300),
          ),
        ),
        GoRoute(
          path: '/saved',
          name: 'saved-items',
          builder: (context, state) => const SavedItemsScreen(),
        ),
        GoRoute(
          path: '/search',
          name: 'search',
          builder: (context, state) => const SearchScreen(),
        ),
        GoRoute(
          path: '/profile',
          name: 'profile',
          builder: (context, state) => const ProfileScreen(),
        ),

        // Admin Routes
        GoRoute(
          path: '/admin',
          name: 'admin-dashboard',
          builder: (context, state) => const AdminDashboardScreen(),
        ),
        GoRoute(
          path: '/admin/dashboard',
          name: 'admin-dashboard-full',
          builder: (context, state) => const AdminDashboardScreen(),
        ),
        GoRoute(
          path: '/admin/content',
          name: 'admin-content',
          builder: (context, state) => const AdminContentEnhanced(),
        ),
        GoRoute(
          path: '/admin/search',
          name: 'admin-search',
          builder: (context, state) => const AdminSearchScreen(),
        ),
        GoRoute(
          path: '/admin/content/create',
          name: 'admin-content-create',
          builder: (context, state) => const AdminVideoKitabFormScreen(
            // videoKitabId: null untuk tambah baru
            // videoKitab: null untuk tambah baru
          ),
        ),
        GoRoute(
          path: '/admin/content/edit',
          name: 'admin-content-edit',
          builder: (context, state) {
            final videoKitab = state.extra as dynamic;
            return AdminVideoKitabFormScreen(
              videoKitabId: videoKitab.id,
              videoKitab: videoKitab,
            );
          },
        ),
        GoRoute(
          path: '/admin/users',
          name: 'admin-users',
          builder: (context, state) => const AdminUsersScreen(),
        ),
        GoRoute(
          path: '/admin/users/:userId',
          name: 'admin-user-detail',
          builder: (context, state) {
            final userId = state.pathParameters['userId']!;
            return AdminUserDetailScreen(userId: userId);
          },
        ),
        GoRoute(
          path: '/admin/analytics',
          name: 'admin-analytics',
          builder: (context, state) => const AdminAnalyticsRealScreen(),
        ),
        GoRoute(
          path: '/admin/analytics-real',
          name: 'admin-analytics-real',
          builder: (context, state) => const AdminAnalyticsRealScreen(),
        ),
        GoRoute(
          path: '/admin/payments',
          name: 'admin-payments',
          builder: (context, state) => const AdminPaymentsScreen(),
        ),
        GoRoute(
          path: '/admin/subscriptions',
          name: 'admin-subscriptions',
          builder: (context, state) => const AdminSubscriptionsScreen(),
        ),
        GoRoute(
          path: '/admin/profile',
          name: 'admin-profile',
          builder: (context, state) => const AdminProfileScreen(),
        ),
        GoRoute(
          path: '/admin/settings',
          name: 'admin-settings',
          builder: (context, state) => const AdminSettingsScreen(),
        ),
        GoRoute(
          path: '/admin/ebooks',
          name: 'admin-ebooks',
          builder: (context, state) => const AdminEbookListScreen(),
        ),
        GoRoute(
          path: '/admin/kitab/:id',
          name: 'admin-kitab-detail',
          builder: (context, state) {
            final kitabId = state.pathParameters['id']!;
            return admin_kitab.AdminKitabDetailScreen(kitabId: kitabId);
          },
        ),
        
        // PDF Viewer Route
        GoRoute(
          path: '/pdf-viewer',
          name: 'pdf-viewer',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>;
            return PdfViewerScreen(
              pdfUrl: extra['pdfUrl'],
              title: extra['title'],
              kitabId: extra['kitabId'],
            );
          },
        ),

        // Payment Routes
        GoRoute(
          path: '/subscription',
          name: 'subscription',
          builder: (context, state) => const SubscriptionScreen(),
          routes: [
            GoRoute(
              path: 'payment',
              name: 'payment',
              builder: (context, state) {
                final Map<String, dynamic> params =
                    state.extra as Map<String, dynamic>;
                return PaymentScreen(
                  plan: params['plan'] as SubscriptionPlan,
                  userEmail: params['userEmail'] as String,
                  userName: params['userName'] as String,
                  userPhone: params['userPhone'] as String,
                  userId: params['userId'] as String,
                );
              },
              routes: [
                GoRoute(
                  path: 'success',
                  name: 'payment-success',
                  builder: (context, state) => const PaymentSuccessScreen(),
                ),
                GoRoute(
                  path: 'failed',
                  name: 'payment-failed',
                  builder: (context, state) => const PaymentFailedScreen(),
                ),
                GoRoute(
                  path: 'cancelled',
                  name: 'payment-cancelled',
                  builder: (context, state) => const PaymentCancelledScreen(),
                ),
                // 🆕 NEW: Payment Callback Route
                GoRoute(
                  path: 'callback',
                  name: 'payment-callback',
                  builder: (context, state) {
                    final billId = state.uri.queryParameters['billId'];
                    final planId = state.uri.queryParameters['planId'];
                    final amountStr = state.uri.queryParameters['amount'];
                    
                    if (billId == null || planId == null || amountStr == null) {
                      // Invalid parameters - redirect to subscription
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        context.go('/subscription');
                      });
                      return const Scaffold(
                        body: Center(
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }
                    
                    final amount = double.tryParse(amountStr) ?? 0.0;
                    
                    return PaymentCallbackPage(
                      billId: billId,
                      planId: planId,
                      amount: amount,
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ],
      errorBuilder: (context, state) => const NotFoundScreen(),
    );
  }
}

class PaymentSuccessScreen extends StatelessWidget {
  const PaymentSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: Colors.green,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              'Pembayaran Berjaya!',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('Langganan anda telah berjaya diaktifkan.'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/'),
              child: const Text('Kembali ke Halaman Utama'),
            ),
          ],
        ),
      ),
    );
  }
}

class PaymentFailedScreen extends StatelessWidget {
  const PaymentFailedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            Text(
              'Pembayaran Gagal',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('Sila cuba lagi atau pilih kaedah pembayaran lain.'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/subscription'),
              child: const Text('Cuba Lagi'),
            ),
          ],
        ),
      ),
    );
  }
}

class PaymentCancelledScreen extends StatelessWidget {
  const PaymentCancelledScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cancel_outlined, color: Colors.orange, size: 64),
            const SizedBox(height: 16),
            Text(
              'Pembayaran Dibatalkan',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('Pembayaran telah dibatalkan oleh pengguna.'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/subscription'),
              child: const Text('Cuba Lagi'),
            ),
          ],
        ),
      ),
    );
  }
}

class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'Halaman Tidak Dijumpai',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/'),
              child: const Text('Kembali ke Halaman Utama'),
            ),
          ],
        ),
      ),
    );
  }
}
