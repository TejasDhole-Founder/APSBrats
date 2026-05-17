class Validators {
  const Validators._();

  static String? requiredField(String? value, {String fieldName = 'Field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  static String? username(String? value) {
    final base = requiredField(value, fieldName: 'Username');
    if (base != null) {
      return base;
    }
    if (value!.trim().length < 3) {
      return 'Username must be at least 3 characters';
    }
    return null;
  }
}
