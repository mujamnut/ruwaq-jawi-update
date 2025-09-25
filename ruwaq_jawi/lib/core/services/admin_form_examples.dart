import 'package:flutter/material.dart';
import '../widgets/auto_generated_form.dart';
import '../services/simple_database_schema_analyzer.dart';
import '../../features/admin/screens/generic_admin_form_screen.dart';

/// Examples of how to use auto-generated forms for different tables
class AdminFormExamples {

  /// Example: Category Form with custom field configurations
  static Widget buildCategoryForm(BuildContext context) {
    return const GenericAdminFormScreen(
      tableName: 'categories',
      fieldConfigs: {
        'name': FormFieldConfig(
          label: 'Category Name',
          placeholder: 'Enter category name',
          additionalValidations: [ValidationRule.required],
        ),
        'description': FormFieldConfig(
          label: 'Description',
          placeholder: 'Optional category description',
        ),
        'icon_url': FormFieldConfig(
          label: 'Icon URL',
          placeholder: 'https://example.com/icon.png',
          additionalValidations: [ValidationRule.url],
        ),
        'sort_order': FormFieldConfig(
          label: 'Sort Order',
          placeholder: '0',
        ),
        'is_active': FormFieldConfig(
          label: 'Active Category',
          placeholder: 'Enable/disable this category',
        ),
      },
      hiddenFields: ['id', 'created_at', 'updated_at'],
      title: 'Category Management',
    );
  }

  /// Example: Ebook Form with file upload fields
  static Widget buildEbookForm(BuildContext context) {
    return const GenericAdminFormScreen(
      tableName: 'ebooks',
      fieldConfigs: {
        'title': FormFieldConfig(
          label: 'Ebook Title',
          placeholder: 'Enter ebook title',
          additionalValidations: [ValidationRule.required],
        ),
        'author': FormFieldConfig(
          label: 'Author Name',
          placeholder: 'Enter author name',
        ),
        'description': FormFieldConfig(
          label: 'Description',
          placeholder: 'Brief description of the ebook content',
        ),
        'category_id': FormFieldConfig(
          label: 'Category',
          // Will automatically create dropdown from categories table
        ),
        'pdf_url': FormFieldConfig(
          label: 'PDF File',
          placeholder: 'Upload PDF file...',
          additionalValidations: [ValidationRule.required, ValidationRule.url],
        ),
        'thumbnail_url': FormFieldConfig(
          label: 'Thumbnail Image',
          placeholder: 'Upload thumbnail image...',
        ),
        'total_pages': FormFieldConfig(
          label: 'Total Pages',
          placeholder: '0',
          additionalValidations: [ValidationRule.positive],
        ),
        'is_premium': FormFieldConfig(
          label: 'Premium Content',
          placeholder: 'Require subscription to access',
        ),
        'is_active': FormFieldConfig(
          label: 'Active Ebook',
          placeholder: 'Enable/disable this ebook',
        ),
      },
      hiddenFields: [
        'id',
        'created_at',
        'updated_at',
        'pdf_storage_path',
        'pdf_file_size',
      ],
      title: 'Ebook Management',
    );
  }

  /// Example: Video Kitab Form with YouTube integration
  static Widget buildVideoKitabForm(BuildContext context) {
    return const GenericAdminFormScreen(
      tableName: 'video_kitab',
      fieldConfigs: {
        'title': FormFieldConfig(
          label: 'Video Kitab Title',
          placeholder: 'Enter video kitab title',
          additionalValidations: [ValidationRule.required],
        ),
        'author': FormFieldConfig(
          label: 'Author/Speaker',
          placeholder: 'Enter author or speaker name',
        ),
        'description': FormFieldConfig(
          label: 'Description',
          placeholder: 'Description of the video content',
        ),
        'category_id': FormFieldConfig(
          label: 'Category',
        ),
        'youtube_playlist_id': FormFieldConfig(
          label: 'YouTube Playlist ID',
          placeholder: 'PLxxxxxxxxxxxxxxxxxx',
        ),
        'youtube_playlist_url': FormFieldConfig(
          label: 'YouTube Playlist URL',
          placeholder: 'https://youtube.com/playlist?list=...',
          additionalValidations: [ValidationRule.url],
        ),
        'pdf_url': FormFieldConfig(
          label: 'Companion PDF (Optional)',
          placeholder: 'PDF file URL if available',
        ),
        'thumbnail_url': FormFieldConfig(
          label: 'Thumbnail Image',
          placeholder: 'Upload thumbnail...',
        ),
        'is_premium': FormFieldConfig(
          label: 'Premium Content',
        ),
        'auto_sync_enabled': FormFieldConfig(
          label: 'Auto Sync from YouTube',
          placeholder: 'Automatically sync new videos',
        ),
        'is_active': FormFieldConfig(
          label: 'Active Video Kitab',
        ),
      },
      hiddenFields: [
        'id',
        'created_at',
        'updated_at',
        'total_videos',
        'total_duration_minutes',
        'views_count',
        'last_synced_at',
        'pdf_storage_path',
        'pdf_file_size',
        'total_pages',
      ],
      title: 'Video Kitab Management',
    );
  }

