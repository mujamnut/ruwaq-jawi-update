import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'core/config/app_config.dart';
import 'core/config/environment.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/app_router.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/kitab_provider.dart';
import 'core/providers/saved_items_provider.dart';
import 'core/providers/analytics_provider.dart';
import 'core/providers/settings_provider.dart';
import 'core/providers/notifications_provider.dart';
import 'core/providers/payment_provider.dart';
import 'core/services/supabase_service.dart';
import 'core/services/toyyibpay_service.dart';
import 'core/services/subscription_service.dart';
import 'core/services/content_service.dart';
import 'core/config/payment_config.dart';
import 'core/providers/bookmark_provider.dart';
import 'core/providers/content_provider.dart';
import 'core/providers/subscription_provider.dart';
import 'core/providers/connectivity_provider.dart';
import 'core/services/deep_link_service.dart';
import 'core/services/background_payment_service.dart';
import 'core/services/local_favorites_service.dart';
import 'core/services/video_progress_service.dart';
import 'core/services/pdf_cache_service.dart';
import 'core/services/local_saved_items_service.dart';
import 'core/widgets/offline_banner.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize Hive for local storage
    await Hive.initFlutter();
    
    // Initialize local favorites service
    await LocalFavoritesService.initialize();
    
    // Initialize video progress service
    await VideoProgressService.initialize();
    
    // Initialize PDF cache service
    await PdfCacheService.initialize();
    
    // Initialize local saved items service
    await LocalSavedItemsService.initialize();

    // Set environment (default to development)
    EnvironmentConfig.setEnvironment(Environment.development);
    AppConfig.setEnvironment(Environment.development);

    // Connection test removed - handled by Supabase initialization
    
    // Initialize Supabase with timeout
    await SupabaseService.initialize().timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        throw Exception('Supabase initialization timed out');
      },
    );

    // Fix memory leaks and frame buffer issues
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Force garbage collection after initialization
      if (kDebugMode) {
        print('App initialized successfully');
      }
    });

    runApp(const MaktabahApp());
  } catch (e) {
    // If initialization fails, show error app
    runApp(MaktabahErrorApp(error: e.toString()));
  }
}

class MaktabahApp extends StatelessWidget {
  const MaktabahApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = AppRouter.createRouter();

    // Initialize deep link service
    DeepLinkService.initialize(router);
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) {
            final authProvider = AuthProvider();
            // Reset to initial state to prevent stuck loading
            authProvider.resetToInitial();
            return authProvider;
          },
        ),
        ChangeNotifierProvider(create: (_) => KitabProvider()),
        ChangeNotifierProvider(create: (_) => SavedItemsProvider()),
        ChangeNotifierProvider(create: (_) => AnalyticsProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => NotificationsProvider()),
        ChangeNotifierProvider(create: (_) => BookmarkProvider()),
        ChangeNotifierProxyProvider<AuthProvider, PaymentProvider>(
          create: (context) {
            final authProvider = Provider.of<AuthProvider>(
              context,
              listen: false,
            );
            final paymentProvider = PaymentProvider(
              ToyyibpayService(
                secretKey: PaymentConfig.userSecretKey,
                categoryCode: PaymentConfig.categoryCode,
                isProduction: PaymentConfig.isProduction,
              ),
              SubscriptionService(SupabaseService.supabase),
            );
            // Connect auth provider to payment provider
            paymentProvider.setAuthProvider(authProvider);
            return paymentProvider;
          },
          update: (context, authProvider, paymentProvider) {
            paymentProvider?.setAuthProvider(authProvider);
            return paymentProvider!;
          },
        ),
        // 🆕 NEW: SubscriptionProvider for payment verification
        ChangeNotifierProvider(create: (_) => SubscriptionProvider()),
        // 🆕 NEW: ConnectivityProvider for internet monitoring
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
        ChangeNotifierProvider(
          create: (context) {
            final auth = context.read<AuthProvider>();
            return ContentProvider(
              ContentService(
                SupabaseService.supabase,
                auth.currentUserId ?? '',
              ),
            );
          },
        ),
      ],
      child: BackgroundPaymentWrapper(
        child: OfflineBanner(
          child: MaterialApp.router(
            title: AppConfig.appName,
            debugShowCheckedModeBanner: false,

            // Theme Configuration
            theme: AppTheme.lightTheme,

            // Router Configuration
            routerConfig: router,

            // Localization (can be added later)
            // localizationsDelegates: const [
            //   GlobalMaterialLocalizations.delegate,
            //   GlobalWidgetsLocalizations.delegate,
            //   GlobalCupertinoLocalizations.delegate,
            // ],
            // supportedLocales: const [
            //   Locale('en', 'US'),
            //   Locale('ms', 'MY'),
            //   Locale('ar', 'SA'),
            // ],
          ),
        ),
      ),
    );
  }
}

/// Wrapper widget untuk start background payment service
class BackgroundPaymentWrapper extends StatefulWidget {
  final Widget child;

  const BackgroundPaymentWrapper({super.key, required this.child});

  @override
  State<BackgroundPaymentWrapper> createState() =>
      _BackgroundPaymentWrapperState();
}

class _BackgroundPaymentWrapperState extends State<BackgroundPaymentWrapper>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Start background service selepas app fully loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startBackgroundServiceIfNeeded();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Clean up background service
    BackgroundPaymentService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        // App resumed - check for pending payments
        _startBackgroundServiceIfNeeded();
        break;
      case AppLifecycleState.paused:
        // App paused - optionally stop background service to save battery
        // BackgroundPaymentService.stopBackgroundVerification();
        break;
      case AppLifecycleState.detached:
        // App terminated - clean up
        BackgroundPaymentService.dispose();
        break;
      default:
        break;
    }
  }

  void _startBackgroundServiceIfNeeded() {
    try {
      if (context.mounted && !BackgroundPaymentService.isRunning) {
        print('🚀 Starting background payment verification service...');
        BackgroundPaymentService.startBackgroundVerification(context);
      }
    } catch (e) {
      print('❌ Error starting background payment service: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class MaktabahErrorApp extends StatelessWidget {
  final String error;

  const MaktabahErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Maktabah Error',
      theme: AppTheme.lightTheme,
      home: Scaffold(
        backgroundColor: AppTheme.primaryColor,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 80,
                  color: AppTheme.textLightColor,
                ),
                const SizedBox(height: 24),
                Text(
                  'Ralat Memulakan Aplikasi',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textLightColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Tidak dapat menyambung ke pelayan. Sila semak sambungan internet anda.',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppTheme.textLightColor.withOpacity(0.8),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () {
                    // Restart the app
                    main();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.textLightColor,
                    foregroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                  child: const Text('Cuba Lagi'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
