class Validators {
  Validators._();

  static final RegExp _usernamePattern = RegExp(r'^[a-z0-9_.]{3,30}$');

  static String? username(String? value) {
    final v = (value ?? '').trim().toLowerCase();
    if (v.isEmpty) return 'Username is required';
    if (!_usernamePattern.hasMatch(v)) {
      return '3–30 characters, lowercase letters, numbers, dot or underscore';
    }
    return null;
  }

  static String? displayName(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Display name is required';
    if (v.length > 60) return 'Keep it under 60 characters';
    return null;
  }

  static String? bio(String? value) {
    if ((value ?? '').length > 200) return 'Keep your bio under 200 characters';
    return null;
  }

  static String? notEmpty(String? value, [String label = 'This field']) {
    if ((value ?? '').trim().isEmpty) return '$label is required';
    return null;
  }
}
