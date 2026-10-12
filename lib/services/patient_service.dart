import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/patient_model.dart';
import 'database_service.dart';
import 'inventory_service.dart';

class PatientService {
  final DatabaseService _dbService = DatabaseService();
  final InventoryService _inventoryService = InventoryService();

  Future<PatientModel?> getPatient(int id) async {
    final db = await _dbService.database;
    final maps = await db.query('patients', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return PatientModel.fromMap(maps.first);
  }

  Future<void> updatePatient(PatientModel patient) async {
    final db = await _dbService.database;
    final updatedMap = patient.toMap();
    updatedMap['updated_at'] = DateTime.now().toIso8601String();

    await db.update(
      'patients',
      updatedMap,
      where: 'id = ?',
      whereArgs: [patient.id],
    );
  }

  Future<int> getNextDailyId() async {
    final db = await _dbService.database;
    String today = DateTime.now().toIso8601String().split('T')[0];

    // Get all daily_ids for today, sorted ascending
    final List<Map<String, dynamic>> maps = await db.query(
      'patients',
      columns: ['daily_id'],
      where: 'created_at LIKE ?',
      whereArgs: ['$today%'],
      orderBy: 'daily_id ASC',
    );

    if (maps.isEmpty) {
      return 1;
    }

    // Find the first gap
    int expectedId = 1;
    for (var map in maps) {
      int currentId = map['daily_id'] as int;
      if (currentId != expectedId) {
        return expectedId;
      }
      expectedId++;
    }

    // No gap found, return next
    return expectedId;
  }

  Future<Map<String, dynamic>?> getPatientSummary(int id) async {
    final db = await _dbService.database;
    final results = await db.rawQuery(
      '''
      SELECT p.*, 
             d.name as doctor_name,
             (SELECT COUNT(*) FROM patient_tests WHERE patient_id = p.id) as test_count,
             (SELECT CASE 
                WHEN COUNT(*) = SUM(CASE WHEN status = 'Approved' THEN 1 ELSE 0 END) THEN 'مكتمل'
                ELSE 'غير مكتمل'
              END FROM patient_tests WHERE patient_id = p.id) as overall_status
      FROM patients p
      LEFT JOIN doctors d ON p.doctor_id = d.id
      WHERE p.id = ?
    ''',
      [id],
    );

    if (results.isEmpty) return null;
    return results.first;
  }

  Future<List<Map<String, dynamic>>> getPatientsTodayMap() async {
    final db = await _dbService.database;
    String today = DateTime.now().toIso8601String().split('T')[0];

    return await db.rawQuery(
      '''
      SELECT p.*, 
             d.name as doctor_name,
             (SELECT COUNT(*) FROM patient_tests WHERE patient_id = p.id) as test_count,
             (SELECT CASE 
                WHEN COUNT(*) = SUM(CASE WHEN status = 'Approved' THEN 1 ELSE 0 END) THEN 'مكتمل'
                ELSE 'غير مكتمل'
              END FROM patient_tests WHERE patient_id = p.id) as overall_status
      FROM patients p
      LEFT JOIN doctors d ON p.doctor_id = d.id
      WHERE p.created_at LIKE ?
      ORDER BY p.daily_id DESC
    ''',
      ['$today%'],
    );
  }

  Future<int> savePatientWithTests(
    PatientModel patient,
    List<Map<String, dynamic>> testsToSync,
  ) async {
    final db = await _dbService.database;
    return await db.transaction((txn) async {
      int patientId;

      if (patient.id != null) {
        // Update existing patient
        final updatedMap = patient.toMap();
        updatedMap['updated_at'] = DateTime.now().toIso8601String();
        await txn.update(
          'patients',
          updatedMap,
          where: 'id = ?',
          whereArgs: [patient.id],
        );
        patientId = patient.id!;
      } else {
        // Insert new patient with gapless dailyId allocation inside transaction
        String today = DateTime.now().toIso8601String().split('T')[0];
        final List<Map<String, dynamic>> maps = await txn.query(
          'patients',
          columns: ['daily_id'],
          where: 'created_at LIKE ?',
          whereArgs: ['$today%'],
          orderBy: 'daily_id ASC',
        );

        int dailyId = 1;
        if (maps.isNotEmpty) {
          int expectedId = 1;
          for (var map in maps) {
            int currentId = map['daily_id'] as int;
            if (currentId != expectedId) {
              dailyId = expectedId;
              break;
            }
            expectedId++;
          }
          if (dailyId == 1 && maps.first['daily_id'] == 1) {
            dailyId = expectedId;
          }
        }

        final now = DateTime.now().toIso8601String();
        final patientToInsert = PatientModel(
          dailyId: dailyId,
          fileNo: patient.fileNo,
          name: patient.name,
          age: patient.age,
          gender: patient.gender,
          phone: patient.phone,
          address: patient.address,
          isWhatsapp: patient.isWhatsapp,
          doctorId: patient.doctorId,
          notes: patient.notes,
          createdAt: patient.createdAt,
          updatedAt: now,
        );

        patientId = await txn.insert('patients', patientToInsert.toMap());
      }

      // Execute syncPatientTests logic inside the same transaction
      final existing = await txn.query(
        'patient_tests',
        where: 'patient_id = ?',
        whereArgs: [patientId],
      );

      Map<int, int> existingTestMap = {
        for (var row in existing) (row['test_id'] as int): (row['id'] as int),
      };

      int sortOrder = 0;
      for (var test in testsToSync) {
        int testId = test['test_id'];

        if (existingTestMap.containsKey(testId)) {
          await txn.update(
            'patient_tests',
            {
              'sort_order': sortOrder++,
              'total_price': test['total_price'],
              'discount': test['discount'],
              'paid': test['paid'],
            },
            where: 'id = ?',
            whereArgs: [existingTestMap[testId]],
          );
          existingTestMap.remove(testId);
        } else {
          await txn.insert('patient_tests', {
            'patient_id': patientId,
            'test_id': testId,
            'sort_order': sortOrder++,
            'total_price': test['total_price'],
            'discount': test['discount'],
            'paid': test['paid'],
            'status': 'Draft',
            'created_at': DateTime.now().toIso8601String(),
          });
        }
      }

      // Remove deleted tests and their results
      for (var patientTestId in existingTestMap.values) {
        await txn.delete(
          'test_results',
          where: 'patient_test_id = ?',
          whereArgs: [patientTestId],
        );
        await txn.delete(
          'patient_tests',
          where: 'id = ?',
          whereArgs: [patientTestId],
        );
      }

      return patientId;
    });
  }

  Future<List<Map<String, dynamic>>> getAllPatientsWithFinancials({
    int? limit,
    int? offset,
    String? searchQuery,
  }) async {
    final db = await _dbService.database;

    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final query = '%${searchQuery.trim()}%';
      whereClause = 'WHERE p.name LIKE ? OR p.phone LIKE ? OR p.file_no LIKE ? OR CAST(p.daily_id AS TEXT) LIKE ?';
      whereArgs = [query, query, query, query];
    }

    String limitOffsetClause = '';
    if (limit != null) {
      limitOffsetClause = ' LIMIT $limit';
      if (offset != null) {
        limitOffsetClause += ' OFFSET $offset';
      }
    }

    return await db.rawQuery('''
      SELECT 
        p.*,
        COUNT(pt.id) as test_count,
        SUM(pt.total_price) as total_gross,
        SUM(pt.discount) as total_discount,
        SUM(pt.paid) as total_paid
      FROM patients p
      LEFT JOIN patient_tests pt ON p.id = pt.patient_id
      $whereClause
      GROUP BY p.id
      ORDER BY p.daily_id DESC
      $limitOffsetClause
    ''', whereArgs);
  }

