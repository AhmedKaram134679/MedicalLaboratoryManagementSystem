import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';
import 'database_service.dart';
import 'google_drive_service.dart';
import 'settings_service.dart';

class BackupService {
  final DatabaseService _dbService = DatabaseService();
  final GoogleDriveService _gDriveService = GoogleDriveService();
  final SettingsService _settingsService = SettingsService();

  Future<File> createLocalBackup(String targetPath) async {
    final db = await _dbService.database;
    try {
      await db.execute("VACUUM INTO ?", [targetPath]);
      return File(targetPath);
    } catch (e) {
      File src = File(db.path);
      if (await src.exists()) {
        return await src.copy(targetPath);
      }
      rethrow;
    }
  }

  Future<void> performFullBackup({
    Function(double)? onProgress,
    Function(String)? onStatus,
    String triggerType = 'manual',
  }) async {
    String? error;
    String? folderId;
    try {
      onStatus?.call('Checking connection...');
      if (!await _gDriveService.isConnected()) {
        throw Exception('Google Drive is not authenticated or connected.');
      }

      folderId = await _settingsService.getSetting('gdrive_backup_folder_id');
      if (folderId == null || folderId.trim().isEmpty) {
        throw Exception('Google Drive backup folder has not been selected in Settings.');
      }

      onStatus?.call('Creating local backup...');
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateFormat(
        'yyyy-MM-dd_HH-mm-ss',
      ).format(DateTime.now());
      final fileName = 'LabBackup_$timestamp.db';
      final tempPath = p.join(tempDir.path, fileName);

      final localFile = await createLocalBackup(tempPath);
      onProgress?.call(0.1);

      onStatus?.call('Uploading to Google Drive...');
      await _gDriveService.uploadFile(
        file: localFile,
        remoteName: fileName,
        onProgress: (p) => onProgress?.call(0.1 + (p * 0.9)),
      );

      // Cleanup temp file
      if (await localFile.exists()) {
        await localFile.delete();
      }

      final nowIso = DateTime.now().toIso8601String();
      await _settingsService.saveSetting('last_backup_at', nowIso);
      await _settingsService.saveSetting('last_backup_attempt_at', nowIso);
      await _settingsService.saveSetting('backup_failure_count', '0');
      onStatus?.call('Backup completed successfully.');
      await _logBackupAttempt(
        'success',
        triggerType: triggerType,
        folder: folderId,
      );
    } catch (e) {
      error = e.toString();
      final nowIso = DateTime.now().toIso8601String();
      await _settingsService.saveSetting('last_backup_error', error);
      await _settingsService.saveSetting('last_backup_attempt_at', nowIso);
      
      final currentFailures = int.tryParse(
            await _settingsService.getSetting('backup_failure_count') ?? '0',
          ) ??
          0;
      await _settingsService.saveSetting(
        'backup_failure_count',
        (currentFailures + 1).toString(),
      );

      await _logBackupAttempt(
        'failure',
        error: error,
        triggerType: triggerType,
        folder: folderId,
      );
      rethrow;
    }
  }

