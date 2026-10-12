import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/statistics_service.dart';
import 'package:intl/intl.dart' as intl;

class DashboardScreen extends StatefulWidget {
  final Function(int, {Map<String, dynamic>? data})? onNavigate;
  const DashboardScreen({super.key, this.onNavigate});

  @override
  State<DashboardScreen> createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> with WidgetsBindingObserver {
  final StatisticsService _statsService = StatisticsService();
  Timer? _refreshTimer;
  Future<List<Map<String, dynamic>>>? _cachedAlertsFuture;
  Future<Map<String, dynamic>>? _cachedDashboardStatsFuture;
  Future<List<Map<String, dynamic>>>? _cachedPendingTestsFuture;
  Future<List<Map<String, dynamic>>>? _cachedTodayPatientsFuture;
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    refreshData();
    _startTimer();
  }

  void _startTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted && !_isPaused) {
        refreshData();
      }
    });
  }

  void refreshData() {
    if (mounted) {
      setState(() {
        _cachedAlertsFuture = _statsService.getAlerts();
        _cachedDashboardStatsFuture = _statsService.getDashboardStats();
        _cachedPendingTestsFuture = _statsService.getPendingTests();
        _cachedTodayPatientsFuture = _statsService.getTodayPatientsDetails();
      });
    } else {
      _cachedAlertsFuture = _statsService.getAlerts();
      _cachedDashboardStatsFuture = _statsService.getDashboardStats();
      _cachedPendingTestsFuture = _statsService.getPendingTests();
      _cachedTodayPatientsFuture = _statsService.getTodayPatientsDetails();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _isPaused = true;
      _refreshTimer?.cancel();
    } else if (state == AppLifecycleState.resumed) {
      _isPaused = false;
      _startTimer();
      refreshData();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 20.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                _buildSummaryCards(),
                const SizedBox(height: 24),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: _buildMainTables()),
                      const SizedBox(width: 24),
                      Expanded(flex: 1, child: _buildAlertsSection()),
                    ],
                  ),
                ),
                const SizedBox(height: 60), // Space for ticker
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildNotificationTicker(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'لوحة التحكم - Dashboard',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'متابعة حالة المعمل لحظياً - ${intl.DateFormat('yyyy/MM/dd').format(DateTime.now())}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
        IconButton(
          onPressed: () {
            setState(() {
              refreshData();
            });
          },
          icon: const Icon(Icons.refresh),
          style: IconButton.styleFrom(backgroundColor: theme.cardColor),
        ),
      ],
    );
  }

  Widget _buildSummaryCards() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _cachedDashboardStatsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LinearProgressIndicator();
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('خطأ في تحميل الإحصائيات: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
          );
        }
        if (!snapshot.hasData) {
          return const LinearProgressIndicator();
        }
        final data = snapshot.data!;
        return Row(
          children: [
            _buildStatCard(
              'مرضى اليوم',
              data['patients'].toString(),
              Icons.people,
              Colors.blue,
            ),
            const SizedBox(width: 16),
            _buildStatCard(
              'تحاليل اليوم',
              data['tests'].toString(),
              Icons.science,
              Colors.orange,
            ),
            const SizedBox(width: 16),
            _buildStatCard(
              'نتائج معلقة',
              data['pending'].toString(),
              Icons.pending_actions,
              Colors.purple,
            ),
            const SizedBox(width: 16),
            _buildStatCard(
              'إيراد اليوم',
              data['paid'] is num
                  ? (data['paid'] as num).toStringAsFixed(1)
                  : data['paid'].toString(),
              Icons.account_balance_wallet,
              Colors.green,
            ),
            const SizedBox(width: 16),
            _buildStatCard(
              'ديون اليوم',
              data['remaining'] is num
                  ? (data['remaining'] as num).toStringAsFixed(1)
                  : data['remaining'].toString(),
              Icons.money_off,
              Colors.red,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 12),
            Text(
              title,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainTables() {
    final theme = Theme.of(context);
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              tabs: const [
                Tab(text: 'تحاليل قيد المعالجة (Pending)'),
                Tab(text: 'مرضى مسجلون اليوم'),
              ],
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor: theme.unselectedWidgetColor,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              children: [_buildPendingTestsTable(), _buildTodayPatientsTable()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingTestsTable() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _cachedPendingTestsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('خطأ في تحميل التحاليل المعلقة: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final tests = snapshot.data!;
        return _buildCardTable(
          columns: const ['ID', 'المريض', 'التحليل', 'الحالة', 'التاريخ'],
          rows: tests
              .map(
                (t) => [
                  t['id'].toString(),
                  t['patient_name'],
                  t['test_name'],
                  _buildStatusChip(t['status']),
                  t['created_at'].toString().substring(11, 16),
                ],
              )
              .toList(),
          onRowTap: (index) {
            final test = tests[index];
            widget.onNavigate?.call(
              3,
              data: {
                'patient_id': test['patient_id'],
                'patient_test_id': test['id'],
              },
            );
          },
        );
      },
    );
  }

  Widget _buildTodayPatientsTable() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _cachedTodayPatientsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('خطأ في تحميل مرضى اليوم: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final patients = snapshot.data!;
        return _buildCardTable(
          columns: const ['ID', 'المريض', 'التحاليل', 'الطبيب', 'الحالة'],
          rows: patients
              .map(
                (p) => [
                  p['id'].toString(),
                  p['name'],
                  p['test_count'].toString(),
                  p['doctor_name'] ?? 'لا يوجد',
                  _buildStatusChip(p['overall_status']),
                ],
              )
              .toList(),
          onRowTap: (index) {
            widget.onNavigate?.call(2);
          },
        );
      },
    );
  }

  Widget _buildCardTable({
    required List<String> columns,
    required List<List<dynamic>> rows,
    Function(int)? onRowTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: SingleChildScrollView(
        child: DataTable(
          showCheckboxColumn: false,
          columns: columns
              .map(
                (c) => DataColumn(
                  label: Text(
                    c,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              )
              .toList(),
          rows: rows.asMap().entries.map((entry) {
            return DataRow(
              onSelectChanged: (_) => onRowTap?.call(entry.key),
              cells: entry.value
                  .map(
                    (cell) =>
                        DataCell(cell is Widget ? cell : Text(cell.toString())),
                  )
                  .toList(),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String? status) {
    Color color = Colors.grey;
    if (status == 'Pending' || status == 'غير مكتمل') color = Colors.orange;
    if (status == 'Draft') color = Colors.blue;
    if (status == 'Completed') color = Colors.purple;
    if (status == 'Approved' || status == 'مكتمل') color = Colors.green;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status ?? 'غير معروف',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildAlertsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'التنبيهات ومركز الإشعارات',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _cachedAlertsFuture,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'خطأ في تحميل التنبيهات: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                );
              }
              if (!snapshot.hasData) return const SizedBox();
              final alerts = snapshot.data!;
              if (alerts.isEmpty) {
                return Center(
                  child: Text(
                    'لا توجد تنبيهات حالياً',
                    style: TextStyle(color: Theme.of(context).hintColor),
                  ),
                );
              }
              return ListView.separated(
                itemCount: alerts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final alert = alerts[index];
                  final isWarning = alert['severity'] == 'warning';
                  final cardBg = isWarning
                      ? Colors.red.withValues(alpha: 0.1)
                      : Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4);
                  final cardBorder = isWarning
                      ? Colors.red.withValues(alpha: 0.3)
                      : Theme.of(context).colorScheme.primary.withValues(alpha: 0.3);
                  final iconColor = isWarning
                      ? Colors.red
                      : Theme.of(context).colorScheme.primary;

                  return InkWell(
                    onTap: () {
                      if (alert['data'] != null) {
                        widget.onNavigate?.call(3, data: alert['data']);
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cardBorder),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isWarning ? Icons.report : Icons.info,
                            color: iconColor,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              alert['message'],
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationTicker() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _cachedAlertsFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) return const SizedBox();
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox();
        }
        final alerts = snapshot.data!;
        final tickerText = alerts.map((a) => a['message']).join('   |   ');

        return Container(
          height: 40,
          color: Theme.of(context).primaryColor,
          child: _Marquee(
            child: Text(
              tickerText,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Marquee extends StatefulWidget {
  final Widget child;
  const _Marquee({required this.child});

  @override
  State<_Marquee> createState() => _MarqueeState();
}

class _MarqueeState extends State<_Marquee>
    with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScrolling());
  }

  void _startScrolling() async {
    while (mounted) {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      double maxScroll = _scrollController.position.maxScrollExtent;
      await _scrollController.animateTo(
        maxScroll,
        duration: Duration(milliseconds: (maxScroll * 40).toInt()),
        curve: Curves.linear,
      );
      if (!mounted) return;
      _scrollController.jumpTo(0);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      children: [
        const SizedBox(width: 1000), // Start from offset
        widget.child,
        const SizedBox(width: 1000), // Buffer
      ],
    );
  }
}
