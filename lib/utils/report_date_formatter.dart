import 'package:intl/intl.dart';

/// Unified date formatting utility for summary reports, analytics, preview screens, and PDF generation.
class ReportDateFormatter {
  ReportDateFormatter._();

  static final DateFormat _isoDateFormat = DateFormat('yyyy-MM-dd');
  static final DateFormat _dateTimeFormat = DateFormat('yyyy-MM-dd HH:mm');

  /// Formats a [DateTime] into a standard 'yyyy-MM-dd' string.
  static String formatDate(DateTime date) {
    return _isoDateFormat.format(date);
  }

  /// Formats a [DateTime] into a standard 'yyyy-MM-dd HH:mm' string.
  static String formatDateTime(DateTime dateTime) {
    return _dateTimeFormat.format(dateTime);
  }

  /// Parses an ISO date string ('yyyy-MM-dd') into a [DateTime].
  static DateTime? tryParseDate(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return null;
    try {
      return _isoDateFormat.parse(dateStr.trim().split('T')[0]);
    } catch (_) {
      return DateTime.tryParse(dateStr);
    }
  }

  /// Formats a date range for display e.g. "2026-10-01 - 2026-10-06"
  static String formatDateRange(DateTime start, DateTime end) {
    return '${formatDate(start)} - ${formatDate(end)}';
  }

  /// Formats metadata label for display e.g. start_date -> From / من
  static String getMetadataKeyDisplay(String key, {bool isArabic = false}) {
    if (key == 'start_date') {
      return isArabic ? 'من تاريخ' : 'From Date';
    } else if (key == 'end_date') {
      return isArabic ? 'إلى تاريخ' : 'To Date';
    }
    return key;
  }
}
