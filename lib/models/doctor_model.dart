class DoctorModel {
  final int? id;
  final String name;
  final String? specialization;

  DoctorModel({this.id, required this.name, this.specialization});

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'specialization': specialization};
  }

  factory DoctorModel.fromMap(Map<String, dynamic> map) {
    return DoctorModel(
      id: map['id'],
      name: map['name'],
      specialization: map['specialization'],
    );
  }
}
