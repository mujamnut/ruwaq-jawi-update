import 'package:flutter/material.dart';
import '../core/services/supabase_service.dart';

/// Debug utility to test video_episodes table structure and operations
class TestVideoEpisodes {
  
  /// Test the table structure and basic operations
  static Future<Map<String, dynamic>> testTableStructure() async {
    final result = <String, dynamic>{};
    
    try {
      print('=== Testing video_episodes table ===');
      
      // Test 1: Check if table exists and get structure
      try {
        final tableTest = await SupabaseService.from('video_episodes')
            .select()
            .limit(1);
        result['table_exists'] = true;
        result['table_accessible'] = true;
        print('✅ Table exists and is accessible');
      } catch (e) {
        result['table_exists'] = false;
        result['table_error'] = e.toString();
        print('❌ Table access error: $e');
      }
      
      // Test 2: Try to get table columns info (this might fail but worth trying)
      try {
        final columns = await SupabaseService.client
            .from('information_schema.columns')
            .select('column_name, data_type, is_nullable')
            .eq('table_name', 'video_episodes');
        result['columns'] = columns;
        print('✅ Table columns: $columns');
      } catch (e) {
        print('ℹ️ Could not get column info: $e');
      }
      
      // Test 3: Try a simple insert with video_kitab_id to see exact error
      try {
        final testData = {
          'video_kitab_id': 'test-video-kitab-id',
          'title': 'Test Episode',
          'youtube_video_id': 'dQw4w9WgXcQ',
          'part_number': 999,
          'duration_minutes': 5,
          'is_active': true,
          'is_preview': false,
          'sort_order': 999,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        };
        
        print('Attempting test insert with data: ${testData.keys.join(', ')}');
        
        final insertResult = await SupabaseService.from('video_episodes')
            .insert(testData)
            .select()
            .single();
            
        result['insert_test'] = 'success';
        result['inserted_record'] = insertResult;
        print('✅ Test insert successful: $insertResult');
        
        // Clean up test record
        await SupabaseService.from('video_episodes')
            .delete()
            .eq('id', insertResult['id']);
        print('✅ Test record cleaned up');
        
      } catch (e) {
        result['insert_test'] = 'failed';
        result['insert_error'] = e.toString();
        print('❌ Insert test failed: $e');
        
        // Check if the error mentions kitab_id specifically
        if (e.toString().toLowerCase().contains('kitab_id')) {
          result['kitab_id_error'] = true;
          print('🔍 Error mentions kitab_id - this is the source of the problem!');
        }
      }
      
      // Test 4: Check what tables exist that might be related
      try {
        final tables = await SupabaseService.client.rpc('get_table_names');
        final videoTables = tables.where((table) => 
          table.toString().toLowerCase().contains('video') || 
          table.toString().toLowerCase().contains('kitab') ||
          table.toString().toLowerCase().contains('episode')
        ).toList();
        result['related_tables'] = videoTables;
        print('ℹ️ Related tables found: $videoTables');
      } catch (e) {
        print('ℹ️ Could not list tables: $e');
      }
      
    } catch (e) {
      result['general_error'] = e.toString();
      print('❌ General error: $e');
    }
    
    return result;
  }
  
  /// Test creating an episode with different field variations
  static Future<void> testFieldVariations(String videoKitabId) async {
    print('=== Testing field variations ===');
    
    final variations = [
      // Test with video_kitab_id (correct)
      {
        'video_kitab_id': videoKitabId,
        'title': 'Test Episode A',
        'youtube_video_id': 'dQw4w9WgXcQ',
        'part_number': 998,
      },
      // Test with kitab_id (old field)
      {
        'kitab_id': videoKitabId,
        'title': 'Test Episode B', 
        'youtube_video_id': 'dQw4w9WgXcQ',
        'part_number': 997,
      },
    ];
    
    for (int i = 0; i < variations.length; i++) {
      final testData = {
        ...variations[i],
        'duration_minutes': 5,
        'is_active': true,
        'is_preview': false,
        'sort_order': 990 + i,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      try {
        print('Testing variation ${i + 1}: ${testData.keys.join(', ')}');
        final result = await SupabaseService.from('video_episodes')
            .insert(testData)
            .select()
            .single();
        print('✅ Variation ${i + 1} successful: ${result['id']}');
        
        // Clean up
        await SupabaseService.from('video_episodes')
            .delete()
            .eq('id', result['id']);
            
      } catch (e) {
        print('❌ Variation ${i + 1} failed: $e');
      }
    }
  }
}

/// Widget to run the tests and display results
class TestVideoEpisodesScreen extends StatefulWidget {
  const TestVideoEpisodesScreen({super.key});
  
  @override
  State<TestVideoEpisodesScreen> createState() => _TestVideoEpisodesScreenState();
}

class _TestVideoEpisodesScreenState extends State<TestVideoEpisodesScreen> {
  Map<String, dynamic>? testResults;
  bool isLoading = false;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Video Episodes'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton(
              onPressed: isLoading ? null : _runTests,
              child: isLoading 
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Run Table Structure Tests'),
            ),
            const SizedBox(height: 20),
            if (testResults != null) ...[
              const Text(
                'Test Results:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: SingleChildScrollView(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SelectableText(
                      _formatResults(testResults!),
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Future<void> _runTests() async {
    setState(() {
      isLoading = true;
    });
    
    try {
      final results = await TestVideoEpisodes.testTableStructure();
      setState(() {
        testResults = results;
      });
    } catch (e) {
      setState(() {
        testResults = {'error': e.toString()};
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }
  
  String _formatResults(Map<String, dynamic> results) {
    final buffer = StringBuffer();
    
    results.forEach((key, value) {
      buffer.writeln('$key: ${_formatValue(value)}');
      buffer.writeln('---');
    });
    
    return buffer.toString();
  }
  
  String _formatValue(dynamic value) {
    if (value is Map || value is List) {
      try {
        return value.toString();
      } catch (e) {
        return 'Complex object: ${value.runtimeType}';
      }
    }
    return value.toString();
  }
}
