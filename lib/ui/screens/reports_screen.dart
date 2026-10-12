import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:lab_managment_system/utils/report_date_formatter.dart';
import '../../models/report_model.dart';
import '../../services/report_service.dart';
import '../../services/statistics_service.dart';
import '../../services/database_service.dart';
import '../widgets/report_card.dart';
import '../widgets/report_filter_bar.dart';
import 'report_preview_screen.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => ReportsScreenState();
}

class ReportsScreenState extends State<ReportsScreen> {
  // Services
  final ReportService _reportService = ReportService();
  final StatisticsService _statsService = StatisticsService();

  // State
  List<ReportModel> _reports = [];
  bool _isLoading = true;
  String _searchQuery = '';
  ReportType? _filterType;
  ReportStatus? _filterStatus;
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;
  int? _filterDoctorId;
  int? _filterTestId;
  int _touchedChartIndex = -1;

  List<Map<String, dynamic>> _doctors = [];
  List<Map<String, dynamic>> _testsMetadata = [];

  // Analytics State
  DateTime _anaStartDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _anaEndDate = DateTime.now();

  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  void refreshData() {
    _loadReports();
    _loadFilterData();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await _loadReports();
    await _loadFilterData();
  }

  Future<void> _loadFilterData() async {
    final db = await DatabaseService().database;
    final doctors = await db.query('doctors', columns: ['id', 'name']);
    final tests = await db.query(
      'tests_metadata',
      columns: ['id', 'name'],
      where: 'is_active = 1',
    );
    if (!mounted) return;
    setState(() {
      _doctors = doctors;
      _testsMetadata = tests;
    });
  }