  Future<void> restoreFromGDrive(
    String fileId, {
    Function(double)? onProgress,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final tempPath = p.join(tempDir.path, 'restore_temp.db');

    // 1. Download
    await _gDriveService.downloadFile(
      fileId: fileId,
      localPath: tempPath,
      onProgress: (p) => onProgress?.call(p * 0.8),
    );

    // 2. Restore local
    await restoreBackup(tempPath);
    onProgress?.call(1.0);

    // 3. Cleanup
    File temp = File(tempPath);
    if (await temp.exists()) await temp.delete();
  }

  Future<void> restoreBackup(String sourcePath) async {
    final src = File(sourcePath);
    if (!await src.exists()) {
      throw Exception('Backup file does not exist: $sourcePath');
    }

    // Validate SQLite file header: Must start with "SQLite format 3\000"
    final bytes = await src.openRead(0, 16).first;
    final headerStr = String.fromCharCodes(bytes);
    if (!headerStr.startsWith('SQLite format 3')) {
      throw Exception('Invalid backup file: Not a valid SQLite database.');
    }

    final db = await _dbService.database;
    final String dbPath = db.path;
    await _dbService.close();

    final target = File(dbPath);
    final backupCopy = File('$dbPath.bak');
    final walFile = File('$dbPath-wal');
    final shmFile = File('$dbPath-shm');

    try {
      if (await target.exists()) {
        await target.copy(backupCopy.path);
        await target.delete();
      }
      if (await walFile.exists()) {
        await walFile.delete();
      }
      if (await shmFile.exists()) {
        await shmFile.delete();
      }
      await src.copy(dbPath);
      if (await backupCopy.exists()) {
        await backupCopy.delete();
      }
    } catch (e) {
      // Rollback if failure occurred during overwrite
      if (await backupCopy.exists()) {
        await backupCopy.copy(dbPath);
        await backupCopy.delete();
      }
      rethrow;
    } finally {
      // Re-open database
      await _dbService.database;
    }
  }

  Future<void> _logBackupAttempt(
    String status, {
    String? error,
    required String triggerType,
    String? folder,
  }) async {
    final db = await _dbService.database;
    await db.insert('backup_logs', {
      'timestamp': DateTime.now().toIso8601String(),
      'status': status,
      'error_message': error,
      'target_folder': folder,
      'trigger_type': triggerType,
    });

    // Prune backup_logs: protect successful entries while keeping recent failure/attempt logs capped at 100
    try {
      await db.execute('''
        DELETE FROM backup_logs 
        WHERE status != 'success' 
        AND id NOT IN (
          SELECT id FROM backup_logs ORDER BY id DESC LIMIT 100
        )
      ''');
    } catch (e) {
      debugPrint('Backup log pruning error: $e');
    }
  }

  // Scheduling logic
  bool _isScheduledRunning = false;
  DateTime? _lastCheckedMemoryTime;

  Future<void> checkAndRunScheduledBackup() async {
    if (_isScheduledRunning) return;
    _isScheduledRunning = true;

    try {
      final enabled =
          await _settingsService.getSetting('backup_auto_enabled') == 'true';
      if (!enabled) return;

      final now = DateTime.now();

      // Throttle 'last_checked_at' DB writes: update only once every 10 minutes to save disk IO
      if (_lastCheckedMemoryTime == null ||
          now.difference(_lastCheckedMemoryTime!).inMinutes >= 10) {
        _lastCheckedMemoryTime = now;
        await _settingsService.saveSetting(
          'last_checked_at',
          now.toIso8601String(),
        );
      }

      final lastBackupStr = await _settingsService.getSetting('last_backup_at');
      final lastAttemptStr =
          await _settingsService.getSetting('last_backup_attempt_at');
      final failureCount = int.tryParse(
            await _settingsService.getSetting('backup_failure_count') ?? '0',
          ) ??
          0;

      // Exponential backoff check for failed scheduled attempts (15m, 30m, 60m, 120m, 240m, up to 360m / 6h)
      if (failureCount > 0 && lastAttemptStr != null) {
        final lastAttempt = DateTime.tryParse(lastAttemptStr);
        if (lastAttempt != null) {
          final backoffMinutes = (15 * (1 << (failureCount - 1).clamp(0, 5))).clamp(15, 360);
          if (now.difference(lastAttempt).inMinutes < backoffMinutes) {
            // Still in backoff window, skip retry
            return;
          }
        }
      }

      final frequency =
          await _settingsService.getSetting('backup_frequency') ?? 'Daily';
      final timeStr =
          await _settingsService.getSetting('backup_time') ?? '00:00';
      final dayOfWeek = int.parse(
        await _settingsService.getSetting('backup_day_of_week') ?? '1',
      );
      final dayOfMonth = int.parse(
        await _settingsService.getSetting('backup_day_of_month') ?? '1',
      );
      final month = int.parse(
        await _settingsService.getSetting('backup_month') ?? '0',
      );

      final lastBackup = lastBackupStr != null
          ? DateTime.parse(lastBackupStr)
          : null;

      DateTime lastScheduledOccurrence = _calculateLastScheduledOccurrence(
        now,
        frequency,
        timeStr,
        dayOfWeek,
        dayOfMonth,
        month,
      );

      bool shouldBackup = false;
      // Deterministic check: if we haven't backed up since the last scheduled window began
      if (lastBackup == null || lastBackup.isBefore(lastScheduledOccurrence)) {
        shouldBackup = true;
      }

      if (shouldBackup) {
        // Prevent continuous re-attempts within the exact same minute window if an attempt already occurred
        if (lastAttemptStr != null) {
          final lastAttempt = DateTime.tryParse(lastAttemptStr);
          if (lastAttempt != null && now.difference(lastAttempt).inMinutes < 5) {
            return;
          }
        }

        // Re-verify connection silently
        if (await _gDriveService.isConnected()) {
          try {
            await performFullBackup(triggerType: 'scheduled');
          } catch (e) {
            debugPrint('Scheduled backup failed: $e');
          }
        } else {
          final nowIso = now.toIso8601String();
          await _settingsService.saveSetting('last_backup_attempt_at', nowIso);
          final currentFailures = failureCount + 1;
          await _settingsService.saveSetting(
            'backup_failure_count',
            currentFailures.toString(),
          );
          // Only log a failure record if the previous logged failure was more than 15 minutes ago
          final lastFailureLoggedStr = await _settingsService.getSetting('last_backup_failure_logged_at');
          bool shouldLogFailure = true;
          if (lastFailureLoggedStr != null) {
            final lastLogged = DateTime.tryParse(lastFailureLoggedStr);
            if (lastLogged != null && now.difference(lastLogged).inMinutes < 15) {
              shouldLogFailure = false;
            }
          }
          if (shouldLogFailure) {
            await _settingsService.saveSetting('last_backup_failure_logged_at', nowIso);
            await _logBackupAttempt(
              'failure',
              error: 'تعذر الاتصال بـ Google Drive أو انتهت صلاحية المصادقة أثناء النسخ التلقائي.',
              triggerType: 'scheduled',
            );
          }
        }
      }
    } finally {
      _isScheduledRunning = false;
    }
  }

  DateTime _calculateLastScheduledOccurrence(
    DateTime now,
    String frequency,
    String timeStr,
    int dayOfWeek,
    int dayOfMonth,
    int month,
  ) {
    final timeParts = timeStr.split(':');
    final hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1]);

