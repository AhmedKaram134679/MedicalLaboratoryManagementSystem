import 'package:flutter/material.dart';
import '../../models/report_model.dart';

class ReportFilterBar extends StatefulWidget {
  final Function(
    ReportType? type,
    ReportStatus? status,
    DateTime? startDate,
    DateTime? endDate,
    int? doctorId,
    int? testId,
  )
  onFilterChanged;

  final List<Map<String, dynamic>> doctors;
  final List<Map<String, dynamic>> tests;

  const ReportFilterBar({
    super.key,
    required this.onFilterChanged,
    required this.doctors,
    required this.tests,
  });

  @override
  State<ReportFilterBar> createState() => _ReportFilterBarState();
}

class _ReportFilterBarState extends State<ReportFilterBar> {
  bool _isExpanded = false;
  ReportType? _selectedType;
  ReportStatus? _selectedStatus;
  DateTime? _startDate;
  DateTime? _endDate;
  int? _selectedDoctorId;
  int? _selectedTestId;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.filter_list),
            title: const Text('تصفية النتائج والتحليلات'),
            trailing: IconButton(
              icon: Icon(_isExpanded ? Icons.expand_less : Icons.expand_more),
              onPressed: () => setState(() => _isExpanded = !_isExpanded),
            ),
          ),
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<ReportType>(
                          decoration: const InputDecoration(
                            labelText: 'نوع التقرير',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.category),
                          ),
                          initialValue: _selectedType,
                          items: const [
                            DropdownMenuItem(value: null, child: Text('الكل')),
                            DropdownMenuItem(
                              value: ReportType.inventory,
                              child: Text('مخزون'),
                            ),
                            DropdownMenuItem(
                              value: ReportType.financial,
                              child: Text('مالي'),
                            ),
                            DropdownMenuItem(
                              value: ReportType.tests,
                              child: Text('تحاليل'),
                            ),
                            DropdownMenuItem(
                              value: ReportType.daily,
                              child: Text('يومي'),
                            ),
                            DropdownMenuItem(
                              value: ReportType.monthly,
                              child: Text('شهري'),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() => _selectedType = value);
                            _applyFilters();
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<ReportStatus>(
                          decoration: const InputDecoration(
                            labelText: 'حالة التقرير / الفحص',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.info_outline),
                          ),
                          initialValue: _selectedStatus,
                          items: const [
                            DropdownMenuItem(value: null, child: Text('الكل')),
                            DropdownMenuItem(
                              value: ReportStatus.draft,
                              child: Text('مسودة'),
                            ),
                            DropdownMenuItem(
                              value: ReportStatus.ready,
                              child: Text('جاهز'),
                            ),
                            DropdownMenuItem(
                              value: ReportStatus.approved,
                              child: Text('معتمد'),
                            ),
                            DropdownMenuItem(
                              value: ReportStatus.rejected,
                              child: Text('مرفوض'),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() => _selectedStatus = value);
                            _applyFilters();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          decoration: const InputDecoration(
                            labelText: 'الطبيب المُحيل',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person),
                          ),
                          initialValue: _selectedDoctorId,
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('كل الأطباء'),
                            ),
                            ...widget.doctors.map(
                              (d) => DropdownMenuItem(
                                value: d['id'] as int,
                                child: Text(d['name']),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() => _selectedDoctorId = value);
                            _applyFilters();
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          decoration: const InputDecoration(
                            labelText: 'نوع التحليل',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.science),
                          ),
                          initialValue: _selectedTestId,
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('كل التحاليل'),
                            ),
                            ...widget.tests.map(
                              (t) => DropdownMenuItem(
                                value: t['id'] as int,
                                child: Text(t['name']),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() => _selectedTestId = value);
                            _applyFilters();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Date Range Filter
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _startDate ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (!mounted) return;
                            if (picked != null) {
                              setState(() => _startDate = picked);
                              _applyFilters();
                            }
                          },
                          icon: const Icon(Icons.date_range),
                          label: Text(
                            _startDate == null
                                ? 'من تاريخ'
                                : '${_startDate!.year}-${_startDate!.month}-${_startDate!.day}',
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _endDate ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (!mounted) return;
                            if (picked != null) {
                              setState(() => _endDate = picked);
                              _applyFilters();
                            }
                          },
                          icon: const Icon(Icons.date_range),
                          label: Text(
                            _endDate == null
                                ? 'إلى تاريخ'
                                : '${_endDate!.year}-${_endDate!.month}-${_endDate!.day}',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Reset Button
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _selectedType = null;
                        _selectedStatus = null;
                        _startDate = null;
                        _endDate = null;
                        _selectedDoctorId = null;
                        _selectedTestId = null;
                      });
                      _applyFilters();
                    },
                    icon: const Icon(Icons.clear_all),
                    label: const Text('إعادة تعيين الفلاتر'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _applyFilters() {
    widget.onFilterChanged(
      _selectedType,
      _selectedStatus,
      _startDate,
      _endDate,
      _selectedDoctorId,
      _selectedTestId,
    );
  }
}
