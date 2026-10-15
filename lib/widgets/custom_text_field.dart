import 'package:flutter/material.dart';

/// Input teks kustom bergaya Material 3 Google Keep
class CustomTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String label;
  final String? hintText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final bool enabled;

  const CustomTextField({
    super.key,
    this.controller,
    required this.label,
    this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF3C4043),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          onChanged: onChanged,
          enabled: enabled,
          style: const TextStyle(
            fontSize: 15,
            color: Color(0xFF202124),
          ),
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, color: const Color(0xFF5F6368), size: 20)
                : null,
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    );
  }
}

