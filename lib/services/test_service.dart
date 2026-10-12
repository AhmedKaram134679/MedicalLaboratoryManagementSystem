import '../models/test_metadata_model.dart';
import 'database_service.dart';

class TestService {
  final DatabaseService _dbService = DatabaseService();

  Future<List<TestMetadataModel>> getAllTests() async {
    final db = await _dbService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'tests_metadata',
      where: 'is_active = 1',
    );
    return List.generate(
      maps.length,
      (i) => TestMetadataModel.fromMap(maps[i]),
    );
  }

  Future<List<TestMetadataModel>> getAllTestsIncludingInactive() async {
    final db = await _dbService.database;
    final List<Map<String, dynamic>> maps = await db.query('tests_metadata');
    return List.generate(
      maps.length,
      (i) => TestMetadataModel.fromMap(maps[i]),
    );
  }

  Future<int> addTest(String name, double price, {String? templateType}) async {
    final db = await _dbService.database;
    final map = <String, dynamic>{
      'name': name,
      'price': price,
      'is_active': 1,
    };
    if (templateType != null) {
      map['template_type'] = templateType;
    }
    return await db.insert('tests_metadata', map);
  }

  Future<void> updateTest(int id, String name, double price, {String? templateType}) async {
    final db = await _dbService.database;
    final map = <String, dynamic>{'name': name, 'price': price};
    if (templateType != null) {
      map['template_type'] = templateType;
    }
    await db.update(
      'tests_metadata',
      map,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<bool> isTestUsed(int id) async {
    final db = await _dbService.database;
    final res = await db.query(
      'patient_tests',
      where: 'test_id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return res.isNotEmpty;
  }

  Future<void> deleteTest(int id) async {
    final db = await _dbService.database;
    await db.transaction((txn) async {
      await txn.delete('test_fields', where: 'test_metadata_id = ?', whereArgs: [id]);
      await txn.delete('test_inventory_usage', where: 'test_id = ?', whereArgs: [id]);
      await txn.delete('tests_metadata', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> disableTest(int id) async {
    final db = await _dbService.database;
    await db.update(
      'tests_metadata',
      {'is_active': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- Inventory Consumption ---

  Future<List<Map<String, dynamic>>> getConsumption(int testId) async {
    final db = await _dbService.database;
    return await db.rawQuery(
      '''
      SELECT tiu.*, i.item_name, i.unit
      FROM test_inventory_usage tiu
      JOIN inventory i ON tiu.inventory_id = i.id
      WHERE tiu.test_id = ?
    ''',
      [testId],
    );
  }

  Future<void> updateConsumption(
    int testId,
    List<Map<String, dynamic>> items,
  ) async {
    final db = await _dbService.database;
    await db.transaction((txn) async {
      // 1. Delete existing
      await txn.delete(
        'test_inventory_usage',
        where: 'test_id = ?',
        whereArgs: [testId],
      );

      // 2. Insert new
      for (var item in items) {
        await txn.insert('test_inventory_usage', {
          'test_id': testId,
          'inventory_id': item['inventory_id'] ?? item['inventory_item_id'],
          'quantity': item['quantity'] ?? item['quantity_consumed'],
        });
      }
    });
  }

  // --- Test Fields (Parameters) Management ---

  Future<List<Map<String, dynamic>>> getTestFields(int testMetadataId) async {
    final db = await _dbService.database;
    return await db.query(
      'test_fields',
      where: 'test_metadata_id = ?',
      whereArgs: [testMetadataId],
    );
  }

  Future<int> addTestField(int testMetadataId, String fieldName, String? unit, String? defaultRange) async {
    final db = await _dbService.database;
    return await db.insert('test_fields', {
      'test_metadata_id': testMetadataId,
      'field_name': fieldName,
      'unit': unit,
      'default_range': defaultRange,
    });
  }

  Future<void> updateTestField(int fieldId, String fieldName, String? unit, String? defaultRange) async {
    final db = await _dbService.database;
    await db.update(
      'test_fields',
      {
        'field_name': fieldName,
        'unit': unit,
        'default_range': defaultRange,
      },
      where: 'id = ?',
      whereArgs: [fieldId],
    );
  }

  Future<void> deleteTestField(int fieldId) async {
    final db = await _dbService.database;
    await db.delete(
      'test_fields',
      where: 'id = ?',
      whereArgs: [fieldId],
    );
  }
}
