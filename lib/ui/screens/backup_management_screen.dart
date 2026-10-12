import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import '../../services/backup_service.dart';
import '../../services/google_drive_service.dart';
import '../../services/settings_service.dart';
import '../../services/database_service.dart';
import '../../providers/app_provider.dart';

class BackupManagementScreen extends StatefulWidget {
  const BackupManagementScreen({super.key});

  @override
  State<BackupManagementScreen> createState() => _BackupManagementScreenState();
}

class _BackupManagementScreenState extends State<BackupManagementScreen> {
  final BackupService _backupService = BackupService();
  final GoogleDriveService _gDriveService = GoogleDriveService();
  final SettingsService _settingsService = SettingsService();

  bool _isConnected = false;
  bool _isLoadingHistory = false;
  List<drive.File> _backupHistory = [];
  String? _selectedFolderId;
  String? _selectedFolderName;

  // Scheduled backup settings
  bool _autoEnabled = false;
  String _frequency = 'Daily';
  TimeOfDay _backupTime = const TimeOfDay(hour: 0, minute: 0);
  DateTime _startDate = DateTime.now();
  int _dayOfWeek = 1; // Monday
  int _dayOfMonth = 1;
  int _month = 0; // 0 = Every Month

  @override
  void initState() {
    super.initState();
    _checkConnection();
    _loadScheduleSettings();
  }

  Future<void> _checkConnection() async {
    final connected = await _gDriveService.isConnected();
    if (!mounted) return;
    setState(() => _isConnected = connected);
    if (connected) {
      _loadHistory();
      _checkFolder();
    }
  }

