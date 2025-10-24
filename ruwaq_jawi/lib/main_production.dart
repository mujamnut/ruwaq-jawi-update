import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/config/app_config.dart';
import 'core/config/environment.dart';
import 'core/services/supabase_service.dart';
import 'core/services/local_favorites_service.dart';
import 'core/services/video_progress_service.dart';
import 'core/services/pdf_cache_service.dart';
import 'core/services/local_saved_items_service.dart';
import 'main.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // 🚀 Load .env file for Production
    // For production, you can create .env.production or use the same .env
    await dotenv.load(fileName: ".env");

    // 🚀 Set Production environment
    EnvironmentConfig.setEnvironment(Environment.production);
    AppConfig.setEnvironment(Environment.production);

    // Initialize Hive for local storage
    await Hive.initFlutter();

    // Initialize services
    await LocalFavoritesService.initialize();
    await VideoProgressService.initialize();
    await PdfCacheService.initialize();
    await LocalSavedItemsService.initialize();

    // Initialize Supabase (will use keys from .env)
    await SupabaseService.initialize();

    runApp(const MaktabahApp());
  } catch (e) {
    // Production error handling
    debugPrint('❌ Failed to initialize app: $e');
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Failed to start app',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('Error: $e'),
            ],
          ),
        ),
      ),
    ));
  }
}
