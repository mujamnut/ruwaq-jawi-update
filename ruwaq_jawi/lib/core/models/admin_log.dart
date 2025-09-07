class AdminLog {
  final String id;
  final String? adminId;
  final String action;
  final String? tableName;
  final String? recordId;
  final Map<String, dynamic>? oldValues;
  final Map<String, dynamic>? newValues;
  final String? ipAddress;
  final String? userAgent;
  final DateTime createdAt;

  AdminLog({
    required this.id,
    this.adminId,
    required this.action,
    this.tableName,
    this.recordId,
    this.oldValues,
    this.newValues,
    this.ipAddress,
    this.userAgent,
    required this.createdAt,
  });

  factory AdminLog.fromJson(Map<String, dynamic> json) {
    return AdminLog(
      id: json['id'] as String,
      adminId: json['admin_id'] as String?,
      action: json['action'] as String,
      tableName: json['table_name'] as String?,
      recordId: json['record_id'] as String?,
      oldValues: json['old_values'] as Map<String, dynamic>?,
      newValues: json['new_values'] as Map<String, dynamic>?,
      ipAddress: json['ip_address'] as String?,
      userAgent: json['user_agent'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'admin_id': adminId,
      'action': action,
      'table_name': tableName,
      'record_id': recordId,
      'old_values': oldValues,
      'new_values': newValues,
      'ip_address': ipAddress,
      'user_agent': userAgent,
      'created_at': createdAt.toIso8601String(),
    };
  }

  AdminLog copyWith({
    String? id,
    String? adminId,
    String? action,
    String? tableName,
    String? recordId,
    Map<String, dynamic>? oldValues,
    Map<String, dynamic>? newValues,
    String? ipAddress,
    String? userAgent,
    DateTime? createdAt,
  }) {
    return AdminLog(
      id: id ?? this.id,
      adminId: adminId ?? this.adminId,
      action: action ?? this.action,
      tableName: tableName ?? this.tableName,
      recordId: recordId ?? this.recordId,
      oldValues: oldValues ?? this.oldValues,
      newValues: newValues ?? this.newValues,
      ipAddress: ipAddress ?? this.ipAddress,
      userAgent: userAgent ?? this.userAgent,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  String get actionDisplayName {
    switch (action) {
      case 'create_kitab':
        return 'Tambah Kitab';
      case 'update_user':
        return 'Kemaskini Pengguna';
      case 'delete_kitab':
        return 'Padam Kitab';
      case 'create_category':
        return 'Tambah Kategori';
      case 'update_subscription':
        return 'Kemaskini Langganan';
      default:
        return action;
    }
  }
}