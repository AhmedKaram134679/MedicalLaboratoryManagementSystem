import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/inventory_service.dart';
import '../../providers/app_provider.dart';
import '../../models/report_model.dart';
import 'report_preview_screen.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => InventoryScreenState();
}

class InventoryScreenState extends State<InventoryScreen> {
  final InventoryService _inventoryService = InventoryService();
  List<Map<String, dynamic>> _items = [];
  List<String> _alerts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void refreshData() {
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final items = await _inventoryService.getItemsWithStatus();
    final alerts = await _inventoryService.getUrgentAlerts();
    if (!mounted) return;
    setState(() {
      _items = items;
      _alerts = alerts;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = Provider.of<AppProvider>(context).isAdmin;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(isAdmin),
                const SizedBox(height: 24),
                _buildSummaryBar(),
                const SizedBox(height: 24),
                Expanded(child: _buildInventoryTable(isAdmin)),
                const SizedBox(height: 60), // For ticker
              ],
            ),
          ),
          if (_alerts.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildAlertTicker(),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isAdmin) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'إدارة المخزون - Inventory Management',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'متابعة الكواشف والمستلزمات الطبية',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
        Row(
          children: [
            if (isAdmin)
              ElevatedButton.icon(
                onPressed: () => _showItemDialog(),
                icon: const Icon(Icons.add),
                label: const Text('إضافة مادة جديدة'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 15,
                  ),
                ),
              ),
            const SizedBox(width: 12),
            IconButton(
              onPressed: _printReport,
              icon: const Icon(Icons.print),
              tooltip: 'طباعة التقرير',
              style: IconButton.styleFrom(backgroundColor: theme.cardColor),
            ),
            const SizedBox(width: 12),
            IconButton(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              tooltip: 'تحديث',
              style: IconButton.styleFrom(backgroundColor: theme.cardColor),
            ),
          ],
        ),
      ],
    );
  }

  void _printReport() {
    final user = Provider.of<AppProvider>(context, listen: false).currentUser;
    final report = ReportModel(
      id: 'INV-${DateTime.now().millisecondsSinceEpoch}',
      title: 'تقرير المخزون',
      type: ReportType.inventory,
      generatedBy: user?.fullName ?? 'Unknown',
      generatedAt: DateTime.now(),
      status: ReportStatus.draft,
      columns: [
        const ReportColumn(title: 'اسم المادة', key: 'item_name', width: 150),
        const ReportColumn(title: 'النوع', key: 'category'),
        const ReportColumn(title: 'الكمية', key: 'quantity', isNumeric: true),
        const ReportColumn(title: 'الواحدة', key: 'unit'),
        const ReportColumn(title: 'الحالة', key: 'status'),
      ],
      data: _items,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReportPreviewScreen(report: report),
      ),
    );
  }

  Widget _buildSummaryBar() {
    int critical = _items.where((i) => i['status'] == 'Critical').length;
    int warning = _items.where((i) => i['status'] == 'Warning').length;
    int safe = _items.where((i) => i['status'] == 'Safe').length;

    return Row(
      children: [
        _buildSummaryCard(
          'آمن (Safe)',
          safe.toString(),
          Colors.green,
          Icons.check_circle,
        ),
        const SizedBox(width: 16),
        _buildSummaryCard(
          'تحذير (Warning)',
          warning.toString(),
          Colors.orange,
          Icons.warning,
        ),
        const SizedBox(width: 16),
        _buildSummaryCard(
          'حرج (Critical)',
          critical.toString(),
          Colors.red,
          Icons.error,
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    Color color,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                    fontSize: 14,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInventoryTable(bool isAdmin) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Container(
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(
              Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            ),
            columns: const [
              DataColumn(
                label: Text(
                  'اسم المادة',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'النوع',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'الكمية',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'الحد الأدنى',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'تاريخ الصلاحية',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'الحالة',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'الإجراءات',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
            rows: _items.map((item) {
              Color rowColor = Colors.transparent;
              if (item['status'] == 'Critical') rowColor = Colors.red.shade50;
              if (item['status'] == 'Warning') rowColor = Colors.orange.shade50;

              return DataRow(
                color: WidgetStateProperty.all(rowColor),
                cells: [
                  DataCell(Text(item['item_name'])),
                  DataCell(Text(item['category'] ?? '-')),
                  DataCell(Text('${item['quantity']} ${item['unit']}')),
                  DataCell(Text('${item['min_threshold']} ${item['unit']}')),
                  DataCell(Text(item['expiry_date'] ?? '-')),
                  DataCell(_buildStatusChip(item['status'])),
                  DataCell(
                    Row(
                      children: [
                        if (isAdmin)
                          IconButton(
                            icon: const Icon(
                              Icons.edit,
                              color: Colors.blue,
                              size: 20,
                            ),
                            onPressed: () => _showItemDialog(item: item),
                          ),
                        if (isAdmin)
                          IconButton(
                            icon: const Icon(
                              Icons.delete,
                              color: Colors.red,
                              size: 20,
                            ),
                            onPressed: () => _confirmDelete(item),
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
    );
  }

  Widget _buildStatusChip(String status) {
    Color color = status == 'Critical'
        ? Colors.red
        : (status == 'Warning' ? Colors.orange : Colors.green);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        status == 'Critical' ? 'حرج' : (status == 'Warning' ? 'تحذير' : 'آمن'),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildAlertTicker() {
    final tickerText = _alerts.join('   |   ');
    return Container(
      height: 40,
      color: Colors.red.shade700,
      child: _Marquee(
        child: Text(
          tickerText,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  void _showItemDialog({Map<String, dynamic>? item}) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: item?['item_name']);
    final qtyController = TextEditingController(
      text: item?['quantity']?.toString(),
    );
    final thresholdController = TextEditingController(
      text: item?['min_threshold']?.toString(),
    );
    final expiryController = TextEditingController(text: item?['expiry_date']);

    // Safe mapping for legacy Arabic data
    final typeMapping = {
      'كاشف': 'Chemical',
      'اداة': 'Tool',
      'مستهلكات': 'Consumable',
      'Chemical': 'Chemical',
      'Tool': 'Tool',
      'Consumable': 'Consumable',
    };
    final unitMapping = {
      'قطعة': 'Piece',
      'علبة': 'Box',
      'لتر': 'Liter',
      'مل': 'ml',
      'جرام': 'Gram',
      'Piece': 'Piece',
      'Box': 'Box',
      'Liter': 'Liter',
      'ml': 'ml',
      'Gram': 'Gram',
    };

    String? selectedType =
        typeMapping[item?['category']] ??
        (item?['category'] != null ? 'Consumable' : null);
    String? selectedUnit =
        unitMapping[item?['unit']] ?? (item?['unit'] != null ? 'Piece' : null);

    final Map<String, String> itemTypes = {
      'Chemical': 'كاشف (Chemical)',
      'Tool': 'أداة (Tool)',
      'Consumable': 'مستهلك (Consumable)',
    };
    final Map<String, String> units = {
      'Piece': 'قطعة (Piece)',
      'Box': 'علبة (Box)',
      'Liter': 'لتر (Liter)',
      'ml': 'مل (ml)',
      'Gram': 'جرام (Gram)',
    };

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              item == null ? Icons.add_box : Icons.edit,
              color: Colors.blue.shade700,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item == null ? 'إضافة مادة جديدة' : 'تعديل بيانات مادة',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.info_outline, color: Colors.blue),
              onPressed: () => _showDataEntryHelp(),
              tooltip: 'إرشادات إدخال البيانات',
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  const SizedBox(height: 16),
                  _buildFieldLabel('اسم المادة (Item Name) *'),
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      hintText: 'مثال: Urine Container',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.inventory_2_outlined),
                      isDense: true,
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'هذا الحقل مطلوب' : null,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldLabel('النوع (Type) *'),
                            DropdownButtonFormField<String>(
                              initialValue: selectedType,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.category_outlined),
                                isDense: true,
                              ),
                              items: itemTypes.entries
                                  .map(
                                    (entry) => DropdownMenuItem(
                                      value: entry.key,
                                      child: Text(entry.value),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) => selectedType = v,
                              validator: (v) => v == null ? 'مطلوب' : null,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldLabel('الوحدة (Unit) *'),
                            DropdownButtonFormField<String>(
                              initialValue: selectedUnit,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.straighten_outlined),
                                isDense: true,
                              ),
                              items: units.entries
                                  .map(
                                    (entry) => DropdownMenuItem(
                                      value: entry.key,
                                      child: Text(entry.value),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) => selectedUnit = v,
                              validator: (v) => v == null ? 'مطلوب' : null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldLabel('الكمية الحالية *'),
                            TextFormField(
                              controller: qtyController,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.numbers_outlined),
                                isDense: true,
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return 'مطلوب';
                                final parsed = double.tryParse(v.trim());
                                if (parsed == null || parsed <= 0) return 'يجب أن تكون قيمة موجبة أكبر من صفر';
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldLabel('حد التنبيه *'),
                            TextFormField(
                              controller: thresholdController,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(
                                  Icons.notifications_active_outlined,
                                ),
                                isDense: true,
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return 'مطلوب';
                                final parsed = double.tryParse(v.trim());
                                if (parsed == null || parsed <= 0) return 'يجب أن تكون قيمة موجبة أكبر من صفر';
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildFieldLabel('تاريخ الصلاحية (Expiry Date)'),
                  TextFormField(
                    controller: expiryController,
                    decoration: const InputDecoration(
                      hintText: 'YYYY-MM-DD',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_month_outlined),
                      suffixIcon: Icon(Icons.edit_calendar),
                      isDense: true,
                    ),
                    readOnly: true,
                    onTap: () async {
                      DateTime? initialDate;
                      if (expiryController.text.isNotEmpty) {
                        try {
                          initialDate = DateTime.parse(expiryController.text);
                        } catch (e) {
                          debugPrint('Error parsing initial date in InventoryScreen: $e');
                        }
                      }
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: initialDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        expiryController.text = picked.toIso8601String().split(
                          'T',
                        )[0];
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '* الحقول المميزة مطلوبة لضمان عمل نظام التنبيهات.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              nameController.dispose();
              qtyController.dispose();
              thresholdController.dispose();
              expiryController.dispose();
              Navigator.pop(dialogContext);
            },
            child: Text(
              'إلغاء',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final user = Provider.of<AppProvider>(
                  context,
                  listen: false,
                ).currentUser;
                final Map<String, dynamic> data = {
                  'item_name': nameController.text.trim(),
                  'category': selectedType,
                  'quantity': double.parse(qtyController.text),
                  'min_threshold': double.parse(thresholdController.text),
                  'unit': selectedUnit,
                  'expiry_date': expiryController.text.isEmpty
                      ? null
                      : expiryController.text,
                };

                if (item == null) {
                  await _inventoryService.addItem(
                    data,
                    userName: user?.fullName,
                  );
                } else {
                  await _inventoryService.updateItem(
                    item['id'],
                    data,
                    userName: user?.fullName,
                  );
                }

                if (!mounted || !dialogContext.mounted) return;
                nameController.dispose();
                qtyController.dispose();
                thresholdController.dispose();
                expiryController.dispose();
                Navigator.pop(dialogContext);
                _loadData();
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('تم الحفظ بنجاح')));
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
        ),
      ),
    );
  }

  void _showDataEntryHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.help_outline, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            const Text('إرشادات إدخال بيانات المخزون'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HelpItem(
                title: 'اسم المادة:',
                description: 'الاسم الكامل والواضح (مثال: Glucose Reagent).',
              ),
              _HelpItem(
                title: 'النوع:',
                description: 'تصنيف المادة (كواشف، مستهلكات، أجهزة).',
              ),
              _HelpItem(
                title: 'الكمية:',
                description: 'الرقم المتوفر حالياً في المختبر.',
              ),
              _HelpItem(
                title: 'الوحدة:',
                description: 'وحدة القياس (كيس، علبة، لتر، إلخ).',
              ),
              _HelpItem(
                title: 'الحد الأدنى:',
                description: 'أقل كمية تسمح بها قبل ظهور تنبيه نقص المخزون.',
              ),
              _HelpItem(
                title: 'تاريخ الصلاحية:',
                description: 'تاريخ انتهاء المادة (هام جداً للتنبيهات).',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('فهمت'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف "${item['item_name']}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () async {
              final user = Provider.of<AppProvider>(
                context,
                listen: false,
              ).currentUser;
              try {
                await _inventoryService.deleteItem(
                  item['id'],
                  userName: user?.fullName,
                );
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                _loadData();
              } catch (e) {
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                if (!mounted) return;
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('تعذر الحذف'),
                    content: Text(
                      e.toString().replaceAll('Exception: ', ''),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('حسناً'),
                      ),
                    ],
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
      if (!_scrollController.hasClients) return;
      double maxScroll = _scrollController.position.maxScrollExtent;
      if (maxScroll <= 0) continue;
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
        const SizedBox(width: 800),
        Center(child: widget.child),
        const SizedBox(width: 800),
      ],
    );
  }
}

class _HelpItem extends StatelessWidget {
  final String title;
  final String description;

  const _HelpItem({required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
