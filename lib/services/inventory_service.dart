import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'database_service.dart';

class InventoryService {
  final DatabaseService _dbService = DatabaseService();

  // Fetch all inventory items
  Future<List<Map<String, dynamic>>> getAllItems() async {
    final db = await _dbService.database;
    return await db.query('inventory', orderBy: 'item_name ASC');
  }

  // Add new item
  Future<int> addItem(Map<String, dynamic> item, {String? userName}) async {
    final db = await _dbService.database;
    int id = await db.insert('inventory', {
      ...item,
      'last_updated': DateTime.now().toIso8601String(),
    });

    await db.insert('audit_logs', {
      'user_name': userName ?? 'System',
      'action': 'Add Item',
      'data_type': 'Inventory',
      'details': 'Added inventory item: ${item['item_name']}',
      'timestamp': DateTime.now().toIso8601String(),
    });
    return id;
  }

  // Update item
  Future<int> updateItem(
    int id,
    Map<String, dynamic> item, {
    String? userName,
  }) async {
    final db = await _dbService.database;
    int count = await db.update(
      'inventory',
      {...item, 'last_updated': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );

    await db.insert('audit_logs', {
      'user_name': userName ?? 'System',
      'action': 'Update Item',
      'data_type': 'Inventory',
      'details': 'Updated inventory item ID: $id (${item['item_name']})',
      'timestamp': DateTime.now().toIso8601String(),
    });
    return count;
  }

  // Delete item
  Future<int> deleteItem(int id, {String? userName}) async {
    final db = await _dbService.database;

    // Check if referenced in active test usage
    final usage = await db.query(
      'test_inventory_usage',
      where: 'inventory_id = ?',
      whereArgs: [id],
    );
    if (usage.isNotEmpty) {
      throw Exception('لا يمكن حذف المادة لأنها مرتبطة بفحوصات نشطة في النظام');
    }

    final item = await db.query('inventory', where: 'id = ?', whereArgs: [id]);
    String itemName = item.isNotEmpty
        ? item.first['item_name'] as String
        : 'Unknown';

    int count = await db.delete('inventory', where: 'id = ?', whereArgs: [id]);

    await db.insert('audit_logs', {
      'user_name': userName ?? 'System',
      'action': 'Delete Item',
      'data_type': 'Inventory',
      'details': 'Deleted inventory item: $itemName (ID: $id)',
      'timestamp': DateTime.now().toIso8601String(),
    });
    return count;
  }

  // Get items with status (Safe, Warning, Critical)
  Future<List<Map<String, dynamic>>> getItemsWithStatus() async {
    final db = await _dbService.database;
    final items = await db.query('inventory');

    DateTime now = DateTime.now();

    return items.map((item) {
      String status = 'Safe';
      double quantity = (item['quantity'] as num).toDouble();
      double threshold = (item['min_threshold'] as num).toDouble();
      String? expiryStr = item['expiry_date'] as String?;

      // Check Quantity
      if (quantity <= 0) {
        status = 'Critical';
      } else if (quantity <= threshold) {
        status = 'Warning';
      }

      // Check Expiry
      if (expiryStr != null && expiryStr.isNotEmpty) {
        DateTime expiry = DateTime.parse(expiryStr);
        if (expiry.isBefore(now)) {
          status = 'Critical';
        } else if (expiry.difference(now).inDays <= 30 &&
            status != 'Critical') {
          status = 'Warning';
        }
      }

      return {...item, 'status': status};
    }).toList();
  }

  // Get alerts for ticker
  Future<List<String>> getUrgentAlerts() async {
    final items = await getItemsWithStatus();
    List<String> alerts = [];

    for (var item in items) {
      if (item['status'] == 'Critical') {
        alerts.add(
          'تنبيه حرج: ${item['item_name']} (${item['quantity']} ${item['unit']}) - نفد أو منتهي!',
        );
      } else if (item['status'] == 'Warning') {
        alerts.add(
          'تنبيه: ${item['item_name']} اقترب من النفاد أو الانتهاء (${item['quantity']} ${item['unit']})',
        );
      }
    }

    return alerts;
  }

  // Link test to inventory item
  Future<void> linkTestToInventory(
    int testMetadataId,
    int inventoryItemId,
    double quantity,
  ) async {
    final db = await _dbService.database;
    await db.insert('test_inventory_usage', {
      'test_id': testMetadataId,
      'inventory_id': inventoryItemId,
      'quantity': quantity,
    });
  }

  // Deduct stock for a patient test atomically
  Future<void> deductStockForTest(
    int patientTestId, {
    String? userName,
    DatabaseExecutor? txn,
  }) async {
    if (txn != null) {
      await _executeStockDeduction(txn, patientTestId, userName: userName);
    } else {
      final db = await _dbService.database;
      await db.transaction((innerTxn) async {
        await _executeStockDeduction(innerTxn, patientTestId, userName: userName);
      });
    }
  }

  Future<void> _executeStockDeduction(
    DatabaseExecutor txn,
    int patientTestId, {
    String? userName,
  }) async {
    // 1. Get the patient test record and check if already deducted
    final ptRecord = await txn.query(
      'patient_tests',
      columns: ['test_id', 'inventory_deducted'],
      where: 'id = ?',
      whereArgs: [patientTestId],
    );

      if (ptRecord.isEmpty) return;

      // Check if already deducted
      if ((ptRecord.first['inventory_deducted'] as int? ?? 0) == 1) {
        return; // Skip if already done
      }

      int testMetadataId = ptRecord.first['test_id'] as int;

      // 2. Get consumption mappings
      final consumptions = await txn.query(
        'test_inventory_usage',
        where: 'test_id = ?',
        whereArgs: [testMetadataId],
      );

      if (consumptions.isEmpty) {
        await txn.update(
          'patient_tests',
          {'inventory_deducted': 1},
          where: 'id = ?',
          whereArgs: [patientTestId],
        );
        return;
      }

      final now = DateTime.now();

      // 3. Check stock availability and expiry for all items atomically
      for (var mapping in consumptions) {
        int itemId = mapping['inventory_id'] as int;
        double consumed = (mapping['quantity'] as num).toDouble();

        final itemResult = await txn.query(
          'inventory',
          where: 'id = ?',
          whereArgs: [itemId],
        );

        if (itemResult.isEmpty) {
          throw Exception('المادة المخزنية المرتبطة غير موجودة (ID: $itemId)');
        }

        final item = itemResult.first;
        String itemName = item['item_name'] as String? ?? 'مادة غير معروفة';
        double currentQty = (item['quantity'] as num?)?.toDouble() ?? 0.0;
        String? expiryStr = item['expiry_date'] as String?;

        if (expiryStr != null && expiryStr.isNotEmpty) {
          try {
            DateTime expiry = DateTime.parse(expiryStr);
            if (expiry.isBefore(now)) {
              throw Exception('المادة $itemName منتهية الصلاحية!');
            }
          } catch (e) {
            if (e is Exception && e.toString().contains('منتهية الصلاحية')) {
              rethrow;
            }
          }
        }

        if (currentQty < consumed) {
          throw Exception('كمية غير كافية من $itemName. المتوفر: $currentQty، المطلوب: $consumed');
        }

        // Atomically deduct quantity with SQL guard to prevent negative stock
        int updatedRows = await txn.rawUpdate(
          'UPDATE inventory SET quantity = quantity - ?, last_updated = ? WHERE id = ? AND quantity >= ?',
          [consumed, now.toIso8601String(), itemId, consumed],
        );

        if (updatedRows == 0) {
          throw Exception('فشل خصم المخزون: كمية غير كافية من $itemName');
        }

        // Log the deduction
        await txn.insert('audit_logs', {
          'user_name': userName ?? 'System',
          'action': 'Stock Deduction',
          'data_type': 'Inventory',
          'details':
              'Automatically deducted $consumed ($itemName) for patient test #$patientTestId',
          'timestamp': now.toIso8601String(),
        });
      }

      // 4. Mark as deducted in patient_tests WITHIN the transaction
      await txn.update(
        'patient_tests',
        {'inventory_deducted': 1},
        where: 'id = ?',
        whereArgs: [patientTestId],
      );
  }
}
