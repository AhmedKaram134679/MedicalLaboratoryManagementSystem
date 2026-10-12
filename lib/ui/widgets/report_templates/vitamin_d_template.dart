import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../models/patient_model.dart';
import '../../../utils/arabic_utils.dart';

class VitaminDTemplate {
  final PatientModel patient;
  final int patientTestId; // Added for correct buffer binding
  final List<Map<String, dynamic>> results;
  final String? doctorName;
  final String? address;
  final String? testName;
  final String? comment;
  final Map<String, dynamic> labSettings;
  final bool isEditable;
  final Function(String fieldName, String value)? onResultChanged;
  final Map<String, String>? resultsBuffer;

  VitaminDTemplate({
    required this.patient,
    required this.patientTestId,
    required this.results,
    this.doctorName,
    this.address,
    this.testName,
    this.comment,
    required this.labSettings,
    this.isEditable = false,
    this.onResultChanged,
    this.resultsBuffer,
  });

  // --- UI Rendering (Flutter) ---

  Widget buildUI(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      color: Theme.of(context).cardColor,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildUIHeader(),
            const SizedBox(height: 20),
            _buildUIPatientInfo(context),
            const SizedBox(height: 15),
            _buildUITitle(context),
            const SizedBox(height: 20),
            _buildUITable(context),
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

    final logoPath = labSettings['labLogo'] as String?;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              labSettings['labName'] ?? 'Laboratory Name',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            Text(labSettings['labAddress'] ?? ''),
            Text('Tel: ${labSettings['labPhone'] ?? ''}'),
          ],
        ),
        if (logoPath != null && logoPath.isNotEmpty && File(logoPath).existsSync())
          Image.file(
            File(logoPath),
            width: 70,
            height: 70,
            fit: BoxFit.contain,
          )
        else
          const Icon(
            Icons.biotech,
            size: 60,
            color: Colors.blue,
          ),
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
              _uiInfoItem('Name:', patient.name, flex: 3),
              const SizedBox(width: 20),
              _uiInfoItem('Age:', ageText, flex: 2),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _uiInfoItem('Mobile:', patient.phone ?? '', flex: 3),
              const SizedBox(width: 20),
              _uiInfoItem('Sex:', patient.gender, flex: 2),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _uiInfoItem('Referred by:', doctorName ?? '', flex: 3),
              const SizedBox(width: 20),
              _uiInfoItem(
                'Testing Date:',
                patient.createdAt.toString().split(' ')[0],
                flex: 2,
              ),
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
          'Laboratory Report',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildUITable(BuildContext context) {
    final List<TableRow> rows = results.isEmpty
        ? [
            _buildUIRow(context, {
              'field_name': 'Vit.D3 ( 25-OH Vit.D Total )',
              'unit': 'ng / ml',
            }),
          ]
        : results.map((r) => _buildUIRow(context, r)).toList();

    return Table(
      border: TableBorder.all(color: Theme.of(context).dividerColor),
      columnWidths: const {
        0: FlexColumnWidth(2.5),
        1: FlexColumnWidth(1.5),
        2: FlexColumnWidth(1),
        3: FlexColumnWidth(2.5),
      },
      children: [
        TableRow(
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)),
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
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(8),
              child: Text(
                'Unit',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(8),
              child: Text(
                'Ref.Range',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        ...rows,
      ],
    );
  }

  TableRow _buildUIRow(BuildContext context, Map<String, dynamic> r) {
    final String fieldName = r['field_name'] ?? 'Vit.D3 ( 25-OH Vit.D Total )';
    // CRITICAL: Use patientTestId for correct buffer lookup
    final String bufferKey = '${patientTestId}_$fieldName';
    final String value = resultsBuffer != null
        ? (resultsBuffer![bufferKey] ?? '')
        : (r['result_value'] ?? '');

    final style = _getResultStyle(context, value, r['min_range'], r['max_range']);

    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            fieldName,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.underline, // Underline as per image
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(4),
          child: isEditable
              ? Container(
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: Colors.blue.withValues(alpha: 0.2),
                    ),
                  ),
                  child: TextFormField(
                    initialValue: value,
                    style: style,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Enter Value',
                    ),
                    onChanged: (v) => onResultChanged?.call(fieldName, v),
                  ),
                )
              : Text(value, style: style, textAlign: TextAlign.center),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            r['unit'] ?? 'ng / ml',
            textAlign: TextAlign.center,
          ), // Matching image: "ng / ml"
        ),
        const Padding(
          padding: EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Weak Deficiency < 10', style: TextStyle(fontSize: 10)),
              Text(
                'Moderate Deficiency (10 - 29)',
                style: TextStyle(fontSize: 10),
              ),
              Text('Preferred level > 30', style: TextStyle(fontSize: 10)),
              Text('Toxicity > 150', style: TextStyle(fontSize: 10)),
            ],
          ),
        ),
      ],
    );
  }

  TextStyle _getResultStyle(BuildContext context, String value, dynamic minStr, dynamic maxStr) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    if (value.isEmpty) return TextStyle(color: onSurface);

    final double? val = double.tryParse(value);
    if (val == null) {
      return TextStyle(
        color: onSurface,
        fontWeight: FontWeight.bold,
      ); // Bold for text mismatch
    }

    final double min = double.tryParse(minStr?.toString() ?? '30') ?? 30;
    final double max = double.tryParse(maxStr?.toString() ?? '150') ?? 150;

    if (val < min) {
      return TextStyle(
        color: Colors.orange.shade800,
        fontWeight: FontWeight.bold,
      );
    }
    if (val > max) {
      return const TextStyle(color: Colors.red, fontWeight: FontWeight.bold);
    }

    return TextStyle(color: onSurface, fontWeight: FontWeight.normal);
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
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  // --- PDF Rendering (List<pw.Widget>) ---

  List<pw.Widget> buildPdf(pw.Context context, pw.Font regular, pw.Font bold) {
    return [
      _buildPdfHeader(),
      pw.SizedBox(height: 20),
      _buildPdfPatientInfo(regular, bold),
      pw.SizedBox(height: 15),
      _buildPdfTitle(bold),
      pw.SizedBox(height: 20),
      _buildPdfTable(regular, bold),
      if (comment?.isNotEmpty == true) ...[
        pw.SizedBox(height: 15),
        _buildPdfComment(regular, bold),
      ],
      pw.SizedBox(height: 40),
      _buildPdfSignature(bold),
    ];
  }

  pw.Widget _buildPdfComment(pw.Font regular, pw.Font bold) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Comment:', style: pw.TextStyle(font: bold, fontSize: 10)),
        pw.SizedBox(height: 4),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(6),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.black, width: 0.5),
          ),
          child: pw.Text(
            ArabicUtils.fix(comment!),
            style: pw.TextStyle(font: regular, fontSize: 9),
            textDirection: pw.TextDirection.rtl,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildPdfHeader() {
    final bool usePreprinted = labSettings['use_preprinted_letterhead'] == true ||
        labSettings['use_preprinted_letterhead'] == 'true';
    if (usePreprinted) return pw.SizedBox.shrink();

    final bool includeInfo = labSettings['includeLabInfo'] ?? true;
    if (!includeInfo) return pw.SizedBox(height: 80);

    final logoPath = labSettings['labLogo'] as String?;
    pw.Widget? logoWidget;
    if (logoPath != null && logoPath.isNotEmpty && File(logoPath).existsSync()) {
      try {
        final logoImage = pw.MemoryImage(File(logoPath).readAsBytesSync());
        logoWidget = pw.Container(
          height: 60,
          width: 60,
          child: pw.Image(logoImage, fit: pw.BoxFit.contain),
        );
      } catch (e) {
        debugPrint('Error loading lab logo in VitaminDTemplate: $e');
      }
    }

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              ArabicUtils.fix(labSettings['labName'] ?? 'Laboratory Name'),
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue,
              ),
              textDirection: pw.TextDirection.rtl,
            ),
            pw.Text(
              ArabicUtils.fix(labSettings['labAddress'] ?? ''),
              textDirection: pw.TextDirection.rtl,
            ),
            pw.Text(
              ArabicUtils.fix('Tel: ${labSettings['labPhone'] ?? ''}'),
              textDirection: pw.TextDirection.rtl,
            ),
          ],
        ),
        if (logoWidget != null)
          logoWidget
        else
          pw.Container(
            width: 60,
            height: 60,
            decoration: const pw.BoxDecoration(
              color: PdfColors.blue50,
              shape: pw.BoxShape.circle,
            ),
            child: pw.Center(
              child: pw.Text(
                'BIO',
                style: pw.TextStyle(
                  color: PdfColors.blue,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  pw.Widget _buildPdfPatientInfo(pw.Font regular, pw.Font bold) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black),
      ),
      padding: const pw.EdgeInsets.all(8),
      child: pw.Column(
        children: [
          pw.Row(
            children: [
              _pdfInfoItem('Name:', patient.name, bold, regular, flex: 3),
              pw.SizedBox(width: 14),
              _pdfInfoItem(
                'Age:',
                patient.age > 0 ? '${patient.age} y' : '-',
                bold,
                regular,
                flex: 2,
              ),
              pw.SizedBox(width: 14),
              _pdfInfoItem('Sex:', patient.gender, bold, regular, flex: 2),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Row(
            children: [
              _pdfInfoItem('Address:', patient.address ?? '', bold, regular, flex: 3),
              pw.SizedBox(width: 14),
              _pdfInfoItem('Mobile:', patient.phone ?? '', bold, regular, flex: 2),
              pw.SizedBox(width: 14),
              _pdfInfoItem('ID:', '${patient.dailyId}', bold, regular, flex: 2),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Row(
            children: [
              _pdfInfoItem('Referred by:', doctorName ?? '', bold, regular, flex: 3),
              pw.SizedBox(width: 14),
              _pdfInfoItem(
                'Registered:',
                patient.createdAt.toIso8601String().split('T')[0],
                bold,
                regular,
                flex: 2,
              ),
              pw.SizedBox(width: 14),
              _pdfInfoItem('PID:', patient.fileNo ?? '', bold, regular, flex: 2),
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
    pw.Font regular, {
    int flex = 1,
  }) {
    return pw.Expanded(
      flex: flex,
      child: pw.Row(
        children: [
          pw.Text(label, style: pw.TextStyle(font: bold, fontSize: 9)),
          pw.SizedBox(width: 4),
          pw.Expanded(
            child: pw.Text(
              ArabicUtils.fix(value),
              style: pw.TextStyle(font: regular, fontSize: 9),
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
        padding: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.black, width: 2),
        ),
        child: pw.Text(
          'Laboratory Report',
          style: pw.TextStyle(fontSize: 18, font: bold),
        ),
      ),
    );
  }

  pw.Widget _buildPdfTable(pw.Font regular, pw.Font bold) {
    final List<pw.TableRow> rows = results.isEmpty
        ? [
            _buildPdfRow(
              {'field_name': 'Vit.D3 ( 25-OH Vit.D Total )', 'unit': 'ng / ml'},
              regular,
              bold,
            ),
          ]
        : results.map((r) => _buildPdfRow(r, regular, bold)).toList();

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black),
      columnWidths: const {
        0: pw.FlexColumnWidth(2.5),
        1: pw.FlexColumnWidth(1.5),
        2: pw.FlexColumnWidth(1),
        3: pw.FlexColumnWidth(2.5),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text('Test', style: pw.TextStyle(font: bold)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text('Result', style: pw.TextStyle(font: bold)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text('Unit', style: pw.TextStyle(font: bold)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text('Ref.Range', style: pw.TextStyle(font: bold)),
            ),
          ],
        ),
        ...rows,
      ],
    );
  }

  pw.TableRow _buildPdfRow(
    Map<String, dynamic> r,
    pw.Font regular,
    pw.Font bold,
  ) {
    final String fieldName = r['field_name'] ?? 'Vit.D3 ( 25-OH Vit.D Total )';
    final String bufferKey = '${patientTestId}_$fieldName';
    final String value = resultsBuffer != null
        ? (resultsBuffer![bufferKey] ?? '')
        : (r['result_value'] ?? '');

    final style = _getPdfResultStyle(
      value,
      r['min_range'],
      r['max_range'],
      regular,
      bold,
    );

    final bool isStandardVitD = fieldName.toLowerCase().contains('vit') || fieldName.toLowerCase().contains('25-oh');

    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(
            fieldName,
            style: pw.TextStyle(
              font: bold,
              fontSize: 11,
              decoration: isStandardVitD ? pw.TextDecoration.underline : pw.TextDecoration.none,
            ),
          ),
        ),
        pw.Container(
          alignment: pw.Alignment.center,
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(value, style: style),
        ),
        pw.Container(
          alignment: pw.Alignment.center,
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(
            r['unit'] ?? (isStandardVitD ? 'ng / ml' : ''),
            style: pw.TextStyle(font: regular, fontSize: 11),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: isStandardVitD
              ? pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Weak Deficiency < 10',
                      style: pw.TextStyle(font: regular, fontSize: 9),
                    ),
                    pw.Text(
                      'Moderate Deficiency (10 - 29)',
                      style: pw.TextStyle(font: regular, fontSize: 9),
                    ),
                    pw.Text(
                      'Preferred level > 30',
                      style: pw.TextStyle(font: regular, fontSize: 9),
                    ),
                    pw.Text(
                      'Toxicity > 150',
                      style: pw.TextStyle(font: regular, fontSize: 9),
                    ),
                  ],
                )
              : pw.Text(
                  r['normal_range']?.toString() ?? r['default_range']?.toString() ?? '-',
                  style: pw.TextStyle(font: regular, fontSize: 10),
                ),
        ),
      ],
    );
  }

  pw.TextStyle _getPdfResultStyle(
    String value,
    dynamic minStr,
    dynamic maxStr,
    pw.Font regular,
    pw.Font bold,
  ) {
    if (value.isEmpty) {
      return pw.TextStyle(font: regular, color: PdfColors.black);
    }

    final double? val = double.tryParse(value);
    if (val == null) return pw.TextStyle(font: bold, color: PdfColors.black);

    final double min = double.tryParse(minStr?.toString() ?? '30') ?? 30;
    final double max = double.tryParse(maxStr?.toString() ?? '150') ?? 150;

    if (val < min) {
      return pw.TextStyle(font: bold, color: PdfColors.orange800);
    }
    if (val > max) {
      return pw.TextStyle(font: bold, color: PdfColors.red);
    }

    return pw.TextStyle(font: regular, color: PdfColors.black);
  }

  pw.Widget _buildPdfSignature(pw.Font bold) {
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Padding(
        padding: const pw.EdgeInsets.only(right: 40, bottom: 20),
        child: pw.Text(
          'Signature',
          style: pw.TextStyle(
            font: bold,
            fontWeight: pw.FontWeight.bold,
            fontStyle: pw.FontStyle.italic,
          ),
        ),
      ),
    );
  }
}
