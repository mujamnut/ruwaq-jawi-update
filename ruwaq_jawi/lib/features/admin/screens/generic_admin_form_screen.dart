import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/services/simple_database_schema_analyzer.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/widgets/auto_generated_form.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/admin_bottom_nav.dart';

/// Generic admin form screen that works with any table
class GenericAdminFormScreen extends StatefulWidget {
  final String tableName;
  final String? recordId;
  final Map<String, dynamic>? initialData;
  final Map<String, FormFieldConfig>? fieldConfigs;
  final List<String>? hiddenFields;
  final String? title;

  const GenericAdminFormScreen({
    super.key,
    required this.tableName,
    this.recordId,
    this.initialData,
    this.fieldConfigs,
    this.hiddenFields,
    this.title,
  });

  @override
  State<GenericAdminFormScreen> createState() => _GenericAdminFormScreenState();
}

class _GenericAdminFormScreenState extends State<GenericAdminFormScreen> {
  TableSchema? _schema;
  Map<String, dynamic>? _recordData;
  bool _isLoading = false;
  bool _isInitialLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    try {
      setState(() {
        _isInitialLoading = true;
        _error = null;
      });

      // Check admin access
      await _checkAdminAccess();

      // Get simple table schema
      _schema = SimpleDatabaseSchemaAnalyzer.getSimpleSchema(widget.tableName);

      // Load existing record if editing
      if (widget.recordId != null) {
        await _loadRecord();
      }

      setState(() {
        _isInitialLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isInitialLoading = false;
      });
    }
  }

  Future<void> _checkAdminAccess() async {
    final user = SupabaseService.currentUser;
    if (user == null) {
      if (mounted) {
        context.go('/auth/login');
      }
      return;
    }

    try {
      final profile = await SupabaseService.client
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .single();

      if (profile['role'] != 'admin') {
        throw Exception('Access denied. Admin role required.');
      }
    } catch (e) {
      throw Exception('Failed to verify admin access: $e');
    }
  }

  Future<void> _loadRecord() async {
    try {
      final primaryKeyField = _schema?.primaryKeyField;
      if (primaryKeyField == null) {
        throw Exception('No primary key found for table ${widget.tableName}');
      }

      final data = await SupabaseService.client
          .from(widget.tableName)
          .select('*')
          .eq(primaryKeyField.name, widget.recordId!)
          .single();

      setState(() {
        _recordData = data;
      });
    } catch (e) {
      throw Exception('Failed to load record: $e');
    }
  }

  Future<void> _saveRecord(Map<String, dynamic> formData) async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Clean up null values and prepare data
      final cleanData = <String, dynamic>{};
      formData.forEach((key, value) {
        if (value != null && value != '') {
          cleanData[key] = value;
        }
      });

      // Add timestamps
      if (widget.recordId == null) {
        // Creating new record
        cleanData['created_at'] = DateTime.now().toIso8601String();
      }
      cleanData['updated_at'] = DateTime.now().toIso8601String();

      if (widget.recordId != null) {
        // Update existing record
        final primaryKeyField = _schema?.primaryKeyField;
        if (primaryKeyField == null) {
          throw Exception('No primary key found for update operation');
        }

        await SupabaseService.client
            .from(widget.tableName)
            .update(cleanData)
            .eq(primaryKeyField.name, widget.recordId!);
      } else {
        // Insert new record
        await SupabaseService.client
            .from(widget.tableName)
            .insert(cleanData);
      }

      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.recordId != null
                  ? '${_formatTableName(widget.tableName)} updated successfully'
                  : '${_formatTableName(widget.tableName)} created successfully',
            ),
            backgroundColor: AppTheme.successColor,
          ),
        );

        // Navigate back
        context.pop();
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving record: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          widget.title ?? _buildDefaultTitle(),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimaryColor,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            HugeIcons.strokeRoundedArrowLeft02,
            color: AppTheme.textPrimaryColor,
          ),
          onPressed: () => context.pop(),
        ),
      ),
      body: _buildBody(),
      bottomNavigationBar: const AdminBottomNav(currentIndex: 1),
    );
  }

  Widget _buildBody() {
    if (_isInitialLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: AppTheme.primaryColor,
            ),
            SizedBox(height: 16),
            Text(
              'Loading form...',
              style: TextStyle(
                color: AppTheme.textSecondaryColor,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                HugeIcons.strokeRoundedAlert02,
                size: 64,
                color: AppTheme.errorColor,
              ),
              const SizedBox(height: 16),
              Text(
                'Error Loading Form',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(
                  color: AppTheme.textSecondaryColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _initializeScreen,
                icon: const Icon(HugeIcons.strokeRoundedRefresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_schema == null) {
      return const Center(
        child: Text(
          'No schema available',
          style: TextStyle(color: AppTheme.textSecondaryColor),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: AutoGeneratedForm(
          schema: _schema!,
          initialData: widget.initialData ?? _recordData,
          fieldConfigs: widget.fieldConfigs,
          hiddenFields: widget.hiddenFields,
          isLoading: _isLoading,
          onSave: _saveRecord,
          onCancel: () => context.pop(),
        ),
      ),
    );
  }

  String _buildDefaultTitle() {
    final isEditing = widget.recordId != null;
    final tableName = _formatTableName(widget.tableName);
    return isEditing ? 'Edit $tableName' : 'Add New $tableName';
  }

  String _formatTableName(String tableName) {
    return tableName
        .split('_')
        .map((word) => word.substring(0, 1).toUpperCase() + word.substring(1))
        .join(' ');
  }
}

/// Helper class to easily navigate to generic admin forms
class AdminFormNavigator {
  static void navigateToForm(
    BuildContext context,
    String tableName, {
    String? recordId,
    Map<String, dynamic>? initialData,
    Map<String, FormFieldConfig>? fieldConfigs,
    List<String>? hiddenFields,
    String? title,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => GenericAdminFormScreen(
          tableName: tableName,
          recordId: recordId,
          initialData: initialData,
          fieldConfigs: fieldConfigs,
          hiddenFields: hiddenFields,
          title: title,
        ),
      ),
    );
  }

  /// Quick access methods for common tables
  static void navigateToCategoryForm(
    BuildContext context, {
    String? categoryId,
    Map<String, dynamic>? initialData,
  }) {
    navigateToForm(
      context,
      'categories',
      recordId: categoryId,
      initialData: initialData,
      fieldConfigs: {
        'icon_url': FormFieldConfig(
          label: 'Icon URL',
          placeholder: 'https://example.com/icon.png',
        ),
        'sort_order': FormFieldConfig(
          label: 'Sort Order',
          placeholder: '0',
        ),
      },
      hiddenFields: ['id', 'created_at', 'updated_at'],
    );
  }

  static void navigateToEbookForm(
    BuildContext context, {
    String? ebookId,
    Map<String, dynamic>? initialData,
  }) {
    navigateToForm(
      context,
      'ebooks',
      recordId: ebookId,
      initialData: initialData,
      fieldConfigs: {
        'category_id': FormFieldConfig(
          label: 'Category',
        ),
        'pdf_url': FormFieldConfig(
          label: 'PDF File URL',
          placeholder: 'Upload PDF file...',
        ),
        'thumbnail_url': FormFieldConfig(
          label: 'Thumbnail Image',
          placeholder: 'Upload thumbnail...',
        ),
      },
      hiddenFields: ['id', 'created_at', 'updated_at', 'pdf_storage_path'],
    );
  }
}