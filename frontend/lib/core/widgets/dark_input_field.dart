import 'package:apsbrat_frontend/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class DarkInputField extends StatelessWidget {
  const DarkInputField({
    super.key,
    required this.label,
    required this.hint,
    this.controller,
    this.obscureText = false,
    this.validator,
  });

  final String label;
  final String hint;
  final TextEditingController? controller;
  final bool obscureText;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: AppTextStyles.fieldLabel),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          validator: validator,
          style: AppTextStyles.fieldInput,
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }
}
