import '../models/report_model.dart';
import 'database_service.dart';

class ReportService {
  final DatabaseService _dbService = DatabaseService();

  // Singleton pattern
  static final ReportService _instance = ReportService._internal();
  factory ReportService() => _instance;
  ReportService._internal();

  Future<List<ReportModel>> getReports({
    ReportType? type,
    ReportStatus? status,
    String? searchQuery,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await _dbService.database;

    List<String> whereClauses = [];
    List<dynamic> whereArgs = [];

    if (type != null) {
      whereClauses.add('type = ?');
      whereArgs.add(type.name);
    }
    if (status != null) {
      whereClauses.add('status = ?');
      whereArgs.add(status.name);
    }
    if (startDate != null) {
      whereClauses.add('generated_at >= ?');
      whereArgs.add(startDate.toIso8601String());
    }
    if (endDate != null) {
      final adjustedEndDate = DateTime(
        endDate.year,
        endDate.month,
        endDate.day,
        23,
        59,
        59,
        999,
      );
      whereClauses.add('generated_at <= ?');
      whereArgs.add(adjustedEndDate.toIso8601String());
    }
    if (searchQuery != null && searchQuery.isNotEmpty) {
      whereClauses.add('(title LIKE ? OR id LIKE ? OR generated_by LIKE ?)');
      String q = '%$searchQuery%';
      whereArgs.addAll([q, q, q]);
    }

    String? where = whereClauses.isEmpty ? null : whereClauses.join(' AND ');

    final List<Map<String, dynamic>> maps = await db.query(
      'reports',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'generated_at DESC',
    );

    return List.generate(maps.length, (i) => ReportModel.fromMap(maps[i]));
  }

  Future<ReportModel> createReport(ReportModel report) async {
    final db = await _dbService.database;
    await db.insert('reports', report.toMap());
    return report;
  }

  Future<void> updateReportStatus(String id, ReportStatus status) async {
    final db = await _dbService.database;
    await db.update(
      'reports',
      {'status': status.name},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateReport(ReportModel report) async {
    final db = await _dbService.database;
    await db.update(
      'reports',
      report.toMap(),
      where: 'id = ?',
      whereArgs: [report.id],
    );
  }

  Future<void> updateReportNotes(String id, String notes) async {
    final db = await _dbService.database;
    await db.update(
      'reports',
      {'notes': notes},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteReport(String id) async {
    final db = await _dbService.database;
    await db.delete('reports', where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, int>> getReportStats() async {
    final db = await _dbService.database;
    final today = DateTime.now().toIso8601String().split('T')[0];

    final todayRes = await db.rawQuery(
      'SELECT COUNT(*) as count FROM reports WHERE generated_at LIKE ?',
      ['$today%'],
    );
    final approvedRes = await db.rawQuery(
      "SELECT COUNT(*) as count FROM reports WHERE status = 'approved'",
    );
    final draftRes = await db.rawQuery(
      "SELECT COUNT(*) as count FROM reports WHERE status = 'draft'",
    );

    return {
      'today': todayRes.first['count'] as int? ?? 0,
      'approved': approvedRes.first['count'] as int? ?? 0,
      'draft': draftRes.first['count'] as int? ?? 0,
    };
  }
}
