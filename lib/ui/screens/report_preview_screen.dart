import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, Uint8List;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../models/report_model.dart';
import '../../services/report_service.dart';
import '../../services/settings_service.dart';
import '../../utils/arabic_utils.dart';
import '../../utils/report_date_formatter.dart';

class ReportPreviewScreen extends StatefulWidget {
  final ReportModel report;

  const ReportPreviewScreen({super.key, required this.report});

  @override
  State<ReportPreviewScreen> createState() => _ReportPreviewScreenState();
}

class _ReportPreviewScreenState extends State<ReportPreviewScreen> {
  late ReportModel _report;
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _report = widget.report;
    _notesController.text = _report.notes ?? '';
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_report.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareReport,
            tooltip: 'مشاركة',
          ),
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: _printReport,
            tooltip: 'طباعة',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildInfoCard(),
          Expanded(child: _buildReportTable()),
          _buildActionFooter(),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'رقم التقرير: ${_report.id}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(
                      _report.status,
                    ).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: _getStatusColor(_report.status)),
                  ),
                  child: Text(
                    _getStatusText(_report.status),
                    style: TextStyle(color: _getStatusColor(_report.status)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'تاريخ الإنشاء: ${ReportDateFormatter.formatDateTime(_report.generatedAt)}',
                ),
                Text('بواسطة: ${_report.generatedBy}'),
              ],
            ),
            if (_report.metadata.isNotEmpty) ...[
              const Divider(),
              ..._report.metadata.entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Text(
                        '${ReportDateFormatter.getMetadataKeyDisplay(e.key, isArabic: true)}: ',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text('${e.value}'),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReportTable() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(
            Theme.of(context).primaryColor.withValues(alpha: 0.1),
          ),
          columns: _report.columns
              .map(
                (col) => DataColumn(
                  label: Text(
                    col.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  numeric: col.isNumeric,
                ),
              )
              .toList(),
          rows: _report.data.map((row) {
            return DataRow(
              cells: _report.columns.map((col) {
                return DataCell(Text(row[col.key]?.toString() ?? '-'));
              }).toList(),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildActionFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, -2),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          TextField(
            controller: _notesController,
            decoration: const InputDecoration(
              labelText: 'ملاحظات إضافية',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
            onChanged: (val) {
              setState(() {
                _report = _report.copyWith(notes: val);
              });
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      final notes = _notesController.text;
                      await ReportService().updateReportStatus(
                        _report.id,
                        ReportStatus.draft,
                      );
                      await ReportService().updateReportNotes(
                        _report.id,
                        notes,
                      );
                      if (!mounted) return;
                      setState(() {
                        _report = _report.copyWith(
                          status: ReportStatus.draft,
                          notes: notes,
                        );
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم الحفظ كمسودة بنجاح')),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('خطأ في الحفظ: $e')),
                      );
                    }
                  },
                  icon: const Icon(Icons.save_as),
                  label: const Text('حفظ كمسودة'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _report.status == ReportStatus.approved
                      ? null
                      : () async {
                          try {
                            final notes = _notesController.text;
                            await ReportService().updateReportStatus(
                              _report.id,
                              ReportStatus.approved,
                            );
                            await ReportService().updateReportNotes(
                              _report.id,
                              notes,
                            );
                            if (!mounted) return;
                            setState(() {
                              _report = _report.copyWith(
                                status: ReportStatus.approved,
                                notes: notes,
                              );
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('تم اعتماد التقرير بنجاح')),
                            );
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('خطأ في الاعتماد: $e')),
                            );
                          }
                        },
                  icon: const Icon(Icons.check_circle),
                  label: const Text('اعتماد التقرير'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(ReportStatus status) {
    switch (status) {
      case ReportStatus.draft:
        return Colors.orange;
      case ReportStatus.ready:
        return Colors.blue;
      case ReportStatus.approved:
        return Colors.green;
      case ReportStatus.rejected:
        return Colors.red;
    }
  }

  String _getStatusText(ReportStatus status) {
    switch (status) {
      case ReportStatus.draft:
        return 'مسودة';
      case ReportStatus.ready:
        return 'جاهز للاعتماد';
      case ReportStatus.approved:
        return 'معتمد';
      case ReportStatus.rejected:
        return 'مرفوض';
    }
  }

  Future<void> _printReport() async {
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => _generatePdf(format),
    );
  }

  Future<void> _shareReport() async {
    await Printing.sharePdf(
      bytes: await _generatePdf(PdfPageFormat.a4),
      filename: 'report_${_report.id}.pdf',
    );
  }

  Future<Uint8List> _generatePdf(PdfPageFormat format) async {
    final pdf = pw.Document();
    final fontData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
    final ttf = pw.Font.ttf(fontData);
    final usePreprinted = await SettingsService().getUsePreprintedLetterhead();
    final effectivePageFormat = usePreprinted
        ? format.copyWith(
            marginTop: 141.7, // 5 cm top margin for pre-printed letterhead
          )
        : format;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: effectivePageFormat,
        theme: pw.ThemeData.withFont(base: ttf),
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 10),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('MLMS System', style: const pw.TextStyle(fontSize: 10)),
                pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ],
            ),
          );
        },
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      ArabicUtils.fix(_report.title),
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        font: ttf,
                      ),
                      textDirection: pw.TextDirection.rtl,
                      maxLines: 2,
                    ),
                  ),
                  pw.SizedBox(width: 12),
                  pw.Text(
                    'Report ID: ${_report.id}',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 14),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  ArabicUtils.fix('Generated By: ${_report.generatedBy}'),
                  style: const pw.TextStyle(fontSize: 10),
                  textDirection: pw.TextDirection.rtl,
                ),
                pw.Text(
                  'Date: ${ReportDateFormatter.formatDateTime(_report.generatedAt)}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ],
            ),
            if (_report.metadata.isNotEmpty) ...[
              pw.SizedBox(height: 8),
              ..._report.metadata.entries.map(
                (e) {
                  final keyDisplay = ReportDateFormatter.getMetadataKeyDisplay(e.key, isArabic: true);
                  return pw.Text(
                    ArabicUtils.fix('$keyDisplay: ${e.value}'),
                    style: const pw.TextStyle(fontSize: 10),
                    textDirection: pw.TextDirection.rtl,
                  );
                },
              ),
            ],
            pw.SizedBox(height: 14),
            pw.TableHelper.fromTextArray(
              context: context,
              headers: _report.columns.map((c) => ArabicUtils.fix(c.title)).toList(),
              data: _report.data.map((row) {
                return _report.columns
                    .map((col) => ArabicUtils.fix(row[col.key]?.toString() ?? '-'))
                    .toList();
              }).toList(),
              border: pw.TableBorder.all(),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
                fontSize: 10,
                font: ttf,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blueGrey,
              ),
              cellStyle: pw.TextStyle(font: ttf, fontSize: 10),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              cellAlignment: pw.Alignment.center,
              headerDirection: pw.TextDirection.rtl,
              tableDirection: pw.TextDirection.rtl,
              cellAlignments: {
                for (var i = 0; i < _report.columns.length; i++)
                  i: _report.columns[i].isNumeric
                      ? pw.Alignment.centerRight
                      : pw.Alignment.centerLeft,
              },
            ),
            if (_report.notes != null && _report.notes!.isNotEmpty) ...[
              pw.SizedBox(height: 20),
              pw.Text(
                ArabicUtils.fix('ملاحظات:'),
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: ttf),
                textDirection: pw.TextDirection.rtl,
              ),
              pw.Text(
                ArabicUtils.fix(_report.notes!),
                style: pw.TextStyle(font: ttf),
                textDirection: pw.TextDirection.rtl,
              ),
            ],
          ];
        },
      ),
    );

    return pdf.save();
  }
}
