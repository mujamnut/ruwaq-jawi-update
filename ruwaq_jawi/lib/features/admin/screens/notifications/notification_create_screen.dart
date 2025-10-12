import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_theme.dart';

class AdminNotificationCreateScreen extends StatefulWidget {
  final Map<String, dynamic>? notification; // null for create, filled for edit

  const AdminNotificationCreateScreen({super.key, this.notification});

  @override
  State<AdminNotificationCreateScreen> createState() =>
      _AdminNotificationCreateScreenState();
}

class _AdminNotificationCreateScreenState
    extends State<AdminNotificationCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();

  String _notificationType = 'broadcast'; // broadcast, personal, group
  String _targetType = 'all'; // all, user, role
  String _selectedRole = 'student'; // student, admin
  String? _selectedUserId;
  DateTime? _expiresAt;
  bool _isActive = true;
  bool _isLoading = false;

  // Metadata
  String _selectedIcon = 'notification';
  String? _actionUrl;
  String? _contentId;

  bool get _isEditing => widget.notification != null;

  @override
  void initState() {
    super.initState();
    _checkAdminAccess();
    _expiresAt = DateTime.now().add(
      const Duration(days: 30),
    ); // Default 30 days
  }

  Future<void> _checkAdminAccess() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) {
        Navigator.of(context).pop();
      }
      return;
    }

    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();

      if (profile == null || profile['role'] != 'admin') {
        if (mounted) {
          Navigator.of(context).pop();
        }
        return;
      }

      // Load existing notification data if editing
      if (_isEditing) {
        _initializeFormData();
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  void _initializeFormData() {
    if (widget.notification == null) return;

    final notif = widget.notification!;
    _titleController.text = notif['title'] ?? '';
    _messageController.text = notif['message'] ?? '';
    _notificationType = notif['type'] ?? 'broadcast';
    _targetType = notif['target_type'] ?? 'all';
    _isActive = notif['is_active'] ?? true;

    if (notif['expires_at'] != null) {
      _expiresAt = DateTime.parse(notif['expires_at']);
    }

    // Parse metadata
    if (notif['metadata'] != null) {
      final metadata = notif['metadata'] as Map<String, dynamic>;
      _selectedIcon = metadata['icon'] ?? 'notification';
      _actionUrl = metadata['action_url'];
      _contentId = metadata['content_id'];
    }

    // Parse target criteria
    if (notif['target_criteria'] != null) {
      final criteria = notif['target_criteria'] as Map<String, dynamic>;
      if (_targetType == 'role') {
        _selectedRole = criteria['role'] ?? 'student';
      } else if (_targetType == 'user') {
        _selectedUserId = criteria['user_id'];
      }
    }

    setState(() {});
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Edit Notifikasi' : 'Buat Notifikasi Baru',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _saveNotification,
              child: Text(
                _isEditing ? 'Kemaskini' : 'Hantar',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Maklumat Asas'),
              const SizedBox(height: 16),
              _buildBasicInfoSection(),

              const SizedBox(height: 24),
              _buildSectionTitle('Jenis & Sasaran'),
              const SizedBox(height: 16),
              _buildTypeAndTargetSection(),

              const SizedBox(height: 24),
              _buildSectionTitle('Tetapan Tambahan'),
              const SizedBox(height: 16),
              _buildAdditionalSettings(),

              const SizedBox(height: 24),
              _buildSectionTitle('Pratonton'),
              const SizedBox(height: 16),
              _buildPreview(),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppTheme.textPrimaryColor,
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        children: [
          // Title Field
          TextFormField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: 'Tajuk Notifikasi *',
              hintText: 'Contoh: E-book Baharu Ditambah!',
              prefixIcon: const HugeIcon(
                icon: HugeIcons.strokeRoundedNotification03,
                color: AppTheme.primaryColor,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Tajuk tidak boleh kosong';
              }
              return null;
            },
            maxLength: 100,
          ),
          const SizedBox(height: 16),

          // Message Field
          TextFormField(
            controller: _messageController,
            decoration: InputDecoration(
              labelText: 'Mesej Notifikasi *',
              hintText: 'Tulis mesej notifikasi anda di sini...',
              prefixIcon: const Padding(
                padding: EdgeInsets.only(bottom: 60),
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedMessage01,
                  color: AppTheme.primaryColor,
                ),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.white,
              alignLabelWithHint: true,
            ),
            maxLines: 4,
            maxLength: 500,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Mesej tidak boleh kosong';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTypeAndTargetSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Notification Type
          const Text(
            'Jenis Notifikasi',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildTypeChip(
                  label: 'Broadcast',
                  value: 'broadcast',
                  icon: HugeIcons.strokeRoundedMegaphone01,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTypeChip(
                  label: 'Personal',
                  value: 'personal',
                  icon: HugeIcons.strokeRoundedUser,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTypeChip(
                  label: 'Group',
                  value: 'group',
                  icon: HugeIcons.strokeRoundedUserMultiple,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),

          // Target Type
          const Text(
            'Sasaran Penerima',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 12),

          _buildTargetTypeSelector(),
        ],
      ),
    );
  }

  Widget _buildTypeChip({
    required String label,
    required String value,
    required IconData icon,
  }) {
    final isSelected = _notificationType == value;

    return InkWell(
      onTap: () {
        setState(() {
          _notificationType = value;
          // Reset target type based on notification type
          if (value == 'broadcast') {
            _targetType = 'all';
          } else if (value == 'personal') {
            _targetType = 'user';
          } else if (value == 'group') {
            _targetType = 'role';
          }
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withValues(alpha: 0.1)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            HugeIcon(
              icon: icon,
              color: isSelected ? AppTheme.primaryColor : Colors.grey,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? AppTheme.primaryColor
                    : Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetTypeSelector() {
    if (_notificationType == 'broadcast') {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Row(
          children: [
            const HugeIcon(
              icon: HugeIcons.strokeRoundedCheckmarkCircle02,
              color: Colors.blue,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Notifikasi ini akan dihantar kepada SEMUA pengguna',
                style: TextStyle(
                  color: Colors.blue.shade900,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_notificationType == 'personal') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pilih Pengguna Tertentu',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 13,
              color: AppTheme.textSecondaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const HugeIcon(
                      icon: HugeIcons.strokeRoundedUser,
                      color: AppTheme.primaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedUserId != null ? 'Pengguna Dipilih' : 'Pilih Pengguna',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppTheme.textPrimaryColor,
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showUserSelector(),
                      icon: const HugeIcon(
                        icon: HugeIcons.strokeRoundedSearch01,
                        size: 16.0,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'Cari Pengguna',
                        style: TextStyle(fontSize: 12, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_selectedUserId != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const HugeIcon(
                          icon: HugeIcons.strokeRoundedUserCheck01,
                          color: AppTheme.primaryColor,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FutureBuilder<String?>(
                            future: _getUserName(_selectedUserId!),
                            builder: (context, snapshot) {
                              return Text(
                                snapshot.data ?? 'Memuatkan...',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.primaryColor,
                                ),
                              );
                            },
                          ),
                        ),
                        IconButton(
                          icon: const HugeIcon(
                            icon: HugeIcons.strokeRoundedCancel01,
                            size: 16.0,
                            color: Colors.red,
                          ),
                          onPressed: () {
                            setState(() {
                              _selectedUserId = null;
                            });
                          },
                          constraints: const BoxConstraints(
                            minWidth: 24,
                            minHeight: 24,
                          ),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    }

    if (_notificationType == 'group') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pilih Kumpulan Pengguna',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 13,
              color: AppTheme.textSecondaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildRoleOption(
                  label: 'Pelajar',
                  value: 'student',
                  icon: HugeIcons.strokeRoundedUserCheck01,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildRoleOption(
                  label: 'Admin',
                  value: 'admin',
                  icon: HugeIcons.strokeRoundedUserStar01,
                ),
              ),
            ],
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildRoleOption({
    required String label,
    required String value,
    required IconData icon,
  }) {
    final isSelected = _selectedRole == value;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedRole = value;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withValues(alpha: 0.1)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HugeIcon(
              icon: icon,
              color: isSelected ? AppTheme.primaryColor : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? AppTheme.primaryColor
                    : Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdditionalSettings() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        children: [
          // Expiry Date
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate:
                    _expiresAt ?? DateTime.now().add(const Duration(days: 30)),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) {
                setState(() {
                  _expiresAt = picked;
                });
              }
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Row(
                children: [
                  const HugeIcon(
                    icon: HugeIcons.strokeRoundedCalendar03,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tarikh Luput',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _expiresAt != null
                              ? '${_expiresAt!.day}/${_expiresAt!.month}/${_expiresAt!.year}'
                              : 'Pilih tarikh',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowRight01,
                    color: Colors.grey,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Active Status Toggle
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Row(
              children: [
                HugeIcon(
                  icon: _isActive
                      ? HugeIcons.strokeRoundedCheckmarkCircle02
                      : HugeIcons.strokeRoundedCancel01,
                  color: _isActive ? Colors.green : Colors.grey,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Status Aktif',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isActive
                            ? 'Notifikasi akan dihantar kepada pengguna'
                            : 'Notifikasi tidak akan dihantar',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _isActive,
                  onChanged: (value) {
                    setState(() {
                      _isActive = value;
                    });
                  },
                  activeThumbColor: AppTheme.primaryColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const HugeIcon(
                icon: HugeIcons.strokeRoundedView,
                color: AppTheme.primaryColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Preview Notifikasi',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Preview Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const HugeIcon(
                    icon: HugeIcons.strokeRoundedNotification03,
                    color: AppTheme.primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _titleController.text.isEmpty
                            ? 'Tajuk Notifikasi'
                            : _titleController.text,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppTheme.textPrimaryColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _messageController.text.isEmpty
                            ? 'Mesej notifikasi akan muncul di sini'
                            : _messageController.text,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                          height: 1.4,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sekarang',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveNotification() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_expiresAt == null) {
      _showSnackBar('Sila pilih tarikh luput', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Prepare target criteria
      Map<String, dynamic> targetCriteria = {};
      if (_notificationType == 'group') {
        targetCriteria = {'role': _selectedRole};
      } else if (_notificationType == 'personal' && _selectedUserId != null) {
        targetCriteria = {'user_id': _selectedUserId};
      }

      // Prepare metadata
      final metadata = {
        'icon': _selectedIcon,
        if (_actionUrl != null) 'action_url': _actionUrl,
        if (_contentId != null) 'content_id': _contentId,
      };

      final notificationData = {
        'type': _notificationType,
        'title': _titleController.text.trim(),
        'message': _messageController.text.trim(),
        'target_type': _targetType,
        'target_criteria': targetCriteria,
        'metadata': metadata,
        'expires_at': _expiresAt!.toIso8601String(),
        'is_active': _isActive,
      };

      if (_isEditing) {
        // Update existing notification
        await Supabase.instance.client
            .from('notifications')
            .update(notificationData)
            .eq('id', widget.notification!['id']);

        _showSnackBar('Notifikasi berjaya dikemaskini!');
      } else {
        // Create new notification
        await Supabase.instance.client
            .from('notifications')
            .insert(notificationData);

        _showSnackBar('Notifikasi baharu berjaya dihantar!');
      }

      if (mounted) {
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      _showSnackBar('Ralat: ${e.toString()}', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showUserSelector() async {
    showDialog(
      context: context,
      builder: (context) => Dialog(
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
                      'Pilih Pengguna',
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
                  hintText: 'Cari pengguna...',
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
                  // Trigger rebuild for search
                  if (mounted) {
                    setState(() {});
                  }
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
                        child: Text('Gagal memuatkan pengguna'),
                      );
                    }

                    final users = snapshot.data as List<Map<String, dynamic>>;

                    return ListView.builder(
                      itemCount: users.length,
                      itemBuilder: (context, index) {
                        final user = users[index];
                        final isSelected = _selectedUserId == user['id'];

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isSelected
                                ? AppTheme.primaryColor
                                : Colors.grey.shade300,
                            child: Text(
                              (user['full_name'] ?? 'U')[0].toUpperCase(),
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
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
                          trailing: isSelected
                              ? const HugeIcon(
                                  icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                                  color: AppTheme.primaryColor,
                                  size: 20.0,
                                )
                              : null,
                          onTap: () {
                            setState(() {
                              _selectedUserId = user['id'] as String;
                            });
                            Navigator.of(context).pop();
                          },
                        );
                      },
                    );
                  },
                ),
              ),

              // Actions
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Pilih satu pengguna',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _loadUsers() async {
    try {
      final users = await Supabase.instance.client
          .from('profiles')
          .select('id, full_name, role')
          .order('full_name', ascending: true);

      return List<Map<String, dynamic>>.from(users as List);
    } catch (e) {
      debugPrint('Error loading users: $e');
      return [];
    }
  }

  Future<String?> _getUserName(String userId) async {
    try {
      final result = await Supabase.instance.client
          .from('profiles')
          .select('full_name')
          .eq('id', userId)
          .maybeSingle();

      return result?['full_name'] as String?;
    } catch (e) {
      debugPrint('Error getting user name: $e');
      return null;
    }
  }
}
