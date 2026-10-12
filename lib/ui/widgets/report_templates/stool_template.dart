import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../models/patient_model.dart';
import '../../../utils/arabic_utils.dart';

class StoolTemplate {
  final PatientModel patient;
  final int patientTestId;
  final List<Map<String, dynamic>> results;
  final String? doctorName;
  final Map<String, dynamic> labSettings;
  final bool isEditable;
  final Function(String fieldName, String value)? onResultChanged;
  final Map<String, String>? resultsBuffer;
  final String? comment;

  StoolTemplate({
    required this.patient,
    required this.patientTestId,
    required this.results,
    required this.labSettings,
    this.doctorName,
    this.isEditable = false,
    this.onResultChanged,
    this.resultsBuffer,
    this.comment,
  });

  // Fields organized into 4 distinct panels matching clinical requirements
  static const List<String> physicalFields = [
    'Color',
    'Odor',
    'Consistency',
    'Mucus',
    'Appearance Pus',
    'Blood Gross',
    'Parasite (naked eye)',
    'Undigested Food',
  ];

  static const List<String> microscopicFields = [
    'Pus cells',
    'RBCs',
  ];

  static const List<String> digestionFields = [
    'Starch granules',
    'Fat globules',
    'Vegetable cells',
    'Muscle fibers',
  ];

  static const List<String> parasiteFields = [
    'Protozoa: Vegetative',
    'Protozoa: Cysts',
    'Helminths: Larvae',
    'Helminths: Ova',
  ];

  // --- UI Rendering ---

