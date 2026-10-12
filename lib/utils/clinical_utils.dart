/// Utility functions for clinical test evaluations and financial allocations
class ClinicalUtils {
  /// Evaluates whether a test result falls outside the defined clinical reference range
  static bool isResultAbnormal(String value, String? range) {
    if (value.isEmpty || range == null) return false;

    try {
      final cleanRange = range.trim();
      if (!cleanRange.contains('-')) return false;

      final rawParts = cleanRange
          .split('-')
          .map(
            (e) => double.tryParse(e.replaceAll(RegExp(r'[^0-9.]'), '').trim()),
          )
          .whereType<double>()
          .toList();

      if (rawParts.length >= 2) {
        final double min = rawParts[0] < rawParts[1] ? rawParts[0] : rawParts[1];
        final double max = rawParts[0] > rawParts[1] ? rawParts[0] : rawParts[1];

        if (value.contains('-')) {
          final valParts = value
              .split('-')
              .map(
                (e) => double.tryParse(
                  e.replaceAll(RegExp(r'[^0-9.]'), '').trim(),
                ),
              )
              .whereType<double>()
              .toList();

          if (valParts.length >= 2) {
            final double userMin = valParts[0] < valParts[1] ? valParts[0] : valParts[1];
            final double userMax = valParts[0] > valParts[1] ? valParts[0] : valParts[1];

            if (userMin >= min && userMax <= max) return false;
            return true;
          }
        } else {
          final double? numVal = double.tryParse(
            value.replaceAll(RegExp(r'[^0-9.]'), '').trim(),
          );
          if (numVal != null) {
            if (numVal < min || numVal > max) return true;
            return false;
          }
        }
      }
    } catch (_) {}
    return false;
  }

  /// Distributes global discount and paid amounts proportionally across line items,
  /// guaranteeing that the exact remainder is assigned to the final item so that sum equals total.
  static List<Map<String, dynamic>> distributeFinancials({
    required List<double> prices,
    required double total,
    required double globalDiscount,
    required double globalPaid,
  }) {
    double runningDiscount = 0.0;
    double runningPaid = 0.0;
    final results = <Map<String, dynamic>>[];

    for (int i = 0; i < prices.length; i++) {
      final price = prices[i];
      final bool isLast = i == prices.length - 1;

      double itemDiscount;
      double itemPaid;

      if (isLast) {
        itemDiscount = double.parse((globalDiscount - runningDiscount).toStringAsFixed(2));
        itemPaid = double.parse((globalPaid - runningPaid).toStringAsFixed(2));
      } else {
        final double ratio = total > 0 ? (price / total) : 0;
        itemDiscount = double.parse((globalDiscount * ratio).toStringAsFixed(2));
        itemPaid = double.parse((globalPaid * ratio).toStringAsFixed(2));
        runningDiscount += itemDiscount;
        runningPaid += itemPaid;
      }

      results.add({
        'price': price,
        'discount': itemDiscount,
        'paid': itemPaid,
      });
    }

    return results;
  }
}
