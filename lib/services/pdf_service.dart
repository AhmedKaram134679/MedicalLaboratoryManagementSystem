import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';
import '../models/patient_model.dart';
import '../services/settings_service.dart';
import '../utils/arabic_utils.dart';

class PdfService {
  const PdfService();

  static pw.Font? _regularFont;
  static pw.Font? _boldFont;

  Future<pw.Font> _getRegularFont() async {
    if (_regularFont != null) return _regularFont!;
    final data = await rootBundle.load("assets/fonts/Cairo-Regular.ttf");
    _regularFont = pw.Font.ttf(data);
    return _regularFont!;
  }

  Future<pw.Font> _getBoldFont() async {
    if (_boldFont != null) return _boldFont!;
    final data = await rootBundle.load("assets/fonts/Cairo-Bold.ttf");
    _boldFont = pw.Font.ttf(data);
    return _boldFont!;
  }

  Future<File> generateTestReport({
    required PatientModel patient,
    required String testName,
    required List<Map<String, dynamic>> results,
    String? comment,
    int? patientTestId,
    String? status,
    String? updatedAt,
    String? doctorName,
    String? address,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final cacheDir = Directory(p.join(tempDir.path, 'pdf_cache'));
    if (!cacheDir.existsSync()) {
      cacheDir.createSync(recursive: true);
    }

    final settings = SettingsService();
    final headerPath = await settings.getReportHeaderPath();
    final footerPath = await settings.getReportFooterPath();
    final labName = await settings.getLabName() ?? 'مختبر التحاليل الطبية';
    final labAddress = await settings.getLabAddress() ?? '';
    final labPhone = await settings.getLabPhone() ?? '';
    final labLogoPath = await settings.getLabLogoPath();

    final settingsFingerprint = '${labName.hashCode}_${labAddress.hashCode}_${labPhone.hashCode}_${labLogoPath.hashCode}_${headerPath.hashCode}_${footerPath.hashCode}';

    // Generate a secure cache key
    // Invalidate if: Results change, status changes, test name changes, or lab settings change
    final String cacheKey =
        'report_${patientTestId ?? 'unknown'}_${status ?? 'Draft'}_${(updatedAt ?? 'unknown').replaceAll(':', '-')}_${testName}_$settingsFingerprint.pdf';
    final file = File(p.join(cacheDir.path, cacheKey));

    if (file.existsSync()) {
      debugPrint('PDF Cache Hit: ${file.path}');
      return file;
    }

    debugPrint('PDF Cache Miss: Generating $cacheKey');
    await _cleanupCache(cacheDir);

    final pdf = pw.Document();
    final cairoRegular = await _getRegularFont();
    final cairoBold = await _getBoldFont();

    // Load Settings
    final includeLabInfo = await settings.getReportIncludeInfo();

    // Map positions
    final posName = await settings.getReportPosLabName();
    final posAddress = await settings.getReportPosLabAddress();
    final posPhone = await settings.getReportPosLabPhone();
    final posLogo = await settings.getReportPosLabLogo();

    pw.Widget? headerWidget;
    pw.Widget? footerWidget;

    // Helper to create widgets
    final nameWidget = pw.Text(
      _fix(labName),
      style: pw.TextStyle(
        fontSize: 22,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.blue900,
      ),
      textDirection: pw.TextDirection.rtl,
    );
    final addressWidget = pw.Text(
      _fix(labAddress),
      style: const pw.TextStyle(fontSize: 10),
      textDirection: pw.TextDirection.rtl,
    );
    final phoneWidget = pw.Text(
      _fix('الهاتف: $labPhone'),
      style: const pw.TextStyle(fontSize: 10),
      textDirection: pw.TextDirection.rtl,
    );

    pw.Widget? logoWidget;
    if (labLogoPath != null && File(labLogoPath).existsSync()) {
      final logoImage = pw.MemoryImage(File(labLogoPath).readAsBytesSync());
      logoWidget = pw.Container(
        height: 80,
        width: 80,
        child: pw.Image(logoImage, fit: pw.BoxFit.contain),
      );
    }

    if (!includeLabInfo) {
      // Empty header/footer for pre-printed paper
      headerWidget = pw.SizedBox(height: 100); // Maintain formatting space
      footerWidget = pw.SizedBox(height: 50);
    } else if (headerPath != null &&
        headerPath.isNotEmpty &&
        File(headerPath).existsSync()) {
      // Legacy Header Image support
      final headerImage = pw.MemoryImage(File(headerPath).readAsBytesSync());
      headerWidget = pw.Container(
        height: 100,
        width: double.infinity,
        child: pw.Image(headerImage, fit: pw.BoxFit.fill),
      );
    } else {
      // Dynamic Header Construction
      headerWidget = _buildDynamicSection(
        {
          'name': {'pos': posName, 'widget': nameWidget},
          'address': {'pos': posAddress, 'widget': addressWidget},
          'phone': {'pos': posPhone, 'widget': phoneWidget},
          'logo': {'pos': posLogo, 'widget': logoWidget},
        },
        true, // isTop
      );
    }

    // Dynamic Footer (if not image)
    if (includeLabInfo && (footerPath == null || footerPath.isEmpty)) {
      footerWidget = _buildDynamicSection(
        {
          'name': {'pos': posName, 'widget': nameWidget},
          'address': {'pos': posAddress, 'widget': addressWidget},
          'phone': {'pos': posPhone, 'widget': phoneWidget},
          'logo': {'pos': posLogo, 'widget': logoWidget},
        },
        false, // isTop (isBottom)
      );
    } else if (footerPath != null && File(footerPath).existsSync()) {
      final fImg = pw.MemoryImage(File(footerPath).readAsBytesSync());
      footerWidget = pw.Container(
        height: 50,
        width: double.infinity,
        child: pw.Image(fImg, fit: pw.BoxFit.fill),
      );
    } else {
      footerWidget = pw.SizedBox(height: 20);
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: cairoRegular, bold: cairoBold),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              headerWidget!,
              pw.Divider(thickness: 2, color: PdfColors.blueGrey),

              pw.SizedBox(height: 20),

              // Patient Info Bar (Horizontal)
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: const pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Column(
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Expanded(
                          child: pw.Text(
                            _fix('اسم المريض : ${patient.name}'),
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            textDirection: pw.TextDirection.rtl,
                          ),
                        ),
                        pw.Expanded(
                          child: pw.Text(
                            'Patient ID: ${patient.dailyId}',
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Expanded(
                          child: pw.Text(
                            _fix(
                              'تاريخ الزيارة: ${patient.createdAt.toString().split('T')[0]}',
                            ),
                            textAlign: pw.TextAlign.left,
                            textDirection: pw.TextDirection.rtl,
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Expanded(
                          child: pw.Text(
                            _fix(patient.age > 0 ? 'السن: ${patient.age}' : 'السن: -'),
                            textDirection: pw.TextDirection.rtl,
                          ),
                        ),
                        pw.Expanded(
                          child: pw.Text(
                            _fix(
                              'الجنس: ${(patient.gender.toLowerCase() == 'male' || patient.gender == 'ذكر') ? 'ذكر' : 'أنثى'}',
                            ),
                            textAlign: pw.TextAlign.center,
                            textDirection: pw.TextDirection.rtl,
                          ),
                        ),
                        pw.Expanded(
                          child: pw.Text(
                            _fix('رقم الهاتف: ${patient.phone ?? '-'}'),
                            textAlign: pw.TextAlign.left,
                            textDirection: pw.TextDirection.rtl,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 30),

              // Test Title
              pw.Center(
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 5,
                  ),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      bottom: pw.BorderSide(color: PdfColors.blue, width: 2),
                    ),
                  ),
                  child: pw.Text(
                    _fix('نتيجة تحليل: $testName'),
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    textDirection: pw.TextDirection.rtl,
                  ),
                ),
              ),
              pw.SizedBox(height: 25),

              // Results Table
              pw.Table(
                border: pw.TableBorder.symmetric(
                  inside: const pw.BorderSide(color: PdfColors.grey300),
                  outside: const pw.BorderSide(color: PdfColors.grey400),
                ),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.blue50),
                    children: [
                      _tableHeader('اسم الفحص / Test'),
                      _tableHeader('النتيجة / Result'),
                      _tableHeader('الوحدة / Unit'),
                      _tableHeader('المعدل الطبيعي / Normal'),
                    ],
                  ),
                  ...results.map(
                    (r) => pw.TableRow(
                      children: [
                        _tableCell(r['field_name']),
                        _tableCell(
                          r['result_value'] ?? '',
                          isAbnormal: r['is_abnormal'] == 1,
                        ),
                        _tableCell(r['unit'] ?? ''),
                        _tableCell(r['normal_range'] ?? '-'),
                      ],
                    ),
                  ),
                ],
              ),

              if (comment != null && comment.isNotEmpty) ...[
                pw.SizedBox(height: 20),
                pw.Text(
                  _fix('ملاحظات / Comment:'),
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 12,
                  ),
                  textDirection: pw.TextDirection.rtl,
                ),
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey200),
                  ),
                  child: pw.Text(
                    _fix(comment),
                    style: const pw.TextStyle(fontSize: 11),
                    textDirection: pw.TextDirection.rtl,
                  ),
                ),
              ],

              pw.Spacer(),
              pw.Divider(color: PdfColors.grey200),
              footerWidget!,
            ],
          );
        },
      ),
    );

    final pdfBytes = await _safeSavePdf(pdf);
    await file.writeAsBytes(pdfBytes);
    return file;
  }

  Future<File> generateTemplateReport({
    required dynamic template,
    int? patientTestId,
    String? status,
    String? updatedAt,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final cacheDir = Directory(p.join(tempDir.path, 'pdf_cache'));
    if (!cacheDir.existsSync()) {
      cacheDir.createSync(recursive: true);
    }

    final settings = SettingsService();
    final headerPath = await settings.getReportHeaderPath();
    final footerPath = await settings.getReportFooterPath();
    final labName = await settings.getLabName() ?? 'مختبر التحاليل الطبية';
    final labAddress = await settings.getLabAddress() ?? '';
    final labPhone = await settings.getLabPhone() ?? '';
    final labLogoPath = await settings.getLabLogoPath();

    final bool usePreprintedLetterhead = await settings.getUsePreprintedLetterhead();
    final double topMargin = usePreprintedLetterhead ? 141.7 : 36.0;

    final settingsFingerprint = '${labName.hashCode}_${labAddress.hashCode}_${labPhone.hashCode}_${labLogoPath.hashCode}_${headerPath.hashCode}_${footerPath.hashCode}_$usePreprintedLetterhead';

    final String cacheKey =
        'template_report_${patientTestId ?? 'unknown'}_${status ?? 'Draft'}_${(updatedAt ?? 'unknown').replaceAll(':', '-')}_$settingsFingerprint.pdf';
    final file = File(p.join(cacheDir.path, cacheKey));

    if (file.existsSync()) {
      return file;
    }

    await _cleanupCache(cacheDir);

    final pdf = pw.Document();
    final cairoRegular = await _getRegularFont();
    final cairoBold = await _getBoldFont();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.fromLTRB(30, topMargin, 30, 30),
        theme: pw.ThemeData.withFont(base: cairoRegular, bold: cairoBold),
        build: (context) {
          final content = template.buildPdf(context, cairoRegular, cairoBold);
          if (content is List<pw.Widget>) {
            return content;
          }
          return [content as pw.Widget];
        },
      ),
    );

    final pdfBytes = await _safeSavePdf(pdf);
    await file.writeAsBytes(pdfBytes);
    return file;
  }

  Future<void> _cleanupCache(Directory cacheDir) async {
    try {
      if (!cacheDir.existsSync()) return;

      final List<FileSystemEntity> entities = cacheDir.listSync();
      final now = DateTime.now();

      // 1. Delete files older than 24 hours
      for (var file in entities) {
        if (file is File && file.existsSync()) {
          try {
            final stat = file.statSync();
            if (now.difference(stat.modified).inHours > 24) {
              file.deleteSync();
              debugPrint('Deleted old PDF cache: ${file.path}');
            }
          } catch (e) {
            debugPrint('Error cleaning single cache file: $e');
          }
        }
      }

      // 2. Limit total cache size to 100MB
      final remainingFiles = cacheDir.listSync().whereType<File>().where((f) => f.existsSync()).toList();
      remainingFiles.sort((a, b) {
        try {
          return b.statSync().modified.compareTo(a.statSync().modified);
        } catch (e) {
          debugPrint('Error comparing cache file timestamps: $e');
          return 0;
        }
      }); // Newest first

      int totalSize = 0;
      for (var file in remainingFiles) {
        if (file.existsSync()) {
          try {
            totalSize += file.lengthSync();
            if (totalSize > 100 * 1024 * 1024) {
              // 100 MB
              file.deleteSync();
              debugPrint('Deleted PDF cache due to size limit: ${file.path}');
            }
          } catch (e) {
            debugPrint('Error handling size-limited cache file: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Error cleaning PDF cache: $e');
    }
  }

  Future<File> generateReceipt({
    required PatientModel patient,
    required List<Map<String, dynamic>> selectedTests,
    required double total,
    required double discount,
    required double paid,
    required double remaining,
    String? referredDoctor,
    String? updatedAt,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final cacheDir = Directory(p.join(tempDir.path, 'pdf_cache'));
    if (!cacheDir.existsSync()) {
      cacheDir.createSync(recursive: true);
    }

    final String cacheKey =
        'receipt_${patient.id ?? 'new'}_${(updatedAt ?? 'now').replaceAll(':', '-')}.pdf';
    final file = File(p.join(cacheDir.path, cacheKey));

    if (file.existsSync()) {
      debugPrint('Receipt Cache Hit: ${file.path}');
      return file;
    }

    debugPrint('Receipt Cache Miss: Generating $cacheKey');
    await _cleanupCache(cacheDir);

    final pdf = pw.Document();
    final cairoRegular = await _getRegularFont();
    final cairoBold = await _getBoldFont();

    // Load Settings
    final settings = SettingsService();
    final labName =
        await settings.getLabName() ?? 'معمل الدرة للتحاليل الطبية والكيميائية';
    final labPhone = await settings.getLabPhone() ?? '';
    final labAddress = await settings.getLabAddress() ?? '';
    final logoPath = await settings.getLabLogoPath();

    pw.ImageProvider? logoImage;
    if (logoPath != null &&
        logoPath.isNotEmpty &&
        File(logoPath).existsSync()) {
      logoImage = pw.MemoryImage(File(logoPath).readAsBytesSync());
    }

    final String visitDate = DateFormat('dd/MM/yyyy').format(patient.createdAt);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        theme: pw.ThemeData.withFont(base: cairoRegular, bold: cairoBold),
        build: (context) {
          return [
            // Header
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text(
                    _fix(labName),
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    textDirection: pw.TextDirection.rtl,
                  ),
                  if (labAddress.isNotEmpty)
                    pw.Text(
                      _fix(labAddress),
                      style: const pw.TextStyle(fontSize: 10),
                      textDirection: pw.TextDirection.rtl,
                    ),
                  if (labPhone.isNotEmpty)
                    pw.Text(
                      _fix('هاتف: $labPhone'),
                      style: const pw.TextStyle(fontSize: 10),
                      textDirection: pw.TextDirection.rtl,
                    ),
                  if (logoImage != null)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 8),
                      child: pw.Container(
                        height: 60,
                        child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                      ),
                    ),
                ],
              ),
            ),
            pw.SizedBox(height: 30),

            // Patient Information Box (2x2 Structure)
            pw.Table(
              border: pw.TableBorder.all(),
              columnWidths: {
                0: const pw.FlexColumnWidth(1),
                1: const pw.FlexColumnWidth(1.2),
              },
              children: [
                // Row 1
                pw.TableRow(
                  children: [
                    _blueprintInfoCellWithLabel('Patient Name: ', patient.name),
                    _blueprintInfoCellWithLabel('Transaction Date: ', visitDate),
                  ],
                ),
                // Row 2
                pw.TableRow(
                  children: [
                    pw.Row(
                      children: [
                        _blueprintVerticalCell(
                          'Patient ID:',
                          patient.dailyId.toString(),
                          width: 60,
                        ),
                        pw.VerticalDivider(width: 1),
                        _blueprintVerticalCell(
                          'Mobile:',
                          patient.phone ?? '',
                          width: 80,
                        ),
                        pw.VerticalDivider(width: 1),
                        pw.Expanded(
                          child: pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(
                              patient.age > 0
                                  ? 'Age / Gender : ${patient.age} y / ${patient.gender}'
                                  : 'Age / Gender : - / ${patient.gender}',
                              style: pw.TextStyle(
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    _blueprintInfoCellWithLabel(
                      'Referred By: ',
                      referredDoctor ?? '',
                    ),
                  ],
                ),
                if (patient.address != null && patient.address!.isNotEmpty)
                  pw.TableRow(
                    children: [
                      _blueprintInfoCellWithLabel('Address: ', patient.address!),
                      _blueprintInfoCellWithLabel('File No: ', patient.fileNo ?? '-'),
                    ],
                  ),
              ],
            ),
            pw.SizedBox(height: 25),

            // Tests Table (Simplified to: #, Test Name, Price)
            pw.Table(
              border: pw.TableBorder.all(),
              columnWidths: {
                0: const pw.FlexColumnWidth(0.5),
                1: const pw.FlexColumnWidth(3.0),
                2: const pw.FlexColumnWidth(1.2),
              },
              children: [
                // Headers
                pw.TableRow(
                  children: [
                    _blueprintTableHeader('#'),
                    _blueprintTableHeader('Test Name'),
                    _blueprintTableHeader('Price'),
                  ],
                ),
                // Data Rows
                ...List.generate(selectedTests.length, (index) {
                  final test = selectedTests[index];
                  final priceVal = (test['price'] is num)
                      ? (test['price'] as num).toStringAsFixed(2)
                      : (test['price']?.toString() ?? '0.00');
                  return pw.TableRow(
                    children: [
                      _blueprintTableCell('${index + 1}'),
                      _blueprintTableCell(test['name'] ?? ''),
                      _blueprintTableCell(priceVal),
                    ],
                  );
                }),
              ],
            ),

            pw.SizedBox(height: 40),

            // Financial Summary (Required by text instructions)
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Container(
                  width: 200,
                  child: pw.Column(
                    children: [
                      _financialSummaryRow('Total Amount', total),
                      _financialSummaryRow('Discount', discount),
                      _financialSummaryRow('Paid Amount', paid),
                      if (paid > (total - discount))
                        _financialSummaryRow(
                          'Overpayment / Change',
                          paid - (total - discount),
                          isBold: true,
                        ),
                      pw.Divider(),
                      _financialSummaryRow(
                        'Remaining Amount',
                        remaining,
                        isBold: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            pw.Spacer(),

            // Footer Signature
            pw.Align(
              alignment: pw.Alignment.bottomRight,
              child: pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 20, right: 20),
                child: pw.Text(
                  'Signature',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ];
        },
      ),
    );

    final pdfBytes = await _safeSavePdf(pdf);
    await file.writeAsBytes(pdfBytes);
    return file;
  }

  pw.Widget _blueprintInfoCellWithLabel(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Row(
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
          pw.Expanded(
            child: pw.Text(
              _fix(value),
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
              textDirection: pw.TextDirection.rtl,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _blueprintTableHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
        textDirection: pw.TextDirection.rtl,
      ),
    );
  }

  pw.Widget _blueprintVerticalCell(
    String label,
    String value, {
    double? width,
  }) {
    return pw.Container(
      width: width,
      padding: const pw.EdgeInsets.all(4),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  pw.Widget _blueprintTableCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: const pw.TextStyle(fontSize: 10),
        textDirection: pw.TextDirection.rtl,
      ),
    );
  }

  pw.Widget _financialSummaryRow(
    String label,
    double value, {
    bool isBold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Text(
            value.toStringAsFixed(2),
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _tableCell(
    String text, {
    bool isHeader = false,
    bool isAbnormal = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        _fix(text),
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          fontSize: 11,
          fontWeight: (isHeader || isAbnormal)
              ? pw.FontWeight.bold
              : pw.FontWeight.normal,
          color: isAbnormal ? PdfColors.red : PdfColors.black,
        ),
        textDirection: pw.TextDirection.rtl,
      ),
    );
  }

  pw.Widget _tableHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        _fix(text),
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
        textAlign: pw.TextAlign.center,
        textDirection: pw.TextDirection.rtl,
      ),
    );
  }

  String _fix(String? text) {
    if (text == null || text.isEmpty) return '';
    return ArabicUtils.fix(text);
  }

  pw.Widget _buildDynamicSection(
    Map<String, Map<String, dynamic>> items,
    bool isTop,
  ) {
    List<pw.Widget> leftItems = [];
    List<pw.Widget> centerItems = [];
    List<pw.Widget> rightItems = [];

    items.forEach((key, value) {
      final pos = value['pos'] as String;
      final widget = value['widget'] as pw.Widget?;
      if (widget == null) return;

      if (pos.startsWith(isTop ? 'top_' : 'bottom_')) {
        if (pos.endsWith('_left')) leftItems.add(widget);
        if (pos.endsWith('_center')) centerItems.add(widget);
        if (pos.endsWith('_right')) rightItems.add(widget);
      }
    });

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment:
          pw.CrossAxisAlignment.center, // Align vertically center
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisSize: pw.MainAxisSize.min,
          children: leftItems,
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          mainAxisSize: pw.MainAxisSize.min,
          children: centerItems,
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          mainAxisSize: pw.MainAxisSize.min,
          children: rightItems,
        ),
      ],
    );
  }

  static Future<Uint8List> _safeSavePdf(pw.Document pdf) async {
    try {
      return await compute(_savePdfDocument, pdf);
    } catch (e) {
      debugPrint('[PdfService] Isolate compute failed, falling back to direct pdf.save(): $e');
      return await pdf.save();
    }
  }
}

Future<Uint8List> _savePdfDocument(pw.Document pdf) async {
  return await pdf.save();
}
