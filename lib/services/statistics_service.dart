import 'database_service.dart';

class StatisticsService {
  final DatabaseService _dbService = DatabaseService();

  Future<Map<String, dynamic>> getDashboardStats() async {
    final db = await _dbService.database;
    String today = DateTime.now().toIso8601String().split('T')[0];

    // Patients today
    final patientsResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM patients WHERE created_at LIKE ?',
      ['$today%'],
    );
    int patientsCount = patientsResult.first['count'] as int? ?? 0;

    // Registered tests today
    final testsResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM patient_tests WHERE created_at LIKE ?',
      ['$today%'],
    );
    int testsCount = testsResult.first['count'] as int? ?? 0;

    // Financials
    final financialResult = await db.rawQuery(
      '''SELECT SUM(paid) as total_paid, 
                SUM(CASE WHEN (total_price - discount - paid) > 0 THEN (total_price - discount - paid) ELSE 0 END) as total_remaining 
         FROM patient_tests WHERE created_at LIKE ?''',
      ['$today%'],
    );

    double totalPaid =
        (financialResult.first['total_paid'] as num?)?.toDouble() ?? 0.0;
    double totalRemaining =
        (financialResult.first['total_remaining'] as num?)?.toDouble() ?? 0.0;

    // Round to fix floating point precision noise
    totalPaid = double.parse(totalPaid.toStringAsFixed(2));
    totalRemaining = double.parse(totalRemaining.toStringAsFixed(2));

    // Pending results count (status is 'Pending' or 'Draft' or 'Completed') across all dates
    final pendingResult = await db.rawQuery(
      "SELECT COUNT(*) as count FROM patient_tests WHERE status IN ('Pending', 'Draft', 'Completed')",
    );
    int pendingCount = pendingResult.first['count'] as int? ?? 0;

    return {
      'patients': patientsCount,
      'tests': testsCount,
      'paid': totalPaid,
      'remaining': totalRemaining,
      'pending': pendingCount,
    };
  }

  Future<List<Map<String, dynamic>>> getPendingTests({int limit = 50, int offset = 0}) async {
    final db = await _dbService.database;

    return await db.rawQuery(
      '''
      SELECT pt.id, pt.patient_id, p.name as patient_name, tm.name as test_name, pt.status, pt.created_at
      FROM patient_tests pt
      JOIN patients p ON pt.patient_id = p.id
      JOIN tests_metadata tm ON pt.test_id = tm.id
      WHERE pt.status IN ('Pending', 'Draft', 'Completed')
      ORDER BY pt.id DESC
      LIMIT ? OFFSET ?
    ''',
      [limit, offset],
    );
  }

  Future<List<Map<String, dynamic>>> getTodayPatientsDetails({int limit = 100, int offset = 0}) async {
    final db = await _dbService.database;
    String today = DateTime.now().toIso8601String().split('T')[0];

    return await db.rawQuery(
      '''
      SELECT p.id, p.name, d.name as doctor_name, 
             (SELECT COUNT(*) FROM patient_tests WHERE patient_id = p.id) as test_count,
             (SELECT CASE WHEN COUNT(*) > 0 THEN 'غير مكتمل' ELSE 'مكتمل' END 
              FROM patient_tests WHERE patient_id = p.id AND status != 'Approved') as overall_status
      FROM patients p
      LEFT JOIN doctors d ON p.doctor_id = d.id
      WHERE p.created_at LIKE ?
      ORDER BY p.id DESC
      LIMIT ? OFFSET ?
    ''',
      ['$today%', limit, offset],
    );
  }

  Future<List<Map<String, dynamic>>> getAlerts() async {
    final db = await _dbService.database;
    List<Map<String, dynamic>> alerts = [];

    // Low stock alerts
    final lowStock = await db.query(
      'inventory',
      where: 'quantity <= min_threshold',
    );
    for (var item in lowStock) {
      alerts.add({
        'type': 'low_stock',
        'message':
            'مخزون منخفض: ${item['item_name']} (المتبقي: ${item['quantity']})',
        'severity': 'warning',
      });
    }

    // Pending/Draft/Completed tests (Detailed Alerts)
    final pendingTests = await db.rawQuery('''
      SELECT pt.id, pt.patient_id, pt.status, p.name as patient_name, tm.name as test_name
      FROM patient_tests pt
      JOIN patients p ON pt.patient_id = p.id
      JOIN tests_metadata tm ON pt.test_id = tm.id
      WHERE pt.status IN ('Pending', 'Draft', 'Completed')
      ORDER BY pt.updated_at DESC
    ''');

    for (var test in pendingTests) {
      String status = (test['status'] as String?) ?? 'Pending';
      String patientName =
          (test['patient_name'] as String?) ?? 'مريض غير معروف';
      String testName = (test['test_name'] as String?) ?? 'فحص غير معروف';

      String message = '';
      String severity = 'info';

      if (status == 'Completed') {
        message = 'بانتظار الاعتماد: $patientName - $testName';
        severity = 'info'; // Blue
      } else {
        message =
            'معلق: $patientName - $testName (${status == 'Draft' ? 'مسودة' : 'جديد'})';
        severity = 'warning'; // Red/Orange
      }

      alerts.add({
        'type': 'test_status',
        'message': message,
        'severity': severity,
        'data': {
          'patient_id': test['patient_id'],
          'patient_test_id': test['id'],
        },
      });
    }

    return alerts;
  }

  Future<List<Map<String, dynamic>>> getWeeklyStats() async {
    final db = await _dbService.database;
    final DateTime now = DateTime.now();
    final DateTime startDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
    final DateTime nextDay = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    final String startTimestamp = startDate.toIso8601String().split('T')[0];
    final String nextDayTimestamp = nextDay.toIso8601String().split('T')[0];

    // Group patients by date
    final patientsResult = await db.rawQuery('''
      SELECT SUBSTR(created_at, 1, 10) as day_date, COUNT(*) as count
      FROM patients
      WHERE created_at >= ? AND created_at < ?
      GROUP BY SUBSTR(created_at, 1, 10)
    ''', [startTimestamp, nextDayTimestamp]);

    final Map<String, int> patientMap = {};
    for (var row in patientsResult) {
      final d = row['day_date'] as String?;
      if (d != null) {
        patientMap[d] = (row['count'] as num?)?.toInt() ?? 0;
      }
    }

    // Group revenues by date
    final revenueResult = await db.rawQuery('''
      SELECT SUBSTR(created_at, 1, 10) as day_date, SUM(paid) as total
      FROM patient_tests
      WHERE created_at >= ? AND created_at < ?
      GROUP BY SUBSTR(created_at, 1, 10)
    ''', [startTimestamp, nextDayTimestamp]);

    final Map<String, double> revenueMap = {};
    for (var row in revenueResult) {
      final d = row['day_date'] as String?;
      if (d != null) {
        revenueMap[d] = (row['total'] as num?)?.toDouble() ?? 0.0;
      }
    }

    final List<Map<String, dynamic>> stats = [];
    for (int i = 6; i >= 0; i--) {
      final DateTime date = now.subtract(Duration(days: i));
      final String dateStr = date.toIso8601String().split('T')[0];
      final String dayName = _getDayName(date.weekday);

      final int patients = patientMap[dateStr] ?? 0;
      final double revenue = double.parse((revenueMap[dateStr] ?? 0.0).toStringAsFixed(2));

      stats.add({
        'day': dayName,
        'date': dateStr,
        'patients': patients,
        'revenue': revenue,
      });
    }
    return stats;
  }

  Future<List<Map<String, dynamic>>> getTopTests() async {
    final db = await _dbService.database;
    return await db.rawQuery('''
      SELECT tm.name, COUNT(pt.id) as count
      FROM patient_tests pt
      JOIN tests_metadata tm ON pt.test_id = tm.id
      GROUP BY tm.name
      ORDER BY count DESC
      LIMIT 5
    ''');
  }

  Future<Map<String, dynamic>> getAnalyticsData({
    required DateTime start,
    required DateTime end,
    int? doctorId,
    int? testId,
    String? status,
  }) async {
    final db = await _dbService.database;
    final String startBound = start.toIso8601String().split('T')[0];
    final DateTime endNextDay = DateTime(end.year, end.month, end.day).add(const Duration(days: 1));
    final String endBound = endNextDay.toIso8601String().split('T')[0];

    // Patients Stats
    String patientQuery =
        'SELECT COUNT(*) as count FROM patients WHERE created_at >= ? AND created_at < ?';
    List<dynamic> patientArgs = [startBound, endBound];
    if (doctorId != null) {
      patientQuery += ' AND doctor_id = ?';
      patientArgs.add(doctorId);
    }
    final patientRes = await db.rawQuery(patientQuery, patientArgs);

    // Tests Stats
    String testsQuery = '''
      SELECT 
        COUNT(*) as total,
        SUM(CASE WHEN pt.status = 'Approved' THEN 1 ELSE 0 END) as approved,
        SUM(CASE WHEN pt.status = 'Completed' THEN 1 ELSE 0 END) as completed,
        SUM(CASE WHEN pt.status IN ('Pending', 'Draft') THEN 1 ELSE 0 END) as pending
      FROM patient_tests pt
      JOIN patients p ON pt.patient_id = p.id
      WHERE pt.created_at >= ? AND pt.created_at < ?
    ''';
    List<dynamic> testsArgs = [startBound, endBound];
    if (doctorId != null) {
      testsQuery += ' AND p.doctor_id = ?';
      testsArgs.add(doctorId);
    }
    if (testId != null) {
      testsQuery += ' AND pt.test_id = ?';
      testsArgs.add(testId);
    }
    if (status != null) {
      testsQuery += ' AND pt.status = ?';
      testsArgs.add(status);
    }
    final testsRes = await db.rawQuery(testsQuery, testsArgs);

    // Financial Stats
    String financialQuery = '''
      SELECT 
        SUM(pt.total_price - pt.discount) as revenue,
        SUM(pt.paid) as paid,
        SUM(CASE WHEN (pt.total_price - pt.discount - pt.paid) > 0 THEN (pt.total_price - pt.discount - pt.paid) ELSE 0 END) as remaining,
        SUM(CASE WHEN (pt.paid - (pt.total_price - pt.discount)) > 0 THEN (pt.paid - (pt.total_price - pt.discount)) ELSE 0 END) as overpaid
      FROM patient_tests pt
      JOIN patients p ON pt.patient_id = p.id
      WHERE pt.created_at >= ? AND pt.created_at < ?
    ''';
    List<dynamic> finArgs = [startBound, endBound];
    if (doctorId != null) {
      financialQuery += ' AND p.doctor_id = ?';
      finArgs.add(doctorId);
    }
    final finRes = await db.rawQuery(financialQuery, finArgs);

    return {
      'patientCount': patientRes.first['count'] as int? ?? 0,
      'testTotal': testsRes.first['total'] as int? ?? 0,
      'testApproved': testsRes.first['approved'] as int? ?? 0,
      'testCompleted': testsRes.first['completed'] as int? ?? 0,
      'testPending': testsRes.first['pending'] as int? ?? 0,
      'revenue': (finRes.first['revenue'] as num?)?.toDouble() ?? 0.0,
      'paid': (finRes.first['paid'] as num?)?.toDouble() ?? 0.0,
      'remaining': (finRes.first['remaining'] as num?)?.toDouble() ?? 0.0,
      'overpaid': (finRes.first['overpaid'] as num?)?.toDouble() ?? 0.0,
    };
  }

  Future<List<Map<String, dynamic>>> getTestsFrequency({
    required DateTime start,
    required DateTime end,
  }) async {
    final db = await _dbService.database;
    final String startBound = start.toIso8601String().split('T')[0];
    final DateTime endNextDay = DateTime(end.year, end.month, end.day).add(const Duration(days: 1));
    final String endBound = endNextDay.toIso8601String().split('T')[0];

    return await db.rawQuery(
      '''
      SELECT tm.name, COUNT(pt.id) as count
      FROM patient_tests pt
      JOIN tests_metadata tm ON pt.test_id = tm.id
      WHERE pt.created_at >= ? AND pt.created_at < ?
      GROUP BY tm.name
      ORDER BY count DESC
      LIMIT 10
    ''',
      [startBound, endBound],
    );
  }

  Future<List<Map<String, dynamic>>> getRevenueHistory({
    required DateTime start,
    required DateTime end,
  }) async {
    final db = await _dbService.database;
    final String startBound = start.toIso8601String().split('T')[0];
    final DateTime endNextDay = DateTime(end.year, end.month, end.day).add(const Duration(days: 1));
    final String endBound = endNextDay.toIso8601String().split('T')[0];

    return await db.rawQuery(
      '''
      SELECT 
        strftime('%Y-%m-%d', created_at) as date,
        SUM(total_price - discount) as revenue
      FROM patient_tests
      WHERE created_at >= ? AND created_at < ?
      GROUP BY date
      ORDER BY date ASC
    ''',
      [startBound, endBound],
    );
  }

  Future<List<Map<String, dynamic>>> getPatientsPerDoctor({
    required DateTime start,
    required DateTime end,
  }) async {
    final db = await _dbService.database;
    final String startBound = start.toIso8601String().split('T')[0];
    final DateTime endNextDay = DateTime(end.year, end.month, end.day).add(const Duration(days: 1));
    final String endBound = endNextDay.toIso8601String().split('T')[0];

    return await db.rawQuery(
      '''
      SELECT d.name, COUNT(p.id) as count
      FROM patients p
      LEFT JOIN doctors d ON p.doctor_id = d.id
      WHERE p.created_at >= ? AND p.created_at < ?
      GROUP BY d.name
      ORDER BY count DESC
    ''',
      [startBound, endBound],
    );
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case 1:
        return 'إثنين';
      case 2:
        return 'ثلاثاء';
      case 3:
        return 'أربعاء';
      case 4:
        return 'خميس';
      case 5:
        return 'جمعة';
      case 6:
        return 'سبت';
      case 7:
        return 'أحد';
      default:
        return '';
    }
  }
}