  /// Example: User Subscription Form
  static Widget buildSubscriptionForm(BuildContext context) {
    return const GenericAdminFormScreen(
      tableName: 'user_subscriptions',
      fieldConfigs: {
        'user_id': FormFieldConfig(
          label: 'User',
          // Will create dropdown from users/profiles
        ),
        'subscription_plan_id': FormFieldConfig(
          label: 'Subscription Plan',
          // Will create dropdown from subscription_plans
        ),
        'status': FormFieldConfig(
          label: 'Status',
          // Will create dropdown from enum values
        ),
        'start_date': FormFieldConfig(
          label: 'Start Date',
          placeholder: 'YYYY-MM-DD',
        ),
        'end_date': FormFieldConfig(
          label: 'End Date',
          placeholder: 'YYYY-MM-DD',
        ),
        'amount': FormFieldConfig(
          label: 'Amount',
          placeholder: '0.00',
          additionalValidations: [ValidationRule.nonNegative],
        ),
        'currency': FormFieldConfig(
          label: 'Currency',
          placeholder: 'MYR',
        ),
      },
      hiddenFields: [
        'id',
        'created_at',
        'updated_at',
        'payment_id',
        'user_name', // Auto-populated from user selection
      ],
      title: 'Subscription Management',
    );
  }

  /// Example: Notification Form
  static Widget buildNotificationForm(BuildContext context) {
    return const GenericAdminFormScreen(
      tableName: 'notifications',
      fieldConfigs: {
        'type': FormFieldConfig(
          label: 'Notification Type',
          // Will create dropdown from enum: broadcast, personal, group
        ),
        'title': FormFieldConfig(
          label: 'Title',
          placeholder: 'Notification title',
          additionalValidations: [ValidationRule.required],
        ),
        'message': FormFieldConfig(
          label: 'Message',
          placeholder: 'Notification message content',
          additionalValidations: [ValidationRule.required],
        ),
        'target_type': FormFieldConfig(
          label: 'Target Type',
          // Will create dropdown from enum: all, user, role
        ),
        'target_criteria': FormFieldConfig(
          label: 'Target Criteria (JSON)',
          placeholder: '{"role": "student"} or {"user_ids": [...]}',
        ),
        'metadata': FormFieldConfig(
          label: 'Metadata (JSON)',
          placeholder: '{"icon": "info", "action_url": "..."}',
        ),
        'expires_at': FormFieldConfig(
          label: 'Expires At',
          placeholder: 'YYYY-MM-DD HH:MM:SS',
        ),
        'is_active': FormFieldConfig(
          label: 'Active Notification',
        ),
      },
      hiddenFields: ['id', 'created_at'],
      title: 'Notification Management',
    );
  }

  /// NEW: Preview Content Management Form
  static Widget buildPreviewContentForm(BuildContext context, {String? recordId}) {
    return GenericAdminFormScreen(
      tableName: 'preview_content',
      recordId: recordId,
      fieldConfigs: const {
        'content_type': FormFieldConfig(
          label: 'Content Type',
          placeholder: 'Select content type',
          additionalValidations: [ValidationRule.required],
          // Will auto-generate dropdown from enum: video_episode, ebook, video_kitab
        ),
        'content_id': FormFieldConfig(
          label: 'Content',
          placeholder: 'Select content item',
          additionalValidations: [ValidationRule.required],
          // This will need a custom content selector based on content_type
        ),
        'preview_type': FormFieldConfig(
          label: 'Preview Type',
          placeholder: 'Select preview type',
          additionalValidations: [ValidationRule.required],
          // Will auto-generate dropdown from enum: free_trial, teaser, demo, sample
        ),
        'preview_duration_seconds': FormFieldConfig(
          label: 'Preview Duration (seconds)',
          placeholder: '60',
          // Only for video content
        ),
        'preview_pages': FormFieldConfig(
          label: 'Preview Pages',
          placeholder: '5',
          // Only for ebook content
        ),
        'preview_description': FormFieldConfig(
          label: 'Preview Description',
          placeholder: 'Optional description of what this preview shows',
        ),
        'sort_order': FormFieldConfig(
          label: 'Sort Order',
          placeholder: '0',
        ),
        'is_active': FormFieldConfig(
          label: 'Active Preview',
          placeholder: 'Enable/disable this preview',
        ),
      },
      hiddenFields: [
        'id',
        'created_at',
        'updated_at',
        'content_title',
        'content_thumbnail_url',
        'category_name',
      ],
      title: recordId == null ? 'Add Preview Content' : 'Edit Preview Content',
    );
  }

  /// Example: How to navigate to auto-generated forms
  static void showExampleNavigations(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Auto-Generated Form Examples'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.category),
                title: const Text('Categories'),
                subtitle: const Text('Manage content categories'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => buildCategoryForm(context),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.book),
                title: const Text('Ebooks'),
                subtitle: const Text('Manage ebook content'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => buildEbookForm(context),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.video_library),
                title: const Text('Video Kitab'),
                subtitle: const Text('Manage video content'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => buildVideoKitabForm(context),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.subscriptions),
                title: const Text('Subscriptions'),
                subtitle: const Text('Manage user subscriptions'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => buildSubscriptionForm(context),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.notifications),
                title: const Text('Notifications'),
                subtitle: const Text('Create and manage notifications'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => buildNotificationForm(context),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.preview),
                title: const Text('Preview Content'),
                subtitle: const Text('Manage content previews'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => buildPreviewContentForm(context),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}