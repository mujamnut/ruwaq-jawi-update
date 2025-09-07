// Debug file to help identify dashboard errors
// Run this with: dart debug_dashboard.dart

void main() {
  print('=== DEBUG DASHBOARD ===');
  print('1. Check if this file runs without errors');
  
  // Test basic Dart operations
  try {
    final Map<String, dynamic> testMap = {
      'totalUsers': 0,
      'activeSubscriptions': 0,
      'inactiveUsers': 0,
    };
    print('2. Basic map operations work: $testMap');
    
    // Test list operations
    final List<String> testList = ['id1', 'id2', 'id3'];
    final String formatted = '(${testList.map((id) => '"$id"').join(',')})';
    print('3. String formatting works: $formatted');
    
    // Test date operations
    final DateTime now = DateTime.now();
    final DateTime startOfMonth = DateTime(now.year, now.month, 1);
    print('4. Date operations work: $startOfMonth');
    
    print('5. All basic operations successful!');
    print('The error might be in Supabase connection or specific API calls.');
    
  } catch (e) {
    print('ERROR: $e');
  }
  
  print('=== DEBUG COMPLETE ===');
}