  Future<List<Map<String, dynamic>>> getPatientTests(int patientId) async {
    final db = await _dbService.database;
    return await db.rawQuery(
      '''
      SELECT pt.*, tm.name as test_name, tm.department, tm.template_type
      FROM patient_tests pt
      JOIN tests_metadata tm ON pt.test_id = tm.id
      WHERE pt.patient_id = ?
      ORDER BY pt.sort_order ASC
    ''',
      [patientId],
    );
  }

  Future<void> saveTestResults(
    int patientTestId,
    List<Map<String, dynamic>> results, {
    String status = 'Completed',
    String? comment,
    String? userName,
  }) async {
    final db = await _dbService.database;

    await db.transaction((txn) async {
      // 1. Atomically check stock within the transaction if moving to Completed
      if (status == 'Completed') {
        final stock = await checkStockAvailability(patientTestId, txn: txn);
        if (!stock['available']) {
          throw Exception(stock['message'] ?? 'مخزون غير كافٍ');
        }
      }

      await txn.delete(
        'test_results',
        where: 'patient_test_id = ?',
        whereArgs: [patientTestId],
      );

      for (var result in results) {
        await txn.insert('test_results', {
          'patient_test_id': patientTestId,
          'field_name': result['field_name'],
          'result_value': result['value'],
          'unit': result['unit'],
          'normal_range': result['range'],
          'is_abnormal':
              (result['is_abnormal'] == true || result['is_abnormal'] == 1)
              ? 1
              : 0,
        });
      }

      await txn.update(
        'patient_tests',
        {
          'status': status,
          'comment': comment,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [patientTestId],
      );

      // 2. Deduct stock atomically within the transaction if Completed
      if (status == 'Completed') {
        await _inventoryService.deductStockForTest(
          patientTestId,
          userName: userName,
          txn: txn,
        );
      }
    });
  }

  Future<int> countActiveResultsForRemovedTests(
    int patientId,
    List<int> newTestIds,
  ) async {
    final db = await _dbService.database;
    final existing = await db.query(
      'patient_tests',
      where: 'patient_id = ?',
      whereArgs: [patientId],
    );

    int totalActiveResults = 0;
    for (var row in existing) {
      final int testId = row['test_id'] as int;
      final int ptId = row['id'] as int;
      if (!newTestIds.contains(testId)) {
        final countResult = await db.rawQuery(
          'SELECT COUNT(*) as count FROM test_results WHERE patient_test_id = ? AND result_value IS NOT NULL AND TRIM(result_value) != ""',
          [ptId],
        );
        totalActiveResults += (countResult.first['count'] as num?)?.toInt() ?? 0;
      }
    }
    return totalActiveResults;
  }

  Future<void> updateTestStatus(
    int patientTestId,
    String status, {
    String? userName,
  }) async {
    final db = await _dbService.database;

    await db.transaction((txn) async {
      if (status == 'Approved') {
        // 1. Check stock before approval with explicit txn handle
        final stock = await checkStockAvailability(patientTestId, txn: txn);
        if (!stock['available']) {
          throw Exception(stock['message'] ?? 'مخزون غير كافٍ');
        }

        // 2. Deduct stock upon approval atomically within the same txn
        await _inventoryService.deductStockForTest(
          patientTestId,
          userName: userName,
          txn: txn,
        );
      }

      await txn.update(
        'patient_tests',
        {'status': status, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [patientTestId],
      );
    });
  }

  Future<Map<String, dynamic>> checkStockAvailability(
    int patientTestId, {
    DatabaseExecutor? txn,
  }) async {
    try {
      final DatabaseExecutor executor = txn ?? (await _dbService.database);
      final pt = await executor.query(
        'patient_tests',
        where: 'id = ?',
        whereArgs: [patientTestId],
      );
      if (pt.isEmpty) return {'available': true};

      int testId = pt.first['test_id'] as int;
      final consumptions = await executor.query(
        'test_inventory_usage',
        where: 'test_id = ?',
        whereArgs: [testId],
      );

      for (var mapping in consumptions) {
        final item = await executor.query(
          'inventory',
          where: 'id = ?',
          whereArgs: [mapping['inventory_id']],
        );
        if (item.isNotEmpty) {
          double currentQty = (item.first['quantity'] as num).toDouble();
          double needed = (mapping['quantity'] as num).toDouble();
          String? expiryStr = item.first['expiry_date'] as String?;

          if (currentQty < needed) {
            return {
              'available': false,
              'message':
                  'كمية غير كافية من ${item.first['item_name']}. المتوفر: $currentQty',
            };
          }
          if (expiryStr != null && expiryStr.isNotEmpty) {
            final parsedExpiry = DateTime.tryParse(expiryStr);
            if (parsedExpiry != null && parsedExpiry.isBefore(DateTime.now())) {
              return {
                'available': false,
                'message': 'المادة ${item.first['item_name']} منتهية الصلاحية!',
              };
            }
          }
        }
      }
      return {'available': true};
    } catch (e) {
      debugPrint('Error in checkStockAvailability: $e');
      return {'available': false, 'message': 'خطأ في التحقق من المخزون: $e'};
    }
  }

  Future<List<Map<String, dynamic>>> getResultsForTest(
    int patientTestId,
  ) async {
    final db = await _dbService.database;
    return await db.query(
      'test_results',
      where: 'patient_test_id = ?',
      whereArgs: [patientTestId],
    );
  }

  Future<void> deletePatient(int patientId) async {
    final db = await _dbService.database;
    await db.transaction((txn) async {
      // 0. Get the patient details (daily_id and created_at date)
      final patientRows = await txn.query(
        'patients',
        columns: ['daily_id', 'created_at'],
        where: 'id = ?',
        whereArgs: [patientId],
      );

      if (patientRows.isEmpty) return;

      final deletedDailyId = patientRows.first['daily_id'] as int;
      final createdAt = patientRows.first['created_at'] as String;
      final createdDate = createdAt.split('T')[0];

      // 1. Get all patient_tests IDs
      final patientTests = await txn.query(
        'patient_tests',
        columns: ['id'],
        where: 'patient_id = ?',
        whereArgs: [patientId],
      );

      // 2. Delete test_results for each patient_test
      for (var pt in patientTests) {
        await txn.delete(
          'test_results',
          where: 'patient_test_id = ?',
          whereArgs: [pt['id']],
        );
      }

      // 3. Delete patient_tests
      await txn.delete(
        'patient_tests',
        where: 'patient_id = ?',
        whereArgs: [patientId],
      );

      // 4. Delete patient
      await txn.delete('patients', where: 'id = ?', whereArgs: [patientId]);

      // 5. Shift subsequent patients' daily_id for that same date: daily_id = daily_id - 1
      await txn.rawUpdate(
        '''
        UPDATE patients 
        SET daily_id = daily_id - 1 
        WHERE created_at LIKE ? AND daily_id > ?
        ''',
        ['$createdDate%', deletedDailyId],
      );
    });
  }
}
