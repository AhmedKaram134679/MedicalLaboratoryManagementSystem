class ArabicUtils {
  /// Map of Arabic characters to their directional variants:
  /// [Isolated, End, Middle, Beginning]
  static const Map<int, List<int>> _arabicMapping = {
    0x0621: [0xFE80, 0xFE80, 0xFE80, 0xFE80], // Hamza
    0x0622: [0xFE81, 0xFE82, 0xFE82, 0xFE81], // Alef with Madda
    0x0623: [0xFE83, 0xFE84, 0xFE84, 0xFE83], // Alef with Hamza Above
    0x0624: [0xFE85, 0xFE86, 0xFE86, 0xFE85], // Waw with Hamza Above
    0x0625: [0xFE87, 0xFE88, 0xFE88, 0xFE87], // Alef with Hamza Below
    0x0626: [0xFE89, 0xFE8A, 0xFE8B, 0xFE8C], // Yeh with Hamza Above
    0x0627: [0xFE8D, 0xFE8E, 0xFE8E, 0xFE8D], // Alef
    0x0628: [0xFE8F, 0xFE90, 0xFE91, 0xFE92], // Beh
    0x0629: [0xFE93, 0xFE94, 0xFE94, 0xFE93], // Teh Marbuta
    0x062A: [0xFE95, 0xFE96, 0xFE97, 0xFE98], // Teh
    0x062B: [0xFE99, 0xFE9A, 0xFE9B, 0xFE9C], // Theh
    0x062C: [0xFE9D, 0xFE9E, 0xFE9F, 0xFEA0], // Jeem
    0x062D: [0xFEA1, 0xFEA2, 0xFEA3, 0xFEA4], // Hah
    0x062E: [0xFEA5, 0xFEA6, 0xFEA7, 0xFEA8], // Khah
    0x062F: [0xFEA9, 0xFEAA, 0xFEAA, 0xFEA9], // Dal
    0x0630: [0xFEAB, 0xFEAC, 0xFEAC, 0xFEAB], // Thal
    0x0631: [0xFEAD, 0xFEAE, 0xFEAE, 0xFEAD], // Reh
    0x0632: [0xFEAF, 0xFEB0, 0xFEB0, 0xFEAF], // Zain
    0x0633: [0xFEB1, 0xFEB2, 0xFEB3, 0xFEB4], // Seen
    0x0634: [0xFEB5, 0xFEB6, 0xFEB7, 0xFEB8], // Sheen
    0x0635: [0xFEB9, 0xFEBA, 0xFEBB, 0xFEBC], // Sad
    0x0636: [0xFEBD, 0xFEBE, 0xFEBF, 0xFEC0], // Dad
    0x0637: [0xFEC1, 0xFEC2, 0xFEC3, 0xFEC4], // Tah
    0x0638: [0xFEC5, 0xFEC6, 0xFEC7, 0xFEC8], // Zah
    0x0639: [0xFEC9, 0xFECA, 0xFECB, 0xFECC], // Ain
    0x063A: [0xFECD, 0xFECE, 0xFECF, 0xFED0], // Ghain
    0x0641: [0xFED1, 0xFED2, 0xFED3, 0xFED4], // Feh
    0x0642: [0xFED5, 0xFED6, 0xFED7, 0xFED8], // Qaf
    0x0643: [0xFED9, 0xFEDA, 0xFEDB, 0xFEDC], // Kaf
    0x0644: [0xFEDD, 0xFEDE, 0xFEDF, 0xFEE0], // Lam
    0x0645: [0xFEE1, 0xFEE2, 0xFEE3, 0xFEE4], // Meem
    0x0646: [0xFEE5, 0xFEE6, 0xFEE7, 0xFEE8], // Noon
    0x0647: [0xFEE9, 0xFEEA, 0xFEEB, 0xFEEC], // Heh
    0x0648: [0xFEED, 0xFEEE, 0xFEEE, 0xFEED], // Waw
    0x0649: [0xFEEF, 0xFEF0, 0xFEF0, 0xFEEF], // Alef Maksura
    0x064A: [0xFEF1, 0xFEF2, 0xFEF3, 0xFEF4], // Yeh
    0x067E: [0xFB56, 0xFB57, 0xFB58, 0xFB59], // Peh
    0x0686: [0xFB7A, 0xFB7B, 0xFB7C, 0xFB7D], // Tcheh
    0x06AF: [0xFB92, 0xFB93, 0xFB94, 0xFB95], // Gaf
  };

  /// Characters that do not connect to the left
  static const List<int> _nonLeftConnecting = [
    0x0621, // Hamza
    0x0622, // Alef with Madda
    0x0623, // Alef with Hamza Above
    0x0624, // Waw with Hamza Above
    0x0625, // Alef with Hamza Below
    0x0627, // Alef
    0x062F, // Dal
    0x0630, // Thal
    0x0631, // Reh
    0x0632, // Zain
    0x0648, // Waw
    0x0649, // Alef Maksura
  ];

  /// Reshapes Arabic text for PDF rendering
  static String reshape(String text) {
    if (text.isEmpty) return text;

    // Handle Lam-Alef ligatures first
    String processed = text;
    processed = processed.replaceAll('\u0644\u0622', '\uFEF5');
    processed = processed.replaceAll('\u0644\u0623', '\uFEF7');
    processed = processed.replaceAll('\u0644\u0625', '\uFEF9');
    processed = processed.replaceAll('\u0644\u0627', '\uFEFB');

    final List<int> codes = processed.codeUnits;
    final List<int> reshaped = [];

    for (int i = 0; i < codes.length; i++) {
      int current = codes[i];

      if (!_arabicMapping.containsKey(current)) {
        reshaped.add(current);
        continue;
      }

      int? prev = (i > 0) ? codes[i - 1] : null;
      int? next = (i < codes.length - 1) ? codes[i + 1] : null;

      // Check if previous char connects to the left
      bool connectedPrev =
          prev != null &&
          _arabicMapping.containsKey(prev) &&
          !_nonLeftConnecting.contains(prev);

      // Check if next char connects to its right (exists and is Arabic)
      bool connectedNext = next != null && _arabicMapping.containsKey(next);

      int formIndex;
      if (connectedPrev && connectedNext) {
        formIndex = 2; // Middle
      } else if (connectedPrev) {
        formIndex = 1; // End
      } else if (connectedNext) {
        formIndex = 3; // Beginning
      } else {
        formIndex = 0; // Isolated
      }

      reshaped.add(_arabicMapping[current]![formIndex]);
    }

    return String.fromCharCodes(reshaped);
  }

  /// Fixes Arabic text for PDF.
  /// Reordering is NOT done here because we expect the engine to use RTL direction.
  static String fix(String text) {
    if (text.isEmpty) return text;
    return reshape(text);
  }
}
