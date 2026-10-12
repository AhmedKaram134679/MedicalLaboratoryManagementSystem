import 'dart:convert';

enum ReportStatus { draft, ready, approved, rejected }

enum ReportType { inventory, financial, tests, daily, monthly, custom, other }

class ReportColumn {
  final String title;
  final String key;
  final double width;
  final bool isNumeric;

  const ReportColumn({
    required this.title,
    required this.key,
    this.width = 100,
    this.isNumeric = false,
  });

  Map<String, dynamic> toMap() => {
    'title': title,
    'key': key,
    'width': width,
    'is_numeric': isNumeric ? 1 : 0,
  };

  factory ReportColumn.fromMap(Map<String, dynamic> map) => ReportColumn(
    title: map['title'],
    key: map['key'],
    width: (map['width'] as num).toDouble(),
    isNumeric: map['is_numeric'] == 1,
  );
}

class ReportModel {
  final String id;
  final String title;
  final ReportType type;
  final String generatedBy;
  final DateTime generatedAt;
  final ReportStatus status;
  final Map<String, dynamic> metadata; // Date range, department, etc.
  final List<ReportColumn> columns;
  final List<Map<String, dynamic>> data;
  final int itemCount;
  final String? notes;

  ReportModel({
    required this.id,
    required this.title,
    required this.type,
    required this.generatedBy,
    required this.generatedAt,
    this.status = ReportStatus.draft,
    this.metadata = const {},
    required this.columns,
    required this.data,
    this.itemCount = 0,
    this.notes,
  });

  ReportModel copyWith({
    String? id,
    String? title,
    ReportType? type,
    String? generatedBy,
    DateTime? generatedAt,
    ReportStatus? status,
    Map<String, dynamic>? metadata,
    List<ReportColumn>? columns,
    List<Map<String, dynamic>>? data,
    int? itemCount,
    String? notes,
  }) {
    return ReportModel(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      generatedBy: generatedBy ?? this.generatedBy,
      generatedAt: generatedAt ?? this.generatedAt,
      status: status ?? this.status,
      metadata: metadata ?? this.metadata,
      columns: columns ?? this.columns,
      data: data ?? this.data,
      itemCount: itemCount ?? this.itemCount,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'type': type.name,
    'generated_by': generatedBy,
    'generated_at': generatedAt.toIso8601String(),
    'status': status.name,
    'metadata': jsonEncode(metadata),
    'columns': jsonEncode(columns.map((c) => c.toMap()).toList()),
    'data': jsonEncode(data),
    'item_count': itemCount,
    'notes': notes,
  };

  factory ReportModel.fromMap(Map<String, dynamic> map) {
    return ReportModel(
      id: map['id'],
      title: map['title'],
      type: ReportType.values.byName(map['type']),
      generatedBy: map['generated_by'] ?? '',
      generatedAt: DateTime.parse(map['generated_at']),
      status: ReportStatus.values.byName(map['status']),
      metadata: jsonDecode(map['metadata'] ?? '{}'),
      columns: (jsonDecode(map['columns'] ?? '[]') as List)
          .map((c) => ReportColumn.fromMap(c))
          .toList(),
      data: (jsonDecode(map['data'] ?? '[]') as List)
          .map((d) => d as Map<String, dynamic>)
          .toList(),
      itemCount: map['item_count'] ?? 0,
      notes: map['notes'],
    );
  }
}
