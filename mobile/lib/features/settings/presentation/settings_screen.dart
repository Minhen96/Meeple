import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meeple_hearth/core/config/app_config.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/core/locale/locale_provider.dart';
import 'package:meeple_hearth/core/router/app_router.dart';
import 'package:meeple_hearth/core/security/biometric_service.dart';
import 'package:meeple_hearth/core/storage/cache_store.dart';
import 'package:meeple_hearth/features/auth/providers/auth_provider.dart';
import 'package:meeple_hearth/features/settings/providers/settings_provider.dart';
import 'package:meeple_hearth/l10n/l10n.dart';
import 'package:meeple_hearth/shared/widgets/app_toast.dart';
import 'package:meeple_hearth/shared/widgets/confirm_sheet.dart';
import 'package:meeple_hearth/shared/widgets/meeple_app_bar.dart';
import 'package:url_launcher/url_launcher.dart';

/// App version shown under About (keep in step with pubspec `version`).
const appVersion = '1.0.0';

/// Settings root (SCREENS §11.1).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _open(String url) =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final language = ref.watch(appLocaleProvider);
    final biometric = ref.watch(biometricLockProvider).valueOrNull ?? false;
    // Changing the email needs the current password, which Google-only
    // accounts do not have.
    final hasPassword =
        ref.watch(authNotifierProvider).valueOrNull?.hasPassword ?? true;
    return Scaffold(
      appBar: MeepleAppBar(
        title: l10n.settingsTitle,
        showBackButton: true,
        fallbackRoute: AppRoutes.profile,
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
        children: [
          _Section(l10n.settingsAccount),
          _Item(Icons.person_outline_rounded, l10n.settingsEditProfile,
              route: AppRoutes.editProfile),
          if (hasPassword)
            _Item(Icons.alternate_email_rounded, l10n.settingsChangeEmail,
                route: AppRoutes.changeEmail),
          _Item(Icons.password_rounded, l10n.settingsChangePassword,
              route: AppRoutes.changePassword),
          _Item(Icons.cloud_download_outlined, l10n.settingsBggImport,
              route: AppRoutes.bggImport),
          _Item(Icons.devices_outlined, l10n.settingsSessions,
              route: AppRoutes.sessions),
          _Item(Icons.block_rounded, l10n.blockedTitle,
              route: AppRoutes.blockedUsers),
          _Item(
            Icons.download_outlined,
            l10n.settingsExport,
            onTap: () async {
              try {
                await ref.read(accountActionsProvider).requestExport();
                if (context.mounted) {
                  showToast(context, l10n.settingsExportRequested,
                      type: ToastType.success);
                }
              } catch (e) {
                if (context.mounted) showErrorToast(context, e);
              }
            },
          ),
          _Item(Icons.delete_forever_outlined, l10n.settingsDeleteAccount,
              route: AppRoutes.deleteAccount, destructive: true),
          _Section(l10n.settingsNotifications),
          _Item(Icons.notifications_outlined, l10n.notificationPrefsTitle,
              route: AppRoutes.notificationPrefs),
          _Section(l10n.settingsSecurity),
          SwitchListTile(
            key: const Key('biometric-toggle'),
            secondary: const Icon(Icons.fingerprint_rounded),
            title: Text(l10n.settingsBiometric),
            subtitle: Text(l10n.settingsBiometricBody),
            value: biometric,
            onChanged: (v) async {
              final ok = await ref.read(biometricLockProvider.notifier).setEnabled(
                    enabled: v,
                    reason: l10n.biometricReasonEnable,
                  );
              if (!ok && context.mounted) {
                showToast(context, l10n.settingsBiometricUnavailable,
                    type: ToastType.error);
              }
            },
          ),
          _Section(l10n.settingsAppearance),
          ListTile(
            key: const Key('language-setting'),
            leading: const Icon(Icons.translate_rounded),
            title: Text(l10n.settingsLanguage),
            subtitle: Text(_languageName(l10n, language)),
            onTap: () => _pickLanguage(context, ref, language),
          ),
          ListTile(
            enabled: false,
            leading: const Icon(Icons.dark_mode_outlined),
            title: Text(l10n.settingsTheme),
            subtitle: Text(l10n.settingsThemeLight),
          ),
          _Section(l10n.settingsPrivacy),
          ListTile(
            enabled: false,
            leading: const Icon(Icons.lock_outline_rounded),
            title: Text(l10n.settingsPrivacySettings),
            subtitle: Text(l10n.settingsComingSoon),
          ),
          _Section(l10n.settingsAbout),
          ListTile(
            leading: const Icon(Icons.info_outline_rounded),
            title: Text(l10n.settingsVersion),
            trailing: const Text(appVersion),
          ),
          _Item(Icons.description_outlined, l10n.settingsTerms,
              onTap: () => _open('${AppConfig.webOrigin}/terms')),
          _Item(Icons.privacy_tip_outlined, l10n.settingsPrivacyPolicy,
              onTap: () => _open('${AppConfig.webOrigin}/privacy')),
          _Item(Icons.mail_outline_rounded, l10n.settingsFeedback,
              onTap: () => launchUrl(
                    Uri.parse('mailto:feedback@meeple-hearth.com'),
                  )),
          _Item(
            Icons.cleaning_services_outlined,
            l10n.settingsClearCache,
            onTap: () async {
              await ref.read(cacheStoreProvider).clear();
              if (context.mounted) {
                showToast(context, l10n.settingsCacheCleared,
                    type: ToastType.success);
              }
            },
          ),
          AppSpacing.vGapLg,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: OutlinedButton.icon(
              key: const Key('settings-sign-out'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                minimumSize: const Size.fromHeight(48),
                shape: const StadiumBorder(),
              ),
              onPressed: () async {
                final ok = await showConfirmSheet(
                  context,
                  title: l10n.settingsSignOutTitle,
                  message: l10n.settingsSignOutMessage,
                  confirmLabel: l10n.settingsSignOut,
                  destructive: false,
                  icon: Icons.logout_rounded,
                );
                if (ok) await ref.read(authNotifierProvider.notifier).logout();
              },
              icon: const Icon(Icons.logout_rounded),
              label: Text(l10n.settingsSignOut),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickLanguage(
    BuildContext context,
    WidgetRef ref,
    AppLanguage current,
  ) async {
    final l10n = context.l10n;
    final picked = await showModalBottomSheet<AppLanguage>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.surfaceContainerLowest,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final lang in AppLanguage.values)
              ListTile(
                key: ValueKey('language-${lang.wire}'),
                title: Text(_languageName(l10n, lang)),
                trailing: lang == current
                    ? const Icon(Icons.check_rounded, color: AppColors.primary)
                    : null,
                onTap: () => Navigator.of(sheet).pop(lang),
              ),
          ],
        ),
      ),
    );
    if (picked != null && picked != current) {
      await ref.read(appLocaleProvider.notifier).select(picked);
    }
  }
}

/// Language names are shown in their own language.
String _languageName(AppLocalizations l10n, AppLanguage lang) => switch (lang) {
      AppLanguage.en => 'English',
      AppLanguage.zhCN => '简体中文',
    };

class _Section extends StatelessWidget {
  const _Section(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.xl,
          AppSpacing.lg,
          AppSpacing.xs,
        ),
        child: Text(title.toUpperCase(), style: AppTypography.labelMedium),
      );
}

class _Item extends StatelessWidget {
  const _Item(
    this.icon,
    this.label, {
    this.route,
    this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final String? route;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.error : null;
    return ListTile(
      key: route == null ? null : ValueKey('settings-$route'),
      leading: Icon(icon, color: color),
      title: Text(label, style: TextStyle(color: color)),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap ?? () => context.push(route!),
    );
  }
}
