class AppFormatter {
  static String formatDouble(double value) {
    if (value == 0) return '0';
    
    // Limit to 4 decimal places to avoid long floating point artifacts
    String s = value.toStringAsFixed(4);
    
    // Remove trailing zeros and possible decimal point
    if (s.contains('.')) {
      s = s.replaceAll(RegExp(r'0*$'), '');
      s = s.replaceAll(RegExp(r'\.$'), '');
    }
    return s;
  }
}
