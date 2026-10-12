import 'package:flutter/material.dart';
import '../../models/patient_model.dart';
import '../../services/database_service.dart';
import '../../services/patient_service.dart';
import '../../services/pdf_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/app_provider.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../widgets/report_templates/vitamin_d_template.dart';
import '../widgets/report_templates/urinalysis_template.dart';
import '../widgets/report_templates/stool_template.dart';
import '../../services/settings_service.dart';
import '../../services/user_service.dart';
import '../../utils/clinical_utils.dart';

class ResultsEntryScreen extends StatefulWidget {
  final Map<String, dynamic>? navigationData;
  final VoidCallback? onNavigationConsumed;
  const ResultsEntryScreen({
    super.key,
    this.navigationData,
    this.onNavigationConsumed,
  });

  @override
  State<ResultsEntryScreen> createState() => ResultsEntryScreenState();
}

class ResultsEntryScreenState extends State<ResultsEntryScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final PatientService _patientService = PatientService();
  final Map<String, dynamic> _labSettings = {};

  @override
  void initState() {
    super.initState();
    _loadLabSettings();
    _loadPatients(initialData: widget.navigationData);
  }

  Future<void> _loadLabSettings() async {
    final settings = SettingsService();
    final name = await settings.getLabName();
    final address = await settings.getLabAddress();
    final phone = await settings.getLabPhone();
    final logo = await settings.getLabLogoPath();
    final include = await settings.getReportIncludeInfo();
    final posName = await settings.getReportPosLabName();
    final posAddress = await settings.getReportPosLabAddress();
    final posPhone = await settings.getReportPosLabPhone();
    final posLogo = await settings.getReportPosLabLogo();
    final usePreprinted = await settings.getUsePreprintedLetterhead();

    if (mounted) {
      setState(() {
        _labSettings['labName'] = name;
        _labSettings['labAddress'] = address;
        _labSettings['labPhone'] = phone;
        _labSettings['labLogo'] = logo;
        _labSettings['includeLabInfo'] = include;
        _labSettings['report_pos_lab_name'] = posName;
        _labSettings['report_pos_lab_address'] = posAddress;
        _labSettings['report_pos_lab_phone'] = posPhone;
        _labSettings['report_pos_lab_logo'] = posLogo;
        _labSettings['use_preprinted_letterhead'] = usePreprinted;
      });
    }
  }

  List<Map<String, dynamic>> _patientsToday = [];
  Map<String, dynamic>? _selectedPatient;
  Future<List<Map<String, dynamic>>>? _patientTestsFuture;
  final Map<int, Future<List<Map<String, dynamic>>>> _fieldsFutureCache = {};
  int _currentTabIndex = 0;

  void _onPatientChanged(Map<String, dynamic>? patient) {
    _selectedPatient = patient;
    _fieldsFutureCache.clear();
    _currentTabIndex = 0;
    if (patient != null) {
      _patientTestsFuture = _patientService.getPatientTests(patient['id']);
    } else {
      _patientTestsFuture = null;
    }
  }

  // Store results as: { "patientTestId_fieldName": "value" }
  final Map<String, String> _resultsBuffer = {};
  final Map<int, String> _commentBuffer = {}; // New: Comment per test
  bool _isDirty = false;

  void _setDirty(bool value) {
    if (_isDirty != value) {
      setState(() => _isDirty = value);
      if (mounted) {
        Provider.of<AppProvider>(
          context,
          listen: false,
        ).setHasUnsavedChanges(value);
      }
    }
  }

  static bool isVitaminDTest(dynamic test) {
    if (test == null) return false;
    final templateType = (test is Map ? test['template_type'] : null)
        ?.toString()
        .toLowerCase();
    if (templateType == 'vitamin_d') return true;
    final name = (test is Map ? (test['test_name'] ?? test['name']) : test)
        .toString()
        .toLowerCase();
    return name.contains('vitamin d') ||
        name.contains('vit d') ||
        name.contains('فيتامين د');
  }

  static bool isUrinalysisTest(dynamic test) {
    if (test == null) return false;
    final templateType = (test is Map ? test['template_type'] : null)
        ?.toString()
        .toLowerCase();
    if (templateType == 'urine') return true;
    final name = (test is Map ? (test['test_name'] ?? test['name']) : test)
        .toString()
        .toLowerCase();
    return name.contains('urine') || name.contains('بول');
  }

  static bool isStoolTest(dynamic test) {
    if (test == null) return false;
    final templateType = (test is Map ? test['template_type'] : null)
        ?.toString()
        .toLowerCase();
    if (templateType == 'stool') return true;
    final name = (test is Map ? (test['test_name'] ?? test['name']) : test)
        .toString()
        .toLowerCase();
    return name.contains('stool') || name.contains('براز');
  }

  @override
  void didUpdateWidget(ResultsEntryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.navigationData != oldWidget.navigationData &&
        widget.navigationData != null) {
      _loadPatients(initialData: widget.navigationData);
    }
  }

  void refreshData() async {
    final patients = List<Map<String, dynamic>>.from(
      await _patientService.getPatientsTodayMap(),
    );
    if (!mounted) return;

    setState(() {
      _patientsToday = patients;
      if (_selectedPatient != null) {
        // Keep current selected patient, update their summary details if found
        final match = patients.firstWhere(
          (p) => p['id'] == _selectedPatient!['id'],
          orElse: () => _selectedPatient!,
        );
        _selectedPatient = match;
        // If not dirty, refresh tests future
        if (!_isDirty) {
          _fieldsFutureCache.clear();
          _patientTestsFuture = _patientService.getPatientTests(match['id']);
        }
      } else if (patients.isNotEmpty) {
        _onPatientChanged(patients.first);
      }
    });
  }

  void _loadPatients({Map<String, dynamic>? initialData}) async {
    final patients = List<Map<String, dynamic>>.from(
      await _patientService.getPatientsTodayMap(),
    );
    if (!mounted) return;

    setState(() {
      _patientsToday = patients;

      if (initialData != null && initialData.containsKey('patient_id')) {
        int targetId = initialData['patient_id'];
        final index = patients.indexWhere((p) => p['id'] == targetId);
        if (index != -1) {
          _onPatientChanged(patients[index]);
          _resultsBuffer.clear();
          _commentBuffer.clear();
          _setDirty(false);
        } else {
          // If not in today's list (e.g., historical navigation), fetch manually
          _patientService.getPatientSummary(targetId).then((pMap) {
            if (pMap != null && mounted) {
              setState(() {
                // pMap already matches structure expected by sidebar (has test_count, overall_status)
                final patientMap = Map<String, dynamic>.from(pMap);
                _onPatientChanged(patientMap);

                // Optionally add to list if we want it in sidebar temporary
                if (!_patientsToday.any((item) => item['id'] == pMap['id'])) {
                  _patientsToday.insert(0, patientMap);
                }
                _resultsBuffer.clear();
                _commentBuffer.clear();
                _setDirty(false);
              });
            }
          });
        }
        // Notify that we've consumed the initial navigation data
        widget.onNavigationConsumed?.call();
      } else if (patients.isNotEmpty && _selectedPatient == null) {
        _onPatientChanged(patients.first);
      }
    });
  }

  Future<bool> _handlePatientSwitch(Map<String, dynamic> patient) async {
    if (_isDirty) {
      final bool? proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('تحذير: تغييرات غير محفوظة'),
          content: const Text(
            'يرجى حفظ ما قمت به أولاً قبل الانتقال إلى مريض آخر.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      );
      if (proceed != true) return false;
    }

    setState(() {
      _onPatientChanged(patient);
      _resultsBuffer.clear();
      _commentBuffer.clear();
      _setDirty(false);
    });
    return true;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return PopScope(
      canPop: !_isDirty && _resultsBuffer.values.every((v) => v.trim().isEmpty),
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final bool? confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('تغييرات غير محفوظة'),
            content: const Text(
              'لديك بيانات لم يتم حفظها. هل تريد المغادرة دون حفظ؟',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('البقاء'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('مغادرة دون حفظ'),
              ),
            ],
          ),
        );
        if (confirm == true && context.mounted) {
          setState(() => _isDirty = false);
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Row(
          children: [
            // Main Workspace (Center)
            Expanded(
              child: _selectedPatient == null
                  ? const Center(
                      child: Text('يرجى اختيار مريض من القائمة للبدء'),
                    )
                  : _buildResultsWorkspace(),
            ),
            // Right Sidebar: Patient List
            _buildPatientSidebar(),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientSidebar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final sidebarWidth = (screenWidth * 0.25).clamp(260.0, 360.0);

        return Container(
          width: sidebarWidth,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            border: Border(
              left: BorderSide(
                color: Theme.of(context).dividerColor,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'مرضى اليوم',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _loadPatients,
                      tooltip: 'تحديث القائمة',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: _patientsToday.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: Theme.of(context).dividerColor),
                  itemBuilder: (context, index) {
                    final p = _patientsToday[index];
                    bool isSelected = _selectedPatient?['id'] == p['id'];
                    return Material(
                      color: isSelected
                          ? Theme.of(
                              context,
                            ).primaryColor.withValues(alpha: 0.08)
                          : Colors.transparent,
                      child: ListTile(
                        selected: isSelected,
                        onTap: () => _handlePatientSwitch(p),
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                          child: Text(
                            '${p['daily_id']}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                        title: Text(
                          p['name'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Row(
                          children: [
                            Text(
                              '${p['test_count'] ?? 0} تحاليل',
                              style: const TextStyle(fontSize: 12),
                            ),
                            const Spacer(),
                            _buildStatusChip(
                              p['overall_status'] ?? 'غير مكتمل',
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusChip(String status) {
    bool isComplete = status == 'مكتمل';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isComplete ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: isComplete ? Colors.green : Colors.orange,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildResultsWorkspace() {
    return Column(
      children: [
        _buildPatientHorizontalHeader(),
        const SizedBox(height: 16),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _patientTestsFuture ??= _patientService.getPatientTests(
              _selectedPatient!['id'],
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text('خطأ في تحميل تحاليل المريض: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final tests = snapshot.data!;
              if (tests.isEmpty) {
                return const Center(
                  child: Text('لا توجد تحاليل مسجلة لهذا المريض'),
                );
              }

              int initialIndex = _currentTabIndex.clamp(0, tests.length - 1);
              if (widget.navigationData != null &&
                  widget.navigationData!.containsKey('patient_test_id')) {
                int targetPtId = widget.navigationData!['patient_test_id'];
                for (int i = 0; i < tests.length; i++) {
                  if (tests[i]['id'] == targetPtId) {
                    initialIndex = i;
                    _currentTabIndex = i;
                    break;
                  }
                }
              }

              return DefaultTabController(
                length: tests.length,
                initialIndex: initialIndex,
                key: ValueKey('${_selectedPatient!['id']}_$initialIndex'),
                child: Builder(
                  builder: (tabContext) {
                    final tabController = DefaultTabController.of(tabContext);
                    tabController.addListener(() {
                      if (!tabController.indexIsChanging) {
                        _currentTabIndex = tabController.index;
                      }
                    });
                    return Column(
                      children: [
                        Container(
                          color: Theme.of(context).cardColor,
                          child: TabBar(
                            isScrollable: true,
                            onTap: (idx) => _currentTabIndex = idx,
                            tabs: tests
                                .map((t) => Tab(text: t['test_name']))
                                .toList(),
                            labelColor: Theme.of(context).colorScheme.primary,
                            unselectedLabelColor: Theme.of(context).unselectedWidgetColor,
                            indicatorColor: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        Expanded(
                          child: TabBarView(
                            children: tests
                                .map((t) => _buildTestWorkArea(t))
                                .toList(),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPatientHorizontalHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Theme.of(context).cardColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _headerItem('اسم المريض', _selectedPatient!['name']),
          _headerItem('ID', '${_selectedPatient!['daily_id']}'),
          _headerItem(
            'السن',
            (_selectedPatient!['age'] != null && _selectedPatient!['age'] > 0)
                ? '${_selectedPatient!['age']}'
                : '-',
          ),
          _headerItem(
            'النوع',
            (_selectedPatient!['gender'].toString().toLowerCase() == 'male' ||
                    _selectedPatient!['gender'] == 'ذكر')
                ? 'ذكر'
                : 'أنثى',
          ),
          _headerItem(
            'تاريخ الزيارة',
            _selectedPatient!['created_at'].toString().split('T')[0],
          ),
        ],
      ),
    );
  }

  Widget _headerItem(String label, String value) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildTestWorkArea(Map<String, dynamic> patientTest) {
    bool isApproved = patientTest['status'] == 'Approved';

    return Column(
      children: [
        if (isApproved)
          Container(
            width: double.infinity,
            color: Colors.blue.shade800,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
            child: const Row(
              children: [
                Icon(Icons.lock, color: Colors.white, size: 16),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'تم اعتماد هذه النتيجة وهي الآن مقفلة. التعديل متاح للمسؤولين فقط.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Expanded(child: _buildTestFieldsTable(patientTest)),
        _buildCommentSection(patientTest),
        _buildActionButtons(patientTest),
      ],
    );
  }

  Widget _buildTestFieldsTable(Map<String, dynamic> patientTest) {
    final int ptId = patientTest['id'];
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fieldsFutureCache.putIfAbsent(
        ptId,
        () => _fetchAndPopulateFields(patientTest),
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('خطأ في تحميل حقول التحليل: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final fields = snapshot.data!;

        if (isVitaminDTest(patientTest)) {
          return VitaminDTemplate(
            patient: PatientModel.fromMap(_selectedPatient!),
            patientTestId: patientTest['id'], // Correct binding
            testName: patientTest['test_name'],
            results: fields,
            resultsBuffer: _resultsBuffer,
            comment: _commentBuffer[patientTest['id']],
            doctorName: _selectedPatient!['doctor_name'],
            labSettings: _labSettings,
            isEditable: patientTest['status'] != 'Approved',
            onResultChanged: (field, value) {
              _resultsBuffer['${patientTest['id']}_$field'] = value;
              _setDirty(true);
            },
          ).buildUI(context);
        }

        if (isUrinalysisTest(patientTest)) {
          return UrinalysisTemplate(
            patient: PatientModel.fromMap(_selectedPatient!),
            patientTestId: patientTest['id'],
            results: fields,
            resultsBuffer: _resultsBuffer,
            comment: _commentBuffer[patientTest['id']],
            doctorName: _selectedPatient!['doctor_name'],
            labSettings: _labSettings,
            isEditable: patientTest['status'] != 'Approved',
            onResultChanged: (field, value) {
              _resultsBuffer['${patientTest['id']}_$field'] = value;
              _setDirty(true);
            },
          ).buildUI(context);
        }

        if (isStoolTest(patientTest)) {
          return StoolTemplate(
            patient: PatientModel.fromMap(_selectedPatient!),
            patientTestId: patientTest['id'],
            results: fields,
            resultsBuffer: _resultsBuffer,
            comment: _commentBuffer[patientTest['id']],
            doctorName: _selectedPatient!['doctor_name'],
            labSettings: _labSettings,
            isEditable: patientTest['status'] != 'Approved',
            onResultChanged: (field, value) {
              _resultsBuffer['${patientTest['id']}_$field'] = value;
              _setDirty(true);
            },
          ).buildUI(context);
        }

        return Container(
          margin: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: SingleChildScrollView(
            child: DataTable(
              columns: const [
                DataColumn(
                  label: Text(
                    'الفحص',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'النتيجة (Result)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'الوحدة',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'المعدل الطبيعي (Normal)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
              rows: fields
                  .map(
                    (f) => _buildDataRow(
                      f,
                      patientTest['id'],
                      isLocked: patientTest['status'] == 'Approved',
                    ),
                  )
                  .toList(),
            ),
          ),
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchAndPopulateFields(
    Map<String, dynamic> patientTest,
  ) async {
    final db = await DatabaseService().database;
    final metadataId = patientTest['test_id'];
    int ptId = patientTest['id'];

    // Populate comment from db record
    if (!_commentBuffer.containsKey(ptId)) {
      _commentBuffer[ptId] = patientTest['comment'] ?? '';
    }

    // Fetch results if exists
    final existingResults = await _patientService.getResultsForTest(ptId);
    for (var r in existingResults) {
      _resultsBuffer['${ptId}_${r['field_name']}'] ??= r['result_value'] ?? '';
    }

    return await db.query(
      'test_fields',
      where: 'test_metadata_id = ?',
      whereArgs: [metadataId],
    );
  }

  DataRow _buildDataRow(
    Map<String, dynamic> field,
    int patientTestId, {
    bool isLocked = false,
  }) {
    String bufferKey = '${patientTestId}_${field['field_name']}';
    String value = _resultsBuffer[bufferKey] ?? '';

    Color textColor = _getResultColor(value, field['default_range']);
    FontWeight fontWeight = _getResultWeight(value, field['default_range']);

    return DataRow(
      cells: [
        DataCell(Text(field['field_name'])),
        DataCell(
          TextFormField(
            initialValue: value,
            style: TextStyle(color: textColor, fontWeight: fontWeight),
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: '...',
            ),
            enabled: !isLocked,
            onChanged: (v) {
              _resultsBuffer[bufferKey] = v;
              _setDirty(true);
            },
          ),
        ),
        DataCell(Text(field['unit'] ?? '')),
        DataCell(Text(field['default_range'] ?? '-')),
      ],
    );
  }

  bool isResultAbnormal(String value, String? range) {
    return ClinicalUtils.isResultAbnormal(value, range);
  }

  Color _getResultColor(String value, String? range) {
    final onSurfaceColor = Theme.of(context).colorScheme.onSurface;
    if (value.isEmpty || range == null) return onSurfaceColor;

    try {
      final cleanRange = range.trim();
      if (!cleanRange.contains('-')) return onSurfaceColor;

      final rawParts = cleanRange
          .split('-')
          .map(
            (e) => double.tryParse(e.replaceAll(RegExp(r'[^0-9.]'), '').trim()),
          )
          .whereType<double>()
          .toList();

      if (rawParts.length >= 2) {
        final double min = rawParts[0] < rawParts[1]
            ? rawParts[0]
            : rawParts[1];
        final double max = rawParts[0] > rawParts[1]
            ? rawParts[0]
            : rawParts[1];

        if (value.contains('-')) {
          final valParts = value
              .split('-')
              .map(
                (e) => double.tryParse(
                  e.replaceAll(RegExp(r'[^0-9.]'), '').trim(),
                ),
              )
              .whereType<double>()
              .toList();

          if (valParts.length >= 2) {
            final double userMin = valParts[0] < valParts[1]
                ? valParts[0]
                : valParts[1];
            final double userMax = valParts[0] > valParts[1]
                ? valParts[0]
                : valParts[1];

            if (userMin >= min && userMax <= max) return onSurfaceColor;
            if (userMax > max) return Colors.red;
            if (userMin < min) return Colors.yellow.shade700;
          }
        } else {
          final double? numVal = double.tryParse(
            value.replaceAll(RegExp(r'[^0-9.]'), '').trim(),
          );
          if (numVal != null) {
            if (numVal < min) return Colors.yellow.shade700;
            if (numVal > max) return Colors.red;
            return onSurfaceColor;
          }
        }
      }
    } catch (e) {
      debugPrint('Error in _getResultColor: $e');
    }
    return onSurfaceColor;
  }

  FontWeight _getResultWeight(String value, String? range) {
    return isResultAbnormal(value, range) ? FontWeight.bold : FontWeight.normal;
  }

  Widget _buildCommentSection(Map<String, dynamic> patientTest) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextFormField(
        initialValue: _commentBuffer[patientTest['id']],
        maxLines: 2,
        decoration: const InputDecoration(
          labelText: 'ملاحظات / تعليق (Comment)',
          border: OutlineInputBorder(),
          hintText: 'اكتب أي ملاحظات إضافية هنا...',
        ),
        enabled: patientTest['status'] != 'Approved',
        onChanged: (v) {
          _commentBuffer[patientTest['id']] = v;
          _setDirty(true);
        },
      ),
    );
  }

  Widget _buildActionButtons(Map<String, dynamic> patientTest) {
    bool isApproved = patientTest['status'] == 'Approved';
    final isAdmin = Provider.of<AppProvider>(context, listen: false).isAdmin;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!isApproved)
              ElevatedButton.icon(
                onPressed: () => _showSaveAsDialog(patientTest),
                icon: const Icon(Icons.save),
                label: const Text('حفظ باسم...'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                ),
              ),
            const SizedBox(width: 12),
            if (patientTest['status'] == 'Completed')
              ElevatedButton.icon(
                onPressed: () => _handleApprove(patientTest),
                icon: const Icon(Icons.check_circle),
                label: const Text('اعتماد النتيجة'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                ),
              ),
            if (isApproved)
              ElevatedButton.icon(
                onPressed: () => _handleUnapprove(patientTest),
                icon: const Icon(Icons.undo),
                label: Text(
                  isAdmin ? 'إلغاء الاعتماد (Admin)' : 'طلب إلغاء الاعتماد',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade100,
                  foregroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                ),
              ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: () => _previewOrPrint(patientTest),
              icon: const Icon(Icons.print),
              label: const Text('معاينة وطباعة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSaveAsDialog(Map<String, dynamic> test) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('حفظ التحليل'),
        children: [
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(context);
              _saveResults(test, 'Draft');
            },
            child: const ListTile(
              leading: Icon(Icons.edit_note),
              title: Text('حفظ كـ مسودة (Draft)'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(context);
              _saveResults(test, 'Completed');
            },
            child: const ListTile(
              leading: Icon(Icons.done),
              title: Text('حفظ كـ مكتمل (Completed)'),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _saveResults(Map<String, dynamic> test, String status) async {
    // Prepare for saving
    List<Map<String, dynamic>> resultsToSave = [];
    final db = await DatabaseService().database;
    final fields = await db.query(
      'test_fields',
      where: 'test_metadata_id = ?',
      whereArgs: [test['test_id']],
    );

    final bool isVitaminD = isVitaminDTest(test);
    final bool isUrinalysis = isUrinalysisTest(test);
    final bool isStool = isStoolTest(test);

    if (fields.isEmpty && isVitaminD) {
      String key = '${test['id']}_Vit.D3 ( 25-OH Vit.D Total )';
      String val = _resultsBuffer[key] ?? '';
      if (val.isNotEmpty) {
        final double? dVal = double.tryParse(
          val.replaceAll(RegExp(r'[^0-9.]'), ''),
        );
        // Preferred level > 30 ng/mL; values < 30 are abnormal
        final bool isAbnormal = dVal != null ? (dVal < 30.0) : false;
        resultsToSave.add({
          'field_name': 'Vit.D3 ( 25-OH Vit.D Total )',
          'value': val,
          'unit': 'ng / ml',
          'range': '30 - 150',
          'is_abnormal': isAbnormal,
        });
      }
    }

    if (fields.isEmpty && isUrinalysis) {
      final templateFields = [
        'Volume',
        'Aspect',
        'Color',
        'Deposit',
        'Reaction ( PH )',
        'Sp.Gr',
        'Albumin',
        'Glucose',
        'ketone',
        'Bilirubin',
        'Urobilinogen',
        'Nitrite',
        'Blood',
        'Leucocytes',
        'Pus cells',
        'RBCs',
        'Epithelial Cells',
        'Crystals',
        'Castes',
        'Amorphous',
        'Ova',
        'Other',
      ];

      for (var f in templateFields) {
        String key = '${test['id']}_$f';
        String val = _resultsBuffer[key] ?? '';
        if (val.isNotEmpty) {
          final String defRange = UrinalysisTemplate.getDefaultRange(f);
          final style = UrinalysisTemplate.getSmartColor(val, defRange);
          final bool isAbnormal =
              style.color == Colors.red ||
              style.color == Colors.yellow.shade700 ||
              style.fontWeight == FontWeight.bold;

          resultsToSave.add({
            'field_name': f,
            'value': val,
            'unit': '',
            'range': defRange,
            'is_abnormal': isAbnormal,
          });
        }
      }
    }

    if (fields.isEmpty && isStool) {
      final stoolTemplateFields = [
        ...StoolTemplate.physicalFields,
        ...StoolTemplate.microscopicFields,
        ...StoolTemplate.digestionFields,
        ...StoolTemplate.parasiteFields,
      ];

      for (var f in stoolTemplateFields) {
        String key = '${test['id']}_$f';
        String val = _resultsBuffer[key] ?? '';
        if (val.isNotEmpty) {
          final String defRange = StoolTemplate.getDefaultRange(f);
          final style = StoolTemplate.getSmartColor(val, defRange);
          final bool isAbnormal =
              style.color == Colors.red ||
              style.color == Colors.yellow.shade700 ||
              style.fontWeight == FontWeight.bold;

          resultsToSave.add({
            'field_name': f,
            'value': val,
            'unit': '',
            'range': defRange,
            'is_abnormal': isAbnormal,
          });
        }
      }
    }

    for (var f in fields) {
      String key = '${test['id']}_${f['field_name']}';
      String val = _resultsBuffer[key] ?? '';
      if (val.trim().isNotEmpty) {
        bool isAbnormal =
            isResultAbnormal(val, f['default_range']?.toString());

        resultsToSave.add({
          'field_name': f['field_name'],
          'value': val,
          'unit': f['unit'],
          'range': f['default_range'],
          'is_abnormal': isAbnormal,
        });
      }
    }

    // Validation for completion: mandatory test fields must be populated
    if (status == 'Completed' && resultsToSave.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يرجى ملء حقول التحليل قبل الحفظ كمكتمل'),
          ),
        );
      }
      return false;
    }

    try {
      await _patientService.saveTestResults(
        test['id'],
        resultsToSave,
        status: status,
        comment: _commentBuffer[test['id']],
      );
      if (!mounted) return false;
      _setDirty(false);
      setState(() {
        _fieldsFutureCache.remove(test['id']);
        if (_selectedPatient != null) {
          _patientTestsFuture = _patientService.getPatientTests(
            _selectedPatient!['id'],
          );
        }
        _loadPatients(); // Refresh sidebar status
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم الحفظ بنجاح')));
      }
      return true;
    } catch (e) {
      if (!mounted) return false;
      final errorMsg = e.toString().replaceFirst('Exception: ', '');
      if (errorMsg.contains('كمية غير كافية') ||
          errorMsg.contains('منتهية الصلاحية')) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('خطأ في المخزون'),
            content: Text(errorMsg),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إغلاق'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ في الحفظ: $e')));
      }
      return false;
    }
  }

  void _handleApprove(Map<String, dynamic> test) async {
    // Validate that mandatory test fields are populated before allowing status update to Approved
    final currentResults = await _patientService.getResultsForTest(test['id']);
    bool hasBufferedValues = _resultsBuffer.keys.any(
      (k) =>
          k.startsWith('${test['id']}_') &&
          _resultsBuffer[k]!.trim().isNotEmpty,
    );

    if (currentResults.isEmpty && !hasBufferedValues) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'لا يمكن اعتماد نتيجة فارغة. يرجى إدخال النتائج أولاً.',
          ),
        ),
      );
      return;
    }

    // Check stock availability first
    final stockCheck = await _patientService.checkStockAvailability(test['id']);
    if (stockCheck['available'] == false) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('خطأ في المخزون'),
          content: Text(stockCheck['message']),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      );
      return;
    }

    if (!mounted) return;

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الاعتماد'),
        content: const Text(
          'هل أنت متأكد من اعتماد هذه النتيجة؟ لن يمكن تعديلها بعد الاعتماد إلا بواسطة المسؤول.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('اعتماد'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (!mounted) return;
      // Require explicit saving of UI form buffers before allowing test status to be updated to Approved
      if (_isDirty || hasBufferedValues) {
        final bool saveSuccess = await _saveResults(test, 'Completed');
        if (!saveSuccess || !mounted) return;
      }

      final user = Provider.of<AppProvider>(context, listen: false).currentUser;
      try {
        await _patientService.updateTestStatus(
          test['id'],
          'Approved',
          userName: user?.fullName,
        );
        if (mounted) {
          _loadPatients();
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم اعتماد النتيجة بنجاح')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('فشل اعتماد النتيجة: $e')));
        }
      }
    }
  }

  void _handleUnapprove(Map<String, dynamic> test) async {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final bool isAdmin = appProvider.isAdmin;
    final currentUser = appProvider.currentUser;

    if (isAdmin) {
      await _patientService.updateTestStatus(test['id'], 'Completed');
      if (!mounted) return;
      _loadPatients();
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إلغاء الاعتماد بنجاح')),
      );
    } else {
      // Non-admin user: generate explicit request record in admin_requests table
      final username = currentUser?.username ?? 'user';
      final testName = test['test_name'] ?? 'Test #${test['id']}';
      await UserService().createUnapproveRequest(
        username,
        test['id'],
        testName,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إرسال طلب إلغاء الاعتماد إلى الإدارة للموافقة'),
        ),
      );
    }
  }

  void _previewOrPrint(Map<String, dynamic> patientTest) async {
    try {
      final results = await _patientService.getResultsForTest(
        patientTest['id'],
      );
      final bool isVitaminD = isVitaminDTest(patientTest);
      final bool isUrinalysis = isUrinalysisTest(patientTest);
      final bool isStool = isStoolTest(patientTest);

      if (results.isEmpty && !isVitaminD && !isUrinalysis && !isStool) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا توجد نتائج مسجلة لهذا التحليل بعد')),
        );
        return;
      }

      File file;
      if (isVitaminD) {
        final template = VitaminDTemplate(
          patient: PatientModel.fromMap(_selectedPatient!),
          patientTestId: patientTest['id'],
          testName: patientTest['test_name'],
          results: results,
          resultsBuffer: _resultsBuffer,
          labSettings: _labSettings,
          isEditable: false,
          comment: _commentBuffer[patientTest['id']],
          doctorName: _selectedPatient!.containsKey('doctor_name')
              ? _selectedPatient!['doctor_name']
              : null,
        );
        file = await const PdfService().generateTemplateReport(
          template: template,
          patientTestId: patientTest['id'],
          status: patientTest['status'],
          updatedAt: patientTest['updated_at'],
        );
      } else if (isUrinalysis) {
        final template = UrinalysisTemplate(
          patient: PatientModel.fromMap(_selectedPatient!),
          patientTestId: patientTest['id'],
          results: results,
          resultsBuffer: _resultsBuffer,
          labSettings: _labSettings,
          isEditable: false,
          comment: _commentBuffer[patientTest['id']],
          doctorName: _selectedPatient!.containsKey('doctor_name')
              ? _selectedPatient!['doctor_name']
              : null,
        );
        file = await const PdfService().generateTemplateReport(
          template: template,
          patientTestId: patientTest['id'],
          status: patientTest['status'],
          updatedAt: patientTest['updated_at'],
        );
      } else if (isStool) {
        final template = StoolTemplate(
          patient: PatientModel.fromMap(_selectedPatient!),
          patientTestId: patientTest['id'],
          results: results,
          resultsBuffer: _resultsBuffer,
          labSettings: _labSettings,
          isEditable: false,
          comment: _commentBuffer[patientTest['id']],
          doctorName: _selectedPatient!.containsKey('doctor_name')
              ? _selectedPatient!['doctor_name']
              : null,
        );
        file = await const PdfService().generateTemplateReport(
          template: template,
          patientTestId: patientTest['id'],
          status: patientTest['status'],
          updatedAt: patientTest['updated_at'],
        );
      } else {
        file = await const PdfService().generateTestReport(
          patient: PatientModel.fromMap(_selectedPatient!),
          testName: patientTest['test_name'],
          results: results,
          comment: _commentBuffer[patientTest['id']],
          patientTestId: patientTest['id'],
          status: patientTest['status'],
          updatedAt: patientTest['updated_at'],
        );
      }

      final Uri uri = Uri.file(file.path);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        throw 'Could not launch $uri';
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ في الطباعة: $e')));
    }
  }
}
