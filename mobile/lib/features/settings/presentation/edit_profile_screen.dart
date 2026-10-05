import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/core/router/app_router.dart';
import 'package:meeple_hearth/features/auth/providers/auth_provider.dart';
import 'package:meeple_hearth/features/profile/data/user_repository.dart';
import 'package:meeple_hearth/features/profile/presentation/widgets/avatar_picker.dart';
import 'package:meeple_hearth/features/profile/providers/profile_provider.dart';
import 'package:meeple_hearth/l10n/l10n.dart';
import 'package:meeple_hearth/shared/widgets/app_button.dart';
import 'package:meeple_hearth/shared/widgets/app_toast.dart';
import 'package:meeple_hearth/shared/widgets/meeple_app_bar.dart';

/// Edit profile (SCREENS §11.2): avatar, display name, username (once per
/// 30 days), bio (200), location.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final _user = ref.read(authNotifierProvider).valueOrNull;
  late final _displayName = TextEditingController(text: _user?.displayName);
  late final _username = TextEditingController(text: _user?.username);
  late final _bio = TextEditingController(text: _user?.bio);
  late final _location = TextEditingController(text: _user?.location);
  bool _saving = false;

  static final _usernamePattern = RegExp(r'^[a-z0-9][a-z0-9_]*$');

  @override
  void dispose() {
    _displayName.dispose();
    _username.dispose();
    _bio.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final l10n = context.l10n;
    final username = _username.text.trim();
    setState(() => _saving = true);
    try {
      await ref.read(profileActionsProvider).update(
            ProfileUpdate(
              displayName: _displayName.text.trim(),
              username: username == _user?.username ? null : username,
              bio: _bio.text.trim(),
              location: _location.text.trim(),
            ),
          );
      if (!mounted) return;
      showToast(context, l10n.profileSaved, type: ToastType.success);
      context.canPop() ? context.pop() : context.go(AppRoutes.profile);
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final availableAt = _user?.usernameChangeAvailableAt;
    final daysLeft = availableAt == null
        ? 0
        : availableAt.difference(DateTime.now()).inHours <= 0
            ? 0
            : (availableAt.difference(DateTime.now()).inHours / 24).ceil();
    return Scaffold(
      appBar: MeepleAppBar(
        title: l10n.settingsEditProfile,
        showBackButton: true,
        fallbackRoute: AppRoutes.settings,
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            const Center(child: AvatarPicker()),
            AppSpacing.vGapXl,
            TextFormField(
              key: const Key('edit-display-name'),
              controller: _displayName,
              maxLength: 50,
              decoration: InputDecoration(labelText: l10n.profileDisplayName),
              validator: (v) => (v ?? '').trim().length < 2
                  ? l10n.profileDisplayNameTooShort
                  : null,
            ),
            AppSpacing.vGapSm,
            TextFormField(
              key: const Key('edit-username'),
              controller: _username,
              enabled: daysLeft == 0,
              maxLength: 20,
              decoration: InputDecoration(
                labelText: l10n.profileUsername,
                prefixText: '@',
                helperText:
                    daysLeft > 0 ? l10n.profileUsernameChangeIn(daysLeft) : null,
              ),
              validator: (v) {
                final value = (v ?? '').trim();
                if (value.length < 3) return l10n.profileUsernameInvalid;
                if (!_usernamePattern.hasMatch(value)) {
                  return l10n.profileUsernameInvalid;
                }
                return null;
              },
            ),
            AppSpacing.vGapSm,
            TextFormField(
              key: const Key('edit-bio'),
              controller: _bio,
              maxLength: 200,
              maxLines: 3,
              decoration: InputDecoration(labelText: l10n.profileBio),
            ),
            AppSpacing.vGapSm,
            TextFormField(
              key: const Key('edit-location'),
              controller: _location,
              maxLength: 100,
              decoration: InputDecoration(
                labelText: l10n.eventFieldLocation,
                hintText: l10n.profileLocationHint,
              ),
            ),
            AppSpacing.vGapSm,
            Text(l10n.profileEmailNote, style: AppTypography.bodySmall),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: AppButton(
            key: const Key('edit-save'),
            label: l10n.commonSave,
            isLoading: _saving,
            onPressed: _save,
          ),
        ),
      ),
    );
  }
}
