import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/core/router/app_router.dart';
import 'package:meeple_hearth/core/utils/app_date_utils.dart';
import 'package:meeple_hearth/features/auth/domain/user_model.dart';
import 'package:meeple_hearth/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:meeple_hearth/features/auth/providers/auth_provider.dart';
import 'package:meeple_hearth/features/settings/providers/settings_provider.dart';
import 'package:meeple_hearth/l10n/l10n.dart';
import 'package:meeple_hearth/shared/widgets/app_button.dart';
import 'package:meeple_hearth/shared/widgets/app_toast.dart';
import 'package:meeple_hearth/shared/widgets/confirm_sheet.dart';
import 'package:meeple_hearth/shared/widgets/empty_state.dart';
import 'package:meeple_hearth/shared/widgets/error_state.dart';
import 'package:meeple_hearth/shared/widgets/meeple_app_bar.dart';

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// `POST /users/me/change-email {currentPassword, newEmail}`.
class ChangeEmailScreen extends ConsumerStatefulWidget {
  const ChangeEmailScreen({super.key});

  @override
  ConsumerState<ChangeEmailScreen> createState() => _ChangeEmailScreenState();
}

class _ChangeEmailScreenState extends ConsumerState<ChangeEmailScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _saving = false;
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(accountActionsProvider).changeEmail(
            currentPassword: _password.text,
            newEmail: _email.text.trim(),
          );
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: MeepleAppBar(
        title: l10n.settingsChangeEmail,
        showBackButton: true,
        fallbackRoute: AppRoutes.settings,
      ),
      body: _sent
          ? EmptyState(
              icon: Icons.mark_email_unread_outlined,
              title: l10n.changeEmailSentTitle,
              subtitle: l10n.changeEmailSentBody(_email.text.trim()),
            )
          : Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  Text(l10n.changeEmailBody, style: AppTypography.bodyMedium),
                  AppSpacing.vGapLg,
                  AuthTextField(
                    key: const Key('change-email-new'),
                    label: l10n.changeEmailNew,
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: Icons.alternate_email_rounded,
                    validator: (v) => _emailPattern.hasMatch((v ?? '').trim())
                        ? null
                        : l10n.authInvalidEmail,
                  ),
                  AppSpacing.vGapMd,
                  AuthTextField(
                    key: const Key('change-email-password'),
                    label: l10n.changeEmailCurrentPassword,
                    controller: _password,
                    isPassword: true,
                    textInputAction: TextInputAction.done,
                    prefixIcon: Icons.lock_outline_rounded,
                    validator: (v) =>
                        (v ?? '').isEmpty ? l10n.authPasswordRequired : null,
                  ),
                  AppSpacing.vGapXl,
                  AppButton(
                    key: const Key('change-email-submit'),
                    label: l10n.changeEmailSubmit,
                    isLoading: _saving,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
    );
  }
}

/// Password changes go through the reset email (same as the web).
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  bool _sending = false;
  bool _sent = false;

  Future<void> _send(String email) async {
    setState(() => _sending = true);
    try {
      await ref.read(accountActionsProvider).sendPasswordReset(email);
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final email = ref.watch(authNotifierProvider).valueOrNull?.email;
    return Scaffold(
      appBar: MeepleAppBar(
        title: l10n.settingsChangePassword,
        showBackButton: true,
        fallbackRoute: AppRoutes.settings,
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: _sent
            ? EmptyState(
                icon: Icons.mark_email_read_outlined,
                title: l10n.changePasswordSentTitle,
                subtitle: l10n.changePasswordSentBody,
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    email == null
                        ? l10n.changePasswordNoEmail
                        : l10n.changePasswordBody(email),
                    style: AppTypography.bodyLarge,
                  ),
                  AppSpacing.vGapXl,
                  if (email != null)
                    AppButton(
                      key: const Key('change-password-send'),
                      label: l10n.changePasswordSend,
                      isLoading: _sending,
                      onPressed: () => _send(email),
                    )
                  else
                    AppButton(
                      label: l10n.authForgotPassword,
                      onPressed: () => context.push(AppRoutes.forgotPassword),
                    ),
                ],
              ),
      ),
    );
  }
}

/// Active sessions (SCREENS §11.4).
class ActiveSessionsScreen extends ConsumerWidget {
  const ActiveSessionsScreen({super.key});

