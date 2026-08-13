/// Sri Lanka phone normalization helpers (+94).
class PhoneUtils {
  PhoneUtils._();

  /// Digits-only local form: 07XXXXXXXX → validated length 10 starting with 0.
  static String? normalizeToE164(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^\d+]'), '');

    if (digits.startsWith('+94') && digits.length == 12) {
      return digits;
    }
    if (digits.startsWith('94') && digits.length == 11) {
      return '+$digits';
    }
    if (digits.startsWith('0') && digits.length == 10) {
      return '+94${digits.substring(1)}';
    }
    if (digits.length == 9 && digits.startsWith('7')) {
      return '+94$digits';
    }
    return null;
  }

  static String mask(String phoneE164) {
    if (phoneE164.length < 6) return phoneE164;
    final visible = phoneE164.substring(phoneE164.length - 3);
    return '${phoneE164.substring(0, 4)} ******$visible';
  }

  static bool isValidLocalOrE164(String raw) => normalizeToE164(raw) != null;
}
