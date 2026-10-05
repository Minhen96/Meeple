import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/core/security/biometric_service.dart';
import 'package:meeple_hearth/features/auth/providers/auth_provider.dart';
import 'package:meeple_hearth/l10n/l10n.dart';
import 'package:meeple_hearth/shared/widgets/app_button.dart';

/// Optional biometric app lock (docs/MOBILE_FLUTTER.md §12).
///
/// When enabled in Settings and a user is signed in, the app is covered on
/// launch and after [relockAfter] in the background until the user passes
/// device authentication (biometrics or device PIN).
class AppLock extends ConsumerStatefulWidget {
  const AppLock({super.key, required this.child});

  final Widget child;

  static const relockAfter = Duration(seconds: 30);

  @override
  ConsumerState<AppLock> createState() => _AppLockState();
}

class _AppLockState extends ConsumerState<AppLock> with WidgetsBindingObserver {
  bool _locked = true;
  bool _authenticating = false;
  DateTime? _backgroundedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _backgroundedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final since = _backgroundedAt;
      _backgroundedAt = null;
      if (since != null &&
          DateTime.now().difference(since) > AppLock.relockAfter) {
        setState(() => _locked = true);
      }
    }
  }

  Future<void> _unlock() async {
    if (_authenticating) return;
    setState(() => _authenticating = true);
    final ok = await ref
        .read(deviceAuthenticatorProvider)
        .authenticate(context.l10n.biometricReasonUnlock);
    if (!mounted) return;
    setState(() {
      _authenticating = false;
      if (ok) _locked = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Switching the lock on in Settings must not lock the running session.
    ref.listen<AsyncValue<bool>>(biometricLockProvider, (previous, next) {
      if (previous?.valueOrNull == false && next.valueOrNull == true) {
        setState(() => _locked = false);
      }
    });
    final enabled = ref.watch(biometricLockProvider).valueOrNull ?? false;
    final signedIn = ref.watch(authNotifierProvider).valueOrNull != null;
    if (!enabled || !signedIn || !_locked) {
      return widget.child;
    }
    final l10n = context.l10n;
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: Material(
            color: AppColors.background,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.lock_rounded,
                      size: 56,
                      color: AppColors.primary,
                    ),
                    AppSpacing.vGapLg,
                    Text(
                      l10n.appLockedTitle,
                      style: AppTypography.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    AppSpacing.vGapSm,
                    Text(
                      l10n.appLockedBody,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    AppSpacing.vGapXl,
                    AppButton(
                      key: const Key('app-lock-unlock'),
                      label: l10n.appLockedUnlock,
                      icon: Icons.fingerprint_rounded,
                      isLoading: _authenticating,
                      onPressed: _unlock,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
