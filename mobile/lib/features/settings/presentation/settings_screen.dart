import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meeple_hearth/core/config/app_config.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/core/constants/text_style_weight.dart';
import 'package:meeple_hearth/core/locale/locale_provider.dart';
import 'package:meeple_hearth/core/router/app_router.dart';
import 'package:meeple_hearth/core/security/biometric_service.dart';
import 'package:meeple_hearth/core/storage/cache_store.dart';
import 'package:meeple_hearth/features/auth/providers/auth_provider.dart';
import 'package:meeple_hearth/features/settings/presentation/widgets/settings_widgets.dart';
import 'package:meeple_hearth/features/settings/providers/settings_provider.dart';
import 'package:meeple_hearth/l10n/l10n.dart';
import 'package:meeple_hearth/shared/widgets/app_card.dart';
import 'package:meeple_hearth/shared/widgets/app_toast.dart';
import 'package:meeple_hearth/shared/widgets/confirm_sheet.dart';
import 'package:meeple_hearth/shared/widgets/meeple_app_bar.dart';
import 'package:url_launcher/url_launcher.dart';

/// App version shown under About (keep in step with pubspec `version`).
const appVersion = '1.0.0';

/// Settings root (SCREENS §11.1) — the web `SettingsMenu`: uppercase
/// section labels over groups of white rounded rows, Language / Appearance
/// segmented choices and a red "Log Out" row. Mobile adds Blocked users,
/// Biometric lock and Clear cache in the same style.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _open(String url) =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  Future<void> _setBiometric(
    BuildContext context,
    WidgetRef ref,
    bool enabled,
  ) async {
    final l10n = context.l10n;
    final ok = await ref.read(biometricLockProvider.notifier).setEnabled(
          enabled: enabled,
          reason: l10n.biometricReasonEnable,
        );
    if (!ok && context.mounted) {
      showToast(
        context,
        l10n.settingsBiometricUnavailable,
        type: ToastType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final language = ref.watch(appLocaleProvider);
    final biometric = ref.watch(biometricLockProvider).valueOrNull ?? false;
    // Changing the email needs the current password, which Google-only
    // accounts do not have.
    final hasPassword =
        ref.watch(authNotifierProvider).valueOrNull?.hasPassword ?? true;
    const external = Icon(
      Icons.open_in_new_rounded,
      size: 16,
      color: AppColors.onSurfaceVariant,
    );
    Widget detail(String text) => Text(
          text,
          style: AppTypography.bodySmall
              .copyWith(color: AppColors.onSurfaceVariant),
        );
    return Scaffold(
      appBar: MeepleAppBar(
        title: l10n.settingsTitle,
        showBackButton: true,
        fallbackRoute: AppRoutes.profile,
      ),
      body: ListView(
        padding: settingsPagePadding,
        children: [
          AppTileGroup(
            label: l10n.settingsAccount,
            children: [
              _Item(
                Icons.person_outline_rounded,
                l10n.settingsEditProfile,
                route: AppRoutes.editProfile,
              ),
              if (hasPassword)
                _Item(
                  Icons.alternate_email_rounded,
                  l10n.settingsChangeEmail,
                  route: AppRoutes.changeEmail,
                ),
              _Item(
                Icons.lock_outline_rounded,
                l10n.settingsChangePassword,
                route: AppRoutes.changePassword,
              ),
              _Item(
                Icons.cloud_download_outlined,
                l10n.settingsBggImport,
                route: AppRoutes.bggImport,
              ),
              _Item(
                Icons.devices_outlined,
                l10n.settingsSessions,
                route: AppRoutes.sessions,
              ),
              _Item(
                Icons.download_rounded,
                l10n.settingsExport,
                onTap: () async {
                  try {
                    await ref.read(accountActionsProvider).requestExport();
                    if (context.mounted) {
                      showToast(
                        context,
                        l10n.settingsExportRequested,
                        type: ToastType.success,
                      );
                    }
                  } catch (e) {
                    if (context.mounted) showErrorToast(context, e);
                  }
                },
              ),
              _Item(
                Icons.delete_outline_rounded,
                l10n.settingsDeleteAccount,
                route: AppRoutes.deleteAccount,
                destructive: true,
              ),
            ],
          ),
          AppSpacing.vGapXl,
          AppTileGroup(
            label: l10n.settingsNotifications,
            children: [
              _Item(
                Icons.notifications_none_rounded,
                l10n.notificationPrefsTitle,
                route: AppRoutes.notificationPrefs,
              ),
              _Item(
                Icons.bedtime_outlined,
                l10n.settingsQuietHours,
                keyName: 'quiet-hours',
                route: AppRoutes.notificationPrefs,
              ),
            ],
          ),
          AppSpacing.vGapXl,
          AppTileGroup(
            label: l10n.settingsPrivacy,
            children: [
              _Item(
                Icons.block_rounded,
                l10n.blockedTitle,
                route: AppRoutes.blockedUsers,
              ),
              AppTile(
                icon: Icons.shield_outlined,
                title: l10n.settingsPrivacySettings,
                trailing: detail(l10n.settingsComingSoon),
              ),
            ],
          ),
          AppSpacing.vGapXl,
          AppTileGroup(
            label: l10n.settingsSecurity,
            children: [
              AppTile(
                key: const Key('biometric-toggle'),
                icon: Icons.fingerprint_rounded,
                title: l10n.settingsBiometric,
                subtitle: l10n.settingsBiometricBody,
                onTap: () => _setBiometric(context, ref, !biometric),
                trailing: Switch(
                  value: biometric,
                  onChanged: (v) => _setBiometric(context, ref, v),
                ),
              ),
            ],
          ),
          AppSpacing.vGapXl,
          SectionLabel(l10n.settingsLanguage),
          SettingsSegmented<AppLanguage>(
            key: const Key('language-setting'),
            options: [
              for (final lang in AppLanguage.values)
                (lang, _languageName(lang)),
            ],
            selected: language,
            keyFor: (lang) => ValueKey('language-${lang.wire}'),
            onSelected: (lang) =>
                ref.read(appLocaleProvider.notifier).select(lang),
          ),
          AppSpacing.vGapXl,
          SectionLabel(l10n.settingsAppearance),
          SettingsSegmented<int>(
            options: [
              (0, l10n.settingsThemeLight),
              (1, l10n.settingsThemeDark),
              (2, l10n.settingsThemeSystem),
            ],
            selected: 0,
            enabled: (i) => i == 0,
            onSelected: null,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, AppSpacing.sm, 4, 0),
            child: detail(l10n.settingsThemeHint),
          ),
          AppSpacing.vGapXl,
          AppTileGroup(
            label: l10n.settingsAbout,
            children: [
              AppTile(
                icon: Icons.info_outline_rounded,
                title: l10n.settingsVersion,
                trailing: detail(appVersion),
              ),
              AppTile(
                icon: Icons.gavel_rounded,
                title: l10n.settingsTerms,
                trailing: external,
                onTap: () => _open('${AppConfig.webOrigin}/terms'),
              ),
              AppTile(
                icon: Icons.policy_outlined,
                title: l10n.settingsPrivacyPolicy,
                trailing: external,
                onTap: () => _open('${AppConfig.webOrigin}/privacy'),
              ),
              AppTile(
                icon: Icons.feedback_outlined,
                title: l10n.settingsFeedback,
                trailing: external,
                onTap: () => launchUrl(
                  Uri.parse('mailto:feedback@meeple-hearth.com'),
                ),
              ),
              _Item(
                Icons.cleaning_services_outlined,
                l10n.settingsClearCache,
                onTap: () async {
                  await ref.read(cacheStoreProvider).clear();
                  if (context.mounted) {
                    showToast(
                      context,
                      l10n.settingsCacheCleared,
                      type: ToastType.success,
                    );
                  }
                },
              ),
            ],
          ),
          AppSpacing.vGapXl,
          Material(
            color: AppColors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.panel),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: const Key('settings-sign-out'),
              onTap: () async {
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
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  l10n.settingsSignOut,
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium
                      .weight(FontWeight.w600)
                      .copyWith(color: AppColors.error),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Language names are shown in their own language (web `LANGUAGE_NAMES`).
String _languageName(AppLanguage lang) => switch (lang) {
      AppLanguage.en => 'English',
      AppLanguage.zhCN => '中文',
    };

class _Item extends StatelessWidget {
  const _Item(
    this.icon,
    this.label, {
    this.route,
    this.onTap,
    this.destructive = false,
    this.keyName,
  });

  final IconData icon;
  final String label;
  final String? route;
  final VoidCallback? onTap;
  final bool destructive;
  final String? keyName;

  @override
  Widget build(BuildContext context) {
    return AppTile(
      key: keyName != null
          ? ValueKey('settings-$keyName')
          : route == null
              ? null
              : ValueKey('settings-$route'),
      icon: icon,
      title: label,
      danger: destructive,
      onTap: onTap ?? () => context.push(route!),
    );
  }
}
