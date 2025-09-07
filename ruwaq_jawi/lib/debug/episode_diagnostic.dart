import '../core/services/video_episode_service.dart';

/// Quick diagnostic tool to test episode creation and identify field name issues
class EpisodeDiagnostic {
  
  /// Test episode creation with a real video kitab ID
  static Future<Map<String, dynamic>> testEpisodeCreation(String videoKitabId) async {
    final results = <String, dynamic>{};
    
    print('🔍 Starting episode creation diagnostic...');
    print('📋 Using video kitab ID: $videoKitabId');
    
    try {
      // Test data for creating an episode
      final testEpisodeData = {
        'video_kitab_id': videoKitabId,
        'title': 'Test Episode - DELETE ME',
        'description': 'This is a test episode for diagnosing the field name issue',
        'youtube_video_id': 'dQw4w9WgXcQ', // Rick Roll video ID (safe test video)
        'youtube_video_url': 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        'part_number': 9999, // High number to avoid conflicts
        'duration_minutes': 3,
        'is_active': false, // Keep inactive for testing
        'is_preview': true,
      };
      
      print('📝 Test episode data prepared:');
      testEpisodeData.forEach((key, value) {
        print('   $key: $value');
      });
      
      // Attempt to create the episode
      print('🚀 Attempting to create test episode...');
      final createdEpisode = await VideoEpisodeService.createEpisode(testEpisodeData);
      
      results['success'] = true;
      results['created_episode_id'] = createdEpisode.id;
      results['field_name_used'] = 'video_kitab_id'; // Primary field worked
      
      print('✅ SUCCESS! Episode created with ID: ${createdEpisode.id}');
      print('🧹 Cleaning up test episode...');
      
      // Clean up the test episode
      try {
        await VideoEpisodeService.deleteEpisode(createdEpisode.id);
        print('✅ Test episode cleaned up successfully');
        results['cleanup_success'] = true;
      } catch (cleanupError) {
        print('⚠️  Could not clean up test episode: $cleanupError');
        results['cleanup_success'] = false;
        results['cleanup_error'] = cleanupError.toString();
      }
      
    } catch (e) {
      results['success'] = false;
      results['error'] = e.toString();
      
      print('❌ Episode creation failed: $e');
      
      // Analyze the error
      final errorStr = e.toString().toLowerCase();
      
      if (errorStr.contains('kitab_id') && !errorStr.contains('video_kitab_id')) {
        results['issue_type'] = 'field_name_mismatch';
        results['expected_field'] = 'kitab_id';
        results['used_field'] = 'video_kitab_id';
        print('🔍 DIAGNOSIS: Table expects "kitab_id" but we\'re using "video_kitab_id"');
      } else if (errorStr.contains('does not exist') || errorStr.contains('relation')) {
        results['issue_type'] = 'table_missing';
        print('🔍 DIAGNOSIS: The video_episodes table may not exist');
      } else if (errorStr.contains('foreign key') || errorStr.contains('constraint')) {
        results['issue_type'] = 'constraint_violation';
        print('🔍 DIAGNOSIS: Foreign key constraint issue');
      } else {
        results['issue_type'] = 'unknown';
        print('🔍 DIAGNOSIS: Unknown error type');
      }
    }
    
    return results;
  }
  
  /// Test getting next part number (simpler test)
  static Future<Map<String, dynamic>> testGetNextPartNumber(String videoKitabId) async {
    final results = <String, dynamic>{};
    
    print('🔍 Testing getNextPartNumber...');
    
    try {
      final nextPartNumber = await VideoEpisodeService.getNextPartNumber(videoKitabId);
      
      results['success'] = true;
      results['next_part_number'] = nextPartNumber;
      
      print('✅ SUCCESS! Next part number: $nextPartNumber');
      
    } catch (e) {
      results['success'] = false;
      results['error'] = e.toString();
      
      print('❌ getNextPartNumber failed: $e');
      
      // Same error analysis
      final errorStr = e.toString().toLowerCase();
      
      if (errorStr.contains('kitab_id') && !errorStr.contains('video_kitab_id')) {
        results['issue_type'] = 'field_name_mismatch';
        results['expected_field'] = 'kitab_id';
        results['used_field'] = 'video_kitab_id';
        print('🔍 DIAGNOSIS: Query expects "kitab_id" but we\'re using "video_kitab_id"');
      }
    }
    
    return results;
  }
  
  /// Run full diagnostic
  static Future<Map<String, dynamic>> runFullDiagnostic(String videoKitabId) async {
    print('\n' + '='*50);
    print('🏥 FULL EPISODE DIAGNOSTIC STARTED');
    print('='*50);
    
    final results = <String, dynamic>{
      'video_kitab_id': videoKitabId,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    // Test 1: Get next part number (read operation)
    print('\n📋 TEST 1: Get Next Part Number');
    print('-'*30);
    results['test_1_next_part_number'] = await testGetNextPartNumber(videoKitabId);
    
    // Test 2: Create episode (write operation)
    print('\n📋 TEST 2: Create Episode');
    print('-'*30);
    results['test_2_create_episode'] = await testEpisodeCreation(videoKitabId);
    
    print('\n' + '='*50);
    print('🏥 DIAGNOSTIC COMPLETED');
    print('='*50);
    
    // Summary
    final test1Success = results['test_1_next_part_number']['success'] == true;
    final test2Success = results['test_2_create_episode']['success'] == true;
    
    if (test1Success && test2Success) {
      print('✅ RESULT: All tests passed! Episode functionality should work.');
      results['overall_status'] = 'success';
    } else if (!test1Success && !test2Success) {
      print('❌ RESULT: Both tests failed! Likely a table structure issue.');
      results['overall_status'] = 'complete_failure';
    } else {
      print('⚠️  RESULT: Mixed results. Some functionality may work.');
      results['overall_status'] = 'partial_failure';
    }
    
    return results;
  }
}