  Future<void> _guard(BuildContext context, Future<void> Function() f) async {
    try {
      await f();
    } catch (e) {
      if (context.mounted) showErrorToast(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final sessions = ref.watch(activeSessionsProvider);
    return Scaffold(
      appBar: MeepleAppBar(
        title: l10n.settingsSessions,
        showBackButton: true,
        fallbackRoute: AppRoutes.settings,
      ),
      body: sessions.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          error: e,
          onRetry: () => ref.invalidate(activeSessionsProvider),
        ),
        data: (list) => ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
          children: [
            for (final s in list) _SessionTile(session: s),
            if (list.length > 1)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: AppOutlinedButton(
                  key: const Key('revoke-others'),
                  label: l10n.sessionsRevokeOthers,
                  onPressed: () => _guard(
                    context,
                    () => ref.read(activeSessionsProvider.notifier).revokeOthers(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SessionTile extends ConsumerWidget {
  const _SessionTile({required this.session});

  final ActiveSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final s = session;
    final info = s.deviceInfo ?? l10n.sessionsUnknownDevice;
    final mobile = RegExp('android|iphone|ios|mobile|dart', caseSensitive: false)
        .hasMatch(info);
    return ListTile(
      key: ValueKey('session-${s.id}'),
      leading: Icon(mobile ? Icons.smartphone_rounded : Icons.computer_rounded),
      title: Text(info, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          if (s.current) l10n.sessionsThisDevice,
          if (s.lastUsedAt != null)
            l10n.sessionsLastActive(AppDateUtils.timeAgo(s.lastUsedAt!, l10n)),
        ].join(' · '),
      ),
      trailing: TextButton(
        onPressed: s.current
            ? null
            : () async {
                try {
                  await ref.read(activeSessionsProvider.notifier).revoke(s.id);
                } catch (e) {
                  if (context.mounted) showErrorToast(context, e);
                }
              },
        child: Text(l10n.sessionsSignOut),
      ),
    );
  }
}

/// Delete account (SCREENS §11.5): 30-day grace period, password
/// confirmation (or typed DELETE for passwordless Google accounts) and a
/// bottom-sheet confirmation.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _passwordless = false;
  bool _deleting = false;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (!_form.currentState!.validate()) return;
    final l10n = context.l10n;
    final ok = await showConfirmSheet(
      context,
      title: l10n.deleteConfirmTitle,
      message: l10n.deleteConfirmMessage,
      confirmLabel: l10n.deleteSubmit,
    );
    if (!ok || !mounted) return;
    setState(() => _deleting = true);
    try {
      await ref
          .read(accountActionsProvider)
          .deleteAccount(password: _passwordless ? null : _password.text);
      if (!mounted) return;
      showToast(context, l10n.deleteDone, type: ToastType.info);
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: MeepleAppBar(
        title: l10n.settingsDeleteAccount,
        showBackButton: true,
        fallbackRoute: AppRoutes.settings,
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: const BoxDecoration(
                color: AppColors.errorContainer,
                borderRadius: AppSpacing.borderRadiusXl,
              ),
              child: Text(
                l10n.deleteWarning,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.onErrorContainer,
                ),
              ),
            ),
            AppSpacing.vGapLg,
            SwitchListTile(
              key: const Key('delete-passwordless'),
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.deletePasswordless),
              value: _passwordless,
              onChanged: (v) => setState(() => _passwordless = v),
            ),
            if (_passwordless)
              TextFormField(
                key: const Key('delete-confirm'),
                controller: _confirm,
                decoration: InputDecoration(labelText: l10n.deleteTypeConfirm),
                validator: (v) =>
                    v?.trim() == 'DELETE' ? null : l10n.deleteTypeConfirmError,
              )
            else
              AuthTextField(
                key: const Key('delete-password'),
                label: l10n.authPassword,
                controller: _password,
                isPassword: true,
                textInputAction: TextInputAction.done,
                prefixIcon: Icons.lock_outline_rounded,
                validator: (v) =>
                    (v ?? '').isEmpty ? l10n.authPasswordRequired : null,
              ),
            AppSpacing.vGapXl,
            FilledButton(
              key: const Key('delete-submit'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: AppColors.onError,
                minimumSize: const Size.fromHeight(52),
                shape: const StadiumBorder(),
              ),
              onPressed: _deleting ? null : _delete,
              child: _deleting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.deleteSubmit),
            ),
          ],
        ),
      ),
    );
  }
}
