import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/student/screens/profile_screen.dart';
import '../../features/student/screens/edit_profile_screen.dart';
import '../../features/student/screens/notification_screen.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/reset_password_screen.dart';
import '../../features/auth/screens/email_verification_screen.dart';
import '../../features/auth/screens/welcome_screen.dart';
import '../../features/student/screens/student_home_screen.dart';
import '../../features/student/screens/kitab_list_screen.dart';
import '../../features/student/screens/kitab_detail_screen.dart';
import '../../features/student/screens/category_list_screen.dart';
import '../../features/student/screens/category_detail_screen.dart';
import '../../features/student/screens/saved_items_screen.dart';
import '../../features/student/screens/subscription_screen.dart';
import '../../features/student/screens/subscription_detail_screen.dart';
import '../../features/student/screens/search_screen.dart';
import '../../features/student/screens/content_player_screen.dart';
import '../../features/student/screens/ebook_screen.dart';
import '../../features/student/screens/ebook_detail_screen.dart';
import '../../features/student/screens/preview_video_player_screen.dart';
// Admin - Dashboard
import '../../features/admin/screens/dashboard/dashboard_screen.dart';
// Admin - Videos
import '../../features/admin/screens/videos/list_screen.dart' as admin_video;
import '../../features/admin/screens/videos/form_screen.dart' as admin_video_form;
// Admin - Ebooks
import '../../features/admin/screens/ebooks/list_screen.dart' as admin_ebook;
// Admin - Users
import '../../features/admin/screens/users/list_screen.dart' as admin_user;
import '../../features/admin/screens/users/detail_screen.dart' as admin_user_detail;
// Admin - Analytics
import '../../features/admin/screens/analytics/main_screen.dart' as admin_analytics;
// Admin - Categories
import '../../features/admin/screens/categories/list_screen.dart' as admin_category;
import '../../features/admin/screens/categories/form_screen.dart' as admin_category_form;
// Admin - Notifications
import '../../features/admin/screens/notifications/notification_list_screen.dart' as admin_notification;
// Admin - Subscriptions
import '../../features/admin/screens/subscriptions/subscription_list_screen.dart' as admin_subscription;
// Admin - Shared
import '../../features/admin/shared/profile_screen.dart';
import '../../features/admin/shared/settings_screen.dart';
import '../../features/admin/shared/pdf_viewer_screen.dart';
// Admin - Search, Payments, Reports, Kitab
import '../../features/admin/screens/search/search_screen.dart' as admin_search;
import '../../features/admin/screens/payments/payments_screen.dart' as admin_payments;
import '../../features/admin/screens/reports/reports_screen.dart' as admin_reports_main;
// Admin - Video Kitab
import '../../features/admin/screens/videos/kitab_detail_screen.dart' as admin_kitab;
import '../../features/admin/screens/videos/kitab_manual_form_screen.dart' as admin_kitab_form;
import '../../features/admin/screens/videos/mode_selection_screen.dart';
import '../../features/admin/screens/videos/kitab_auto_form_screen.dart';
// Student Payment
import '../../features/student/screens/payment_screen.dart';
import '../../features/student/screens/toyyibpay_payment_screen.dart';
import '../../features/student/screens/payment_history_screen.dart';
import '../../features/student/screens/privacy_security_screen.dart';
import '../../features/student/screens/help_support_screen.dart';
import '../../features/student/screens/manual_payment_verification_screen.dart';
import '../models/payment_models.dart';
import '../../features/payment/screens/payment_callback_page.dart';

