import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/l10n/l10n.dart';

/// Filled, outline-free text field — the web form input
/// (`bg-surface-container-highest/60 rounded-2xl px-5 py-3.5 text-sm`,
/// `focus:ring-2 ring-primary/40`) with an optional uppercase tracked
/// [label] above it (`text-[10px] font-black uppercase tracking-[.2em]`)
/// and an optional [labelAction] on the label row ("FORGOT PASSWORD?").
///
/// Set [isPassword] for the built-in show/hide toggle.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    this.label,
    this.labelAction,
    this.hint,
    this.controller,
    this.focusNode,
    this.keyboardType = TextInputType.text,
    this.textInputAction,
    this.isPassword = false,
    this.prefixIcon,
    this.suffix,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.autofillHints,
    this.enabled = true,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.autocorrect = true,
    this.fieldKey,
  });

  /// Shown above the field, upper-cased.
  final String? label;
  final Widget? labelAction;
  final String? hint;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final TextInputType keyboardType;
  final TextInputAction? textInputAction;
  final bool isPassword;
  final IconData? prefixIcon;
  final Widget? suffix;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final Iterable<String>? autofillHints;
  final bool enabled;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final bool autocorrect;

  /// Key for the inner [TextFormField] (tests).
  final Key? fieldKey;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final field = TextFormField(
      key: widget.fieldKey,
      controller: widget.controller,
      focusNode: widget.focusNode,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      obscureText: widget.isPassword && _obscure,
      validator: widget.validator,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onFieldSubmitted,
      autofillHints: widget.autofillHints,
      enabled: widget.enabled,
      maxLines: widget.isPassword ? 1 : widget.maxLines,
      minLines: widget.minLines,
      maxLength: widget.maxLength,
      inputFormatters: widget.inputFormatters,
      textCapitalization: widget.textCapitalization,
      autocorrect: !widget.isPassword && widget.autocorrect,
      enableSuggestions: !widget.isPassword,
      style: AppTypography.bodyMedium,
      decoration: appFieldDecoration(
        hint: widget.hint ?? widget.label,
        prefixIcon: widget.prefixIcon,
        suffix: widget.isPassword
            ? IconButton(
                tooltip: _obscure
                    ? l10n.authShowPassword
                    : l10n.authHidePassword,
                icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 22,
                  color: AppColors.onSurfaceVariant,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              )
            : widget.suffix,
      ),
    );
    if (widget.label == null && widget.labelAction == null) return field;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Row(
            children: [
              if (widget.label != null)
                Expanded(
                  child: Text(
                    widget.label!.toUpperCase(),
                    style: AppTypography.eyebrow,
                  ),
                )
              else
                const Spacer(),
              if (widget.labelAction != null) widget.labelAction!,
            ],
          ),
        ),
        field,
      ],
    );
  }
}

/// The shared filled input decoration (web form input). Use it directly on
/// a raw [TextField] when [AppTextField] does not fit.
InputDecoration appFieldDecoration({
  String? hint,
  IconData? prefixIcon,
  Widget? suffix,
  Color fill = AppColors.inputFill,
  double radius = 16,
  EdgeInsetsGeometry contentPadding = const EdgeInsets.symmetric(
    horizontal: 20,
    vertical: 14,
  ),
}) {
  final shape = OutlineInputBorder(
    borderRadius: BorderRadius.circular(radius),
    borderSide: BorderSide.none,
  );
  return InputDecoration(
    hintText: hint,
    hintStyle: AppTypography.bodyMedium.copyWith(
      color: AppColors.onSurfaceVariant.withValues(alpha: 0.4),
    ),
    filled: true,
    fillColor: fill,
    contentPadding: contentPadding,
    prefixIcon: prefixIcon == null
        ? null
        : Icon(prefixIcon, size: 20, color: AppColors.onSurfaceVariant),
    suffixIcon: suffix,
    border: shape,
    enabledBorder: shape,
    disabledBorder: shape,
    focusedBorder: shape.copyWith(
      borderSide: BorderSide(
        color: AppColors.primary.withValues(alpha: 0.4),
        width: 2,
      ),
    ),
    errorBorder: shape.copyWith(
      borderSide: const BorderSide(color: AppColors.error, width: 1.5),
    ),
    focusedErrorBorder: shape.copyWith(
      borderSide: const BorderSide(color: AppColors.error, width: 2),
    ),
  );
}

/// Pill search field — web `bg-surface-container-low rounded-full` search
/// inputs with a leading `search` icon.
class AppSearchField extends StatelessWidget {
  const AppSearchField({
    super.key,
    required this.hint,
    this.controller,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.suffix,
    this.fieldKey,
  });

  final String hint;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final Widget? suffix;
  final Key? fieldKey;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: fieldKey,
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textInputAction: TextInputAction.search,
      style: AppTypography.bodyMedium,
      decoration: appFieldDecoration(
        hint: hint,
        prefixIcon: Icons.search_rounded,
        suffix: suffix,
        fill: AppColors.surfaceContainerLow,
        radius: AppSpacing.radiusFull,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
      ),
    );
  }
}
