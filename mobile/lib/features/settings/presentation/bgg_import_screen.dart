import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/core/router/app_router.dart';
import 'package:meeple_hearth/features/auth/providers/auth_provider.dart';
import 'package:meeple_hearth/features/library/domain/user_game_model.dart';
import 'package:meeple_hearth/features/library/providers/library_provider.dart';
import 'package:meeple_hearth/l10n/l10n.dart';
import 'package:meeple_hearth/shared/widgets/app_button.dart';
import 'package:meeple_hearth/shared/widgets/meeple_app_bar.dart';

/// BGG import form + live progress (shared by Settings and onboarding).
class BggImportPanel extends ConsumerStatefulWidget {
  const BggImportPanel({super.key, this.onDone});

  /// Shown as a "Continue" action once the import finished (onboarding).
  final VoidCallback? onDone;

  @override
  ConsumerState<BggImportPanel> createState() => _BggImportPanelState();
}

class _BggImportPanelState extends ConsumerState<BggImportPanel> {
  late final _username = TextEditingController(
    text: ref.read(authNotifierProvider).valueOrNull?.bggUsername ?? '',
  );

  @override
  void dispose() {
    _username.dispose();
    super.dispose();
  }

  String? _errorText(AppLocalizations l10n, BggImportStatus s) =>
      switch (s.errorCode) {
        'BGG_USER_NOT_FOUND' => l10n.errorBggUserNotFound,
        'BGG_API_UNAVAILABLE' => l10n.errorBggUnavailable,
        null => s.isFailed ? l10n.bggImportFailed : null,
        _ => l10n.bggImportFailed,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final import = ref.watch(bggImportProvider);
    final status = import.valueOrNull ?? const BggImportStatus();
    final running = status.isRunning;
    final error = import.hasError
        ? localizedError(l10n, import.error!)
        : _errorText(l10n, status);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.bggImportTitle, style: AppTypography.headlineSmall),
        AppSpacing.vGapSm,
        Text(l10n.bggImportBody, style: AppTypography.bodyMedium),
        AppSpacing.vGapLg,
        TextField(
          key: const Key('bgg-username'),
          controller: _username,
          enabled: !running,
          decoration: InputDecoration(
            labelText: l10n.bggUsername,
            prefixIcon: const Icon(Icons.person_search_outlined),
            errorText: error,
          ),
        ),
        AppSpacing.vGapSm,
        Text(l10n.bggPrivacyNote, style: AppTypography.bodySmall),
        AppSpacing.vGapLg,
        if (running) ...[
          LinearProgressIndicator(
            value: status.total > 0 ? status.processed / status.total : null,
          ),
          AppSpacing.vGapSm,
          Text(
            status.total > 0
                ? l10n.bggImportProgress(status.processed, status.total)
                : l10n.bggImportStarting,
            style: AppTypography.bodyMedium,
          ),
        ] else if (status.isDone) ...[
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: const BoxDecoration(
              color: AppColors.successContainer,
              borderRadius: AppSpacing.borderRadiusXl,
            ),
            child: Text(
              l10n.bggImportDone(status.imported, status.skipped, status.failed),
              key: const Key('bgg-done'),
              style: AppTypography.titleSmall.copyWith(
                color: AppColors.onSuccessContainer,
              ),
            ),
          ),
          if (widget.onDone != null) ...[
            AppSpacing.vGapLg,
            AppButton(label: l10n.commonContinue, onPressed: widget.onDone),
          ],
        ],
        if (!running) ...[
          AppSpacing.vGapLg,
          AppButton(
            key: const Key('bgg-import'),
            label: l10n.bggImportStart,
            onPressed: () {
              final name = _username.text.trim();
              if (name.isEmpty) return;
              ref.read(bggImportProvider.notifier).start(name);
            },
          ),
        ],
      ],
    );
  }
}

class BggImportScreen extends StatelessWidget {
  const BggImportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MeepleAppBar(
        title: context.l10n.settingsBggImport,
        showBackButton: true,
        fallbackRoute: AppRoutes.settings,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: const [BggImportPanel()],
      ),
    );
  }
}
