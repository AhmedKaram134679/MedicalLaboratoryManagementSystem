class AuditLogModel {
  final int? id;
  final String? userName;
  final String action;
  final String? dataType;
  final DateTime timestamp;

  AuditLogModel({
    this.id,
    this.userName,
    required this.action,
    this.dataType,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_name': userName,
      'action': action,
      'data_type': dataType,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory AuditLogModel.fromMap(Map<String, dynamic> map) {
    return AuditLogModel(
      id: map['id'],
      userName: map['user_name'],
      action: map['action'],
      dataType: map['data_type'],
      timestamp: DateTime.parse(map['timestamp']),
    );
  }
}
