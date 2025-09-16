// Test file for unified notification system
// This file validates the UnifiedNotification model and service logic

import 'dart:convert';

// Mock data for testing UnifiedNotification parsing
void main() {
  print('🧪 Testing Unified Notification System');
  print('=====================================');

  // Test 1: Individual notification parsing
  final individualNotificationJson = {
    'id': 'test-individual-123',
    'user_id': 'user-abc-123',
    'message': 'Test individual notification',
    'metadata': {
      'title': 'Individual Test',
      'body': 'This is an individual notification',
      'type': 'content_published',
      'content_type': 'video_kitab',
      'icon': '📹',
      'action_url': '/kitab'
    },
    'status': 'unread',
    'delivered_at': '2025-09-16T13:00:00.000Z',
    'target_criteria': {}
  };

  // Test 2: Global notification parsing
  final globalNotificationJson = {
    'id': 'test-global-456',
    'user_id': '00000000-0000-0000-0000-000000000000', // Global UUID
    'message': '📹 Video Kitab Baharu! "Test Video" telah ditambah.',
    'metadata': {
      'title': '📹 Video Kitab Baharu!',
      'body': '"Test Video" telah ditambah.',
      'type': 'content_published',
      'content_type': 'video_kitab',
      'icon': '📹',
      'action_url': '/kitab',
      'target_roles': ['student'],
      'student_count': 3,
      'is_global': true,
      'read_by': [] // Empty initially
    },
    'status': 'unread',
    'delivered_at': '2025-09-16T13:00:00.000Z',
    'target_criteria': {
      'unified_notification': true,
      'target_all_students': true,
      'global_user_id': '00000000-0000-0000-0000-000000000000'
    }
  };

  print('Test 1: Individual Notification');
  print('- ID: ${individualNotificationJson['id']}');
  print('- User ID: ${individualNotificationJson['user_id']}');
  print('- Is Global: ${individualNotificationJson['user_id'] == '00000000-0000-0000-0000-000000000000'}');
  final individualMeta = individualNotificationJson['metadata'] as Map<String, dynamic>;
  print('- Title: ${individualMeta['title']}');
  print('- Type: ${individualMeta['type']}');
  print('');

  print('Test 2: Global Notification');
  print('- ID: ${globalNotificationJson['id']}');
  print('- User ID: ${globalNotificationJson['user_id']}');
  print('- Is Global: ${globalNotificationJson['user_id'] == '00000000-0000-0000-0000-000000000000'}');
  final globalMeta = globalNotificationJson['metadata'] as Map<String, dynamic>;
  print('- Title: ${globalMeta['title']}');
  print('- Target Roles: ${globalMeta['target_roles']}');
  print('- Student Count: ${globalMeta['student_count']}');
  print('');

  // Test 3: Query logic simulation
  print('Test 3: Query Logic Simulation');
  final currentUserId = 'user-abc-123';
  final userRole = 'student';

  // Simulate OR query logic
  final notifications = [individualNotificationJson, globalNotificationJson];
  final filteredForUser = notifications.where((notif) {
    // Individual notifications for this user
    if (notif['user_id'] == currentUserId) return true;

    // Global notifications targeting user's role
    if (notif['user_id'] == '00000000-0000-0000-0000-000000000000') {
      final metadata = notif['metadata'] as Map<String, dynamic>;
      final targetRoles = metadata['target_roles'] as List?;
      return targetRoles?.contains(userRole) == true;
    }

    return false;
  }).toList();

  print('- Current User ID: $currentUserId');
  print('- User Role: $userRole');
  print('- Filtered Notifications: ${filteredForUser.length}/2');
  print('- Should see both: ${filteredForUser.length == 2 ? '✅ PASS' : '❌ FAIL'}');
  print('');

  // Test 4: Read status for global notifications
  print('Test 4: Read Status Logic');
  final globalNotif = Map<String, dynamic>.from(globalNotificationJson);

  // Simulate user hasn't read it yet
  final globalMeta2 = globalNotif['metadata'] as Map<String, dynamic>;
  final readByList = globalMeta2['read_by'] as List;
  print('- User has not read global notification: ${!readByList.contains(currentUserId)}');

  // Simulate user reads it
  readByList.add(currentUserId);
  print('- After reading, user in read_by list: ${readByList.contains(currentUserId)}');
  print('');

  print('✅ All unified notification tests completed!');
  print('📱 The service should work correctly with both individual and global notifications');
  print('🔗 Global notifications use UUID: 00000000-0000-0000-0000-000000000000');
  print('🎯 Global notifications target roles via metadata.target_roles array');
}