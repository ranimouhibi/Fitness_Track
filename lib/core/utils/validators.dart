class Validators {
  /// Text must not be empty and must not exceed [max] characters.
  static String? requiredText(String? v, String label, {int max = 60}) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return 'Enter $label.';
    if (t.length > max) return '$label must be $max characters or less.';
    return null;
  }

  /// Text must have at least [min] characters.
  static String? minLength(String? v, String label, int min) {
    final t = (v ?? '').trim();
    if (t.length < min) return '$label must be at least $min characters.';
    return null;
  }

  /// Whole number between [min] and [max], inclusive.
  static String? intInRange(String? v, String label, int min, int max) {
    final n = int.tryParse((v ?? '').trim());
    if (n == null) return '$label must be a whole number.';
    if (n < min || n > max) return '$label must be between $min and $max.';
    return null;
  }
}