import '../services/supabase_service.dart';

/// Simple validation rules for form fields
enum ValidationRule {
  required,
  email,
  url,
  integer,
  decimal,
  positive,
  nonNegative,
  minLength,
  maxLength,
}

/// Form field types supported by the auto-generator
enum FormFieldType {
  text,
  textArea,
  number,
  decimal,
  email,
  url,
  switch_,
  dropdown,
  date,
  datetime,
}

/// Database field representation
class DatabaseField {
  final String name;
  final String dataType;
  final bool isNullable;
  final bool isPrimaryKey;
  final FormFieldType formFieldType;
  final List<ValidationRule> validationRules;
  final List<String>? enumValues;
  final String? foreignKeyTable;
  final String? comment;

  DatabaseField({
    required this.name,
    required this.dataType,
    required this.isNullable,
    required this.isPrimaryKey,
    required this.formFieldType,
    required this.validationRules,
    this.enumValues,
    this.foreignKeyTable,
    this.comment,
  });
}

/// Table schema representation
class TableSchema {
  final String tableName;
  final String? description;
  final List<String> primaryKeys;
  final List<DatabaseField> formFields;

  // Computed properties for compatibility
  String get name => tableName;
  List<DatabaseField> get foreignKeyFields => formFields.where((f) => f.foreignKeyTable != null).toList();
  DatabaseField? get primaryKeyField => formFields.where((f) => f.isPrimaryKey).firstOrNull;

  TableSchema({
    required this.tableName,
    this.description,
    required this.primaryKeys,
    required this.formFields,
  });
}

/// Simple database schema analyzer
class SimpleDatabaseSchemaAnalyzer {
  /// Get a simplified schema for common table structures
  static TableSchema getSimpleSchema(String tableName) {
    switch (tableName) {
      case 'categories':
        return TableSchema(
          tableName: 'categories',
          description: 'Content categories management',
          primaryKeys: ['id'],
          formFields: [
            DatabaseField(
              name: 'name',
              dataType: 'text',
              isNullable: false,
              isPrimaryKey: false,
              formFieldType: FormFieldType.text,
              validationRules: [ValidationRule.required],
            ),
            DatabaseField(
              name: 'description',
              dataType: 'text',
              isNullable: true,
              isPrimaryKey: false,
              formFieldType: FormFieldType.textArea,
              validationRules: [],
            ),
            DatabaseField(
              name: 'icon_url',
              dataType: 'text',
              isNullable: true,
              isPrimaryKey: false,
              formFieldType: FormFieldType.url,
              validationRules: [ValidationRule.url],
            ),
            DatabaseField(
              name: 'sort_order',
              dataType: 'integer',
              isNullable: true,
              isPrimaryKey: false,
              formFieldType: FormFieldType.number,
              validationRules: [ValidationRule.nonNegative],
            ),
            DatabaseField(
              name: 'is_active',
              dataType: 'boolean',
              isNullable: true,
              isPrimaryKey: false,
              formFieldType: FormFieldType.switch_,
              validationRules: [],
            ),
          ],
        );

      case 'preview_content':
        return TableSchema(
          tableName: 'preview_content',
          description: 'Preview content management',
          primaryKeys: ['id'],
          formFields: [
            DatabaseField(
              name: 'content_type',
              dataType: 'text',
              isNullable: false,
              isPrimaryKey: false,
              formFieldType: FormFieldType.dropdown,
              validationRules: [ValidationRule.required],
              enumValues: ['video_episode', 'ebook', 'video_kitab'],
            ),
            DatabaseField(
              name: 'content_id',
              dataType: 'uuid',
              isNullable: false,
              isPrimaryKey: false,
              formFieldType: FormFieldType.text,
              validationRules: [ValidationRule.required],
            ),
            DatabaseField(
              name: 'preview_type',
              dataType: 'text',
              isNullable: false,
              isPrimaryKey: false,
              formFieldType: FormFieldType.dropdown,
              validationRules: [ValidationRule.required],
              enumValues: ['free_trial', 'teaser', 'demo', 'sample'],
            ),
            DatabaseField(
              name: 'preview_duration_seconds',
              dataType: 'integer',
              isNullable: true,
              isPrimaryKey: false,
              formFieldType: FormFieldType.number,
              validationRules: [ValidationRule.positive],
            ),
            DatabaseField(
              name: 'preview_pages',
              dataType: 'integer',
              isNullable: true,
              isPrimaryKey: false,
              formFieldType: FormFieldType.number,
              validationRules: [ValidationRule.positive],
            ),
            DatabaseField(
              name: 'preview_description',
              dataType: 'text',
              isNullable: true,
              isPrimaryKey: false,
              formFieldType: FormFieldType.textArea,
              validationRules: [],
            ),
            DatabaseField(
              name: 'sort_order',
              dataType: 'integer',
              isNullable: true,
              isPrimaryKey: false,
              formFieldType: FormFieldType.number,
              validationRules: [ValidationRule.nonNegative],
            ),
            DatabaseField(
              name: 'is_active',
              dataType: 'boolean',
              isNullable: true,
              isPrimaryKey: false,
              formFieldType: FormFieldType.switch_,
              validationRules: [],
            ),
          ],
        );

      default:
        // Return a generic schema for unknown tables
        return TableSchema(
          tableName: tableName,
          description: 'Generic form for $tableName',
          primaryKeys: ['id'],
          formFields: [
            DatabaseField(
              name: 'title',
              dataType: 'text',
              isNullable: false,
              isPrimaryKey: false,
              formFieldType: FormFieldType.text,
              validationRules: [ValidationRule.required],
            ),
            DatabaseField(
              name: 'description',
              dataType: 'text',
              isNullable: true,
              isPrimaryKey: false,
              formFieldType: FormFieldType.textArea,
              validationRules: [],
            ),
            DatabaseField(
              name: 'is_active',
              dataType: 'boolean',
              isNullable: true,
              isPrimaryKey: false,
              formFieldType: FormFieldType.switch_,
              validationRules: [],
            ),
          ],
        );
    }
  }
}