import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;

class ConnectionTest {
  static Future<void> testSupabaseConnection() async {
    final url = 'https://ckgxglvozrsognqqkpkk.supabase.co';
    
    debugPrint('🔍 Testing Supabase connection...');
    
    // Test 1: HTTP connectivity
    try {
      debugPrint('📡 Testing HTTP connection to: $url');
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
      );
      debugPrint('✅ HTTP Response: ${response.statusCode}');
    } catch (e) {
      debugPrint('❌ HTTP Error: $e');
    }
    
    // Test 2: DNS lookup
    try {
      debugPrint('🔍 Testing DNS lookup for: ckgxglvozrsognqqkpkk.supabase.co');
      final addresses = await InternetAddress.lookup('ckgxglvozrsognqqkpkk.supabase.co');
      debugPrint('✅ DNS resolved to: ${addresses.map((addr) => addr.address).join(', ')}');
    } catch (e) {
      debugPrint('❌ DNS Error: $e');
    }
    
    // Test 3: Supabase client initialization
    try {
      debugPrint('🔧 Testing Supabase client initialization...');
      final client = SupabaseClient(
        url,
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNrZ3hnbHZvenJzb2ducXFrcGtrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTYyOTIwMDYsImV4cCI6MjA3MTg2ODAwNn0.AnTcS1uSC83m7pYT9UxAb_enhcEGCIor49AhuyCTkiQ',
      );
      
      // Test simple query
      final response = await client
          .from('categories')
          .select('id, name')
          .limit(1)
          .timeout(const Duration(seconds: 10));
      
      debugPrint('✅ Supabase query success: ${response.length} records');
    } catch (e) {
      debugPrint('❌ Supabase Error: $e');
    }
    
    // Test 4: Network interface info
    try {
      debugPrint('🌐 Network interfaces:');
      final interfaces = await NetworkInterface.list();
      for (final interface in interfaces) {
        debugPrint('  - ${interface.name}: ${interface.addresses.map((addr) => addr.address).join(', ')}');
      }
    } catch (e) {
      debugPrint('❌ Network interface error: $e');
    }
    
    debugPrint('🏁 Connection test completed');
  }
}
