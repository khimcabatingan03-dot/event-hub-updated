import 'package:flutter/material.dart';
import 'app_colors.dart';

// success message 
void showSuccessSnack(BuildContext context, String message) {
  if (!context.mounted) return;
  showSnackOn(ScaffoldMessenger.of(context), message, error: false);
}

// error message 
void showErrorSnack(BuildContext context, String message) {
  if (!context.mounted) return;
  showSnackOn(ScaffoldMessenger.of(context), message, error: true);
}

// use this when the messenger must be captured before a dialog closes
void showSnackOn(ScaffoldMessengerState messenger, String message,
    {bool error = false}) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor:
            error ? const Color(0xFFB3261E) : AppColors.primary,
      ),
    );
}

// yes / no confirmation — returns true when the user confirms
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Yes',
  String cancelLabel = 'Cancel',
  bool danger = false,
}) async {
  final bool? result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(cancelLabel,
              style: const TextStyle(color: AppColors.greyText)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            confirmLabel,
            style: TextStyle(
              color: danger ? const Color(0xFFB3261E) : AppColors.primary,
            ),
          ),
        ),
      ],
    ),
  );
  return result ?? false;
}

// single-button dialog for important issues or information
Future<void> showInfoDialog(
  BuildContext context, {
  required String title,
  required String message,
  String label = 'OK',
}) async {
  await showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(label, style: const TextStyle(color: AppColors.primary)),
        ),
      ],
    ),
  );
}

String? validateRequired(String? value, {String label = 'This field'}) {
  if (value == null || value.trim().isEmpty) return '$label is required.';
  return null;
}

String? validateEmail(String? value) {
  final String email = (value ?? '').trim();
  if (email.isEmpty) return 'Email is required.';
  if (!email.contains('@')) return 'Email must contain @';
  final RegExp emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  if (!emailPattern.hasMatch(email)) return 'Please enter a valid email.';
  return null;
}

String? validateStudentId(String? value) {
  final String studentId = (value ?? '').trim();
  if (studentId.isEmpty) return 'Student ID is required.';
  if (studentId.length > 10) return 'Student ID must not exceed 10 digits.';
  return null;
}

String? validatePassword(String? value) {
  final String password = value ?? '';
  if (password.isEmpty) return 'Password is required.';
  if (password.length < 8) return 'Password must be at least 8 characters.';
  return null;
}

String? validatePasswordConfirmation(String? value, String password) {
  final String confirmation = value ?? '';
  if (confirmation.isEmpty) return 'Please re-enter your password.';
  if (confirmation != password) return 'Passwords do not match.';
  return null;
}


InputDecoration appInputDecoration({
  required String label,
  String? hint,
  IconData? prefixIcon,
  Widget? suffixIcon,
  String? suffixText,
  TextStyle? suffixStyle,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
    suffixIcon: suffixIcon,
    suffixText: suffixText,
    suffixStyle: suffixStyle,
    // normal outline while the input is valid
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    // invalid input - red outline around the field
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.red),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.red, width: 2),
    ),
  );
}