  Widget buildUI(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      color: Theme.of(context).cardColor,
      child: SingleChildScrollView(
        child: Column(
          children: [
            _buildUIHeader(),
            const SizedBox(height: 20),
            _buildUIPatientInfo(context),
            const SizedBox(height: 15),
            _buildUITitle(context),
            const SizedBox(height: 20),
            _buildUITable(context),
            if (comment != null && comment!.trim().isNotEmpty) ...[
              const SizedBox(height: 15),
              _buildUIComment(context),
            ],
            const SizedBox(height: 40),
            _buildUISignature(),
          ],
        ),
      ),
    );
  }

  Widget _buildUIHeader() {
    final bool includeInfo = labSettings['includeLabInfo'] ?? true;
    if (!includeInfo) return const SizedBox(height: 80);

    final labName = labSettings['labName'] ?? 'Laboratory Name';
    final labAddress = labSettings['labAddress'] ?? '';
    final labPhone = labSettings['labPhone'] ?? '';
    final logoPath = labSettings['labLogo'] as String?;

    final nameWidget = Text(
      labName,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.blue,
      ),
    );
    final addressWidget = Text(labAddress);
    final phoneWidget = Text('Tel: $labPhone');

    Widget? logoWidget;
    if (logoPath != null && logoPath.isNotEmpty && File(logoPath).existsSync()) {
      logoWidget = Image.file(
        File(logoPath),
        width: 70,
        height: 70,
        fit: BoxFit.contain,
      );
    } else {
      logoWidget = const Icon(Icons.biotech, size: 60, color: Colors.blue);
    }

    final posName = labSettings['report_pos_lab_name'] as String? ?? 'top_right';
    final posAddress = labSettings['report_pos_lab_address'] as String? ?? 'top_center';
    final posPhone = labSettings['report_pos_lab_phone'] as String? ?? 'top_left';
    final posLogo = labSettings['report_pos_lab_logo'] as String? ?? 'top_left';

    final items = {
      'name': {'pos': posName, 'widget': nameWidget},
      'address': {'pos': posAddress, 'widget': addressWidget},
      'phone': {'pos': posPhone, 'widget': phoneWidget},
      'logo': {'pos': posLogo, 'widget': logoWidget},
    };

    return Column(
      children: [
        _buildUIDynamicRow(items, true),
        const SizedBox(height: 8),
        _buildUIDynamicRow(items, false),
      ],
    );
  }

  Widget _buildUIDynamicRow(Map<String, Map<String, dynamic>> items, bool isTop) {
    List<Widget> leftWidgets = [];
    List<Widget> centerWidgets = [];
    List<Widget> rightWidgets = [];

    items.forEach((key, val) {
      final pos = (val['pos'] as String?) ?? '';
      final w = val['widget'] as Widget?;
      if (w == null) return;

      if (pos.startsWith(isTop ? 'top_' : 'bottom_')) {
        if (pos.endsWith('_left')) leftWidgets.add(w);
        if (pos.endsWith('_center')) centerWidgets.add(w);
        if (pos.endsWith('_right')) rightWidgets.add(w);
      }
    });

    if (leftWidgets.isEmpty && centerWidgets.isEmpty && rightWidgets.isEmpty) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: leftWidgets),
        Column(crossAxisAlignment: CrossAxisAlignment.center, children: centerWidgets),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: rightWidgets),
      ],
    );
  }

  Widget _buildUIPatientInfo(BuildContext context) {
    final borderColor = Theme.of(context).colorScheme.outline;
    final ageText = patient.age > 0 ? '${patient.age} y' : '-';
    return Container(
      decoration: BoxDecoration(border: Border.all(color: borderColor)),
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Row(
            children: [
              _uiInfoItem('Name:', patient.name),
              const SizedBox(width: 10),
              _uiInfoItem('Sex:', patient.gender),
              const SizedBox(width: 10),
              _uiInfoItem('Age:', ageText),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              _uiInfoItem('Address:', patient.address ?? ''),
              const SizedBox(width: 10),
              _uiInfoItem('Mobile:', patient.phone ?? ''),
              const SizedBox(width: 10),
              _uiInfoItem('ID:', '${patient.dailyId}'),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              _uiInfoItem('Referred by:', doctorName ?? '', flex: 3),
              const SizedBox(width: 8),
              _uiInfoItem(
                'Registered:',
                patient.createdAt.toIso8601String().split('T')[0],
                flex: 2,
              ),
              const SizedBox(width: 8),
              _uiInfoItem('PID:', patient.fileNo ?? '', flex: 1),
            ],
          ),
        ],
      ),
    );
  }

  Widget _uiInfoItem(String label, String value, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 11),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUITitle(BuildContext context) {
    final borderColor = Theme.of(context).colorScheme.outline;
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: borderColor, width: 2),
        ),
        child: const Text(
          'Stool Analysis',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildUITable(BuildContext context) {
    final borderColor = Theme.of(context).colorScheme.outline;
    return Table(
      border: TableBorder(
        top: BorderSide(color: borderColor),
        bottom: BorderSide(color: borderColor),
        left: BorderSide(color: borderColor),
        right: BorderSide(color: borderColor),
      ),
      columnWidths: const {
        0: FlexColumnWidth(2.5),
        1: FlexColumnWidth(2),
        2: FlexColumnWidth(2),
      },
      children: [
        // Header Row: Use "Normal" as instructed
        TableRow(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: borderColor)),
          ),
          children: const [
            Padding(
              padding: EdgeInsets.all(8),
              child: Text(
                'Test',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(8),
              child: Text(
                'Result',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(8),
              child: Text(
                'Normal',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        ..._buildSectionRows(context, 'Physical examination:', physicalFields),
        ..._buildSectionRows(context, 'Microscopic examination:', microscopicFields),
        ..._buildSectionRows(context, 'State of digestion:', digestionFields),
        ..._buildSectionRows(context, 'Parasites:', parasiteFields),
      ],
    );
  }

  List<TableRow> _buildSectionRows(BuildContext context, String sectionTitle, List<String> fields) {
    List<TableRow> rows = [];
    rows.add(
      TableRow(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
            child: Text(
              sectionTitle,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
          const SizedBox(),
          const SizedBox(),
        ],
      ),
    );

    for (var f in fields) {
      final resultData = results.firstWhere(
        (r) =>
            r['field_name'].toString().toLowerCase() == f.toLowerCase(),
        orElse: () => {
          'field_name': f,
          'unit': '',
          'default_range': '',
        },
      );
      rows.add(_buildUIResultRow(context, resultData));
    }
    return rows;
  }

  TableRow _buildUIResultRow(BuildContext context, Map<String, dynamic> r) {
    final String fieldName = r['field_name'];
    final String bufferKey = '${patientTestId}_$fieldName';
    
    String value = '';
    if (resultsBuffer != null && resultsBuffer!.containsKey(bufferKey) && resultsBuffer![bufferKey]!.isNotEmpty) {
      value = resultsBuffer![bufferKey]!;
    } else {
      value = r['result_value']?.toString() ?? '';
    }

    final String refRange = getDefaultRange(fieldName);
    final style = getSmartColor(value, refRange, context);

    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(fieldName),
        ),
        Padding(
          padding: const EdgeInsets.all(4),
          child: isEditable
              ? TextFormField(
                  initialValue: value,
                  style: style,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    border: InputBorder.none,
                    hintText: '...',
                  ),
                  onChanged: (v) => onResultChanged?.call(fieldName, v),
                )
              : Center(child: Text(value, style: style)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            refRange,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildUIComment(BuildContext context) {
    final borderColor = Theme.of(context).colorScheme.outline;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(border: Border.all(color: borderColor)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Comment:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
          const SizedBox(height: 4),
          Text(comment ?? ''),
        ],
      ),
    );
  }

  Widget _buildUISignature() {
    return const Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: EdgeInsets.only(right: 40),
        child: Text(
          'Signature',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }

  // --- PDF Rendering ---

  List<pw.Widget> buildPdf(pw.Context context, pw.Font regular, pw.Font bold) {
    return [
      _buildPdfHeader(),
      pw.SizedBox(height: 8),
      _buildPdfPatientInfo(regular, bold),
      pw.SizedBox(height: 6),
      _buildPdfTitle(bold),
      pw.SizedBox(height: 8),
      _buildPdfTable(regular, bold),
      if (comment != null && comment!.trim().isNotEmpty) ...[
        pw.SizedBox(height: 6),
        _buildPdfComment(regular, bold),
      ],
      pw.SizedBox(height: 16),
      _buildPdfSignature(bold),
    ];
  }

  pw.Widget _buildPdfHeader() {
    final bool usePreprinted = labSettings['use_preprinted_letterhead'] == true ||
        labSettings['use_preprinted_letterhead'] == 'true';
    if (usePreprinted) return pw.SizedBox.shrink();

    final bool includeInfo = labSettings['includeLabInfo'] ?? true;
    if (!includeInfo) return pw.SizedBox(height: 50);

    final labName = labSettings['labName'] ?? 'Laboratory Name';
    final labAddress = labSettings['labAddress'] ?? '';
    final labPhone = labSettings['labPhone'] ?? '';
    final logoPath = labSettings['labLogo'] as String?;

    final nameWidget = pw.Text(
      ArabicUtils.fix(labName),
      style: pw.TextStyle(
        fontSize: 16,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.blue,
      ),
      textDirection: pw.TextDirection.rtl,
    );
    final addressWidget = pw.Text(
      ArabicUtils.fix(labAddress),
      style: const pw.TextStyle(fontSize: 8.5),
      textDirection: pw.TextDirection.rtl,
    );
    final phoneWidget = pw.Text(
      ArabicUtils.fix('Tel: $labPhone'),
      style: const pw.TextStyle(fontSize: 8.5),
      textDirection: pw.TextDirection.rtl,
    );

    pw.Widget? logoWidget;
    if (logoPath != null && logoPath.isNotEmpty && File(logoPath).existsSync()) {
      try {
        final logoImage = pw.MemoryImage(File(logoPath).readAsBytesSync());
        logoWidget = pw.Container(
          height: 48,
          width: 48,
          child: pw.Image(logoImage, fit: pw.BoxFit.contain),
        );
      } catch (_) {
        logoWidget = null;
      }
    }

    final posName = labSettings['report_pos_lab_name'] as String? ?? 'top_right';
    final posAddress = labSettings['report_pos_lab_address'] as String? ?? 'top_center';
    final posPhone = labSettings['report_pos_lab_phone'] as String? ?? 'top_left';
    final posLogo = labSettings['report_pos_lab_logo'] as String? ?? 'top_left';

    final items = {
      'name': {'pos': posName, 'widget': nameWidget},
      'address': {'pos': posAddress, 'widget': addressWidget},
      'phone': {'pos': posPhone, 'widget': phoneWidget},
      'logo': {'pos': posLogo, 'widget': logoWidget},
    };

    return pw.Column(
      children: [
        _buildPdfDynamicRow(items, true),
        pw.SizedBox(height: 4),
        _buildPdfDynamicRow(items, false),
      ],
    );
  }

  pw.Widget _buildPdfDynamicRow(Map<String, Map<String, dynamic>> items, bool isTop) {
    List<pw.Widget> leftWidgets = [];
    List<pw.Widget> centerWidgets = [];
    List<pw.Widget> rightWidgets = [];

    items.forEach((key, val) {
      final pos = (val['pos'] as String?) ?? '';
      final w = val['widget'] as pw.Widget?;
      if (w == null) return;

      if (pos.startsWith(isTop ? 'top_' : 'bottom_')) {
        if (pos.endsWith('_left')) leftWidgets.add(w);
        if (pos.endsWith('_center')) centerWidgets.add(w);
        if (pos.endsWith('_right')) rightWidgets.add(w);
      }
    });

    if (leftWidgets.isEmpty && centerWidgets.isEmpty && rightWidgets.isEmpty) {
      return pw.SizedBox.shrink();
    }

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: leftWidgets),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: centerWidgets),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: rightWidgets),
      ],
    );
  }

  pw.Widget _buildPdfPatientInfo(pw.Font regular, pw.Font bold) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 0.8),
      ),
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: pw.Column(
        children: [
          pw.Row(
            children: [
              _pdfInfoItem('Name:', patient.name, bold, regular),
              pw.SizedBox(width: 8),
              _pdfInfoItem('Sex:', patient.gender, bold, regular),
              pw.SizedBox(width: 8),
              _pdfInfoItem(
                'Age:',
                patient.age > 0 ? '${patient.age} y' : '-',
                bold,
                regular,
              ),
            ],
          ),
          pw.SizedBox(height: 3),
          pw.Row(
            children: [
              _pdfInfoItem('Address:', patient.address ?? '', bold, regular),
              pw.SizedBox(width: 8),
              _pdfInfoItem('Mobile:', patient.phone ?? '', bold, regular),
              pw.SizedBox(width: 8),
              _pdfInfoItem('ID:', '${patient.dailyId}', bold, regular),
            ],
          ),
          pw.SizedBox(height: 3),
          pw.Row(
            children: [
              _pdfInfoItem('Referred by:', doctorName ?? '', bold, regular),
              pw.SizedBox(width: 8),
              _pdfInfoItem(
                'Registered:',
                patient.createdAt.toIso8601String().split('T')[0],
                bold,
                regular,
              ),
              pw.SizedBox(width: 8),
              _pdfInfoItem('PID:', patient.fileNo ?? '', bold, regular),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfInfoItem(
    String label,
    String value,
    pw.Font bold,
    pw.Font regular,
  ) {
    return pw.Expanded(
      child: pw.Row(
        children: [
          pw.Text(label, style: pw.TextStyle(font: bold, fontSize: 8.5)),
          pw.SizedBox(width: 3),
          pw.Expanded(
            child: pw.Text(
              ArabicUtils.fix(value),
              style: pw.TextStyle(font: regular, fontSize: 8.5),
              textDirection: pw.TextDirection.rtl,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfTitle(pw.Font bold) {
    return pw.Center(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 4),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.black, width: 1.5),
        ),
        child: pw.Text(
          'Stool Analysis',
          style: pw.TextStyle(fontSize: 14, font: bold),
        ),
      ),
    );
  }

  pw.Widget _buildPdfTable(pw.Font regular, pw.Font bold) {
    return pw.Table(
      border: const pw.TableBorder(
        top: pw.BorderSide(color: PdfColors.black, width: 0.8),
        bottom: pw.BorderSide(color: PdfColors.black, width: 0.8),
        left: pw.BorderSide(color: PdfColors.black, width: 0.8),
        right: pw.BorderSide(color: PdfColors.black, width: 0.8),
        horizontalInside: pw.BorderSide.none,
        verticalInside: pw.BorderSide.none,
      ),
      columnWidths: const {
        0: pw.FlexColumnWidth(2.5),
        1: pw.FlexColumnWidth(2),
        2: pw.FlexColumnWidth(2),
      },
      children: [
        // Header Row: Use "Normal"
        pw.TableRow(
          decoration: const pw.BoxDecoration(
            border: pw.TableBorder(
              bottom: pw.BorderSide(color: PdfColors.black, width: 0.8),
            ),
          ),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              child: pw.Text('Test', style: pw.TextStyle(font: bold, fontSize: 9)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              child: pw.Center(
                child: pw.Text('Result', style: pw.TextStyle(font: bold, fontSize: 9)),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              child: pw.Center(
                child: pw.Text(
                  'Normal',
                  style: pw.TextStyle(font: bold, fontSize: 9),
                ),
              ),
            ),
          ],
        ),
        ..._buildPdfSectionRows('Physical examination:', physicalFields, regular, bold),
        ..._buildPdfSectionRows('Microscopic examination:', microscopicFields, regular, bold),
        ..._buildPdfSectionRows('State of digestion:', digestionFields, regular, bold),
        ..._buildPdfSectionRows('Parasites:', parasiteFields, regular, bold),
        ..._buildPdfCustomFieldsRows(regular, bold),
      ],
    );
  }

  List<pw.TableRow> _buildPdfCustomFieldsRows(pw.Font regular, pw.Font bold) {
    final standardFields = {
      ...physicalFields.map((f) => f.toLowerCase()),
      ...microscopicFields.map((f) => f.toLowerCase()),
      ...digestionFields.map((f) => f.toLowerCase()),
      ...parasiteFields.map((f) => f.toLowerCase()),
    };

    final customResults = results.where((r) {
      final name = r['field_name']?.toString().toLowerCase() ?? '';
      return name.isNotEmpty && !standardFields.contains(name);
    }).toList();

    if (customResults.isEmpty) return [];

    List<pw.TableRow> rows = [];
    rows.add(
      pw.TableRow(
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(6, 4, 6, 1),
            child: pw.Text(
              'Additional / Custom tests:',
              style: pw.TextStyle(
                font: bold,
                fontSize: 8.5,
                decoration: pw.TextDecoration.underline,
              ),
            ),
          ),
          pw.SizedBox(),
          pw.SizedBox(),
        ],
      ),
    );

    for (var r in customResults) {
      final String fieldName = r['field_name'] ?? '';
      final String bufferKey = '${patientTestId}_$fieldName';
      final String val = (resultsBuffer != null && resultsBuffer!.containsKey(bufferKey))
          ? resultsBuffer![bufferKey]!
          : (r['result_value']?.toString() ?? '');
      final String refRange = r['normal_range']?.toString() ?? r['default_range']?.toString() ?? '-';
      final style = _getPdfSmartStyle(val, refRange, regular, bold);

      rows.add(
        pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              child: pw.Text(fieldName, style: pw.TextStyle(font: regular, fontSize: 8)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
              child: pw.Center(child: pw.Text(val, style: style)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              child: pw.Center(
                child: pw.Text(refRange, style: pw.TextStyle(font: regular, fontSize: 8)),
              ),
            ),
          ],
        ),
      );
    }
    return rows;
  }

  List<pw.TableRow> _buildPdfSectionRows(
    String sectionTitle,
    List<String> fields,
    pw.Font regular,
    pw.Font bold,
  ) {
    List<pw.TableRow> rows = [];
    rows.add(
      pw.TableRow(
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(6, 4, 6, 1),
            child: pw.Text(
              sectionTitle,
              style: pw.TextStyle(
                font: bold,
                fontSize: 8.5,
                decoration: pw.TextDecoration.underline,
              ),
            ),
          ),
          pw.SizedBox(),
          pw.SizedBox(),
        ],
      ),
    );

    for (var f in fields) {
      final String bufferKey = '${patientTestId}_$f';
      
      String value = '';
      if (resultsBuffer != null && resultsBuffer!.containsKey(bufferKey) && resultsBuffer![bufferKey]!.isNotEmpty) {
        value = resultsBuffer![bufferKey]!;
      } else {
        final match = results.firstWhere(
          (r) => r['field_name'].toString().toLowerCase() == f.toLowerCase(),
          orElse: () => <String, dynamic>{},
        );
        value = match['result_value']?.toString() ?? '';
      }

      final String refRange = getDefaultRange(f);
      final style = _getPdfSmartStyle(value, refRange, regular, bold);

      rows.add(
        pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 1.5,
              ),
              child: pw.Text(f, style: pw.TextStyle(font: regular, fontSize: 8)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
              child: pw.Center(child: pw.Text(value, style: style)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 1.5,
              ),
              child: pw.Center(
                child: pw.Text(refRange, style: pw.TextStyle(font: regular, fontSize: 8)),
              ),
            ),
          ],
        ),
      );
    }
    return rows;
  }

  pw.Widget _buildPdfComment(pw.Font regular, pw.Font bold) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Comment:', style: pw.TextStyle(font: bold, fontSize: 8.5)),
        pw.SizedBox(height: 2),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(4),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.black, width: 0.5),
          ),
          child: pw.Text(
            ArabicUtils.fix(comment!),
            style: pw.TextStyle(font: regular, fontSize: 8),
            textDirection: pw.TextDirection.rtl,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildPdfSignature(pw.Font bold) {
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Padding(
        padding: const pw.EdgeInsets.only(right: 30),
        child: pw.Text(
          'Signature',
          style: pw.TextStyle(font: bold, fontSize: 9, fontStyle: pw.FontStyle.italic),
        ),
      ),
    );
  }

  // --- Logic ---

  static String getDefaultRange(String field) {
    const defaults = {
      'color': 'Brown',
      'consistency': 'Semi - Formed',
      'blood gross': 'Absent',
      'mucus': 'Absent',
      'appearance pus': 'Absent',
      'parasite (naked eye)': 'Absent',
      'odor': 'Offensive',
      'undigested food': 'Absent',
      'pus cells': '0 - 5 / HPF',
      'rbcs': '0 - 5 / HPF',
      'r.b.cs': '0 - 5 / HPF',
      'fat globules': '+',
      'starch granules': '+',
      'muscle fibers': '+',
      'muscle fibres': '+',
      'vegetable cells': '+',
      'protozoa: vegetative': 'Absent',
      'protozoa: cysts': 'Absent',
      'helminths: larvae': 'Absent',
      'helminths: ova': 'Absent',
    };
    return defaults[field.toLowerCase()] ?? '';
  }

  static TextStyle getSmartColor(String value, String ref, [BuildContext? context]) {
    final defaultColor = context != null ? Theme.of(context).colorScheme.onSurface : Colors.black;
    if (value.isEmpty) return TextStyle(color: defaultColor);

    final val = value.trim().toLowerCase();
    final reference = ref.trim().toLowerCase();

    // 1. Numeric Range Logic (e.g. 0 - 5 / HPF)
    if (reference.contains('-') && RegExp(r'\d').hasMatch(reference)) {
      try {
        final rawParts = reference
            .split('-')
            .map((e) => double.tryParse(e.replaceAll(RegExp(r'[^0-9.]'), '').trim()) ?? 0.0)
            .toList();

        if (rawParts.length >= 2) {
          final double min = rawParts[0] < rawParts[1] ? rawParts[0] : rawParts[1];
          final double max = rawParts[0] > rawParts[1] ? rawParts[0] : rawParts[1];

          // Case A: User entered a range (e.g. "3 - 5" or "1 - 2")
          if (val.contains('-')) {
            final valParts = val
                .split('-')
                .map((e) => double.tryParse(e.replaceAll(RegExp(r'[^0-9.]'), '').trim()) ?? 0.0)
                .toList();

            if (valParts.length >= 2) {
              final double userMin = valParts[0] < valParts[1] ? valParts[0] : valParts[1];
              final double userMax = valParts[0] > valParts[1] ? valParts[0] : valParts[1];

              // Normal if user range is entirely within [min, max]
              if (userMin >= min && userMax <= max) {
                return TextStyle(color: defaultColor, fontWeight: FontWeight.normal);
              }
              // If userMax exceeds normal max -> Red
              if (userMax > max) {
                return const TextStyle(color: Colors.red, fontWeight: FontWeight.bold);
              }
              // If userMin is lower than normal min -> Yellow
              if (userMin < min) {
                return TextStyle(color: Colors.yellow.shade700, fontWeight: FontWeight.bold);
              }
            }
          } else {
            // Case B: User entered a single number (e.g. "2")
            final double? numVal = double.tryParse(val.replaceAll(RegExp(r'[^0-9.]'), '').trim());
            if (numVal != null) {
              if (numVal >= min && numVal <= max) {
                return TextStyle(color: defaultColor, fontWeight: FontWeight.normal);
              }
              if (numVal < min) {
                return TextStyle(color: Colors.yellow.shade700, fontWeight: FontWeight.bold);
              }
              if (numVal > max) {
                return const TextStyle(color: Colors.red, fontWeight: FontWeight.bold);
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Error parsing numeric range in StoolTemplate: $e');
      }
    }

    // 2. Special Keywords for High / Abnormal Values (use word boundaries and numerical check)
    final highAbnormalRegex = RegExp(r'\b(many|plenty|numerous|over\s+\d+)|>\s*\d+', caseSensitive: false);
    if (highAbnormalRegex.hasMatch(val) ||
        (RegExp(r'\bfound\b', caseSensitive: false).hasMatch(val) &&
            !RegExp(r'\bnot\s+found\b', caseSensitive: false).hasMatch(val))) {
      return const TextStyle(color: Colors.red, fontWeight: FontWeight.bold);
    }

    // 3. Qualitative / Textual comparison
    if (reference == 'nil' ||
        reference == 'not found' ||
        reference == 'absent' ||
        reference == 'offensive' ||
        reference == 'brown' ||
        reference == 'formed' ||
        reference == 'semi - formed' ||
        reference == 'faecal' ||
        reference == 'few' ||
        reference == '+') {
      if (val != reference &&
          val != 'normal' &&
          val != 'negative' &&
          val != 'absent' &&
          val != '-') {
        // Section 6.5: Non-matching Textual results -> Keep default text color + Bold
        return TextStyle(color: defaultColor, fontWeight: FontWeight.bold);
      }
    }

    return TextStyle(color: defaultColor, fontWeight: FontWeight.normal);
  }

  pw.TextStyle _getPdfSmartStyle(
    String value,
    String ref,
    pw.Font regular,
    pw.Font bold,
  ) {
    final style = getSmartColor(value, ref);
    if (style.color == Colors.red) {
      return pw.TextStyle(color: PdfColors.red, font: bold);
    }
    if (style.color == Colors.yellow.shade700 || style.color == Colors.yellow) {
      return pw.TextStyle(color: PdfColors.amber800, font: bold);
    }
    if (style.fontWeight == FontWeight.bold) {
      return pw.TextStyle(color: PdfColors.black, font: bold);
    }
    return pw.TextStyle(color: PdfColors.black, font: regular);
  }
}
