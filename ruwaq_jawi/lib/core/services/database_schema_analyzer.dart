import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

/// Database field information
class DatabaseField {
  final String name;
  final String dataType;
  final bool isNullable;
  final String? defaultValue;
  final bool isPrimaryKey;
  final bool isUnique;
  final List<String> checkConstraints;
  final String? foreignKeyTable;
  final String? foreignKeyColumn;
  final List<String>? enumValues;
  final String? comment;

  DatabaseField({
    required this.name,
    required this.dataType,
    required this.isNullable,
    this.defaultValue,
    this.isPrimaryKey = false,
    this.isUnique = false,
    this.checkConstraints = const [],
    this.foreignKeyTable,
    this.foreignKeyColumn,
    this.enumValues,
    this.comment,
  });

  /// Determine Flutter form field type based on database type
  FormFieldType get formFieldType {
    // Primary keys are usually hidden in forms
    if (isPrimaryKey) return FormFieldType.hidden;

    // Auto-generated timestamps
    if (name.endsWith('_at') && dataType.contains('timestamp')) {
      return FormFieldType.hidden;
    }

    // Foreign key relationships
    if (foreignKeyTable != null) {
      return FormFieldType.dropdown;
    }

    // Enum types
    if (enumValues != null && enumValues!.isNotEmpty) {
      return FormFieldType.dropdown;
    }

    // Based on data type
    switch (dataType.toLowerCase()) {
      case 'boolean':
      case 'bool':
        return FormFieldType.switch_;
      case 'integer':
      case 'int4':
      case 'int8':
      case 'bigint':
        return FormFieldType.number;
      case 'numeric':
      case 'decimal':
      case 'double precision':
      case 'real':
        return FormFieldType.decimal;
      case 'text':
        // Check if it's a long text field based on name
        if (name.contains('description') || name.contains('content') ||
            name.contains('message') || name.contains('body')) {
          return FormFieldType.textarea;
        }
        return FormFieldType.text;
      case 'uuid':
        return FormFieldType.text;
      case 'date':
        return FormFieldType.date;
      case 'timestamp with time zone':
      case 'timestamptz':
        return FormFieldType.datetime;
      case 'jsonb':
      case 'json':
        return FormFieldType.json;
      default:
        return FormFieldType.text;
    }
  }

  /// Get validation rules based on field properties
  List<ValidationRule> get validationRules {
    final rules = <ValidationRule>[];

    // Required field validation
    if (!isNullable && defaultValue == null && !isPrimaryKey) {
      rules.add(ValidationRule.required);
    }

    // Type-specific validations
    switch (formFieldType) {
      case FormFieldType.number:
        rules.add(ValidationRule.integer);
        break;
      case FormFieldType.decimal:
        rules.add(ValidationRule.decimal);
        break;
      case FormFieldType.text:
        if (name.contains('email')) {
          rules.add(ValidationRule.email);
        } else if (name.contains('url')) {
          rules.add(ValidationRule.url);
        }
        break;
      default:
        break;
    }

    // Check constraints
    for (final constraint in checkConstraints) {
      if (constraint.contains('> 0')) {
        rules.add(ValidationRule.positive);
      } else if (constraint.contains('>= 0')) {
        rules.add(ValidationRule.nonNegative);
      }
    }

    return rules;
  }
}

/// Table schema information
class TableSchema {
  final String name;
  final List<DatabaseField> fields;
  final List<String> primaryKeys;
  final bool rlsEnabled;
  final String? comment;

  TableSchema({
    required this.name,
    required this.fields,
    required this.primaryKeys,
    this.rlsEnabled = false,
    this.comment,
  });

  /// Get fields that should be displayed in forms
  List<DatabaseField> get formFields {
    return fields.where((field) =>
      field.formFieldType != FormFieldType.hidden
    ).toList();
  }

  /// Get the primary key field
  DatabaseField? get primaryKeyField {
    return fields.where((field) => field.isPrimaryKey).firstOrNull;
  }

  /// Get foreign key fields
  List<DatabaseField> get foreignKeyFields {
    return fields.where((field) => field.foreignKeyTable != null).toList();
  }
}

/// Form field types for UI generation
enum FormFieldType {
  text,
  textarea,
  number,
  decimal,
  switch_,
  dropdown,
  date,
  datetime,
  json,
  file,
  image,
  hidden,
}

/// Validation rules
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

/// Database schema analyzer service
class DatabaseSchemaAnalyzer {
  static final SupabaseClient _client = SupabaseService.client;

  /// Analyze table schema and return structured information
  static Future<TableSchema> analyzeTable(String tableName) async {
    try {
      // Get basic table info
      final tableInfoQuery = '''
        SELECT
          t.table_name,
          obj_description(c.oid) as table_comment,
          t.row_security as rls_enabled
        FROM information_schema.tables t
        LEFT JOIN pg_class c ON c.relname = t.table_name
        WHERE t.table_schema = 'public'
        AND t.table_name = '$tableName'
      ''';

      final tableInfo = await _client.rpc('execute_sql', params: {'query': tableInfoQuery}) as List<dynamic>;

      if (tableInfo.isEmpty) {
        throw Exception('Table $tableName not found');
      }

      // Get column information
      final fields = await _analyzeTableColumns(tableName);

      // Get primary keys
      final primaryKeys = await _getPrimaryKeys(tableName);

      return TableSchema(
        name: tableName,
        fields: fields,
        primaryKeys: primaryKeys,
        rlsEnabled: tableInfo[0]['rls_enabled'] == 'YES',
        comment: tableInfo[0]['table_comment'],
      );
    } catch (e) {
      throw Exception('Failed to analyze table $tableName: $e');
    }
  }

