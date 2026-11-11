import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/core/constants/text_style_weight.dart';
import 'package:meeple_hearth/l10n/l10n.dart';
import 'package:meeple_hearth/shared/widgets/app_text_field.dart';

/// Page padding of the settings sub-pages (web `PageContainer` px-4).
const settingsPagePadding = EdgeInsets.fromLTRB(
  AppSpacing.lg,
  AppSpacing.sm,
  AppSpacing.lg,
  AppSpacing.xxxl,
);

/// Settings form field — web `<label class="text-xs font-label font-bold
/// uppercase tracking-widest">` above a `bg-surface-container-highest
/// rounded-xl px-4 py-3 text-sm` input.
class SettingsField extends StatefulWidget {
  const SettingsField({
    super.key,
    this.label,
    this.controller,
    this.fieldKey,
    this.hint,
    this.helper,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction,
    this.validator,
    this.onChanged,
    this.enabled = true,
    this.maxLines = 1,
    this.maxLength,
    this.prefixText,
    this.autofillHints,
    this.textCapitalization = TextCapitalization.none,
    this.showCounter = false,
    this.danger = false,
    this.focusNode,
    this.onFieldSubmitted,
  });

  /// Uppercase label above the field; null for placeholder-only inputs
  /// (web auth forms).
  final String? label;
  final TextEditingController? controller;
  final Key? fieldKey;
  final String? hint;

  /// Small note under the field (`text-xs text-on-surface-variant px-1`).
  final String? helper;
  final bool isPassword;
  final TextInputType keyboardType;
  final TextInputAction? textInputAction;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final int maxLines;
  final int? maxLength;

  /// Fixed text inside the field before the value (the `@` of usernames).
  final String? prefixText;
  final Iterable<String>? autofillHints;
  final TextCapitalization textCapitalization;

  /// Right-aligned `12/200` counter under the field (web bio).
  final bool showCounter;

  /// Error-tinted focus ring (delete account).
  final bool danger;
  final FocusNode? focusNode;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  State<SettingsField> createState() => _SettingsFieldState();
}

class _SettingsFieldState extends State<SettingsField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final base = appFieldDecoration(
      hint: widget.hint,
      fill: AppColors.surfaceContainerHighest,
      radius: widget.maxLines > 1 ? AppSpacing.radiusXl : AppRadius.tile,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      suffix: widget.isPassword
          ? IconButton(
              tooltip: _obscure ? l10n.authShowPassword : l10n.authHidePassword,
              icon: Icon(
                _obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 20,
                color: AppColors.onSurfaceVariant,
              ),
              onPressed: () => setState(() => _obscure = !_obscure),
            )
          : null,
    );
    final ring = OutlineInputBorder(
      borderRadius: BorderRadius.circular(
        widget.maxLines > 1 ? AppSpacing.radiusXl : AppRadius.tile,
      ),
      borderSide: BorderSide(
        color: (widget.danger ? AppColors.error : AppColors.primary)
            .withValues(alpha: 0.2),
        width: 2,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              widget.label!.toUpperCase(),
              style: AppTypography.overline,
            ),
          ),
        TextFormField(
          key: widget.fieldKey,
          controller: widget.controller,
          focusNode: widget.focusNode,
          onFieldSubmitted: widget.onFieldSubmitted,
          enabled: widget.enabled,
          obscureText: widget.isPassword && _obscure,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          validator: widget.validator,
          onChanged: widget.showCounter
              ? (v) {
                  setState(() {});
                  widget.onChanged?.call(v);
                }
              : widget.onChanged,
          maxLines: widget.isPassword ? 1 : widget.maxLines,
          minLines: widget.maxLines > 1 ? widget.maxLines : null,
          inputFormatters: widget.maxLength == null
              ? null
              : [LengthLimitingTextInputFormatter(widget.maxLength)],
          autofillHints: widget.autofillHints,
          autocorrect: !widget.isPassword,
          enableSuggestions: !widget.isPassword,
          textCapitalization: widget.textCapitalization,
          style: AppTypography.bodyMedium.copyWith(
            color: widget.enabled
                ? AppColors.onSurface
                : AppColors.onSurface.withValues(alpha: 0.6),
          ),
          decoration: base.copyWith(
            focusedBorder: ring,
            prefixText: widget.prefixText,
            prefixStyle: AppTypography.bodyMedium
                .copyWith(color: AppColors.onSurfaceVariant),
            hintStyle: AppTypography.bodyMedium
                .copyWith(color: AppColors.onSurfaceVariant),
            errorStyle:
                AppTypography.bodySmall.copyWith(color: AppColors.error),
          ),
        ),
        if (widget.helper != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
            child: Text(
              widget.helper!,
              style: AppTypography.bodySmall
                  .copyWith(color: AppColors.onSurfaceVariant),
            ),
          ),
        if (widget.showCounter && widget.maxLength != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
            child: Text(
              '${widget.controller?.text.length ?? 0}/${widget.maxLength}',
              textAlign: TextAlign.right,
              style: AppTypography.bodySmall.copyWith(
                color:
                    (widget.controller?.text.length ?? 0) >= widget.maxLength!
                        ? AppColors.error
                        : AppColors.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

/// `text-sm text-on-surface-variant` intro paragraph.
class SettingsNote extends StatelessWidget {
  const SettingsNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: AppTypography.bodyMedium
            .copyWith(color: AppColors.onSurfaceVariant),
      );
}

/// Web `bg-surface-container-low rounded-xl p-4 text-sm` info panel.
class SettingsInfoPanel extends StatelessWidget {
  const SettingsInfoPanel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        ),
        child: SettingsNote(text),
      );
}

