import '../models/audit_log_model.dart';
import 'database_service.dart';

class AuditService {
  final DatabaseService _dbService = DatabaseService();

  Future<void> logAction({
    required String action,
    String? userName,
    String? dataType,
  }) async {
    final db = await _dbService.database;
    await db.insert('audit_logs', {
      'user_name': userName ?? 'System',
      'action': action,
      'data_type': dataType,
      'timestamp': DateTime.now().toIso8601String(),
    });

    // Prune audit_logs: retain latest 1000 logs to prevent unbounded database growth
    try {
      await db.execute('''
        DELETE FROM audit_logs 
        WHERE id NOT IN (
          SELECT id FROM audit_logs ORDER BY id DESC LIMIT 1000
        )
      ''');
    } catch (_) {}
  }

  Future<List<AuditLogModel>> getAllLogs() async {
    final db = await _dbService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'audit_logs',
      orderBy: 'timestamp DESC',
    );
    return List.generate(maps.length, (i) => AuditLogModel.fromMap(maps[i]));
  }
}
