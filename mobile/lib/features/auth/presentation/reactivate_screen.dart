import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/core/router/app_router.dart';
import 'package:meeple_hearth/features/auth/data/google_auth_client.dart';
import 'package:meeple_hearth/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:meeple_hearth/features/auth/providers/auth_provider.dart';
import 'package:meeple_hearth/l10n/l10n.dart';
import 'package:meeple_hearth/shared/widgets/app_button.dart';
import 'package:meeple_hearth/shared/widgets/app_toast.dart';

/// Shown when login returns `ACCOUNT_DELETED` (within the 30-day grace
/// period): `POST /auth/reactivate {emailOrUsername, password}` — or
/// `{googleIdToken}` for Google accounts — restores the account and signs in.
class ReactivateScreen extends ConsumerStatefulWidget {
  const ReactivateScreen({super.key, this.emailOrUsername = ''});

  final String emailOrUsername;

  @override
  ConsumerState<ReactivateScreen> createState() => _ReactivateScreenState();
}

class _ReactivateScreenState extends ConsumerState<ReactivateScreen> {
  final _form = GlobalKey<FormState>();
  late final _identifier = TextEditingController(text: widget.emailOrUsername);
  final _password = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _reactivateWithGoogle() async {
    setState(() => _loading = true);
    final l10n = context.l10n;
    try {
      final done =
          await ref.read(authNotifierProvider.notifier).reactivateWithGoogle();
      if (done && mounted) {
        showToast(context, l10n.reactivateDone, type: ToastType.success);
      }
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reactivate() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    final l10n = context.l10n;
    try {
      await ref.read(authNotifierProvider.notifier).reactivate(
            emailOrUsername: _identifier.text.trim(),
            password: _password.text,
          );
      if (mounted) {
        showToast(context, l10n.reactivateDone, type: ToastType.success);
      }
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.transparent,
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(AppRoutes.login),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: AppSpacing.pagePadding,
            children: [
              const Icon(
                Icons.restore_rounded,
                size: 56,
                color: AppColors.tertiary,
              ),
              AppSpacing.vGapLg,
              Text(
                l10n.reactivateTitle,
                style: AppTypography.headlineSmall,
                textAlign: TextAlign.center,
              ),
              AppSpacing.vGapSm,
              Text(
                l10n.reactivateBody,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              AppSpacing.vGapXl,
              AuthTextField(
                key: const Key('reactivate-identifier'),
                label: l10n.authEmailOrUsername,
                controller: _identifier,
                prefixIcon: Icons.person_outline_rounded,
                validator: (v) => (v ?? '').trim().isEmpty
                    ? l10n.authEmailOrUsernameRequired
                    : null,
              ),
              AppSpacing.vGapMd,
              AuthTextField(
                key: const Key('reactivate-password'),
                label: l10n.authPassword,
                controller: _password,
                isPassword: true,
                textInputAction: TextInputAction.done,
                prefixIcon: Icons.lock_outline_rounded,
                validator: (v) =>
                    (v ?? '').isEmpty ? l10n.authPasswordRequired : null,
                onFieldSubmitted: (_) => _reactivate(),
              ),
              AppSpacing.vGapXl,
              AppButton(
                key: const Key('reactivate-submit'),
                label: l10n.reactivateSubmit,
                isLoading: _loading,
                onPressed: _reactivate,
              ),
              if (ref.watch(googleAuthClientProvider).isAvailable) ...[
                AppSpacing.vGapMd,
                TextButton.icon(
                  key: const Key('reactivate-google'),
                  onPressed: _loading ? null : _reactivateWithGoogle,
                  icon: const Icon(Icons.g_mobiledata_rounded, size: 28),
                  label: Text(l10n.reactivateWithGoogle),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
