import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/patient_model.dart';
import '../../models/test_metadata_model.dart';
import '../../services/patient_service.dart';
import '../../services/test_service.dart';
import 'package:printing/printing.dart';
import '../../services/pdf_service.dart';
import '../../models/doctor_model.dart';
import '../../services/doctor_service.dart';

class PatientRegistrationScreen extends StatefulWidget {
  final int? editPatientId;
  final Function(int)? onNavigate;
  const PatientRegistrationScreen({super.key, this.editPatientId, this.onNavigate});

  @override
  State<PatientRegistrationScreen> createState() =>
      _PatientRegistrationScreenState();
}

class _PatientRegistrationScreenState extends State<PatientRegistrationScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _fileNoController = TextEditingController();
  final _ageController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _discountController = TextEditingController(text: '0');
  final _paidController = TextEditingController(text: '0');
  final _newDoctorController = TextEditingController();

  String _gender = 'Male';
  bool _isWhatsapp = false;
  int _nextDailyId = 1;

  List<DoctorModel> _doctors = [];
  int? _selectedDoctorId;
  bool _isAddingNewDoctor = false;

  List<TestMetadataModel> _availableTests = [];
  List<TestMetadataModel?> _selectedTests = [
    null,
    null,
    null,
  ]; // Default 3 slots slots as requested

  double _total = 0;

  final _notesController = TextEditingController();
  bool _isPrintingReceipt = true;

  String get _safeGender {
    if (_gender == 'Male' || _gender == 'Female') return _gender;
    return 'Male';
  }

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _fileNoController.dispose();
    _ageController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _discountController.dispose();
    _paidController.dispose();
    _newDoctorController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _loadInitialData() async {
    await _loadTests(); // Await to ensure tests are loaded before setting selected
    _loadDoctors();

    if (widget.editPatientId != null) {
      _loadPatientForEdit(widget.editPatientId!);
    } else {
      _loadNextDailyId();
    }
  }

  Future<void> _loadTests() async {
    final tests = await TestService().getAllTests();
    if (!mounted) return;
    setState(() => _availableTests = tests);
  }

  void _loadPatientForEdit(int id) async {
    final patient = await PatientService().getPatient(id);
    if (!mounted || patient == null) return;

    final patientTests = await PatientService().getPatientTests(id);
    if (!mounted) return;

    // Populate tests
    List<TestMetadataModel?> loadedTests = [];
    for (var pt in patientTests) {
      try {
        var meta = _availableTests.firstWhere((t) => t.id == pt['test_id']);
        loadedTests.add(meta);
      } catch (e) {
        // Test might be disabled or deleted
      }
    }

    // Pad to 3
    while (loadedTests.length < 3) {
      loadedTests.add(null);
    }

    double totalDiscount = 0;
    double totalPaid = 0;
    for (var pt in patientTests) {
      totalDiscount += (pt['discount'] as num).toDouble();
      totalPaid += (pt['paid'] as num).toDouble();
    }

    double sum = 0;
    for (var test in loadedTests) {
      if (test != null) sum += test.price;
    }

    if (!mounted) return;

    setState(() {
      _nextDailyId = patient.dailyId;
      _nameController.text = patient.name;
      _fileNoController.text = patient.fileNo ?? '';
      _ageController.text = patient.age > 0 ? patient.age.toString() : '';

      // Normalize gender value
      String dbGender = patient.gender.trim();
      if (dbGender == 'ذكر' || dbGender == 'Male') {
        _gender = 'Male';
      } else if (dbGender == 'أنثى' || dbGender == 'Female') {
        _gender = 'Female';
      } else {
        _gender = 'Male'; // Default fallback
      }

      _phoneController.text = patient.phone ?? '';
      _addressController.text = patient.address ?? '';
      _isWhatsapp = patient.isWhatsapp;
      _selectedDoctorId = patient.doctorId;
      _notesController.text = patient.notes ?? '';

      _selectedTests = loadedTests;
      _total = sum;
      _discountController.text = totalDiscount.toString();
      _paidController.text = totalPaid.toString();
    });
  }

  void _loadDoctors() async {
    final doctors = await DoctorService().getAllDoctors();
    if (!mounted) return;
    setState(() => _doctors = doctors);
  }

  void _loadNextDailyId() async {
    final id = await PatientService().getNextDailyId();
    if (!mounted) return;
    setState(() => _nextDailyId = id);
  }

  void _calculateTotal() {
    double sum = 0;
    for (var test in _selectedTests) {
      if (test != null) sum += test.price;
    }
    setState(() => _total = sum);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    double discount = double.tryParse(_discountController.text) ?? 0;
    double netTotal = max(_total - discount, 0);
    double paid = double.tryParse(_paidController.text) ?? 0;
    double remaining = max(netTotal - paid, 0);
    double overpayment = max(paid - netTotal, 0);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تسجيل مريض جديد',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          _buildPatientInfoCard(),
                          const SizedBox(height: 24),
                          _buildTestsCard(),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      flex: 1,
                      child: _buildBillingCard(
                        discount,
                        netTotal,
                        paid,
                        remaining,
                        overpayment: overpayment,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPatientInfoCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'البيانات الأساسية',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: _nextDailyId.toString(),
                    key: Key('daily_id_$_nextDailyId'),
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Patient ID (Daily)',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.tag),
                      fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'اسم المريض',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (v) => v!.isEmpty ? 'يرجى إدخال الاسم' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _fileNoController,
              decoration: const InputDecoration(
                labelText: 'رقم الملف / ID (اختياري)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description_outlined),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _ageController,
                    decoration: const InputDecoration(
                      labelText: 'السن',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _safeGender,
                    decoration: const InputDecoration(
                      labelText: 'النوع',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Male',
                        child: Text('Male (ذكر)'),
                      ),
                      DropdownMenuItem(
                        value: 'Female',
                        child: Text('Female (أنثى)'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _gender = v);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int?>(
                    initialValue: _selectedDoctorId,
                    decoration: const InputDecoration(
                      labelText: 'الطبيب المحوّل',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.medical_services_outlined),
                    ),
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('None')),
                      ..._doctors.map(
                        (d) =>
                            DropdownMenuItem(value: d.id, child: Text(d.name)),
                      ),
                      const DropdownMenuItem(
                        value: -1,
                        child: Row(
                          children: [
                            Icon(Icons.add, size: 18),
                            SizedBox(width: 8),
                            Text('Add New Doctor'),
                          ],
                        ),
                      ),
                    ],
                    onChanged: (v) {
                      if (v == -1) {
                        setState(() {
                          _isAddingNewDoctor = true;
                          _selectedDoctorId = null;
                        });
                      } else {
                        setState(() {
                          _isAddingNewDoctor = false;
                          _selectedDoctorId = v;
                        });
                      }
                    },
                  ),
                ),
                if (_isAddingNewDoctor) ...[
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _newDoctorController,
                      decoration: InputDecoration(
                        labelText: 'اسم الطبيب الجديد',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.check, color: Colors.green),
                          onPressed: () async {
                            if (_newDoctorController.text.isNotEmpty) {
                              final id = await DoctorService().addDoctor(
                                _newDoctorController.text,
                              );
                              _loadDoctors();
                              setState(() {
                                _selectedDoctorId = id;
                                _isAddingNewDoctor = false;
                                _newDoctorController.clear();
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'رقم الهاتف',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'العنوان (Address)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              title: const Text('رقم واتساب؟'),
              value: _isWhatsapp,
              onChanged: (v) => setState(() => _isWhatsapp = v!),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'ملاحظات طبية (Clinical Notes)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note_alt_outlined),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestsCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'التحاليل المطلوبة',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _selectedTests.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                return Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<TestMetadataModel>(
                        initialValue: _selectedTests[index],
                        decoration: InputDecoration(
                          labelText: 'التحليل ${index + 1}',
                          border: const OutlineInputBorder(),
                        ),
                        items: _availableTests
                            .map(
                              (t) => DropdownMenuItem(
                                value: t,
                                child: Text(t.name),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          setState(() => _selectedTests[index] = v);
                          _calculateTotal();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: TextFormField(
                        initialValue:
                            _selectedTests[index]?.price.toString() ?? '0',
                        key: Key('price_${_selectedTests[index]?.id}_$index'),
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'السعر',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => setState(() {
                        _selectedTests.removeAt(index);
                        _calculateTotal();
                      }),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            Center(
              child: ElevatedButton.icon(
                onPressed: () => setState(() => _selectedTests.add(null)),
                icon: const Icon(Icons.add),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
                label: const Text('إضافة تحليل (Add Test)'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBillingCard(
    double discount,
    double netTotal,
    double paid,
    double remaining, {
    double overpayment = 0.0,
  }) {
    return Card(
      elevation: 0,
      color: Theme.of(context).primaryColor.withAlpha(
        (255 * 0.05).round(),
      ), // Changed from withOpacity to withAlpha
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).primaryColor.withAlpha(
            (255 * 0.2).round(),
          ), // Changed from withOpacity to withAlpha
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Text('ملخص الحساب', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            _buildSummaryRow(
              'إجمالي التحاليل (Total)',
              _total.toStringAsFixed(2),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _discountController,
              decoration: const InputDecoration(
                labelText: 'الخصم',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            _buildSummaryRow(
              'الإجمالي الصافي (Net Total)',
              netTotal.toStringAsFixed(2),
              isBold: true,
            ),
            const Divider(height: 32),
            TextFormField(
              controller: _paidController,
              decoration: const InputDecoration(
                labelText: 'المدفوع',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
            ),
            const Divider(height: 32),
            _buildSummaryRow(
              'المتبقي',
              remaining > 0
                  ? '${remaining.toStringAsFixed(2)} (دين / مستحق)'
                  : overpayment > 0
                      ? '${overpayment.toStringAsFixed(2)} (فائض / مسترد)'
                      : '0.00 (خالص)',
              isBold: true,
              color: remaining > 0
                  ? Colors.red
                  : overpayment > 0
                      ? Colors.green
                      : Theme.of(context).colorScheme.onSurface,
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              title: const Text('طباعة إيصال (Print Receipt)'),
              value: _isPrintingReceipt,
              onChanged: (v) => setState(() => _isPrintingReceipt = v!),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _savePatient,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _isPrintingReceipt
                      ? (widget.editPatientId != null
                            ? 'تحديث وطباعة'
                            : 'حفظ وطباعة')
                      : (widget.editPatientId != null
                            ? 'تحديث البيانات'
                            : 'حفظ وتسجيل'),
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _savePatient() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedTests.where((t) => t != null).isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يرجى اختيار تحليل واحد على الأقل')),
        );
        return;
      }

      final patient = PatientModel(
        id: widget.editPatientId, // Keep ID if editing
        dailyId: _nextDailyId,
        fileNo: _fileNoController.text.isEmpty ? null : _fileNoController.text,
        name: _nameController.text,
        age: int.tryParse(_ageController.text) ?? 0,
        gender: _gender,
        phone: _phoneController.text,
        address: _addressController.text.isEmpty ? null : _addressController.text,
        isWhatsapp: _isWhatsapp,
        doctorId: _selectedDoctorId,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
        createdAt: DateTime.now(),
      );

      try {
        // Prepare tests for Sync
        List<Map<String, dynamic>> testsToSync = [];

        double globalDiscount = double.tryParse(_discountController.text) ?? 0;
        double globalPaid = double.tryParse(_paidController.text) ?? 0;
        double total = _total;

        final validTests = _selectedTests.whereType<TestMetadataModel>().toList();
        double runningDiscount = 0.0;
        double runningPaid = 0.0;

        for (int i = 0; i < validTests.length; i++) {
          final test = validTests[i];
          final bool isLast = i == validTests.length - 1;

          double itemDiscount;
          double itemPaid;

          if (isLast) {
            // Assign remaining difference to the last item to guarantee sum equals global totals exactly
            itemDiscount = double.parse((globalDiscount - runningDiscount).toStringAsFixed(2));
            itemPaid = double.parse((globalPaid - runningPaid).toStringAsFixed(2));
          } else {
            double ratio = total > 0 ? (test.price / total) : 0;
            itemDiscount = double.parse((globalDiscount * ratio).toStringAsFixed(2));
            itemPaid = double.parse((globalPaid * ratio).toStringAsFixed(2));
            runningDiscount += itemDiscount;
            runningPaid += itemPaid;
          }

          testsToSync.add({
            'test_id': test.id,
            'total_price': test.price,
            'discount': itemDiscount,
            'paid': itemPaid,
          });
        }

        // Check if modifying tests will delete existing entered results
        if (widget.editPatientId != null) {
          final newTestIds = testsToSync.map((t) => t['test_id'] as int).toList();
          final activeResultsCount = await PatientService().countActiveResultsForRemovedTests(
            widget.editPatientId!,
            newTestIds,
          );
          if (activeResultsCount > 0) {
            if (!mounted) return;
            final bool? proceed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('تأكيد تعديل الفحوصات'),
                  ],
                ),
                content: Text(
                  'تنبيه: إزالة بعض الفحوصات سيؤدي إلى حذف $activeResultsCount نتيجة مسجلة بالفعل لها.\nهل أنت متأكد من المتابعة وحذف هذه النتائج؟',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('إلغاء'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text('نعم، احذف وتابع'),
                  ),
                ],
              ),
            );
            if (proceed != true) return;
          }
        }

        // Save patient and sync tests in ONE single atomic transaction
        int patientId;
        if (widget.editPatientId != null) {
          final old = await PatientService().getPatient(widget.editPatientId!);
          final updatedPatient = PatientModel(
            id: old!.id,
            dailyId: old.dailyId,
            fileNo: _fileNoController.text.isEmpty
                ? null
                : _fileNoController.text,
            name: _nameController.text,
            age: int.tryParse(_ageController.text) ?? 0,
            gender: _gender,
            phone: _phoneController.text,
            address: _addressController.text.isEmpty ? null : _addressController.text,
            isWhatsapp: _isWhatsapp,
            doctorId: _selectedDoctorId,
            notes: _notesController.text.isEmpty ? null : _notesController.text,
            createdAt: old.createdAt,
          );
          patientId = await PatientService().savePatientWithTests(updatedPatient, testsToSync);
        } else {
          patientId = await PatientService().savePatientWithTests(patient, testsToSync);
        }

        if (!mounted) return;

        if (_isPrintingReceipt) {
          // Call print service
          double globalDiscount =
              double.tryParse(_discountController.text) ?? 0;
          double globalPaid = double.tryParse(_paidController.text) ?? 0;
          double netTotal = max(_total - globalDiscount, 0);
          double remaining = max(netTotal - globalPaid, 0);

          List<Map<String, dynamic>> receiptTests = [];
          for (var t in _selectedTests) {
            if (t != null) {
              receiptTests.add({'name': t.name, 'price': t.price});
            }
          }

          try {
            // Re-fetch persisted patient from database to guarantee accurate persisted dailyId
            final persistedPatient = await PatientService().getPatient(patientId) ?? patient;

            String? doctorName;
            if (_selectedDoctorId != null) {
              try {
                doctorName = _doctors
                    .firstWhere((d) => d.id == _selectedDoctorId)
                    .name;
              } catch (e) {
                debugPrint('Referred doctor lookup fallback: $e');
              }
            }

            final pdfFile = await const PdfService().generateReceipt(
              patient: persistedPatient,
              selectedTests: receiptTests,
              total: _total,
              discount: globalDiscount,
              paid: globalPaid,
              remaining: remaining,
              referredDoctor: doctorName,
              updatedAt: persistedPatient.updatedAt,
            );

            await Printing.layoutPdf(
              onLayout: (format) => pdfFile.readAsBytes(),
              name: 'Receipt_${persistedPatient.dailyId}.pdf',
            );

            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تم الحفظ وجاري الطباعة...')),
            );
          } catch (e) {
            debugPrint('Printing error: $e');
            if (mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('خطأ في الطباعة: $e')));
            }
          }
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم حفظ بيانات المريض والتحاليل بنجاح'),
            ),
          );
        }

        if (widget.editPatientId != null) {
          if (widget.onNavigate != null) {
            widget.onNavigate!(1); // Navigate back to Patients Management tab
          } else if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }
        } else {
          _resetForm();
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ في الحفظ: $e')));
      }
    }
  }

  void _resetForm() {
    _formKey.currentState!.reset();
    _nameController.clear();
    _fileNoController.clear();
    _ageController.clear();
    _phoneController.clear();
    _discountController.text = '0';
    _paidController.text = '0';
    _newDoctorController.clear();
    setState(() {
      _gender = 'Male';
      _selectedTests = [null, null, null];
      _selectedDoctorId = null;
      _isAddingNewDoctor = false;
      _total = 0;
      _notesController.clear();
      _isPrintingReceipt = true;
    });
    _loadNextDailyId();
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool isBold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 18 : 14,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
