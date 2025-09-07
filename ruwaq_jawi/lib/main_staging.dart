import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/config/app_config.dart';
import 'core/config/environment.dart';
import 'core/services/supabase_service.dart';
import 'main.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Hive for local storage
  await Hive.initFlutter();
  
  // Set staging environment
  EnvironmentConfig.setEnvironment(Environment.staging);
  AppConfig.setEnvironment(Environment.staging);
  
  // Initialize Supabase
  await SupabaseService.initialize();
  
  runApp(const MaktabahApp());
}
