import 'package:flutter/material.dart';

InputDecoration authInputDecoration({
  required String label,
  required String hint,
  required IconData icon,
  Widget? suffixIcon,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: Icon(icon, color: const Color(0xFF5E74FF)),
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: const Color(0xFFF4F8FF),
    labelStyle: const TextStyle(color: Color(0xFF5E688B)),
    hintStyle: const TextStyle(color: Color(0xFF9DA9C8)),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFFDDE6FF)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFF5E74FF), width: 1.8),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFFDE5A77)),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFFDE5A77), width: 1.6),
    ),
  );
}

