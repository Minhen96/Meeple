import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/router/app_router.dart';
import 'package:meeple_hearth/features/auth/providers/auth_provider.dart';
import 'package:meeple_hearth/features/onboarding/presentation/onboarding_scaffold.dart';
import 'package:meeple_hearth/features/profile/data/user_repository.dart';
import 'package:meeple_hearth/features/profile/presentation/widgets/avatar_picker.dart';
import 'package:meeple_hearth/features/profile/providers/profile_provider.dart';
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
  late final _name = TextEditingController(
    text: ref.read(authNotifierProvider).valueOrNull?.displayName,
  );
  late final _location = TextEditingController(
    text: ref.read(authNotifierProvider).valueOrNull?.location,
  );
  bool _saving = false;

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
      subtitle: l10n.onboardingProfileBody,
      bottom: AppButton(
        key: const Key('onboarding-profile-continue'),
        label: l10n.commonContinue,
        isLoading: _saving,
        onPressed: _continue,
      ),
      child: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          children: [
            const Center(child: AvatarPicker()),
            AppSpacing.vGapXl,
            TextFormField(
              key: const Key('onboarding-display-name'),
              controller: _name,
              maxLength: 50,
              decoration: InputDecoration(labelText: l10n.profileDisplayName),
              validator: (v) => (v ?? '').trim().length < 2
                  ? l10n.profileDisplayNameTooShort
                  : null,
            ),
            AppSpacing.vGapSm,
            TextFormField(
              controller: _location,
              maxLength: 100,
              decoration: InputDecoration(
                labelText: l10n.eventFieldLocation,
                hintText: l10n.profileLocationHint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
