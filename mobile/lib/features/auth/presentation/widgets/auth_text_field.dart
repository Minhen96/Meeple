import 'package:flutter/material.dart';
import 'package:meeple_hearth/shared/widgets/app_text_field.dart';

/// Text field for all auth forms — the shared [AppTextField] (web form
/// input with the uppercase tracked label above it), with the password
/// visibility toggle, autofill and no autocorrect.
class AuthTextField extends StatelessWidget {
  const AuthTextField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.isPassword = false,
    this.prefixIcon,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.autofillHints,
    this.enabled = true,
    this.focusNode,
    this.labelAction,
  });

  final String label;
  final String? hint;
  final TextEditingController? controller;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final bool isPassword;
  final IconData? prefixIcon;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final List<String>? autofillHints;
  final bool enabled;
  final FocusNode? focusNode;

  /// Trailing link on the label row (e.g. "FORGOT PASSWORD?").
  final Widget? labelAction;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      label: label,
      labelAction: labelAction,
      hint: hint,
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      isPassword: isPassword,
      prefixIcon: prefixIcon,
      validator: validator,
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
      autofillHints: autofillHints,
      enabled: enabled,
      autocorrect: false,
    );
  }
}
