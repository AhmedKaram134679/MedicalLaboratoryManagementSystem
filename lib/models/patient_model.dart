// lib/models/patient_model.dart
class PatientModel {
  final int? id;
  final int dailyId;
  final String? fileNo;
  final String name;
  final int age;
  final String gender;
  final String? phone;
  final String? address;
  final bool isWhatsapp;
  final int? doctorId;
  final String? notes;
  final DateTime createdAt;
  final String? updatedAt;

  PatientModel({
    this.id,
    required this.dailyId,
    this.fileNo,
    required this.name,
    required this.age,
    required this.gender,
    this.phone,
    this.address,
    this.isWhatsapp = false,
    this.doctorId,
    this.notes,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'daily_id': dailyId,
      'file_no': fileNo,
      'name': name,
      'age': age,
      'gender': gender,
      'phone': phone,
      'address': address,
      'whatsapp': isWhatsapp ? 1 : 0,
      'doctor_id': doctorId,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt,
    };
  }

  factory PatientModel.fromMap(Map<String, dynamic> map) {
    return PatientModel(
      id: map['id'],
      dailyId: map['daily_id'],
      fileNo: map['file_no'],
      name: map['name'],
      age: map['age'],
      gender: map['gender'],
      phone: map['phone'],
      address: map['address'],
      isWhatsapp: map['whatsapp'] == 1,
      doctorId: map['doctor_id'],
      notes: map['notes'],
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: map['updated_at'],
    );
  }
}
