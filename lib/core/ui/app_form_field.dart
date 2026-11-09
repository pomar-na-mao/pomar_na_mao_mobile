import 'package:flutter/material.dart';

InputDecoration appFormInputDecoration(
  BuildContext context, {
  Widget? prefixIcon,
  Widget? suffixIcon,
  String? hintText,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  final radius = BorderRadius.circular(14);
  return InputDecoration(
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    hintText: hintText,
    filled: true,
    fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: colorScheme.outlineVariant),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: colorScheme.outlineVariant),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: colorScheme.primary, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: colorScheme.error),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: colorScheme.error, width: 2),
    ),
  );
}

class AppFormFieldLabel extends StatelessWidget {
  const AppFormFieldLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelLarge
          ?.copyWith(fontWeight: FontWeight.bold),
    ),
  );
}
