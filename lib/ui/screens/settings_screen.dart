import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:lab_managment_system/providers/app_provider.dart';
import 'package:provider/provider.dart';
import '../../services/doctor_service.dart';
import '../../services/test_service.dart';
import '../../services/settings_service.dart';
import '../../services/audit_service.dart';
import '../../services/user_service.dart';
import '../../services/inventory_service.dart';
import '../../models/doctor_model.dart';
import '../../models/test_metadata_model.dart';
import '../../models/audit_log_model.dart';
import '../../models/user_model.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _labNameController = TextEditingController();
  final _labPhoneController = TextEditingController();
  final _labAddressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _labNameController.dispose();
    _labPhoneController.dispose();
    _labAddressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إعدادات النظام (Settings)'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.science), text: 'التحاليل'),
            Tab(icon: Icon(Icons.person_pin), text: 'الأطباء'),
            Tab(icon: Icon(Icons.group), text: 'المستخدمين'),
            Tab(icon: Icon(Icons.business), text: 'بيانات المعمل'),
            Tab(icon: Icon(Icons.history), text: 'سجل العمليات'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTestsTab(),
          _buildDoctorsTab(),
          _buildUsersTab(),
          _buildLabInfoTab(),
          _buildAuditLogTab(),
        ],
      ),
    );
  }

  // --- 1. Tests Management Tab ---
  Widget _buildTestsTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'قائمة التحاليل المتاحة',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddEditTestDialog(),
                icon: const Icon(Icons.add),
                label: const Text('إضافة تحليل جديد'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<TestMetadataModel>>(
              future: TestService().getAllTestsIncludingInactive(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('خطأ في تحميل التحاليل: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('لا توجد تحاليل مسجلة حالياً'));
                }
                final tests = snapshot.data!;
                return ListView.builder(
                  itemCount: tests.length,
                  itemBuilder: (context, index) {
                    final test = tests[index];
                    return ListTile(
                      title: Text(test.name),
                      subtitle: Text('السعر: ${test.price}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (test.isActive == 0)
                            const Padding(
                              padding: EdgeInsets.only(left: 8.0),
                              child: Chip(
                                label: Text(
                                  'غير نشط',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.white,
                                  ),
                                ),
                                backgroundColor: Colors.orange,
                              ),
                            ),
                          IconButton(
                            icon: const Icon(Icons.list_alt, color: Colors.teal),
                            tooltip: 'تعديل عناصر التحليل (Test Fields)',
                            onPressed: () => _showManageTestFieldsDialog(test),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _showAddEditTestDialog(test: test),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _confirmDeleteTest(test),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- 2. Doctors Management Tab ---
  Widget _buildDoctorsTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'قائمة الأطباء المحولين',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddEditDoctorDialog(),
                icon: const Icon(Icons.add),
                label: const Text('إضافة طبيب جديد'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<DoctorModel>>(
              future: DoctorService().getAllDoctors(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('خطأ في تحميل بيانات الأطباء: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('لا يوجد أطباء مسجلون حالياً'));
                }
                final doctors = snapshot.data!;
                return ListView.builder(
                  itemCount: doctors.length,
                  itemBuilder: (context, index) {
                    final doctor = doctors[index];
                    return ListTile(
                      title: Text(doctor.name),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () =>
                                _showAddEditDoctorDialog(doctor: doctor),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _confirmDeleteDoctor(doctor),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- 3. Users Tab ---
  Widget _buildUsersTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'إدارة المستخدمين',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddEditUserDialog(),
                icon: const Icon(Icons.person_add),
                label: const Text('إضافة مستخدم جديد'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<UserModel>>(
              future: UserService().getAllUsers(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('خطأ في تحميل المستخدمين: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('لا يوجد مستخدمون مسجلون حالياً'));
                }
                final users = snapshot.data!;
                return ListView.separated(
                  itemCount: users.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) {
                    final user = users[index];
                    return ListTile(
                      leading: CircleAvatar(
                        child: Icon(
                          user.role == 'admin' ? Icons.security : Icons.person,
                        ),
                      ),
                      title: Text(user.fullName ?? user.username),
                      subtitle: Text(
                        'اسم المستخدم: ${user.username} - النوع: ${user.role}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _showAddEditUserDialog(user: user),
                          ),
                          Builder(
                            builder: (btnCtx) {
                              final appProvider = Provider.of<AppProvider>(btnCtx, listen: false);
                              final isCurrentUser = appProvider.currentUser?.id == user.id;
                              if (isCurrentUser) return const SizedBox.shrink();
                              return IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _confirmDeleteUser(user),
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabInfoTab() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: FutureBuilder<Map<String, dynamic>>(
        future:
            Future.wait([
              SettingsService().getLabName(),
              SettingsService().getLabPhone(),
              SettingsService().getLabAddress(),
              SettingsService().getLabLogoPath(),
              SettingsService().getReportIncludeInfo(),
              SettingsService().getReportPosLabName(),
              SettingsService().getReportPosLabAddress(),
              SettingsService().getReportPosLabPhone(),
              SettingsService().getReportPosLabLogo(),
              SettingsService().getUsePreprintedLetterhead(),
            ]).then(
              (values) => {
                'name': values[0] as String?,
                'phone': values[1] as String?,
                'address': values[2] as String?,
                'logo': values[3] as String?,
                'include_info': values[4] as bool,
                'pos_name': values[5] as String,
                'pos_address': values[6] as String,
                'pos_phone': values[7] as String,
                'pos_logo': values[8] as String,
                'use_preprinted_letterhead': values[9] as bool,
              },
            ),
        builder: (snapshotContext, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            if (_labNameController.text.isEmpty) {
              _labNameController.text = snapshot.data?['name'] ?? '';
              _labPhoneController.text = snapshot.data?['phone'] ?? '';
              _labAddressController.text = snapshot.data?['address'] ?? '';
            }
          }
          final logoPath = snapshot.data?['logo'];

          // Use state variables if initialized, otherwise snapshot, but we need state for dropdowns
          // Since this is a builder, we should use a StatefulBuilder inside or manage state in parent.
          // Current structure rebuilds on clean, but dropdowns need state.
          // Let's use a local StatefulBuilder for the form part or rely on the parent state if variables were lifted.
          // BUT the parent definition doesn't have these vars.
          // Correct approach: We need to add these vars to the main state class and initialize them.
          // However, to avoid massive refactor of the whole file, I will use a StatefulBuilder WRAPPER around the interactive parts,
          // OR better: define the default values from snapshot and control them via local variables if I could.
          // ACTUALLY, the cleanest way without changing the class state definitions (which I can't easily see all of)
          // is to use StatefulBuilder for the new section.

          bool includeInfo = snapshot.data?['include_info'] ?? true;
          bool usePreprintedLetterhead = snapshot.data?['use_preprinted_letterhead'] ?? false;
          String posName = snapshot.data?['pos_name'] ?? 'top_right';
          String posAddress = snapshot.data?['pos_address'] ?? 'top_center';
          String posPhone = snapshot.data?['pos_phone'] ?? 'top_left';
          String posLogo = snapshot.data?['pos_logo'] ?? 'top_left';

          return StatefulBuilder(
            builder: (context, setInternalState) {
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'بيانات المعمل الأساسية',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _labNameController,
                      decoration: const InputDecoration(
                        labelText: 'اسم المعمل',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.business),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _labPhoneController,
                      decoration: const InputDecoration(
                        labelText: 'رقم الهاتف',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _labAddressController,
                      decoration: const InputDecoration(
                        labelText: 'العنوان',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.location_on),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'شعار المعمل (Logo)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          height: 100,
                          width: 200,
                          decoration: BoxDecoration(
                            border: Border.all(color: Theme.of(context).colorScheme.outline),
                            borderRadius: BorderRadius.circular(8),
                            image: logoPath != null
                                ? DecorationImage(
                                    image: FileImage(File(logoPath)),
                                    fit: BoxFit.contain,
                                  )
                                : null,
                          ),
                          child: logoPath == null
                              ? Center(
                                  child: Icon(
                                    Icons.add_a_photo_outlined,
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          onPressed: () => _pickImage('lab_logo_path'),
                          icon: const Icon(Icons.upload),
                          label: const Text('اختيار شعار'),
                        ),
                      ],
                    ),
                    const Divider(height: 48),
                    const Text(
                      'تخصيص التقرير (Report Customization)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SwitchListTile(
                      title: const Text('تضمين بيانات المعمل في التقرير'),
                      subtitle: const Text(
                        'عند التفعيل، سيتم طباعة الاسم والشعار والهاتف في التقرير. عند التعطيل، يترك المكان فارغاً للورق المطبوع مسبقاً.',
                      ),
                      value: includeInfo,
                      onChanged: (val) {
                        setInternalState(() => includeInfo = val);
                      },
                    ),
                    SwitchListTile(
                      title: const Text('استخدام ورق ترويسة مطبوع مسبقاً (Pre-Printed Letterhead)'),
                      subtitle: const Text(
                        'عند التفعيل، يترك هامش علوي مقداره 5 سم (141.7 pt) لكليشة الورق وتُحجب الترويسة المضمنة تلقائياً.',
                      ),
                      value: usePreprintedLetterhead,
                      onChanged: (val) {
                        setInternalState(() => usePreprintedLetterhead = val);
                      },
                    ),
                    if (includeInfo && !usePreprintedLetterhead) ...[
                      const SizedBox(height: 16),
                      _buildPosDropdown(
                        'موقع اسم المعمل',
                        posName,
                        (v) => setInternalState(() => posName = v!),
                      ),
                      _buildPosDropdown(
                        'موقع الشعار',
                        posLogo,
                        (v) => setInternalState(() => posLogo = v!),
                      ),
                      _buildPosDropdown(
                        'موقع الهاتف',
                        posPhone,
                        (v) => setInternalState(() => posPhone = v!),
                      ),
                      _buildPosDropdown(
                        'موقع العنوان',
                        posAddress,
                        (v) => setInternalState(() => posAddress = v!),
                      ),
                    ],
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: () async {
                        await SettingsService().saveSetting(
                          'lab_name',
                          _labNameController.text,
                        );
                        await SettingsService().saveSetting(
                          'lab_phone',
                          _labPhoneController.text,
                        );
                        await SettingsService().saveSetting(
                          'lab_address',
                          _labAddressController.text,
                        );
                        // Save Customization
                        await SettingsService().saveSetting(
                          'report_include_info',
                          includeInfo.toString(),
                        );
                        await SettingsService().saveSetting(
                          'use_preprinted_letterhead',
                          usePreprintedLetterhead.toString(),
                        );
                        await SettingsService().saveSetting(
                          'report_pos_lab_name',
                          posName,
                        );
                        await SettingsService().saveSetting(
                          'report_pos_lab_address',
                          posAddress,
                        );
                        await SettingsService().saveSetting(
                          'report_pos_lab_phone',
                          posPhone,
                        );
                        await SettingsService().saveSetting(
                          'report_pos_lab_logo',
                          posLogo,
                        );

                        await AuditService().logAction(
                          action: 'تعديل بيانات المعمل وتخصيص التقرير',
                          dataType: 'Settings',
                        );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('تم حفظ الإعدادات بنجاح'),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(200, 50),
                      ),
                      child: const Text('حفظ جميع البيانات'),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // --- 5. Audit Log Tab ---
  Widget _buildAuditLogTab() {
    return FutureBuilder<List<AuditLogModel>>(
      future: AuditService().getAllLogs(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('خطأ في تحميل سجل العمليات: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('لا توجد سجلات تدقيق حالياً'));
        }
        final logs = snapshot.data!;
        return ListView.separated(
          itemCount: logs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final log = logs[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(
                  context,
                ).primaryColor.withValues(alpha: 0.1),
                child: const Icon(Icons.history, size: 20),
              ),
              title: Text(log.action),
              subtitle: Text(
                '${log.userName ?? "User"} • ${log.timestamp.toString().split('.')[0]}',
              ),
              trailing: Text(
                log.dataType ?? '',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- Helper Dialogs ---
  void _showAddEditTestDialog({TestMetadataModel? test}) async {
    final nameController = TextEditingController(text: test?.name);
    final priceController = TextEditingController(text: test?.price.toString());
    String selectedTemplateType = test?.templateType ?? 'generic';

    List<Map<String, dynamic>> consumption = [];
    if (test != null) {
      consumption = List.from(await TestService().getConsumption(test.id!));
    }

    final allInventory = await InventoryService().getAllItems();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(test == null ? 'إضافة تحليل جديد' : 'تعديل تحليل'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'اسم التحليل'),
                    textDirection: TextDirection.rtl,
                  ),
                  TextField(
                    controller: priceController,
                    decoration: const InputDecoration(labelText: 'السعر'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: selectedTemplateType,
                    decoration: const InputDecoration(
                      labelText: 'نوع القالب الطبي (Template Type)',
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'generic', child: Text('عام (Generic Table)')),
                      DropdownMenuItem(value: 'urine', child: Text('تحليل بول كامل (Urinalysis)')),
                      DropdownMenuItem(value: 'stool', child: Text('تحليل براز كامل (Stool Analysis)')),
                      DropdownMenuItem(value: 'vitamin_d', child: Text('فيتامين د (Vitamin D)')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedTemplateType = val);
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'استهلاك المخزون (Inventory Consumption)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Divider(),
                  ...consumption.map((item) {
                    return ListTile(
                      title: Text(item['item_name'] ?? 'Unknown'),
                      subtitle: Text('الوحدة: ${item['unit'] ?? ''}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 80,
                            child: TextField(
                              decoration: const InputDecoration(
                                isDense: true,
                                labelText: 'الكمية',
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (val) {
                                item['quantity'] = double.tryParse(val) ?? 0;
                              },
                              controller: TextEditingController(
                                text:
                                    (item['quantity'] ??
                                            item['quantity_consumed'])
                                        .toString(),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.remove_circle_outline,
                              color: Colors.red,
                            ),
                            onPressed: () {
                              setDialogState(() {
                                consumption.remove(item);
                              });
                            },
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(
                      labelText: 'إضافة مادة من المخزون',
                      isDense: true,
                    ),
                    items: allInventory.map((i) {
                      return DropdownMenuItem<int>(
                        value: i['id'],
                        child: Text(i['item_name']),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        final exists = consumption.any(
                          (c) =>
                              (c['inventory_id'] ?? c['inventory_item_id']) ==
                              val,
                        );
                        if (!exists) {
                          final item = allInventory.firstWhere(
                            (i) => i['id'] == val,
                          );
                          setDialogState(() {
                            consumption.add({
                              'inventory_id': val,
                              'item_name': item['item_name'],
                              'unit': item['unit'],
                              'quantity': 1.0,
                            });
                          });
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                nameController.dispose();
                priceController.dispose();
                Navigator.pop(dialogContext);
              },
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text;
                final price = double.tryParse(priceController.text) ?? 0;
                if (name.isNotEmpty) {
                  int testId;
                  if (test == null) {
                    testId = await TestService().addTest(
                      name,
                      price,
                      templateType: selectedTemplateType,
                    );
                    await AuditService().logAction(
                      action: 'إضافة تحليل: $name ($selectedTemplateType)',
                      dataType: 'Tests',
                    );
                  } else {
                    testId = test.id!;
                    await TestService().updateTest(
                      testId,
                      name,
                      price,
                      templateType: selectedTemplateType,
                    );
                    await AuditService().logAction(
                      action: 'تعديل تحليل: ${test.name} -> $name ($selectedTemplateType)',
                      dataType: 'Tests',
                    );
                  }

                  // Update Consumption
                  await TestService().updateConsumption(testId, consumption);

                  if (!mounted) return;
                  nameController.dispose();
                  priceController.dispose();
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                  }
                  setState(() {});
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteTest(TestMetadataModel test) async {
    final isUsed = await TestService().isTestUsed(test.id!);
    if (!mounted) return;

    if (isUsed) {
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('تنبيه: التحليل مستخدم'),
          content: const Text(
            'هذا التحليل مستخدم في سجلات المرضى. لا يمكن حذفه، ولكن يمكنك تعطيله ليكون غير متاح للتسجيلات الجديدة.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () async {
                await TestService().disableTest(test.id!);
                await AuditService().logAction(
                  action: 'تعطيل تحليل: ${test.name}',
                  dataType: 'Tests',
                );
                if (!mounted) return;
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
                setState(() {});
              },
              child: const Text(
                'تعطيل التحليل',
                style: TextStyle(color: Colors.orange),
              ),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('تأكيد الحذف'),
          content: Text('هل أنت متأكد من حذف التحليل "${test.name}"؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () async {
                await TestService().deleteTest(test.id!);
                await AuditService().logAction(
                  action: 'حذف تحليل: ${test.name}',
                  dataType: 'Tests',
                );
                if (!mounted) return;
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
                setState(() {});
              },
              child: const Text('حذف', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
    }
  }

  void _showManageTestFieldsDialog(TestMetadataModel test) async {
    final testService = TestService();
    List<Map<String, dynamic>> fields = await testService.getTestFields(test.id!);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.list_alt, color: Colors.teal),
              const SizedBox(width: 8),
              Expanded(
                child: Text('عناصر فحص: ${test.name} (Test Fields)'),
              ),
            ],
          ),
          content: SizedBox(
            width: 600,
            height: 420,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'العناصر المسجلة للتقرير:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('إضافة عنصر جديد'),
                      onPressed: () {
                        _showAddEditFieldSubDialog(
                          testId: test.id!,
                          onSaved: () async {
                            final updated = await testService.getTestFields(test.id!);
                            setDialogState(() {
                              fields = updated;
                            });
                          },
                        );
                      },
                    ),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: fields.isEmpty
                      ? Center(
                          child: Text(
                            'لا توجد عناصر مخصصة بعد لهذا التحليل.\nالتحاليل القياسية (Stool, Urine, Vitamin D) تستخدم قوالب مدمجة، أو يمكنك إضافة عناصر إضافية هنا.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: fields.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = fields[index];
                            return ListTile(
                              title: Text(item['field_name'] ?? ''),
                              subtitle: Text(
                                'الوحدة: ${item['unit'] ?? '-'} | المعدل الطبيعي: ${item['default_range'] ?? '-'}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 18),
                                    onPressed: () {
                                      _showAddEditFieldSubDialog(
                                        testId: test.id!,
                                        field: item,
                                        onSaved: () async {
                                          final updated = await testService.getTestFields(test.id!);
                                          setDialogState(() {
                                            fields = updated;
                                          });
                                        },
                                      );
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                                    onPressed: () async {
                                      final bool? confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('تأكيد حذف عنصر الفحص'),
                                          content: Text('هل أنت متأكد من حذف العنصر "${item['field_name']}" من هذا التحليل؟'),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(ctx, false),
                                              child: const Text('إلغاء'),
                                            ),
                                            TextButton(
                                              onPressed: () => Navigator.pop(ctx, true),
                                              child: const Text('حذف', style: TextStyle(color: Colors.red)),
                                            ),
                                          ],
                                        ),
                                      );

                                      if (confirm == true) {
                                        await testService.deleteTestField(item['id'] as int);
                                        await AuditService().logAction(
                                          action: 'حذف عنصر تحليل: ${item['field_name']} من التحليل ${test.name}',
                                          dataType: 'Tests',
                                        );
                                        final updated = await testService.getTestFields(test.id!);
                                        setDialogState(() {
                                          fields = updated;
                                        });
                                      }
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddEditFieldSubDialog({
    required int testId,
    Map<String, dynamic>? field,
    required VoidCallback onSaved,
  }) {
    final nameCtrl = TextEditingController(text: field?['field_name']?.toString() ?? '');
    final unitCtrl = TextEditingController(text: field?['unit']?.toString() ?? '');
    final rangeCtrl = TextEditingController(text: field?['default_range']?.toString() ?? '');

    showDialog(
      context: context,
      builder: (subCtx) => AlertDialog(
        title: Text(field == null ? 'إضافة عنصر للتحليل' : 'تعديل عنصر التحليل'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'اسم العنصر (Field Name)*',
                  hintText: 'e.g. Hemoglobin, WBC, Color',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: unitCtrl,
                decoration: const InputDecoration(
                  labelText: 'الوحدة (Unit)',
                  hintText: 'e.g. g/dL, /cumm, ng/mL',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: rangeCtrl,
                decoration: const InputDecoration(
                  labelText: 'المعدل الطبيعي (Default Range)',
                  hintText: 'e.g. 12.0 - 16.0, Negative',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(subCtx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              final unit = unitCtrl.text.trim().isEmpty ? null : unitCtrl.text.trim();
              final range = rangeCtrl.text.trim().isEmpty ? null : rangeCtrl.text.trim();

              final testService = TestService();
              if (field == null) {
                await testService.addTestField(testId, name, unit, range);
              } else {
                await testService.updateTestField(field['id'] as int, name, unit, range);
              }

              if (subCtx.mounted) {
                Navigator.pop(subCtx);
              }
              onSaved();
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _showAddEditDoctorDialog({DoctorModel? doctor}) {
    final nameController = TextEditingController(text: doctor?.name);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(doctor == null ? 'إضافة طبيب جديد' : 'تعديل اسم الطبيب'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'اسم الطبيب'),
          textDirection: TextDirection.rtl,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text;
              if (name.isNotEmpty) {
                if (doctor == null) {
                  await DoctorService().addDoctor(name);
                  await AuditService().logAction(
                    action: 'إضافة طبيب: $name',
                    dataType: 'Doctors',
                  );
                } else {
                  await DoctorService().updateDoctor(doctor.id!, name);
                  await AuditService().logAction(
                    action: 'تعديل طبيب: ${doctor.name} -> $name',
                    dataType: 'Doctors',
                  );
                }
                if (!mounted) return;
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
                setState(() {});
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteDoctor(DoctorModel doctor) async {
    final isUsed = await DoctorService().isDoctorUsed(doctor.id!);
    if (!mounted) return;

    if (isUsed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يمكن حذف هذا الطبيب لأنه مرتبط بسجلات مرضى.'),
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('تأكيد الحذف'),
          content: Text('هل أنت متأكد من حذف الطبيب "${doctor.name}"؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () async {
                await DoctorService().deleteDoctor(doctor.id!);
                await AuditService().logAction(
                  action: 'حذف طبيب: ${doctor.name}',
                  dataType: 'Doctors',
                );
                if (!mounted) return;
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
                setState(() {});
              },
              child: const Text('حذف', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
    }
  }

  // --- Image Picking ---
  Future<void> _pickImage(String settingKey) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );

    if (result != null) {
      String path = result.files.single.path!;
      await SettingsService().saveSetting(settingKey, path);
      await AuditService().logAction(
        action: 'تغيير صورة $settingKey',
        dataType: 'Settings',
      );
      if (!mounted) return;
      setState(() {});
    }
  }

  // --- Helper Widgets ---

  Widget _buildPosDropdown(
    String label,
    String value,
    Function(String?) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<String>(
              initialValue: value,
              items: const [
                DropdownMenuItem(value: 'top_right', child: Text('أعلى يمين')),
                DropdownMenuItem(value: 'top_center', child: Text('أعلى وسط')),
                DropdownMenuItem(value: 'top_left', child: Text('أعلى يسار')),
                DropdownMenuItem(
                  value: 'bottom_right',
                  child: Text('أسفل يمين'),
                ),
                DropdownMenuItem(
                  value: 'bottom_center',
                  child: Text('أسفل وسط'),
                ),
                DropdownMenuItem(
                  value: 'bottom_left',
                  child: Text('أسفل يسار'),
                ),
              ],
              onChanged: onChanged,
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Users Dialogs ---
  void _showAddEditUserDialog({UserModel? user}) {
    final usernameController = TextEditingController(text: user?.username);
    final passwordController = TextEditingController();
    String role = user?.role ?? 'user';

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContextInternal, setDialogState) {
          // Note: InputDecorator fix applied previously, so just updating context names here
          return AlertDialog(
            title: Text(user == null ? 'إضافة مستخدم جديد' : 'تعديل مستخدم'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: usernameController,
                    readOnly: user != null, // Read-only if editing
                    decoration: const InputDecoration(
                      labelText: 'اسم المستخدم',
                    ),
                  ),
                  TextField(
                    controller: passwordController,
                    decoration: InputDecoration(
                      labelText: user == null
                          ? 'كلمة المرور'
                          : 'كلمة المرور الجديدة (اختياري)',
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 16),
                  InputDecorator(
                    decoration: const InputDecoration(labelText: 'الصلاحية'),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: role,
                        isDense: true,
                        items: const [
                          DropdownMenuItem(
                            value: 'admin',
                            child: Text('Admin'),
                          ),
                          DropdownMenuItem(value: 'user', child: Text('User')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => role = val);
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (usernameController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('اسم المستخدم مطلوب')),
                    );
                    return;
                  }

                  final pwd = passwordController.text;
                  if (user == null) {
                    if (pwd.length < 8) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('كلمة المرور يجب أن تكون 8 أحرف على الأقل')),
                      );
                      return;
                    }
                  } else {
                    if (pwd.isNotEmpty && pwd.length < 8) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('كلمة المرور يجب أن تكون 8 أحرف على الأقل')),
                      );
                      return;
                    }
                  }

                  if (usernameController.text.isNotEmpty) {
                    if (user == null) {
                      await UserService().addUser(
                        UserModel(
                          username: usernameController.text,
                          password: passwordController.text,
                          role: role,
                          fullName:
                              usernameController.text, // Default to username
                        ),
                      );
                      await AuditService().logAction(
                        action: 'إضافة مستخدم: ${usernameController.text}',
                        dataType: 'Users',
                      );
                    } else {
                      await UserService().updateUser(
                        UserModel(
                          id: user.id,
                          username: usernameController.text,
                          password: passwordController.text.isEmpty
                              ? user.password
                              : passwordController
                                    .text, // Keep old password if empty
                          role: role,
                          fullName: user
                              .fullName, // Keep existing full name (hidden from edit)
                          forcePasswordChange: user.forcePasswordChange,
                        ),
                        isPasswordAlreadyHashed: passwordController.text.isEmpty,
                      );
                      await AuditService().logAction(
                        action: 'تعديل مستخدم: ${user.username}',
                        dataType: 'Users',
                      );
                    }
                    if (!mounted) return;
                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                    }
                    setState(() {});
                  }
                },
                child: const Text('حفظ'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDeleteUser(UserModel user) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف المستخدم "${user.username}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () async {
              final appProvider = Provider.of<AppProvider>(context, listen: false);
              final currentUserId = appProvider.currentUser?.id;

              final success = await UserService().deleteUser(
                user.id!,
                currentUserId: currentUserId,
              );

              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }

              if (!mounted) return;

              if (success) {
                await AuditService().logAction(
                  action: 'حذف مستخدم: ${user.username}',
                  dataType: 'Users',
                );
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم حذف المستخدم بنجاح')),
                );
                setState(() {});
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('لا يمكن حذف هذا المستخدم (المسؤول الأخير أو المستخدم النشط حالياً)'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
