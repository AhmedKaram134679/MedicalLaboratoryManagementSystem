// lib/models/test_metadata_model.dart
class TestMetadataModel {
  final int? id;
  final String name;
  final double price;
  final String? department;
  final String? normalRangeInfo;
  final int isActive; // 1 for active, 0 for inactive
  final String? templateType;

  TestMetadataModel({
    this.id,
    required this.name,
    required this.price,
    this.department,
    this.normalRangeInfo,
    this.isActive = 1,
    this.templateType,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'department': department,
      'normal_range_info': normalRangeInfo,
      'is_active': isActive,
      'template_type': templateType,
    };
  }

  factory TestMetadataModel.fromMap(Map<String, dynamic> map) {
    return TestMetadataModel(
      id: map['id'],
      name: map['name'],
      price: map['price'],
      department: map['department'],
      normalRangeInfo: map['normal_range_info'],
      isActive: map['is_active'] ?? 1,
      templateType: map['template_type'],
    );
  }
}
