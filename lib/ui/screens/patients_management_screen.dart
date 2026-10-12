import 'package:flutter/material.dart';
import '../../services/patient_service.dart';

class PatientsManagementScreen extends StatefulWidget {
  final Function(int, {Map<String, dynamic>? data})? onNavigate;
  const PatientsManagementScreen({super.key, this.onNavigate});

  @override
  State<PatientsManagementScreen> createState() =>
      PatientsManagementScreenState();
}

class PatientsManagementScreenState extends State<PatientsManagementScreen> {
  final PatientService _patientService = PatientService();
  List<Map<String, dynamic>> _patients = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  int _currentPage = 0;
  static const int _pageSize = 25;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  void refreshData() {
    _loadPatients(reset: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPatients({bool reset = false}) async {
    if (reset) {
      _currentPage = 0;
      _hasMore = true;
    }
    setState(() => _isLoading = true);
    final data = await _patientService.getAllPatientsWithFinancials(
      limit: _pageSize,
      offset: _currentPage * _pageSize,
      searchQuery: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
    );
    if (!mounted) return;
    setState(() {
      _patients = data;
      _hasMore = data.length >= _pageSize;
      _isLoading = false;
    });
  }

  Future<void> _deletePatient(Map<String, dynamic> patient) async {
    int testCount = patient['test_count'] as int;
    int id = patient['id'] as int;
    String name = patient['name'] as String;

    if (testCount > 0) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('تأكيد الحذف النهائي'),
          content: Text(
            'المريض "$name" لديه نتائج مسجلة.\n\nتأكيد الحذف سيقوم بحذف المريض وجميع النتائج المتعلقة به نهائياً.\n\nهل أنت متأكد؟',
            style: const TextStyle(color: Colors.red),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text(
                'تأكيد الحذف',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );

      if (confirm != true) return;
    }

    await _patientService.deletePatient(id);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('تم حذف المريض "$name" بنجاح')));
    _loadPatients();
  }

  void _editPatient(Map<String, dynamic> patient) async {
    // Navigate to Registration Screen (Index 2 in MainLayout)
    widget.onNavigate?.call(2, data: {'patient_id': patient['id']});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المرضى (Patients)'),
        actions: [
          IconButton(onPressed: _loadPatients, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'بحث بالاسم، رقم الهاتف، أو ملف المريض...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _loadPatients(reset: true);
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _loadPatients(reset: true),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _loadPatients(reset: true),
                  icon: const Icon(Icons.search),
                  label: const Text('بحث'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _patients.isEmpty
                    ? const Center(child: Text('لا يوجد مرضى مطابقين للبحث'))
                    : SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('ID')),
                    DataColumn(label: Text('الاسم')),
                    DataColumn(label: Text('العمر')),
                    DataColumn(label: Text('الجنس')),
                    DataColumn(label: Text('تاريخ التسجيل')),
                    DataColumn(label: Text('عدد التحاليل')),
                    DataColumn(label: Text('الإجمالي')),
                    DataColumn(label: Text('المدفوع')),
                    DataColumn(label: Text('المتبقي')),
                    DataColumn(label: Text('إجراءات')),
                  ],
                  rows: _patients.map((p) {
                    double total = (p['total_gross'] as num?)?.toDouble() ?? 0;
                    double discount =
                        (p['total_discount'] as num?)?.toDouble() ?? 0;
                    double paid = (p['total_paid'] as num?)?.toDouble() ?? 0;
                    double netTotal = total - discount;
                    double remaining = paid - netTotal;

                    return DataRow(
                      cells: [
                        DataCell(Text(p['daily_id'].toString())),
                        DataCell(Text(p['name'])),
                        DataCell(Text(p['age'].toString())),
                        DataCell(
                          Text(
                            (p['gender'].toString().toLowerCase() == 'male')
                                ? 'ذكر'
                                : (p['gender'].toString().toLowerCase() ==
                                      'female')
                                ? 'أنثى'
                                : p['gender'],
                          ),
                        ),
                        DataCell(
                          Text(p['created_at'].toString().split('T')[0]),
                        ),
                        DataCell(Text(p['test_count'].toString())),
                        DataCell(Text(netTotal.toStringAsFixed(2))),
                        DataCell(Text(paid.toStringAsFixed(2))),
                        DataCell(
                          Text(
                            remaining.toStringAsFixed(2),
                            style: TextStyle(
                              color: remaining < 0
                                  ? Colors.red
                                  : remaining > 0
                                      ? Colors.green
                                      : Theme.of(context).textTheme.bodyMedium?.color,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.assignment_turned_in,
                                  color: Colors.green,
                                ),
                                tooltip: 'عرض نتائج فحوصات المريض',
                                onPressed: (p['test_count'] as int) > 0
                                    ? () {
                                        widget.onNavigate?.call(
                                          3,
                                          data: {'patient_id': p['id']},
                                        );
                                      }
                                    : null,
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.edit,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                onPressed: () => _editPatient(p),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                onPressed: () => _deletePatient(p),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('الصفحة ${_currentPage + 1} (العدد: ${_patients.length})'),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: _currentPage > 0
                          ? () {
                              setState(() => _currentPage--);
                              _loadPatients();
                            }
                          : null,
                      child: const Text('السابق'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _hasMore
                          ? () {
                              setState(() => _currentPage++);
                              _loadPatients();
                            }
                          : null,
                      child: const Text('التالي'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
