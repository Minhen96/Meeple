import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/core/router/app_router.dart';
import 'package:meeple_hearth/features/auth/providers/auth_provider.dart';
import 'package:meeple_hearth/features/onboarding/presentation/onboarding_scaffold.dart';
import 'package:meeple_hearth/features/profile/data/user_repository.dart';
import 'package:meeple_hearth/features/profile/presentation/widgets/avatar_picker.dart';
import 'package:meeple_hearth/features/profile/providers/profile_provider.dart';
import 'package:meeple_hearth/features/settings/presentation/widgets/settings_widgets.dart';
import 'package:meeple_hearth/l10n/l10n.dart';
import 'package:meeple_hearth/shared/widgets/app_button.dart';
import 'package:meeple_hearth/shared/widgets/app_toast.dart';

/// Onboarding step 2 (SCREENS §3.3): avatar, display name, location.
class OnboardingProfileScreen extends ConsumerStatefulWidget {
  const OnboardingProfileScreen({super.key});

  @override
  ConsumerState<OnboardingProfileScreen> createState() =>
      _OnboardingProfileScreenState();
}

class _OnboardingProfileScreenState
    extends ConsumerState<OnboardingProfileScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _location = TextEditingController();
  bool _saving = false;
  bool _filled = false;

  @override
  void initState() {
    super.initState();
    // The session may still be loading: prefill once the user arrives.
    ref.listenManual(authNotifierProvider, (_, next) {
      final user = next.valueOrNull;
      if (_filled || user == null) return;
      _filled = true;
      if (_name.text.isEmpty) _name.text = user.displayName;
      if (_location.text.isEmpty) _location.text = user.location ?? '';
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _name.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(profileActionsProvider).update(
            ProfileUpdate(
              displayName: _name.text.trim(),
              location: _location.text.trim(),
            ),
          );
      if (mounted) {
        await goToNextOnboardingStep(context, ref, AppRoutes.onboardingProfile);
      }
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return OnboardingScaffold(
      route: AppRoutes.onboardingProfile,
      title: l10n.onboardingProfileTitle,
      bottom: AppButton(
        key: const Key('onboarding-profile-continue'),
        label: l10n.commonContinue,
        isLoading: _saving,
        onPressed: _continue,
      ),
      child: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: onboardingGutter),
          children: [
            const Center(child: AvatarPicker(size: 112)),
            AppSpacing.vGapMd,
            Text(
              l10n.onboardingAvatarHint,
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall
                  .copyWith(color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            SettingsField(
              fieldKey: const Key('onboarding-display-name'),
              label: l10n.profileDisplayName,
              controller: _name,
              maxLength: 50,
              validator: (v) => (v ?? '').trim().length < 2
                  ? l10n.profileDisplayNameTooShort
                  : null,
            ),
            const SizedBox(height: 20),
            SettingsField(
              label: l10n.profileLocation,
              hint: l10n.profileLocationHint,
              controller: _location,
              maxLength: 100,
            ),
          ],
        ),
      ),
    );
  }
}
