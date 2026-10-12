import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/report_model.dart';

class ReportCard extends StatelessWidget {
  final ReportModel report;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onPrint;

  const ReportCard({
    super.key,
    required this.report,
    required this.onTap,
    this.onEdit,
    this.onDelete,
    this.onPrint,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2, // Slight elevation for depth
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon based on Report Type
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _getTypeColor(report.type).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _getTypeIcon(report.type),
                      color: _getTypeColor(report.type),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Title and ID
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          report.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '#${report.id}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontFamily: 'Courier',
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Status Badge
                  _buildStatusBadge(report.status),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),

              // Metadata Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildMetaInfo(
                    Icons.calendar_today,
                    DateFormat('yyyy-MM-dd').format(report.generatedAt),
                  ),
                  _buildMetaInfo(Icons.person_outline, report.generatedBy),
                  if (report.itemCount > 0)
                    _buildMetaInfo(Icons.list_alt, '${report.itemCount} عنصر'),
                ],
              ),

              // Action Buttons Row (if any actions provided)
              if (onEdit != null || onDelete != null || onPrint != null) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (onPrint != null)
                      IconButton(
                        icon: const Icon(Icons.print_outlined, size: 20),
                        color: Colors.blueGrey,
                        tooltip: 'طباعة',
                        onPressed: onPrint,
                      ),
                    if (onEdit != null && report.status == ReportStatus.draft)
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        color: Colors.blue,
                        tooltip: 'تعديل',
                        onPressed: onEdit,
                      ),
                    if (onDelete != null && report.status == ReportStatus.draft)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        color: Colors.red,
                        tooltip: 'حذف',
                        onPressed: onDelete,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(ReportStatus status) {
    Color color;
    String text;
    switch (status) {
      case ReportStatus.draft:
        color = Colors.orange;
        text = 'مسودة';
        break;
      case ReportStatus.ready:
        color = Colors.blue;
        text = 'جاهز';
        break;
      case ReportStatus.approved:
        color = Colors.green;
        text = 'معتمد';
        break;
      case ReportStatus.rejected:
        color = Colors.red;
        text = 'مرفوض';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildMetaInfo(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Color _getTypeColor(ReportType type) {
    switch (type) {
      case ReportType.inventory:
        return Colors.orange;
      case ReportType.financial:
        return Colors.green;
      case ReportType.tests:
        return Colors.blue;
      case ReportType.daily:
        return Colors.purple;
      case ReportType.monthly:
        return Colors.indigo;
      case ReportType.custom:
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  IconData _getTypeIcon(ReportType type) {
    switch (type) {
      case ReportType.inventory:
        return Icons.inventory_2_outlined;
      case ReportType.financial:
        return Icons.attach_money;
      case ReportType.tests:
        return Icons.biotech;
      case ReportType.daily:
        return Icons.today;
      case ReportType.monthly:
        return Icons.calendar_month;
      case ReportType.custom:
        return Icons.dashboard_customize;
      default:
        return Icons.description_outlined;
    }
  }
}