  Future<void> _checkFolder() async {
    final folderId = await _gDriveService.getBackupFolderId();
    if (folderId != null) {
      // In a real app we might want to fetch the folder name from GDrive
      // For now we'll just show "Selected Folder" or use a cached name
      if (!mounted) return;
      setState(() {
        _selectedFolderId = folderId;
        _selectedFolderName = "مجلد موجود (تحقق الحساب)";
      });
      // Try to get actual name
      final api = await _gDriveService.getDriveApi();
      if (api != null) {
        try {
          final drive.File folder = await api.files.get(folderId) as drive.File;
          if (!mounted) return;
          setState(() => _selectedFolderName = folder.name);
        } catch (_) {
          if (!mounted) return;
          setState(() {
            _selectedFolderId = null;
            _selectedFolderName = null;
          });
        }
      }
    }
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoadingHistory = true);
    try {
      final files = await _gDriveService.listBackups();
      if (!mounted) return;
      setState(() => _backupHistory = files);
    } catch (e) {
      // Error loading history
    } finally {
      if (mounted) {
        setState(() => _isLoadingHistory = false);
      }
    }
  }

  Future<void> _loadScheduleSettings() async {
    final enabled =
        await _settingsService.getSetting('backup_auto_enabled') == 'true';
    final freq =
        await _settingsService.getSetting('backup_frequency') ?? 'Daily';
    final timeStr = await _settingsService.getSetting('backup_time') ?? '00:00';
    final startStr = await _settingsService.getSetting('backup_start_date');
    final dayOfWeekStr = await _settingsService.getSetting(
      'backup_day_of_week',
    );
    final dayOfMonthStr = await _settingsService.getSetting(
      'backup_day_of_month',
    );
    final monthStr = await _settingsService.getSetting('backup_month');

    final timeParts = timeStr.split(':');
    if (!mounted) return;
    setState(() {
      _autoEnabled = enabled;
      _frequency = freq;
      _backupTime = TimeOfDay(
        hour: int.parse(timeParts[0]),
        minute: int.parse(timeParts[1]),
      );
      if (startStr != null) _startDate = DateTime.parse(startStr);
      _dayOfWeek = int.parse(dayOfWeekStr ?? '1');
      _dayOfMonth = int.parse(dayOfMonthStr ?? '1');
      _month = int.parse(monthStr ?? '0');
    });
  }

  Future<void> _saveSchedule() async {
    await _settingsService.saveSetting(
      'backup_auto_enabled',
      _autoEnabled.toString(),
    );
    await _settingsService.saveSetting('backup_frequency', _frequency);
    await _settingsService.saveSetting(
      'backup_time',
      '${_backupTime.hour.toString().padLeft(2, '0')}:${_backupTime.minute.toString().padLeft(2, '0')}',
    );
    await _settingsService.saveSetting(
      'backup_start_date',
      _startDate.toIso8601String(),
    );
    await _settingsService.saveSetting(
      'backup_day_of_week',
      _dayOfWeek.toString(),
    );
    await _settingsService.saveSetting(
      'backup_day_of_month',
      _dayOfMonth.toString(),
    );
    await _settingsService.saveSetting('backup_month', _month.toString());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ إعدادات الجدولة بنجاح')),
      );
    }
  }

  Future<void> _showProgressDialog(
    String title,
    Future<void> Function(Function(double), Function(String)) task,
  ) async {
    double progress = 0;
    String status = "جاري البدء...";

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(value: progress),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(status),
                    Text('${(progress * 100).toInt()}%'),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    try {
      await task(
        (p) {
          progress = p;
          if (!mounted) return;
          if (Navigator.canPop(context)) {
            (context as Element)
                .markNeedsBuild(); // Force rebuild of dialog content
          }
        },
        (s) {
          status = s;
          if (!mounted) return;
          if (Navigator.canPop(context)) {
            (context as Element).markNeedsBuild();
          }
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      _loadHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!Provider.of<AppProvider>(context).isAdmin) {
      return const Scaffold(body: Center(child: Text('Access Denied')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة النسخ الاحتياطي السحابي (Google Drive)'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildConnectionStatus(),
            const SizedBox(height: 32),
            if (_isConnected) ...[
              _buildManualSection(),
              const SizedBox(height: 32),
              _buildFolderSection(),
              const SizedBox(height: 32),
              _buildScheduleSection(),
              const SizedBox(height: 32),
              _buildHistorySection(),
              const SizedBox(height: 32),
              _buildLogsSection(),
            ] else
              _buildSetupInstructions(),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionStatus() {
    return Card(
      color: _isConnected ? Colors.green.shade50 : Colors.orange.shade50,
      child: ListTile(
        leading: Icon(
          _isConnected ? Icons.cloud_done : Icons.cloud_off,
          color: _isConnected ? Colors.green : Colors.orange,
          size: 40,
        ),
        title: Text(
          _isConnected ? 'متصل بـ Google Drive' : 'غير متصل بـ Google Drive',
        ),
        subtitle: Text(
          _isConnected
              ? 'يمكنك الآن إجراء عمليات النسخ والجدولة.'
              : 'يرجى إعداد الاتصال للتمكن من النسخ السحابي.',
        ),
        trailing: ElevatedButton(
          onPressed: _showConfigDialog,
          child: Text(_isConnected ? 'إعادة الإعداد' : 'إعداد الاتصال'),
        ),
      ),
    );
  }

  void _showConfigDialog() {
    final clientIdController = TextEditingController();
    final clientSecretController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إعداد Google Drive API'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'يرجى إدخال بيانات مشروع Google Cloud Console الخاص بك.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: clientIdController,
              decoration: const InputDecoration(
                labelText: 'Client ID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: clientSecretController,
              decoration: const InputDecoration(
                labelText: 'Client Secret',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              clientIdController.dispose();
              clientSecretController.dispose();
            },
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              final cId = clientIdController.text.trim();
              final cSecret = clientSecretController.text.trim();
              // Securely save OAuth Client ID and Secret directly into encrypted vault
              await _gDriveService.setOAuthCredentials(cId, cSecret);
              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);
              clientIdController.dispose();
              clientSecretController.dispose();
              final success = await _gDriveService.authenticate();
              if (success && mounted) _checkConnection();
            },
            child: const Text('ربط الحساب'),
          ),
        ],
      ),
    );
  }

  Widget _buildManualSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'عمليات يدوية',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _selectedFolderId == null
                    ? null
                    : () => _showProgressDialog(
                        'إنشاء نسخة احتياطية',
                        (p, s) => _backupService.performFullBackup(
                          onProgress: p,
                          onStatus: s,
                        ),
                      ),
                icon: const Icon(Icons.backup),
                label: const Text('نسخ احتياطي الآن'),
                style: ButtonStyle(
                  padding: WidgetStateProperty.all(const EdgeInsets.all(20)),
                  backgroundColor: WidgetStateProperty.all(Theme.of(context).colorScheme.primary),
                  foregroundColor: WidgetStateProperty.all(Theme.of(context).colorScheme.onPrimary),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildScheduleSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              title: const Text(
                'تفعيل النسخ الاحتياطي التلقائي',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              value: _autoEnabled,
              onChanged: (v) => setState(() => _autoEnabled = v),
            ),
            if (_autoEnabled) ...[
              const Divider(),
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      title: const Text('تكرار النسخ'),
                      subtitle: DropdownButton<String>(
                        value: _frequency,
                        isExpanded: true,
                        items: ['Daily', 'Weekly', 'Monthly']
                            .map(
                              (f) => DropdownMenuItem(value: f, child: Text(f)),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _frequency = v!),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListTile(
                      title: const Text('وقت التنفيذ'),
                      subtitle: TextButton(
                        onPressed: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: _backupTime,
                          );
                          if (time != null) {
                            if (!mounted) return;
                            setState(() => _backupTime = time);
                          }
                        },
                        child: Text(_backupTime.format(context)),
                      ),
                    ),
                  ),
                ],
              ),
              if (_frequency == 'Weekly')
                ListTile(
                  title: const Text('اليوم في الأسبوع'),
                  subtitle: DropdownButton<int>(
                    value: _dayOfWeek,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('الإثنين')),
                      DropdownMenuItem(value: 2, child: Text('الثلاثاء')),
                      DropdownMenuItem(value: 3, child: Text('الأربعاء')),
                      DropdownMenuItem(value: 4, child: Text('الخميس')),
                      DropdownMenuItem(value: 5, child: Text('الجمعة')),
                      DropdownMenuItem(value: 6, child: Text('السبت')),
                      DropdownMenuItem(value: 7, child: Text('الأحد')),
                    ],
                    onChanged: (v) => setState(() => _dayOfWeek = v!),
                  ),
                ),
              if (_frequency == 'Monthly')
                Row(
                  children: [
                    Expanded(
                      child: ListTile(
                        title: const Text('اليوم في الشهر'),
                        subtitle: DropdownButton<int>(
                          value: _dayOfMonth,
                          isExpanded: true,
                          items: List.generate(
                            28,
                            (i) => DropdownMenuItem(
                              value: i + 1,
                              child: Text((i + 1).toString()),
                            ),
                          ),
                          onChanged: (v) => setState(() => _dayOfMonth = v!),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListTile(
                        title: const Text('الشهر'),
                        subtitle: DropdownButton<int>(
                          value: _month,
                          isExpanded: true,
                          items: [
                            const DropdownMenuItem(
                              value: 0,
                              child: Text('كل شهر'),
                            ),
                            ...List.generate(
                              12,
                              (i) => DropdownMenuItem(
                                value: i + 1,
                                child: Text('شهر ${i + 1}'),
                              ),
                            ),
                          ],
                          onChanged: (v) => setState(() => _month = v!),
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              Center(
                child: ElevatedButton(
                  onPressed: _saveSchedule,
                  child: const Text('حفظ إعدادات الجدولة'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'سجل النسخ السحابية',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            IconButton(
              onPressed: _loadHistory,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_isLoadingHistory)
          const Center(child: CircularProgressIndicator())
        else if (_backupHistory.isEmpty)
          const Center(child: Text('لا توجد نسخ احتياطية سحابية حالياً.'))
        else
          Table(
            border: TableBorder.all(color: Theme.of(context).dividerColor),
            columnWidths: const {3: FixedColumnWidth(100)},
            children: [
              TableRow(
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)),
                children: ['اسم الملف', 'التاريخ', 'الحجم', 'إجراءات']
                    .map(
                      (e) => Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          e,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    )
                    .toList(),
              ),
              ..._backupHistory.map(
                (file) => TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(file.name ?? 'Unknown'),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        DateFormat(
                          'yyyy-MM-dd HH:mm',
                        ).format(file.createdTime ?? DateTime.now()),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        '${((int.parse(file.size ?? '0')) / 1024 / 1024).toStringAsFixed(2)} MB',
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(4),
                      child: IconButton(
                        icon: const Icon(Icons.restore, color: Colors.red),
                        onPressed: () => _confirmRestore(file),
                        tooltip: 'استعادة',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }

  Future<void> _confirmRestore(drive.File file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تحذير شديد (استعادة البيانات)'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'سيؤدي هذا الإجراء إلى استبدال كافة بيانات النظام الحالية بالنسخة الاحتياطية المختارة.',
            ),
            SizedBox(height: 8),
            Text(
              'هذه العملية لا يمكن التراجع عنها وستفقد أي بيانات لم يتم نسخها.',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(Colors.red),
              foregroundColor: WidgetStateProperty.all(Colors.white),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('تأكيد الاستعادة وتدمير البيانات الحالية'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (!mounted) return;
      _showProgressDialog('جاري استعادة البيانات', (p, s) async {
        s('جاري التحميل من Google Drive...');
        await _backupService.restoreFromGDrive(file.id!, onProgress: p);
        s('تمت الاستعادة بنجاح. يرجى إعادة تشغيل التطبيق.');
      });
    }
  }

  Widget _buildSetupInstructions() {
    return Center(
      child: Column(
        children: [
          Icon(Icons.help_outline, size: 80, color: Theme.of(context).hintColor),
          const SizedBox(height: 16),
          const Text(
            'نظام النسخ الاحتياطي غير مفعل',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'يجب ربط التطبيق بحساب Google Drive الخاص بالمعمل للتمكن من حفظ واسترجاع البيانات سحابياً.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color ?? Theme.of(context).hintColor),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showConfigDialog,
            icon: const Icon(Icons.settings),
            label: const Text('إعداد الاتصال الآن'),
          ),
        ],
      ),
    );
  }

  Widget _buildFolderSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'مجلد النسخ الاحتياطي',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedFolderName ?? 'لم يتم اختيار مجلد بعد.',
                    style: TextStyle(
                      color: _selectedFolderName == null ? Colors.red : null,
                      fontWeight: _selectedFolderName == null
                          ? FontWeight.bold
                          : null,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _showFolderPicker,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('اختيار مجلد'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showFolderPicker() async {
    setState(() => _isLoadingHistory = true);
    final folders = await _gDriveService.listFolders();
    if (!mounted) return;
    setState(() => _isLoadingHistory = false);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (pickerContext) => AlertDialog(
        title: const Text('اختر مجلد النسخ الاحتياطي'),
        content: SizedBox(
          width: 400,
          child: folders.isEmpty
              ? const Center(child: Text('لا توجد مجلدات متاحة.'))
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: folders.length,
                  itemBuilder: (context, index) {
                    final folder = folders[index];
                    return ListTile(
                      leading: const Icon(Icons.folder),
                      title: Text(folder.name ?? 'بدون اسم'),
                      onTap: () async {
                        await _gDriveService.saveFolderId(folder.id!);
                        if (!mounted) return;
                        setState(() {
                          _selectedFolderId = folder.id;
                          _selectedFolderName = folder.name;
                        });
                        if (pickerContext.mounted) Navigator.pop(pickerContext);
                        _loadHistory();
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(pickerContext),
            child: const Text('إلغاء'),
          ),
        ],
      ),
    );
  }

  Widget _buildLogsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'سجل النشاط (آخر 20 عملية)',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _fetchBackupLogs(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'حدث خطأ أثناء تحميل السجلات: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                ),
              );
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('لا توجد سجلات حالياً.'));
            }

            final logs = snapshot.data!;
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: logs.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final log = logs[index];
                final isSuccess = log['status'] == 'success';
                final timestamp = DateTime.parse(log['timestamp']);

                return ListTile(
                  leading: Icon(
                    isSuccess ? Icons.check_circle : Icons.error,
                    color: isSuccess ? Colors.green : Colors.red,
                  ),
                  title: Text(
                    log['trigger_type'] == 'scheduled'
                        ? 'نسخ مجدول'
                        : 'نسخ يدوي',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(DateFormat('yyyy-MM-dd HH:mm:ss').format(timestamp)),
                      if (log['error_message'] != null)
                        Text(
                          'خطأ: ${log['error_message']}',
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                  trailing: Text(
                    isSuccess ? 'نجح' : 'فشل',
                    style: TextStyle(
                      color: isSuccess ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Future<List<Map<String, dynamic>>> _fetchBackupLogs() async {
    final db = await DatabaseService().database;
    return await db.query('backup_logs', orderBy: 'timestamp DESC', limit: 20);
  }
}
