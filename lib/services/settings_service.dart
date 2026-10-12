import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'database_service.dart';

class SettingsService {
  final DatabaseService _dbService = DatabaseService();

  Future<void> saveSetting(String key, String value) async {
    final db = await _dbService.database;
    await db.insert('app_settings', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getSetting(String key) async {
    final db = await _dbService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: [key],
    );
    if (maps.isEmpty) return null;
    return maps.first['value'] as String?;
  }

  // Helper getters for specific settings
  Future<String?> getLabName() => getSetting('lab_name');
  Future<String?> getLabPhone() => getSetting('lab_phone');
  Future<String?> getLabAddress() => getSetting('lab_address');
  Future<String?> getLabLogoPath() => getSetting('lab_logo_path');
  Future<String?> getReceiptBackgroundPath() =>
      getSetting('receipt_background_path');
  Future<String?> getReportHeaderPath() => getSetting('report_header_path');
  Future<String?> getReportFooterPath() => getSetting('report_footer_path');

  // Report Customization
  Future<bool> getReportIncludeInfo() async {
    final val = await getSetting('report_include_info');
    return val == 'true';
  }

  Future<String> getReportPosLabName() async =>
      await getSetting('report_pos_lab_name') ?? 'top_right';
  Future<String> getReportPosLabAddress() async =>
      await getSetting('report_pos_lab_address') ?? 'top_center';
  Future<String> getReportPosLabPhone() async =>
      await getSetting('report_pos_lab_phone') ?? 'top_left';
  Future<String> getReportPosLabLogo() async =>
      await getSetting('report_pos_lab_logo') ?? 'top_left';

  Future<bool> getUsePreprintedLetterhead() async {
    final val = await getSetting('use_preprinted_letterhead');
    return val == 'true';
  }
}
