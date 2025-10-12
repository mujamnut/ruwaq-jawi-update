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
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Urus Notifikasi',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        elevation: 0,
        centerTitle: true,
        toolbarHeight: 50,
        leading: IconButton(
          icon: const HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            color: Colors.black87,
            size: 30.0,
          ),
          onPressed: () => context.go('/admin'),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: TabBar(
            controller: _tabController,
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: Colors.grey.shade600,
            indicatorColor: AppTheme.primaryColor,
            indicatorWeight: 2,
            labelStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            tabs: const [
              Tab(
                text: 'Hantar Notifikasi',
              ),
              Tab(
                text: 'Sejarah',
              ),
            ],
          ),
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
          const SizedBox(height: 8),

          // Quick Actions
          const Text(
            'Quick Actions',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          LayoutBuilder(
            builder: (context, constraints) {
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: (constraints.maxWidth - 16) / 2,
                    child: _buildQuickActionCard(
                      'Global Notify',
                      'Send to all users',
                      HugeIcons.strokeRoundedGlobal,
                      Colors.blue,
                      () => _showSendNotificationDialog(sendToAll: true),
                    ),
                  ),
                  SizedBox(
                    width: (constraints.maxWidth - 16) / 2,
                    child: _buildQuickActionCard(
                      'Premium Users',
                      'Send to premium users',
                      HugeIcons.strokeRoundedStar,
                      Colors.purple,
                      () => _showSendNotificationDialog(targetType: 'premium'),
                    ),
                  ),
                  SizedBox(
                    width: (constraints.maxWidth - 16) / 2,
                    child: _buildQuickActionCard(
                      'Free Users',
                      'Send to free users',
                      HugeIcons.strokeRoundedUser,
                      Colors.green,
                      () => _showSendNotificationDialog(targetType: 'free'),
                    ),
                  ),
                  SizedBox(
                    width: (constraints.maxWidth - 16) / 2,
                    child: _buildQuickActionCard(
                      'Custom Target',
                      'Select specific users',
                      HugeIcons.strokeRoundedTarget03,
                      Colors.orange,
                      () => _showSendNotificationDialog(targetType: 'custom'),
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 24),

          // Notification Templates
          const Text(
            'Notification Templates',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          _buildTemplateCard(
            'New Content',
            'Notify users about new content',
            'New content available on Ruwaq Jawi! 📚',
            Colors.green,
          ),
          const SizedBox(height: 12),
          _buildTemplateCard(
            'Subscription',
            'Remind users to upgrade premium',
            'Get full access with premium subscription ⭐',
            Colors.purple,
          ),
          const SizedBox(height: 12),
          _buildTemplateCard(
            'System Update',
            'Notify users about updates',
            'System updated with new features! 🚀',
            Colors.blue,
          ),
          const SizedBox(height: 12),
          _buildTemplateCard(
            'Special Promo',
            'Announce special offers',
            'Limited promo for loyal Ruwaq Jawi users! 🎉',
            Colors.red,
          ),
          const SizedBox(height: 12),
          _buildTemplateCard(
            'Weekly Quiz',
            'Invite users to join quiz',
            'Test your knowledge with our weekly quiz! 🎯',
            Colors.orange,
          ),
          const SizedBox(height: 12),
          _buildTemplateCard(
            'Learning Tips',
            'Share useful tips with users',
            'Helpful Arabic learning tips for today 💡',
            Colors.teal,
          ),
          const SizedBox(height: 12),
          _buildTemplateCard(
            'Live Session',
            'Remind about classes or live sessions',
            "Don't miss our live learning session! 📹",
            Colors.indigo,
          ),
          const SizedBox(height: 12),
          _buildTemplateCard(
            'Hari Raya',
            'Send Hari Raya greetings',
            'Happy Hari Raya Aidilfitri from Ruwaq Jawi! 🌙',
            Colors.pink,
          ),
          const SizedBox(height: 12),
          _buildTemplateCard(
            'Maintenance',
            'Notify about system maintenance',
            'System maintenance scheduled for this date 🔧',
            Colors.grey,
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
      height: 100,
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
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: HugeIcon(icon: icon, color: color, size: 18.0),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                    fontSize: 9,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: HugeIcon(
              icon: _getTemplateIcon(template),
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
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
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
                      fontSize: 11,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedSent,
                size: 18.0,
                color: color,
              ),
              onPressed: () => _showSendNotificationDialog(template: template),
              tooltip: 'Guna Template',
            ),
          ),
        ],
      ),
    );
  }

  IconData _getTemplateIcon(String template) {
    if (template.contains('kandungan baharu')) {
      return HugeIcons.strokeRoundedBook01;
    } else if (template.contains('langganan premium')) {
      return HugeIcons.strokeRoundedStar;
    } else if (template.contains('dikemas kini')) {
      return HugeIcons.strokeRoundedRefresh;
    } else if (template.contains('Promosi terhad')) {
      return HugeIcons.strokeRoundedTag01;
    } else if (template.contains('kuiz mingguan')) {
      return HugeIcons.strokeRoundedGameController02;
    } else if (template.contains('Tips pembelajaran')) {
      return HugeIcons.strokeRoundedIdea01;
    } else if (template.contains('sesi pembelajaran langsung')) {
      return HugeIcons.strokeRoundedVideo01;
    } else if (template.contains('Hari Raya Aidilfitri')) {
      return HugeIcons.strokeRoundedMegaphone01;
    } else if (template.contains('penyenggaraan')) {
      return HugeIcons.strokeRoundedWrench01;
    } else {
      return HugeIcons.strokeRoundedMessage02;
    }
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
    List<Map<String, dynamic>> selectedUsers = [];

    if (template != null) {
      // Set title based on template
      if (template.contains('New content')) {
        titleController.text = 'New Content Available';
      } else if (template.contains('premium subscription')) {
        titleController.text = 'Subscription Reminder';
      } else if (template.contains('new features')) {
        titleController.text = 'System Update';
      } else if (template.contains('Limited promo')) {
        titleController.text = 'Special Promotion';
      } else if (template.contains('weekly quiz')) {
        titleController.text = 'Weekly Quiz';
      } else if (template.contains('Arabic learning')) {
        titleController.text = 'Learning Tips';
      } else if (template.contains('live learning')) {
        titleController.text = 'Live Session Reminder';
      } else if (template.contains('Happy Hari Raya')) {
        titleController.text = 'Hari Raya Greetings';
      } else if (template.contains('maintenance scheduled')) {
        titleController.text = 'System Maintenance';
      }
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
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
                    labelText: 'Target',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Users')),
                    DropdownMenuItem(
                      value: 'premium',
                      child: Text('Premium Users'),
                    ),
                    DropdownMenuItem(
                      value: 'free',
                      child: Text('Free Users'),
                    ),
                    DropdownMenuItem(
                      value: 'custom',
                      child: Text('Select Users'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      selectedTargetType = value ?? 'all';
                      if (selectedTargetType != 'custom') {
                        selectedUsers.clear();
                        selectedUserIds.clear();
                      }
                    });
                  },
                ),
                const SizedBox(height: 16),
                if (selectedTargetType == 'custom') ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Select Users (${selectedUsers.length} selected)',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 11,
                              ),
                            ),
                            TextButton(
                              onPressed: () => _showUserSelectionDialog(
                                selectedUsers,
                                selectedUserIds,
                                setState,
                              ),
                              child: const Text(
                                'Select',
                                style: TextStyle(fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                        if (selectedUsers.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: selectedUsers.map((user) {
                              return Chip(
                                label: Text(
                                  user['full_name'] ?? 'Unknown',
                                  style: const TextStyle(fontSize: 10),
                                ),
                                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                                deleteIcon: const Icon(
                                  HugeIcons.strokeRoundedCancel01,
                                  size: 12,
                                  color: Colors.red,
                                ),
                                onDeleted: () {
                                  setState(() {
                                    selectedUsers.removeWhere((u) => u['id'] == user['id']);
                                    selectedUserIds.remove(user['id']);
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                // Validate title and message
                if (titleController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a title'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                if (messageController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a message'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                if (selectedTargetType == 'custom' && selectedUsers.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please select at least one user'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
                _sendNotification(
                  title: titleController.text.trim(),
                  message: messageController.text.trim(),
                  targetType: selectedTargetType,
                  userIds: selectedUserIds,
                );
                Navigator.of(context).pop();
              },
              child: const Text('Send'),
            ),
          ],
        ),
      ),
    );
  }

  void _showUserSelectionDialog(
    List<Map<String, dynamic>> selectedUsers,
    List<String> selectedUserIds,
    StateSetter setState,
  ) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, dialogSetState) => Dialog(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.8,
            height: MediaQuery.of(context).size.height * 0.7,
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Header
                Row(
                  children: [
                    const HugeIcon(
                      icon: HugeIcons.strokeRoundedUser,
                      color: AppTheme.primaryColor,
                      size: 24.0,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Select Users',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const HugeIcon(
                        icon: HugeIcons.strokeRoundedCancel01,
                        size: 20.0,
                        color: Colors.grey,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Search bar
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search users...',
                    prefixIcon: const HugeIcon(
                      icon: HugeIcons.strokeRoundedSearch01,
                      size: 20.0,
                      color: Colors.grey,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onChanged: (value) {
                    dialogSetState(() {});
                  },
                ),
                const SizedBox(height: 16),

                // User list
                Expanded(
                  child: FutureBuilder(
                    future: _loadUsers(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }

                      if (!snapshot.hasData || snapshot.hasError) {
                        return const Center(
                          child: Text('Failed to load users'),
                        );
                      }

                      final users = snapshot.data as List<Map<String, dynamic>>;

                      return ListView.builder(
                        itemCount: users.length,
                        itemBuilder: (context, index) {
                          final user = users[index];
                          final isSelected = selectedUserIds.contains(user['id']);

                          return CheckboxListTile(
                            value: isSelected,
                            onChanged: (bool? value) {
                              setState(() {
                                dialogSetState(() {
                                  if (value == true) {
                                    selectedUsers.add(user);
                                    selectedUserIds.add(user['id'] as String);
                                  } else {
                                    selectedUsers.removeWhere((u) => u['id'] == user['id']);
                                    selectedUserIds.remove(user['id'] as String);
                                  }
                                });
                              });
                            },
                            title: Text(
                              user['full_name'] ?? 'Unknown User',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: user['role'] != null
                                ? Text(
                                    'Role: ${user['role']}',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                                  )
                                : null,
                            secondary: isSelected
                                ? CircleAvatar(
                                    backgroundColor: AppTheme.primaryColor,
                                    child: Text(
                                      (selectedUserIds.indexOf(user['id'] as String) + 1)
                                          .toString(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  )
                                : null,
                          );
                        },
                      );
                    },
                  ),
                ),

                // Actions
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${selectedUsers.length} users selected',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            setState(() {
                              dialogSetState(() {
                                selectedUsers.clear();
                                selectedUserIds.clear();
                              });
                            });
                          },
                          child: const Text(
                            'Clear',
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text(
                            'Done',
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _loadUsers() async {
    try {
      final users = await SupabaseService.from('profiles')
          .select('id, full_name, role')
          .order('full_name', ascending: true);

      return List<Map<String, dynamic>>.from(users as List);
    } catch (e) {
      debugPrint('Error loading users: $e');
      return [];
    }
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
