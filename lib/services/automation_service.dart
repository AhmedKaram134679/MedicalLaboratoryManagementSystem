import 'dart:async';
import 'package:flutter/foundation.dart';
import 'backup_service.dart';

class AutomationService {
  static final AutomationService _instance = AutomationService._internal();
  factory AutomationService() => _instance;
  AutomationService._internal();

  Timer? _backupTimer;
  final BackupService _backupService = BackupService();

  void start() {
    // Stop any existing timer
    stop();

    // Run every 60 seconds
    _backupTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _checkTasks();
    });

    // Run first check after a delay to avoid startup contention
    Future.delayed(const Duration(seconds: 10), () {
      _checkTasks();
    });
  }

  void stop() {
    _backupTimer?.cancel();
    _backupTimer = null;
  }

  Future<void> _checkTasks() async {
    debugPrint('AutomationService: Checking scheduled tasks...');
    try {
      await _backupService.checkAndRunScheduledBackup();
    } catch (e) {
      debugPrint('AutomationService Error: $e');
    }
  }
}
