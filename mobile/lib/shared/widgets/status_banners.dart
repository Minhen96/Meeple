import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/core/network/connectivity_service.dart';
import 'package:meeple_hearth/core/utils/app_date_utils.dart';
import 'package:meeple_hearth/l10n/l10n.dart';

/// Slim "No internet connection" bar (SCREENS §14.4) with a brief
/// "Back online" flash when the connection returns.
class OfflineBanner extends ConsumerStatefulWidget {
  const OfflineBanner({super.key});

  @override
  ConsumerState<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends ConsumerState<OfflineBanner> {
  bool _showBackOnline = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(isOfflineProvider, (previous, next) {
      if (previous == true && !next) {
        setState(() => _showBackOnline = true);
        _timer?.cancel();
        _timer = Timer(const Duration(seconds: 2), () {
          if (mounted) setState(() => _showBackOnline = false);
        });
      }
    });
    final offline = ref.watch(isOfflineProvider);
    final l10n = context.l10n;
    final visible = offline || _showBackOnline;
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      child: !visible
          ? const SizedBox(width: double.infinity)
          : ColoredBox(
              color: offline ? AppColors.onSurface : AppColors.tertiary,
              child: SafeArea(
                bottom: false,
                child: SizedBox(
                  height: 32,
                  width: double.infinity,
                  child: Center(
                    child: Text(
                      offline ? l10n.offlineBanner : l10n.backOnline,
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.inverseOnSurface,
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

/// "Showing cached data from X" (MOBILE_FLUTTER §6) for reads served from
/// the offline cache.
class StaleDataBanner extends StatelessWidget {
  const StaleDataBanner({super.key, required this.cachedAt});

  final DateTime cachedAt;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: const BoxDecoration(
        color: AppColors.secondaryContainer,
        borderRadius: AppSpacing.borderRadiusLg,
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 16,
            color: AppColors.onSecondaryContainer,
          ),
          AppSpacing.hGapSm,
          Expanded(
            child: Text(
              l10n.staleData(AppDateUtils.timeAgo(cachedAt, l10n)),
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Footer for infinite lists: spinner while loading more, "all caught up"
/// when exhausted, retry on error.
class ListFooter extends StatelessWidget {
  const ListFooter({
    super.key,
    required this.isLoading,
    required this.hasMore,
    this.error,
    this.onRetry,
    this.endLabel,
  });

  final bool isLoading;
  final bool hasMore;
  final Object? error;
  final VoidCallback? onRetry;
  final String? endLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    Widget child;
    if (error != null) {
      child = TextButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded),
        label: Text(l10n.commonRetry),
      );
    } else if (isLoading || hasMore) {
      child = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          AppSpacing.hGapSm,
          Text(l10n.loadingMore, style: AppTypography.bodySmall),
        ],
      );
    } else {
      child = Text(
        endLabel ?? l10n.allCaughtUp,
        style: AppTypography.bodySmall,
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Center(child: child),
    );
  }
}

/// Section title used on scrolling pages.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(child: Text(title, style: AppTypography.titleLarge)),
          if (actionLabel != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}