/// Centered success state of the email forms (web `mark_email_unread` in
/// tertiary, semibold title, small body).
class SettingsSentState extends StatelessWidget {
  const SettingsSentState({
    super.key,
    required this.title,
    required this.body,
    this.icon = Icons.mark_email_unread_outlined,
  });

  final String title;
  final String body;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
        child: Column(
          children: [
            Icon(icon, size: 60, color: AppColors.tertiary),
            AppSpacing.vGapLg,
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.bodyLarge
                  .weight(FontWeight.w600)
                  .copyWith(color: AppColors.onSurface),
            ),
            AppSpacing.vGapLg,
            Text(
              body,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.onSurfaceVariant),
            ),
          ],
        ),
      );
}

/// Segmented choice row of the settings menu (web Language / Appearance):
/// a surface-container-low pill holding white options; the selected one is
/// solid primary.
class SettingsSegmented<T> extends StatelessWidget {
  const SettingsSegmented({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.enabled,
    this.keyFor,
  });

  final List<(T, String)> options;

  /// Key of each option (tests); defaults to `segment-<value>`.
  final Key Function(T)? keyFor;
  final T selected;
  final ValueChanged<T>? onSelected;

  /// Options that can be picked (others are greyed out, web "coming soon").
  final bool Function(T)? enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.tile),
      ),
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) AppSpacing.hGapXs,
            Expanded(child: _option(options[i])),
          ],
        ],
      ),
    );
  }

  Widget _option((T, String) o) {
    final active = o.$1 == selected;
    final can = enabled?.call(o.$1) ?? true;
    return Semantics(
      selected: active,
      button: true,
      child: Material(
        color: active ? AppColors.primary : AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.panel),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: keyFor?.call(o.$1) ?? ValueKey('segment-${o.$1}'),
          onTap: !can || onSelected == null || active
              ? null
              : () => onSelected!(o.$1),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Text(
              o.$2,
              textAlign: TextAlign.center,
              style: AppTypography.titleSmall.copyWith(
                color: active
                    ? AppColors.onPrimary
                    : can
                        ? AppColors.onSurface
                        : AppColors.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
