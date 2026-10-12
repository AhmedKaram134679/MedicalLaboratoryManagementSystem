class AdminRequestModel {
  final int? id;
  final String username;
  final String requestType; // 'Password Recovery' or 'Result Update'
  final String? details;
  final String status; // 'Pending', 'Approved', 'Rejected'
  final DateTime createdAt;

  AdminRequestModel({
    this.id,
    required this.username,
    required this.requestType,
    this.details,
    this.status = 'Pending',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'request_type': requestType,
      'details': details,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory AdminRequestModel.fromMap(Map<String, dynamic> map) {
    return AdminRequestModel(
      id: map['id'],
      username: map['username'],
      requestType: map['request_type'],
      details: map['details'],
      status: map['status'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}
