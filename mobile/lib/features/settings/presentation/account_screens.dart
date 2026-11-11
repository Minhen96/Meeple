import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/core/constants/text_style_weight.dart';
import 'package:meeple_hearth/core/router/app_router.dart';
import 'package:meeple_hearth/core/utils/app_date_utils.dart';
import 'package:meeple_hearth/features/auth/domain/user_model.dart';
import 'package:meeple_hearth/features/auth/providers/auth_provider.dart';
import 'package:meeple_hearth/features/settings/presentation/widgets/settings_widgets.dart';
import 'package:meeple_hearth/features/settings/providers/settings_provider.dart';
import 'package:meeple_hearth/l10n/l10n.dart';
import 'package:meeple_hearth/shared/widgets/app_button.dart';
import 'package:meeple_hearth/shared/widgets/app_toast.dart';
import 'package:meeple_hearth/shared/widgets/confirm_sheet.dart';
import 'package:meeple_hearth/shared/widgets/error_state.dart';
import 'package:meeple_hearth/shared/widgets/meeple_app_bar.dart';
import 'package:meeple_hearth/shared/widgets/skeleton_widget.dart';

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Header of every settings sub-page (web `PageHeader`: 20px title).
PreferredSizeWidget settingsSubPageBar(String title) => MeepleAppBar(
      title: title,
      showBackButton: true,
      compactTitle: true,
      fallbackRoute: AppRoutes.settings,
    );

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
    final user = ref.watch(authNotifierProvider).valueOrNull;
    final current = user?.email;
    return Scaffold(
      appBar: settingsSubPageBar(l10n.settingsChangeEmail),
      body: Form(
        key: _form,
        child: ListView(
          padding: settingsPagePadding,
          children: [
            if (current != null && current.isNotEmpty) ...[
              SettingsNote(l10n.changeEmailCurrent(current)),
              AppSpacing.vGapXl,
            ],
            if (user?.hasPassword == false)
              SettingsInfoPanel(l10n.changeEmailGoogleOnly)
            else if (_sent)
              SettingsSentState(
                title: l10n.changeEmailSentTitle,
                body: l10n.changeEmailSentBody(_email.text.trim()),
              )
            else ...[
              SettingsField(
                fieldKey: const Key('change-email-new'),
                label: l10n.changeEmailNew,
                controller: _email,
                onChanged: (_) => setState(() {}),
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                validator: (v) => _emailPattern.hasMatch((v ?? '').trim())
                    ? null
                    : l10n.authInvalidEmail,
              ),
              AppSpacing.vGapLg,
              SettingsField(
                fieldKey: const Key('change-email-password'),
                label: l10n.changeEmailCurrentPassword,
                controller: _password,
                onChanged: (_) => setState(() {}),
                isPassword: true,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                validator: (v) =>
                    (v ?? '').isEmpty ? l10n.authPasswordRequired : null,
              ),
              AppSpacing.vGapLg,
              AppButton(
                key: const Key('change-email-submit'),
                label: l10n.changeEmailSubmit,
                isLoading: _saving,
                onPressed: _email.text.trim().isEmpty || _password.text.isEmpty
                    ? null
                    : _submit,
              ),
            ],
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
      appBar: settingsSubPageBar(l10n.settingsChangePassword),
      body: ListView(
        padding: settingsPagePadding,
        children: _sent
            ? [
                SettingsSentState(
                  title: l10n.changePasswordSentTitle,
                  body: l10n.changePasswordSentBody,
                ),
              ]
            : [
                SettingsNote(
                  email == null
                      ? l10n.changePasswordNoEmail
                      : l10n.changePasswordBody(email),
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
    );
  }
}

/// Active sessions (SCREENS §11.4).
class ActiveSessionsScreen extends ConsumerWidget {
  const ActiveSessionsScreen({super.key});

  Future<void> _revokeOthers(
    BuildContext context,
    WidgetRef ref,
    int count,
  ) async {
    final l10n = context.l10n;
    final ok = await showConfirmSheet(
      context,
      title: l10n.sessionsConfirmTitle,
      message: l10n.sessionsConfirmBody(count),
      confirmLabel: l10n.sessionsRevokeOthers,
      icon: Icons.devices_outlined,
    );
    if (!ok) return;
    try {
      await ref.read(activeSessionsProvider.notifier).revokeOthers();
      if (context.mounted) {
        showToast(context, l10n.sessionsOthersSignedOut,
            type: ToastType.success);
      }
    } catch (e) {
      if (!context.mounted) return;
      ActiveSessions.isSessionInvalid(e)
          ? showToast(context, l10n.sessionsInvalid, type: ToastType.error)
          : showErrorToast(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final sessions = ref.watch(activeSessionsProvider);
    return Scaffold(
      appBar: settingsSubPageBar(l10n.settingsSessions),
      body: sessions.when(
        loading: () => ListView(
          padding: settingsPagePadding,
          children: [
            for (var i = 0; i < 3; i++) ...[
              const SkeletonBox(
                height: 72,
                borderRadius: AppSpacing.borderRadiusLg,
              ),
              AppSpacing.vGapSm,
            ],
          ],
        ),
        error: (e, _) => ErrorState(
          error: e,
          onRetry: () => ref.invalidate(activeSessionsProvider),
        ),
        data: (list) {
          final others = list.where((s) => !s.current).length;
          return ListView(
            padding: settingsPagePadding,
            children: [
              for (final s in list) ...[
                _SessionTile(session: s),
                AppSpacing.vGapSm,
              ],
              if (others > 0) ...[
                AppSpacing.vGapLg,
                AppButton(
                  key: const Key('revoke-others'),
                  label: l10n.sessionsRevokeOthers,
                  variant: AppButtonVariant.secondary,
                  onPressed: () => _revokeOthers(context, ref, others),
                ),
              ],
            ],
          );
        },
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
    final info = (s.deviceInfo == null || s.deviceInfo!.isEmpty)
        ? l10n.sessionsUnknownDevice
        : s.deviceInfo!;
    final mobile =
        RegExp('android|iphone|ios|mobile|dart', caseSensitive: false)
            .hasMatch(info);
    return Container(
      key: ValueKey('session-${s.id}'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: AppSpacing.borderRadiusLg,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.secondaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              mobile ? Icons.smartphone_rounded : Icons.computer_rounded,
              size: 20,
              color: AppColors.onSecondaryContainer,
            ),
          ),
          AppSpacing.hGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        info,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleSmall,
                      ),
                    ),
                    if (s.current) ...[
                      AppSpacing.hGapSm,
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 2,
                        ),
                        decoration: const BoxDecoration(
                          color: AppColors.tertiaryContainer,
                          borderRadius: AppSpacing.borderRadiusFull,
                        ),
                        child: Text(
                          l10n.sessionsThisDevice.toUpperCase(),
                          style: AppTypography.labelSmall
                              .weight(FontWeight.w700)
                              .copyWith(
                                letterSpacing: 0.5,
                                color: AppColors.onTertiaryContainer,
                              ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (s.lastUsedAt != null)
                  Text(
                    l10n.sessionsLastActive(
                      AppDateUtils.timeAgo(s.lastUsedAt!, l10n),
                    ),
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
              textStyle: AppTypography.bodySmall.weight(FontWeight.w700),
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              minimumSize: Size.zero,
            ),
            onPressed: s.current
                ? null
                : () async {
                    try {
                      await ref
                          .read(activeSessionsProvider.notifier)
                          .revoke(s.id);
                      if (context.mounted) {
                        showToast(context, l10n.sessionsSignedOut,
                            type: ToastType.success);
                      }
                    } catch (e) {
                      if (context.mounted) showErrorToast(context, e);
                    }
                  },
            child: Text(l10n.sessionsSignOut),
          ),
        ],
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

  /// Whether the account has a password, from `GET /users/me`; null when
  /// unknown, in which case the user picks the confirmation method.
  bool? get _hasPassword =>
      ref.read(authNotifierProvider).valueOrNull?.hasPassword;

  /// The user's pick when [_hasPassword] is unknown.
  bool _passwordlessChoice = false;

  bool get _passwordless =>
      _hasPassword == false || (_hasPassword == null && _passwordlessChoice);
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
      confirmLabel: l10n.settingsDeleteAccount,
      icon: Icons.person_remove_outlined,
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
    ref.watch(authNotifierProvider);
    final ready = _passwordless
        ? _confirm.text.trim() == 'DELETE'
        : _password.text.isNotEmpty;
    final bullet =
        AppTypography.bodyMedium.copyWith(color: AppColors.onSurfaceVariant);
    return Scaffold(
      appBar: settingsSubPageBar(l10n.settingsDeleteAccount),
      body: Form(
        key: _form,
        child: ListView(
          padding: settingsPagePadding,
          children: [
            Container(
              key: const Key('delete-warning'),
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.deleteWarningTitle,
                    style: AppTypography.bodyMedium
                        .weight(FontWeight.w600)
                        .copyWith(color: AppColors.error),
                  ),
                  AppSpacing.vGapSm,
                  for (final line in [
                    l10n.deleteConsequenceGrace,
                    l10n.deleteConsequenceImmediate,
                    l10n.deleteConsequencePermanent,
                  ])
                    Padding(
                      padding: const EdgeInsets.only(
                        left: AppSpacing.xs,
                        bottom: AppSpacing.xs,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('•  ', style: bullet),
                          Expanded(child: Text(line, style: bullet)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            AppSpacing.vGapXl,
            if (_hasPassword == null) ...[
              AppTileGroupSwitch(
                key: const Key('delete-passwordless'),
                title: l10n.deletePasswordless,
                value: _passwordless,
                onChanged: (v) => setState(() => _passwordlessChoice = v),
              ),
              AppSpacing.vGapLg,
            ],
            if (_passwordless)
              SettingsField(
                fieldKey: const Key('delete-confirm'),
                label: l10n.deleteTypeConfirm,
                hint: 'DELETE',
                controller: _confirm,
                onChanged: (_) => setState(() {}),
                danger: true,
                textCapitalization: TextCapitalization.characters,
                validator: (v) =>
                    v?.trim() == 'DELETE' ? null : l10n.deleteTypeConfirmError,
              )
            else
              SettingsField(
                fieldKey: const Key('delete-password'),
                label: l10n.deletePasswordLabel,
                controller: _password,
                onChanged: (_) => setState(() {}),
                isPassword: true,
                danger: true,
                textInputAction: TextInputAction.done,
                validator: (v) =>
                    (v ?? '').isEmpty ? l10n.authPasswordRequired : null,
              ),
            AppSpacing.vGapLg,
            AppButton(
              key: const Key('delete-submit'),
              label: l10n.deleteSubmit,
              variant: AppButtonVariant.danger,
              isLoading: _deleting,
              onPressed: _deleting || !ready ? null : _delete,
            ),
          ],
        ),
      ),
    );
  }
}

/// A white rounded row with a trailing switch (settings style).
class AppTileGroupSwitch extends StatelessWidget {
  const AppTileGroupSwitch({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        clipBehavior: Clip.antiAlias,
        child: SwitchListTile(
          title: Text(title, style: AppTypography.bodyMedium),
          value: value,
          onChanged: onChanged,
        ),
      );
}