class AppRouter {
  static GoRouter createRouter() {
    return GoRouter(
      initialLocation: '/',
      debugLogDiagnostics: false,
      redirectLimit: 10,
      routes: [
        // Splash Screen Route
        GoRoute(
          path: '/',
          name: 'splash',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: const SplashScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(
                    opacity: animation.drive(
                      CurveTween(curve: Curves.easeInOut),
                    ),
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
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return SlideTransition(
                    position: animation.drive(
                      Tween(
                        begin: const Offset(1.0, 0.0),
                        end: Offset.zero,
                      ).chain(CurveTween(curve: Curves.easeInOutCubic)),
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
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return SlideTransition(
                    position: animation.drive(
                      Tween(
                        begin: const Offset(1.0, 0.0),
                        end: Offset.zero,
                      ).chain(CurveTween(curve: Curves.easeInOutCubic)),
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
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return SlideTransition(
                    position: animation.drive(
                      Tween(
                        begin: const Offset(1.0, 0.0),
                        end: Offset.zero,
                      ).chain(CurveTween(curve: Curves.easeInOutCubic)),
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
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                    return SlideTransition(
                      position: animation.drive(
                        Tween(
                          begin: const Offset(1.0, 0.0),
                          end: Offset.zero,
                        ).chain(CurveTween(curve: Curves.easeInOutCubic)),
                      ),
                      child: child,
                    );
                  },
              transitionDuration: const Duration(milliseconds: 300),
            );
          },
        ),
        GoRoute(
          path: '/auth/confirm',
          name: 'email-confirm',
          pageBuilder: (context, state) {
            final email = state.uri.queryParameters['email'];

            return CustomTransitionPage(
              key: state.pageKey,
              child: EmailVerificationScreen(
                email: email,
                message: 'Email confirmation link clicked successfully',
              ),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                    return SlideTransition(
                      position: animation.drive(
                        Tween(
                          begin: const Offset(1.0, 0.0),
                          end: Offset.zero,
                        ).chain(CurveTween(curve: Curves.easeInOutCubic)),
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
            return CustomTransitionPage(
              key: state.pageKey,
              child: EmailVerificationScreen(email: email, message: message),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                    return SlideTransition(
                      position: animation.drive(
                        Tween(
                          begin: const Offset(1.0, 0.0),
                          end: Offset.zero,
                        ).chain(CurveTween(curve: Curves.easeInOutCubic)),
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
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return SlideTransition(
                    position: animation.drive(
                      Tween(
                        begin: const Offset(1.0, 0.0),
                        end: Offset.zero,
                      ).chain(CurveTween(curve: Curves.easeInOutCubic)),
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
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                    return SlideTransition(
                      position: animation.drive(
                        Tween(
                          begin: const Offset(1.0, 0.0),
                          end: Offset.zero,
                        ).chain(CurveTween(curve: Curves.easeInOutCubic)),
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
          builder: (context, state) => const StudentHomeScreen(),
        ),
        GoRoute(
          path: '/kitab',
          name: 'kitab-list',
          builder: (context, state) {
            final category = state.uri.queryParameters['category'];
            final sort = state.uri.queryParameters['sort'];
            return KitabListScreen(
              initialCategory: category,
              initialSort: sort,
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
          path: '/categories',
          name: 'categories',
          builder: (context, state) => const CategoryListScreen(),
        ),
        GoRoute(
          path: '/category/:id',
          name: 'category-detail',
          builder: (context, state) {
            final categoryId = state.pathParameters['id']!;
            return CategoryDetailScreen(categoryId: categoryId);
          },
        ),
        GoRoute(
          path: '/player/:id',
          name: 'content-player',
          builder: (context, state) {
            final kitabId = state.pathParameters['id']!;
            final episodeId = state.uri.queryParameters['episode'];
            // Use original - stable and working
            return ContentPlayerScreen(kitabId: kitabId, episodeId: episodeId);
          },
        ),
        GoRoute(
          path: '/video/:id',
          name: 'video-only-player',
          builder: (context, state) {
            final kitabId = state.pathParameters['id']!;
            final episodeId = state.uri.queryParameters['episode'];
            // Use original - stable and working
            return ContentPlayerScreen(kitabId: kitabId, episodeId: episodeId);
          },
        ),
        GoRoute(
          path: '/preview/:id',
          name: 'preview-video-player',
          builder: (context, state) {
            final kitabId = state.pathParameters['id']!;
            final videoId = state.uri.queryParameters['video'];
            return PreviewVideoPlayerScreen(
              videoKitabId: kitabId,
              videoId: videoId,
            );
          },
        ),
        GoRoute(
          path: '/ebook',
          name: 'ebook',
          builder: (context, state) => const EbookScreen(),
        ),
        GoRoute(
          path: '/ebook/:id',
          name: 'ebook-detail',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: EbookDetailScreen(ebookId: state.pathParameters['id']!),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return SlideTransition(
                    position: animation.drive(
                      Tween(
                        begin: const Offset(1.0, 0.0),
                        end: Offset.zero,
                      ).chain(CurveTween(curve: Curves.easeInOutCubic)),
                    ),
                    child: FadeTransition(
                      opacity: animation.drive(
                        Tween(
                          begin: 0.0,
                          end: 1.0,
                        ).chain(CurveTween(curve: Curves.easeInOut)),
                      ),
                      child: ScaleTransition(
                        scale: animation.drive(
                          Tween(
                            begin: 0.95,
                            end: 1.0,
                          ).chain(CurveTween(curve: Curves.easeOutBack)),
                        ),
                        child: child,
                      ),
                    ),
                  );
                },
            transitionDuration: const Duration(milliseconds: 350),
          ),
        ),
        GoRoute(
          path: '/ebook/reader/:id',
          name: 'ebook-reader',
          builder: (context, state) {
            final ebookId = state.pathParameters['id']!;
            return PdfViewerScreen(
              pdfUrl: 'placeholder', // This will be dynamically loaded
              title: 'E-book Reader',
              kitabId: ebookId,
            );
          },
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
        GoRoute(
          path: '/payment-history',
          name: 'payment-history',
          builder: (context, state) => const PaymentHistoryScreen(),
        ),
        GoRoute(
          path: '/privacy-security',
          name: 'privacy-security',
          builder: (context, state) => const PrivacySecurityScreen(),
        ),
        GoRoute(
          path: '/help-support',
          name: 'help-support',
          builder: (context, state) => const HelpSupportScreen(),
        ),
        GoRoute(
          path: '/verify-payment',
          name: 'verify-payment',
          builder: (context, state) => const ManualPaymentVerificationScreen(),
        ),
        GoRoute(
          path: '/notifications',
          name: 'notifications',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: const NotificationScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return SlideTransition(
                    position: animation.drive(
                      Tween(
                        begin: const Offset(1.0, 0.0),
                        end: Offset.zero,
                      ).chain(CurveTween(curve: Curves.easeInOutCubic)),
                    ),
                    child: child,
                  );
                },
            transitionDuration: const Duration(milliseconds: 300),
          ),
        ),
        GoRoute(
          path: '/edit-profile',
          name: 'edit-profile',
          builder: (context, state) => const EditProfileScreen(),
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
          builder: (context, state) => const admin_video.AdminVideoListScreen(),
        ),
        GoRoute(
          path: '/admin/search',
          name: 'admin-search',
          builder: (context, state) => const admin_search.AdminSearchScreen(),
        ),
        GoRoute(
          path: '/admin/content/create',
          name: 'admin-content-create',
          builder: (context, state) => const admin_video_form.AdminVideoKitabFormScreen(
            // videoKitabId: null untuk tambah baru
            // videoKitab: null untuk tambah baru
          ),
        ),
        GoRoute(
          path: '/admin/content/edit',
          name: 'admin-content-edit',
          builder: (context, state) {
            final videoKitab = state.extra as dynamic;
            return admin_video_form.AdminVideoKitabFormScreen(
              videoKitabId: videoKitab.id,
              videoKitab: videoKitab,
            );
          },
        ),
        GoRoute(
          path: '/admin/users',
          name: 'admin-users',
          builder: (context, state) => const admin_user.AdminUsersScreen(),
        ),
        GoRoute(
          path: '/admin/users/:userId',
          name: 'admin-user-detail',
          builder: (context, state) {
            final userId = state.pathParameters['userId']!;
            return admin_user_detail.AdminUserDetailScreen(userId: userId);
          },
        ),
        GoRoute(
          path: '/admin/analytics',
          name: 'admin-analytics',
          builder: (context, state) => const admin_analytics.AdminAnalyticsRealScreen(),
        ),
        GoRoute(
          path: '/admin/analytics-real',
          name: 'admin-analytics-real',
          builder: (context, state) => const admin_analytics.AdminAnalyticsRealScreen(),
        ),
        GoRoute(
          path: '/admin/payments',
          name: 'admin-payments',
          builder: (context, state) => const admin_payments.AdminPaymentsScreen(),
        ),
        GoRoute(
          path: '/admin/subscriptions',
          name: 'admin-subscriptions',
          builder: (context, state) => const admin_subscription.AdminSubscriptionsScreen(),
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
          builder: (context, state) => const admin_ebook.AdminEbookListScreen(),
        ),
        // Admin Categories Routes
        GoRoute(
          path: '/admin/categories',
          name: 'admin-categories',
          builder: (context, state) => const admin_category.AdminCategoriesScreen(),
        ),
        GoRoute(
          path: '/admin/categories/add',
          name: 'admin-categories-add',
          builder: (context, state) => const admin_category_form.AdminAddCategoryScreen(),
        ),
        GoRoute(
          path: '/admin/categories/edit/:id',
          name: 'admin-categories-edit',
          builder: (context, state) {
            final categoryId = state.pathParameters['id']!;
            return admin_category_form.AdminAddCategoryScreen(categoryId: categoryId);
          },
        ),
        // Admin Reports Route
        GoRoute(
          path: '/admin/reports',
          name: 'admin-reports',
          builder: (context, state) => const admin_reports_main.AdminReportsScreen(),
        ),
        // Admin Notifications Routes
        GoRoute(
          path: '/admin/notifications',
          name: 'admin-notifications',
          builder: (context, state) => const admin_notification.AdminNotificationsScreen(),
        ),
        GoRoute(
          path: '/admin/notifications/send',
          name: 'admin-notifications-send',
          builder: (context, state) => const admin_notification.AdminNotificationsScreen(),
        ),
        // Admin Kitabs Routes
        // Mode Selection (Choose Manual or Auto)
        GoRoute(
          path: '/admin/kitabs/add',
          name: 'admin-kitabs-add',
          builder: (context, state) => const AdminKitabModeSelectionScreen(),
        ),
        // Manual Mode - Add/Edit Kitab with episodes one by one
        GoRoute(
          path: '/admin/kitabs/add-manual',
          name: 'admin-kitabs-add-manual',
          builder: (context, state) {
            final kitabData = state.extra as Map<String, dynamic>?;
            final kitabId = state.uri.queryParameters['id'];
            return admin_kitab_form.AdminKitabFormScreen(
              kitabId: kitabId,
              kitabData: kitabData,
            );
          },
        ),
        // Auto Mode - Sync from YouTube playlist
        GoRoute(
          path: '/admin/kitabs/add-auto',
          name: 'admin-kitabs-add-auto',
          builder: (context, state) => const AdminYouTubeAutoFormScreen(),
        ),
        // Kitab Detail
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
          path: '/payment/toyyibpay',
          name: 'toyyibpay-payment',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>;
            return ToyyibpayPaymentScreen(
              billCode: extra['billCode'] as String,
              billUrl: extra['billUrl'] as String,
              planId: extra['planId'] as String?,
              amount: extra['amount'] as double?,
            );
          },
        ),
        GoRoute(
          path: '/payment-callback',
          name: 'payment-callback-direct',
          builder: (context, state) {
            // ToyyibPay uses 'billcode' (lowercase) and 'order_id' contains plan info
            final billId = state.uri.queryParameters['billcode'] ?? state.uri.queryParameters['billId'];
            final planId = state.uri.queryParameters['planId'];
            final amountStr = state.uri.queryParameters['amount'];
            final status = state.uri.queryParameters['status'];
            final statusId = state.uri.queryParameters['status_id'];

            // Extract redirect status parameters passed from ToyyibPayPaymentScreen
            final redirectStatus = state.uri.queryParameters['redirectStatus'];
            final redirectStatusId = state.uri.queryParameters['redirectStatusId'];

            // Extract plan from order_id if planId not available
            String? extractedPlanId = planId;
            if (extractedPlanId == null) {
              final orderId = state.uri.queryParameters['order_id'];
              if (orderId != null && orderId.contains('_')) {
                // order_id format: userId_planId or just planId
                final parts = orderId.split('_');
                if (parts.length > 1) {
                  extractedPlanId = parts[1];
                } else {
                  extractedPlanId = parts[0];
                }
              }
            }

            // Debug logging for payment callback
            print('🔍 Payment callback route - URL: ${state.uri}');
            print('📋 Parsed parameters: billId=$billId, planId=$extractedPlanId, amount=$amountStr, status=$status, statusId=$statusId');

            // Try to get amount from order_id parsing or use default
            double amount = 0.0;
            if (amountStr != null) {
              amount = double.tryParse(amountStr) ?? 0.0;
            } else {
              // Default amount if not provided - will be handled by subscription verification
              final orderId = state.uri.queryParameters['order_id'];
              if (orderId != null && orderId.contains('monthly_premi')) {
                amount = 27.90; // Default for monthly premium
              } else if (orderId != null && orderId.contains('monthly_basic')) {
                amount = 15.90; // Default for monthly basic
              }
            }

            // More flexible validation - only billId is required
            if (billId == null) {
              print('❌ No billId found in redirect URL');
              WidgetsBinding.instance.addPostFrameCallback((_) {
                context.go('/subscription');
              });
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            print('✅ Proceeding with payment callback: billId=$billId, planId=$extractedPlanId, amount=$amount');

            return PaymentCallbackPage(
              billId: billId,
              planId: extractedPlanId ?? 'unknown',
              amount: amount,
              redirectStatus: redirectStatus ?? status,
              redirectStatusId: redirectStatusId ?? statusId,
            );
          },
        ),
        GoRoute(
          path: '/subscription-detail',
          name: 'subscription-detail',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: const SubscriptionDetailScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return SlideTransition(
                    position: animation.drive(
                      Tween(
                        begin: const Offset(1.0, 0.0),
                        end: Offset.zero,
                      ).chain(CurveTween(curve: Curves.easeInOutCubic)),
                    ),
                    child: child,
                  );
                },
            transitionDuration: const Duration(milliseconds: 300),
          ),
        ),
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
                    // ToyyibPay uses 'billcode' (lowercase) and 'order_id' contains plan info
                    final billId = state.uri.queryParameters['billcode'] ?? state.uri.queryParameters['billId'];
                    final planId = state.uri.queryParameters['planId'];
                    final amountStr = state.uri.queryParameters['amount'];
                    final status = state.uri.queryParameters['status'];
                    final statusId = state.uri.queryParameters['status_id'];

                    // Extract redirect status parameters passed from ToyyibPayPaymentScreen
                    final redirectStatus = state.uri.queryParameters['redirectStatus'];
                    final redirectStatusId = state.uri.queryParameters['redirectStatusId'];

                    // Extract plan from order_id if planId not available
                    String? extractedPlanId = planId;
                    if (extractedPlanId == null) {
                      final orderId = state.uri.queryParameters['order_id'];
                      if (orderId != null && orderId.contains('_')) {
                        // order_id format: userId_planId or just planId
                        final parts = orderId.split('_');
                        if (parts.length > 1) {
                          extractedPlanId = parts[1];
                        } else {
                          extractedPlanId = parts[0];
                        }
                      }
                    }

                    // Try to get amount from order_id parsing or use default
                    double amount = 0.0;
                    if (amountStr != null) {
                      amount = double.tryParse(amountStr) ?? 0.0;
                    } else {
                      // Default amount if not provided - will be handled by subscription verification
                      final orderId = state.uri.queryParameters['order_id'];
                      if (orderId != null && orderId.contains('monthly_premi')) {
                        amount = 27.90; // Default for monthly premium
                      } else if (orderId != null && orderId.contains('monthly_basic')) {
                        amount = 15.90; // Default for monthly basic
                      }
                    }

                    // More flexible validation - only billId is required
                    if (billId == null) {
                      print('❌ No billId found in redirect URL');
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        context.go('/subscription');
                      });
                      return const Scaffold(
                        body: Center(child: CircularProgressIndicator()),
                      );
                    }

                    print('✅ Proceeding with payment callback (route 2): billId=$billId, planId=$extractedPlanId, amount=$amount');

                    return PaymentCallbackPage(
                      billId: billId,
                      planId: extractedPlanId ?? 'unknown',
                      amount: amount,
                      redirectStatus: redirectStatus ?? status,
                      redirectStatusId: redirectStatusId ?? statusId,
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ],
      errorBuilder: (context, state) {
        // Check if this is a hot restart scenario - redirect to splash instead of error
        if (state.error?.toString().contains('redirect') == true ||
            state.error?.toString().contains('loop') == true) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/');
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return const NotFoundScreen();
      },
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

class NotFoundScreen extends StatefulWidget {
  const NotFoundScreen({super.key});

  @override
  State<NotFoundScreen> createState() => _NotFoundScreenState();
}

class _NotFoundScreenState extends State<NotFoundScreen> {
  @override
  void initState() {
    super.initState();
    // Auto-redirect to splash after a short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        context.go('/');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
            const SizedBox(height: 8),
            const Text(
              'Halaman yang anda cari tidak wujud.',
              style: TextStyle(color: Colors.grey),
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
