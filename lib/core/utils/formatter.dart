class AppFormatter {
  static String formatDouble(double value) {
    if (value == 0) return '0';
    // Remove trailing zeros and possible decimal point
    String s = value.toString();
    if (s.contains('.')) {
      s = s.replaceAll(RegExp(r'0*$'), '');
      s = s.replaceAll(RegExp(r'\.$'), '');
    }
    return s;
  }
}
