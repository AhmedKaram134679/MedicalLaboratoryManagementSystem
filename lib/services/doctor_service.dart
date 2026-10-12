import '../models/doctor_model.dart';
import 'database_service.dart';

class DoctorService {
  final DatabaseService _dbService = DatabaseService();

  Future<List<DoctorModel>> getAllDoctors() async {
    final db = await _dbService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'doctors',
      orderBy: 'name ASC',
    );
    return List.generate(maps.length, (i) => DoctorModel.fromMap(maps[i]));
  }

  Future<int> addDoctor(String name) async {
    final db = await _dbService.database;
    return await db.insert('doctors', {'name': name});
  }

  Future<void> updateDoctor(int id, String name) async {
    final db = await _dbService.database;
    await db.update(
      'doctors',
      {'name': name},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<bool> isDoctorUsed(int id) async {
    final db = await _dbService.database;
    final res = await db.query(
      'patients',
      where: 'doctor_id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return res.isNotEmpty;
  }

  Future<void> deleteDoctor(int id) async {
    final db = await _dbService.database;
    await db.delete('doctors', where: 'id = ?', whereArgs: [id]);
  }
}