    DateTime scheduledToday = DateTime(
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (frequency == 'Daily') {
      return now.isAfter(scheduledToday)
          ? scheduledToday
          : scheduledToday.subtract(const Duration(days: 1));
    } else if (frequency == 'Weekly') {
      int diff = now.weekday - dayOfWeek;
      if (diff < 0) diff += 7;

      DateTime lastOccurrenceDay = scheduledToday.subtract(
        Duration(days: diff),
      );
      if (now.isBefore(lastOccurrenceDay)) {
        lastOccurrenceDay = lastOccurrenceDay.subtract(const Duration(days: 7));
      }
      return lastOccurrenceDay;
    } else if (frequency == 'Monthly') {
      DateTime target = DateTime(now.year, now.month, dayOfMonth, hour, minute);

      if (month != 0) {
        // Annual backup for a specific month
        target = DateTime(now.year, month, dayOfMonth, hour, minute);
        if (now.isBefore(target)) {
          target = DateTime(now.year - 1, month, dayOfMonth, hour, minute);
        }
      } else {
        // Every month
        if (now.isBefore(target)) {
          // DateTime handles month overflow (e.g., month 0 becomes December of previous year)
          target = DateTime(now.year, now.month - 1, dayOfMonth, hour, minute);
        }
      }
      return target;
    }
    return DateTime(2000);
  }
}
