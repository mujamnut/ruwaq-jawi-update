import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../../core/services/supabase_service.dart';
import '../../../../core/services/enhanced_notification_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../widgets/admin_bottom_nav.dart';
import 'notification_create_screen.dart';

class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  State<AdminNotificationsScreen> createState() =>
      _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen>
    with TickerProviderStateMixin {
  List<Map<String, dynamic>> _notifications = [];
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  String? _error;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkAdminAccess();
  }

  Future<void> _checkAdminAccess() async {
    final user = SupabaseService.currentUser;
    if (user == null) {
      if (mounted) {
        context.go('/login');
      }
      return;
    }

    try {
      final profile = await SupabaseService.from(
        'profiles',
      ).select('role').eq('id', user.id).maybeSingle();

      if (profile == null || profile['role'] != 'admin') {
        if (mounted) {
          context.go('/home');
        }
        return;
      }

      _loadData();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Akses ditolak. Anda tidak mempunyai kebenaran admin.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _error = null;
        _isLoading = true;
      });

      // Load notifications from enhanced system only, and users in parallel
      final [enhancedNotificationsData, usersData] = await Future.wait([
        SupabaseService.from('notifications')
            .select('*, notification_reads(*)')
            .order('created_at', ascending: false)
            .limit(100),
        SupabaseService.from(
          'profiles',
        ).select('id, full_name, role').order('full_name', ascending: true),
      ]);

      // Convert enhanced system notifications for display
      final allNotifications = <Map<String, dynamic>>[];

      for (final notification in enhancedNotificationsData as List) {
        allNotifications.add({
          'id': notification['id'],
          'user_id': notification['target_type'] == 'all'
              ? null
              : 'enhanced_system',
          'message': notification['message'],
          'metadata': {
            'title': notification['title'],
            'body': notification['message'],
            'target_type': notification['target_type'],
            'source': 'enhanced_system',
            'created_at': notification['created_at'],
            ...(notification['metadata'] as Map<String, dynamic>? ?? {}),
          },
          'delivered_at': notification['created_at'],
        });
      }

      // Sort combined notifications by date
      allNotifications.sort((a, b) {
        final aDate = DateTime.parse(a['delivered_at']);
        final bDate = DateTime.parse(b['delivered_at']);
        return bDate.compareTo(aDate);
      });

      setState(() {
        _notifications = allNotifications;
        _users = List<Map<String, dynamic>>.from(usersData);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Gagal memuatkan data: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        title: const Text('Urus Notifikasi'),
        elevation: 0,
        leading: IconButton(
          icon: const HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            color: Colors.white,
            size: 20.0,
          ),
          onPressed: () => context.go('/admin'),
        ),
        actions: [
          IconButton(
            icon: const HugeIcon(
              icon: HugeIcons.strokeRoundedRefresh,
              color: Colors.white,
              size: 24.0,
            ),
            onPressed: _loadData,
            tooltip: 'Muat Semula',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedNotification03,
                color: Colors.white,
                size: 20.0,
              ),
              text: 'Hantar Notifikasi',
            ),
            Tab(
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedNotificationBlock02,
                color: Colors.white,
                size: 20.0,
              ),
              text: 'Sejarah',
            ),
          ],
        ),
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AdminNotificationCreateScreen(),
            ),
          );

          // Reload data if notification was created
          if (result == true && mounted) {
            _loadData();
          }
        },
        backgroundColor: AppTheme.primaryColor,
        icon: const HugeIcon(
          icon: HugeIcons.strokeRoundedAdd01,
          color: Colors.white,
          size: 20.0,
        ),
        label: const Text(
          'Buat Notifikasi',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      bottomNavigationBar: const AdminBottomNav(currentIndex: 1),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Memuatkan data...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const HugeIcon(
              icon: HugeIcons.strokeRoundedAlert02,
              size: 64.0,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Ralat',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondaryColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ShadButton(onPressed: _loadData, child: const Text('Cuba Lagi')),
          ],
        ),
      );
    }

    return TabBarView(
      controller: _tabController,
      children: [_buildSendNotificationTab(), _buildHistoryTab()],
    );
  }

  Widget _buildSendNotificationTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primaryColor.withValues(alpha: 0.1),
                  AppTheme.primaryColor.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.primaryColor.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const HugeIcon(
                    icon: HugeIcons.strokeRoundedNotification03,
                    color: AppTheme.primaryColor,
                    size: 24.0,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hantar Notifikasi',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Hantar notifikasi kepada pengguna aplikasi',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Quick Actions
          const Text(
            'Tindakan Pantas',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.8,
            children: [
              _buildQuickActionCard(
                'Notifikasi Global',
                'Hantar ke semua pengguna',
                HugeIcons.strokeRoundedGlobal,
                Colors.blue,
                () => _showSendNotificationDialog(sendToAll: true),
              ),
              _buildQuickActionCard(
                'Premium Users',
                'Hantar ke pengguna premium',
                HugeIcons.strokeRoundedStar,
                Colors.purple,
                () => _showSendNotificationDialog(targetType: 'premium'),
              ),
              _buildQuickActionCard(
                'Free Users',
                'Hantar ke pengguna percuma',
                HugeIcons.strokeRoundedUser,
                Colors.green,
                () => _showSendNotificationDialog(targetType: 'free'),
              ),
              _buildQuickActionCard(
                'Custom Target',
                'Pilih pengguna tertentu',
                HugeIcons.strokeRoundedTarget03,
                Colors.orange,
                () => _showSendNotificationDialog(targetType: 'custom'),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Notification Templates
          const Text(
            'Template Notifikasi',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          _buildTemplateCard(
            'Kandungan Baharu',
            'Beritahu pengguna tentang kandungan baharu',
            'Ada kandungan baharu tersedia di Ruwaq Jawi! 📚',
            Colors.green,
          ),
          const SizedBox(height: 12),
          _buildTemplateCard(
            'Peringatan Langganan',
            'Ingatkan pengguna untuk melanggan premium',
            'Dapatkan akses penuh dengan langganan premium ⭐',
            Colors.purple,
          ),
          const SizedBox(height: 12),
          _buildTemplateCard(
            'Kemaskini Sistem',
            'Beritahu pengguna tentang kemaskini',
            'Sistem telah dikemas kini dengan ciri-ciri baharu! 🚀',
            Colors.blue,
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: _notifications.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedNotificationOff01,
                    size: 64.0,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Tiada Sejarah Notifikasi',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Notifikasi yang dihantar akan dipaparkan di sini',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _notifications.length,
              itemBuilder: (context, index) {
                final notification = _notifications[index];
                return _buildNotificationHistoryCard(notification);
              },
            ),
    );
  }

  Widget _buildQuickActionCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          splashColor: color.withValues(alpha: 0.1),
          highlightColor: color.withValues(alpha: 0.05),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: HugeIcon(icon: icon, color: color, size: 20.0),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTemplateCard(
    String title,
    String description,
    String template,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedMessage02,
              color: color,
              size: 20.0,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Text(
                    template,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const HugeIcon(
              icon: HugeIcons.strokeRoundedSent,
              size: 20.0,
              color: Colors.grey,
            ),
            onPressed: () => _showSendNotificationDialog(template: template),
            tooltip: 'Guna Template',
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationHistoryCard(Map<String, dynamic> notification) {
    final metadata = notification['metadata'] as Map<String, dynamic>? ?? {};
    final deliveredAt = DateTime.parse(notification['delivered_at']);
    final timeAgo = _formatTimeAgo(deliveredAt);

    final title = metadata['title'] ?? 'Notifikasi';
    final body = metadata['body'] ?? notification['message'] ?? '';
    final targetType = metadata['target_type'] ?? 'unknown';
    final isGlobal =
        notification['user_id'] == null ||
        notification['user_id'] == '00000000-0000-0000-0000-000000000000';
    final isEnhancedSystem = metadata['source'] == 'enhanced_system';

    Color typeColor;
    IconData typeIcon;
    String typeText;

    if (isGlobal) {
      typeColor = Colors.blue;
      typeIcon = HugeIcons.strokeRoundedGlobal;
      typeText = 'Global';
    } else if (targetType == 'premium') {
      typeColor = Colors.purple;
      typeIcon = HugeIcons.strokeRoundedStar;
      typeText = 'Premium';
    } else if (targetType == 'free') {
      typeColor = Colors.green;
      typeIcon = HugeIcons.strokeRoundedUser;
      typeText = 'Free';
    } else {
      typeColor = Colors.orange;
      typeIcon = HugeIcons.strokeRoundedTarget03;
      typeText = 'Custom';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: HugeIcon(icon: typeIcon, color: typeColor, size: 24.0),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 6),
              Text(
                body,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: typeColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      typeText,
                      style: TextStyle(
                        fontSize: 11,
                        color: typeColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (isEnhancedSystem) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.teal.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: Colors.teal.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        'V2',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.teal,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    timeAgo,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSendNotificationDialog({
    bool sendToAll = false,
    String? targetType,
    String? template,
  }) {
    final titleController = TextEditingController();
    final messageController = TextEditingController(text: template);
    String selectedTargetType = targetType ?? 'all';
    List<String> selectedUserIds = [];

    if (template != null) {
      // Set title based on template
      if (template.contains('kandungan baharu')) {
        titleController.text = 'Kandungan Baharu Tersedia';
      } else if (template.contains('langganan premium')) {
        titleController.text = 'Peringatan Langganan';
      } else if (template.contains('dikemas kini')) {
        titleController.text = 'Kemaskini Sistem';
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hantar Notifikasi'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Tajuk Notifikasi',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: messageController,
                decoration: const InputDecoration(
                  labelText: 'Mesej',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedTargetType,
                decoration: const InputDecoration(
                  labelText: 'Sasaran',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('Semua Pengguna')),
                  DropdownMenuItem(
                    value: 'premium',
                    child: Text('Pengguna Premium'),
                  ),
                  DropdownMenuItem(
                    value: 'free',
                    child: Text('Pengguna Percuma'),
                  ),
                  DropdownMenuItem(
                    value: 'custom',
                    child: Text('Pilih Pengguna'),
                  ),
                ],
                onChanged: (value) {
                  selectedTargetType = value ?? 'all';
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              _sendNotification(
                title: titleController.text,
                message: messageController.text,
                targetType: selectedTargetType,
                userIds: selectedUserIds,
              );
              Navigator.of(context).pop();
            },
            child: const Text('Hantar'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendNotification({
    required String title,
    required String message,
    required String targetType,
    List<String>? userIds,
  }) async {
    try {
      final metadata = {
        'type': 'admin_announcement',
        'sub_type': 'admin_notification',
        'icon': '📢',
        'priority': 'normal',
        'target_type': targetType,
        'sent_by_admin': true,
        'sent_at': DateTime.now().toIso8601String(),
        'source': 'admin_notifications_screen',
      };

      if (targetType == 'all') {
        // Send global broadcast notification using enhanced service
        final success =
            await EnhancedNotificationService.createBroadcastNotification(
              title: title,
              message: message,
              metadata: metadata,
              targetRoles: [
                'student',
                'admin',
              ], // Include all roles for global notifications
            );

        if (!success) {
          throw Exception(
            'Failed to create broadcast notification using enhanced service',
          );
        }
      } else if (targetType == 'premium' || targetType == 'free') {
        // Send broadcast notification with specific target roles using enhanced service
        List<String> targetRoles = ['student']; // Default to students

        final success =
            await EnhancedNotificationService.createBroadcastNotification(
              title: title,
              message: message,
              metadata: {
                ...metadata,
                'subscription_filter':
                    targetType, // Add filter for enhanced processing
              },
              targetRoles: targetRoles,
            );

        if (!success) {
          throw Exception(
            'Failed to create targeted broadcast notification using enhanced service',
          );
        }
      } else {
        // Custom user selection - send individual notifications
        final targetUserIds = userIds ?? [];

        int successCount = 0;
        for (String userId in targetUserIds) {
          final success =
              await EnhancedNotificationService.createPersonalNotification(
                userId: userId,
                title: title,
                message: message,
                metadata: metadata,
              );

          if (success) {
            successCount++;
          }
        }

        if (successCount == 0 && targetUserIds.isNotEmpty) {
          throw Exception('Failed to send any personal notifications');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Notifikasi "$title" berjaya dihantar menggunakan enhanced system',
            ),
            backgroundColor: AppTheme.primaryColor,
          ),
        );
        _loadData(); // Refresh history
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menghantar notifikasi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minit lalu';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} jam lalu';
    } else if (difference.inDays < 30) {
      return '${difference.inDays} hari lalu';
    } else {
      final months = (difference.inDays / 30).floor();
      return '$months bulan lalu';
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
