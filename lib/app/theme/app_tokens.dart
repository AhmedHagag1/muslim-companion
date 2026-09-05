abstract final class AppSpacing {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

abstract final class AppRadius {
  static const small = 10.0;
  static const medium = 16.0;
  static const large = 24.0;
  static const pill = 999.0;
}

abstract final class AppTypography {
  // Null deliberately selects the platform's installed Arabic-capable UI font.
  static const String? uiFont = null;
  static const quranFont = 'AmiriQuran';
}
