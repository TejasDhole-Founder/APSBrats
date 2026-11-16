import 'package:apsbrat_frontend/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The standard form field look used across profile and onboarding forms:
/// white fill, soft border, crimson focus ring, red error ring.
InputDecoration appInputDecoration(
  String hint, {
  Widget? suffix,
  String? prefix,
}) {
  OutlineInputBorder border(Color color) => OutlineInputBorder(
    borderRadius: AppRadius.sm,
    borderSide: BorderSide(color: color, width: 1.5),
  );

  return InputDecoration(
    hintText: hint,
    prefixText: prefix,
    suffixIcon: suffix,
    filled: true,
    fillColor: Colors.white,
    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFFBBB4A8)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    border: border(const Color(0xFFE2DDD5)),
    enabledBorder: border(const Color(0xFFE2DDD5)),
    focusedBorder: border(AppColors.crimson),
    errorBorder: border(Colors.redAccent),
    focusedErrorBorder: border(Colors.redAccent),
  );
}

const appFieldLabelStyle = TextStyle(
  fontSize: 10,
  fontWeight: FontWeight.w800,
  letterSpacing: 0.8,
  color: AppColors.crimson,
);

/// Usernames match the server rule: letters, numbers and underscores, up to
/// 20 characters, always lowercase. Anything else is dropped as you type.
final List<TextInputFormatter> usernameInputFormatters = [
  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]')),
  LengthLimitingTextInputFormatter(20),
  TextInputFormatter.withFunction(
    (oldValue, newValue) =>
        newValue.copyWith(text: newValue.text.toLowerCase()),
  ),
];