  Future<void> _loadReports() async {
    setState(() => _isLoading = true);
    final reports = await _reportService.getReports(
      searchQuery: _searchQuery,
      type: _filterType,
      status: _filterStatus,
      startDate: _filterStartDate,
      endDate: _filterEndDate,
    );
    if (!mounted) return;
    setState(() {
      _reports = reports;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(
          title: const Text('التقارير والإحصائيات'),
          bottom: const TabBar(
            tabs: [
              Tab(
                text: 'أرشيف التقارير (Library)',
                icon: Icon(Icons.library_books),
              ),
              Tab(text: 'الإحصائيات (Analytics)', icon: Icon(Icons.analytics)),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                _loadReports();
                _loadFilterData();
              },
            ),
          ],
        ),
        body: TabBarView(
          children: [_buildReportsLibrary(), _buildAnalyticsTab()],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showCreateReportDialog,
          icon: const Icon(Icons.add_chart),
          label: const Text('إنشاء تقرير'),
        ),
      ),
    );
  }

  // --- Tab 1: Reports Library ---
  Widget _buildReportsLibrary() {
    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'بحث عن تقرير (اسم، رقم، المستخدم)...',
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: Theme.of(context).cardColor,
            ),
            onChanged: (value) {
              _searchQuery = value;
              _debounceTimer?.cancel();
              _debounceTimer = Timer(const Duration(milliseconds: 300), () {
                if (mounted) {
                  _loadReports();
                }
              });
            },
          ),
        ),

        // Filter Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: ReportFilterBar(
            doctors: _doctors,
            tests: _testsMetadata,
            onFilterChanged: (type, status, start, end, docId, testId) {
              setState(() {
                _filterType = type;
                _filterStatus = status;
                _filterStartDate = start;
                _filterEndDate = end;
                _filterDoctorId = docId;
                _filterTestId = testId;
              });
              _loadReports();
            },
          ),
        ),

        const Divider(height: 32),

        // Reports List
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _reports.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _reports.length,
                  itemBuilder: (context, index) {
                    final report = _reports[index];
                    return ReportCard(
                      report: report,
                      onTap: () => _navigateToPreview(report),
                      onPrint: () => _navigateToPreview(report),
                      onEdit: report.status == ReportStatus.draft
                          ? () => _editReport(report)
                          : null,
                      onDelete: report.status == ReportStatus.draft
                          ? () => _deleteReport(report)
                          : null,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox,
            size: 64,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد تقارير مطابقة',
            style: TextStyle(
              fontSize: 18,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              setState(() {
                _searchQuery = '';
                _filterType = null;
                _filterStatus = null;
                _filterStartDate = null;
                _filterEndDate = null;
                _filterDoctorId = null;
                _filterTestId = null;
              });
              _loadReports();
            },
            child: const Text('إلغاء الفلاتر'),
          ),
        ],
      ),
    );
  }

  // --- Tab 2: Analytics ---
  Widget _buildAnalyticsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAnalyticsHeader(),
          const SizedBox(height: 24),
          FutureBuilder<Map<String, dynamic>>(
            future: _statsService.getAnalyticsData(
              start: _anaStartDate,
              end: _anaEndDate,
              doctorId: _filterDoctorId,
              testId: _filterTestId,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text('خطأ في تحميل البيانات: ${snapshot.error}'),
                );
              }
              final data = snapshot.data!;

              return Column(
                children: [
                  _buildFinancialSummary(context, data),
                  const SizedBox(height: 24),
                  _buildStatsGrid(data),
                  const SizedBox(height: 32),
                  _buildChartsSection(),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(Icons.date_range, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            const Text(
              'الفترة الزمنية للتحليل:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () async {
                final range = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                  initialDateRange: DateTimeRange(
                    start: _anaStartDate,
                    end: _anaEndDate,
                  ),
                );
                if (range != null) {
                  setState(() {
                    _anaStartDate = range.start;
                    _anaEndDate = range.end;
                  });
                }
              },
              icon: const Icon(Icons.edit_calendar),
              label: Text(
                ReportDateFormatter.formatDateRange(_anaStartDate, _anaEndDate),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid(Map<String, dynamic> data) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          'إجمالي المرضى',
          data['patientCount'].toString(),
          Icons.people,
          Colors.purple,
        ),
        _buildStatCard(
          'إجمالي التحاليل',
          data['testTotal'].toString(),
          Icons.science,
          Colors.blue,
        ),
        _buildStatCard(
          'نتائج معتمدة',
          data['testApproved'].toString(),
          Icons.check_circle,
          Colors.green,
        ),
        _buildStatCard(
          'بانتظار الموافقة',
          data['testCompleted'].toString(),
          Icons.pending_actions,
          Colors.orange,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          Text(
            label,
            style: TextStyle(
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialSummary(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.monetization_on, color: Colors.green),
              const SizedBox(width: 8),
              const Text(
                'الملخص المالي',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (data['overpaid'] > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'تموزع زيادة: ${data['overpaid']}',
                    style: TextStyle(
                      color: Colors.orange.shade800,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _buildStatBox(
                context,
                'صافي الإيراد',
                data['revenue'].toStringAsFixed(2),
                Theme.of(context).colorScheme.primary,
              ),
              Container(width: 1, height: 50, color: Theme.of(context).dividerColor),
              _buildStatBox(
                context,
                'المبالغ المحصلة',
                data['paid'].toStringAsFixed(2),
                Colors.green,
              ),
              Container(width: 1, height: 50, color: Theme.of(context).dividerColor),
              _buildStatBox(
                context,
                'الديون المتبقية',
                data['remaining'].toStringAsFixed(2),
                Colors.red,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartsSection() {
    return Column(
      children: [
        _buildWeeklyRevenueChart(),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildTopTestsChart()),
            const SizedBox(width: 24),
            Expanded(child: _buildPatientsPerDoctorChart()),
          ],
        ),
      ],
    );
  }

  Widget _buildWeeklyRevenueChart() {
    return Container(
      height: 400,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'حركة الإيرادات خلال الفترة المختارة',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _statsService.getRevenueHistory(
                start: _anaStartDate,
                end: _anaEndDate,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('خطأ في تحميل حركة الإيرادات: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final stats = snapshot.data!;
                if (stats.isEmpty) {
                  return const Center(
                    child: Text('لا توجد بيانات لهذه الفترة'),
                  );
                }

                return LineChart(
                  LineChartData(
                    gridData: const FlGridData(
                      show: true,
                      drawVerticalLine: false,
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 60,
                          getTitlesWidget: (value, meta) => Text(
                            value.toStringAsFixed(0),
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            int index = value.toInt();
                            if (index >= 0 && index < stats.length) {
                              // Only show some labels if many days
                              if (stats.length > 10 &&
                                  index % (stats.length ~/ 5) != 0) {
                                return const SizedBox();
                              }
                              String date = stats[index]['date'];
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  date.substring(5),
                                  style: const TextStyle(fontSize: 9),
                                ),
                              );
                            }
                            return const SizedBox();
                          },
                        ),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: stats
                            .asMap()
                            .entries
                            .map(
                              (e) => FlSpot(
                                e.key.toDouble(),
                                (e.value['revenue'] as num).toDouble(),
                              ),
                            )
                            .toList(),
                        isCurved: true,
                        color: Theme.of(context).colorScheme.primary,
                        barWidth: 3,
                        dotData: const FlDotData(show: true),
                        belowBarData: BarAreaData(
                          show: true,
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopTestsChart() {
    return Container(
      height: 400,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'أكثر 10 تحاليل طلباً',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _statsService.getTestsFrequency(
                start: _anaStartDate,
                end: _anaEndDate,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('خطأ في تحميل التحاليل الأكثر طلباً: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final tests = snapshot.data!;
                if (tests.isEmpty) {
                  return const Center(child: Text('لا توجد بيانات'));
                }

                return PieChart(
                  PieChartData(
                    pieTouchData: PieTouchData(
                      touchCallback: (FlTouchEvent event, pieTouchResponse) {
                        setState(() {
                          if (!event.isInterestedForInteractions ||
                              pieTouchResponse == null ||
                              pieTouchResponse.touchedSection == null) {
                            _touchedChartIndex = -1;
                            return;
                          }
                          _touchedChartIndex = pieTouchResponse
                              .touchedSection!
                              .touchedSectionIndex;
                        });
                      },
                    ),
                    sectionsSpace: 2,
                    centerSpaceRadius: 40,
                    sections: tests.asMap().entries.map((e) {
                      final isTouched = e.key == _touchedChartIndex;
                      return PieChartSectionData(
                        color:
                            Colors.primaries[e.key % Colors.primaries.length],
                        value: (e.value['count'] as num).toDouble(),
                        title: isTouched
                            ? '${e.value['name']}\n${e.value['count']}'
                            : '${e.value['count']}',
                        radius: isTouched ? 70 : 60,
                        titleStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientsPerDoctorChart() {
    return Container(
      height: 400,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'توزيع المرضى حسب الطبيب',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _statsService.getPatientsPerDoctor(
                start: _anaStartDate,
                end: _anaEndDate,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('خطأ في تحميل توزيع المرضى: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final data = snapshot.data!;
                if (data.isEmpty) {
                  return const Center(child: Text('لا توجد بيانات'));
                }

                return BarChart(
                  BarChartData(
                    gridData: const FlGridData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            int index = value.toInt();
                            if (index >= 0 && index < data.length) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  data[index]['name'] ?? 'غير معروف',
                                  style: const TextStyle(fontSize: 9),
                                ),
                              );
                            }
                            return const SizedBox();
                          },
                        ),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: data.asMap().entries.map((e) {
                      return BarChartGroupData(
                        x: e.key,
                        barRods: [
                          BarChartRodData(
                            toY: (e.value['count'] as num).toDouble(),
                            color: Colors.purple,
                            width: 16,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- Actions ---
  void _navigateToPreview(ReportModel report) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ReportPreviewScreen(report: report)),
    ).then((_) => _loadReports()); // Reload on return in case of status change
  }

  void _showCreateReportDialog() {
    // For now, let's allow creating a "Snapshot" report of current analytics
    final titleController = TextEditingController(
      text: 'تقرير موجز - ${DateTime.now().toLocal().toString().substring(0, 16)}',
    );
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('حفظ التقرير الحالي'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'سيتم حفظ إحصائيات الفترة المختارة كتقرير في الأرشيف.',
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'عنوان التقرير',
                  border: OutlineInputBorder(),
                ),
                controller: titleController,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogCtx);
                titleController.dispose();
              },
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                final title = titleController.text.trim();
                final stats = await _statsService.getAnalyticsData(
                  start: _anaStartDate,
                  end: _anaEndDate,
                );
                final report = ReportModel(
                  id: 'RPT-${DateTime.now().millisecondsSinceEpoch}',
                  title: title,
                  type: ReportType.custom,
                  generatedBy: 'مدير النظام',
                  generatedAt: DateTime.now(),
                  status: ReportStatus.approved,
                  metadata: {
                    'start_date': ReportDateFormatter.formatDate(_anaStartDate),
                    'end_date': ReportDateFormatter.formatDate(_anaEndDate),
                  },
                  columns: [
                    const ReportColumn(
                      title: 'البيان',
                      key: 'label',
                      width: 200,
                    ),
                    const ReportColumn(
                      title: 'القيمة',
                      key: 'value',
                      isNumeric: true,
                    ),
                  ],
                  data: [
                    {'label': 'إجمالي المرضى', 'value': stats['patientCount']},
                    {'label': 'إجمالي التحاليل', 'value': stats['testTotal']},
                    {'label': 'الإيرادات', 'value': (stats['revenue'] as num?)?.toStringAsFixed(2) ?? '0.00'},
                    {'label': 'المبالغ المحصلة', 'value': (stats['paid'] as num?)?.toStringAsFixed(2) ?? '0.00'},
                    {'label': 'الديون المتبقية', 'value': (stats['remaining'] as num?)?.toStringAsFixed(2) ?? '0.00'},
                    {'label': 'المبالغ المدفوعة بالزيادة', 'value': (stats['overpaid'] as num?)?.toStringAsFixed(2) ?? '0.00'},
                  ],
                  itemCount: 6,
                );
                await _reportService.createReport(report);
                if (dialogCtx.mounted) {
                  Navigator.pop(dialogCtx);
                }
                titleController.dispose();
                if (!mounted) return;
                _loadReports();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم حفظ التقرير بنجاح')),
                );
              },
              child: const Text('حفظ'),
            ),
          ],
        );
      },
    );
  }

  void _editReport(ReportModel report) {
    final titleController = TextEditingController(text: report.title);
    final notesController = TextEditingController(text: report.notes ?? '');

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تعديل التقرير'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'عنوان التقرير',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'ملاحظات إضافية',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              titleController.dispose();
              notesController.dispose();
            },
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              final updatedReport = report.copyWith(
                title: titleController.text.trim(),
                notes: notesController.text.trim(),
              );
              await _reportService.updateReport(updatedReport);
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }
              titleController.dispose();
              notesController.dispose();
              if (!mounted) return;
              _loadReports();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم تحديث التقرير بنجاح')),
              );
            },
            child: const Text('حفظ التعديلات'),
          ),
        ],
      ),
    );
  }

  void _deleteReport(ReportModel report) async {
    await _reportService.deleteReport(report.id);
    _loadReports();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('تم حذف التقرير ${report.title}')));
  }
}