  /// Analyze table columns and their properties
  static Future<List<DatabaseField>> _analyzeTableColumns(String tableName) async {
    final columnsQuery = '''
      SELECT
        c.column_name,
        c.data_type,
        c.is_nullable,
        c.column_default,
        c.is_identity,
        CASE WHEN pk.column_name IS NOT NULL THEN true ELSE false END as is_primary_key,
        CASE WHEN u.column_name IS NOT NULL THEN true ELSE false END as is_unique,
        col_description(pgc.oid, c.ordinal_position) as comment,
        -- Foreign key info
        fk.foreign_table_name,
        fk.foreign_column_name,
        -- Enum values if applicable
        CASE
          WHEN c.data_type = 'USER-DEFINED' THEN (
            SELECT string_agg(e.enumlabel, ',' ORDER BY e.enumsortorder)
            FROM pg_type t
            JOIN pg_enum e ON t.oid = e.enumtypid
            WHERE t.typname = c.udt_name
          )
          ELSE NULL
        END as enum_values
      FROM information_schema.columns c
      LEFT JOIN pg_class pgc ON pgc.relname = c.table_name
      -- Primary key info
      LEFT JOIN (
        SELECT kcu.column_name
        FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu
          ON tc.constraint_name = kcu.constraint_name
        WHERE tc.constraint_type = 'PRIMARY KEY'
        AND tc.table_name = '$tableName'
      ) pk ON pk.column_name = c.column_name
      -- Unique constraint info
      LEFT JOIN (
        SELECT kcu.column_name
        FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu
          ON tc.constraint_name = kcu.constraint_name
        WHERE tc.constraint_type = 'UNIQUE'
        AND tc.table_name = '$tableName'
      ) u ON u.column_name = c.column_name
      -- Foreign key info
      LEFT JOIN (
        SELECT
          kcu.column_name,
          ccu.table_name AS foreign_table_name,
          ccu.column_name AS foreign_column_name
        FROM information_schema.table_constraints AS tc
        JOIN information_schema.key_column_usage AS kcu
          ON tc.constraint_name = kcu.constraint_name
        JOIN information_schema.constraint_column_usage AS ccu
          ON ccu.constraint_name = tc.constraint_name
        WHERE tc.constraint_type = 'FOREIGN KEY'
        AND tc.table_name = '$tableName'
      ) fk ON fk.column_name = c.column_name
      WHERE c.table_name = '$tableName'
      ORDER BY c.ordinal_position
    ''';

    final columnsData = await _client.rpc('execute_sql', params: {
      'query': columnsQuery
    }) as List<dynamic>;

    final fields = <DatabaseField>[];
    for (final row in columnsData) {
      final enumValues = row['enum_values']?.toString().split(',');

      fields.add(DatabaseField(
        name: row['column_name'],
        dataType: row['data_type'],
        isNullable: row['is_nullable'] == 'YES',
        defaultValue: row['column_default'],
        isPrimaryKey: row['is_primary_key'] == true,
        isUnique: row['is_unique'] == true,
        foreignKeyTable: row['foreign_table_name'],
        foreignKeyColumn: row['foreign_column_name'],
        enumValues: enumValues,
        comment: row['comment'],
      ));
    }

    return fields;
  }

  /// Get primary keys for a table
  static Future<List<String>> _getPrimaryKeys(String tableName) async {
    final pkQuery = '''
      SELECT kcu.column_name
      FROM information_schema.table_constraints tc
      JOIN information_schema.key_column_usage kcu
        ON tc.constraint_name = kcu.constraint_name
      WHERE tc.constraint_type = 'PRIMARY KEY'
      AND tc.table_name = '$tableName'
      ORDER BY kcu.ordinal_position
    ''';

    final pkData = await _client.rpc('execute_sql', params: {
      'query': pkQuery
    }) as List<dynamic>;

    return pkData.map((row) => row['column_name'] as String).toList();
  }

  /// Get list of all tables available for analysis
  static Future<List<String>> getAvailableTables() async {
    final tablesQuery = '''
      SELECT table_name
      FROM information_schema.tables
      WHERE table_schema = 'public'
      AND table_type = 'BASE TABLE'
      ORDER BY table_name
    ''';

    final tablesData = await _client.rpc('execute_sql', params: {
      'query': tablesQuery
    }) as List<dynamic>;

    return tablesData.map((row) => row['table_name'] as String).toList();
  }

  /// Get foreign key reference data for dropdowns
  static Future<List<Map<String, dynamic>>> getForeignKeyData(
    String tableName,
    String valueField,
    String displayField
  ) async {
    try {
      final data = await _client
          .from(tableName)
          .select('$valueField, $displayField')
          .eq('is_active', true)
          .order(displayField);

      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      // Fallback if no is_active field
      try {
        final data = await _client
            .from(tableName)
            .select('$valueField, $displayField')
            .order(displayField);

        return List<Map<String, dynamic>>.from(data);
      } catch (e2) {
        // Debug logging removed
        return [];
      }
    }
  }
}