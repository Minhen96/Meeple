import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/router/app_router.dart';
import 'package:meeple_hearth/features/auth/domain/user_model.dart';
import 'package:meeple_hearth/features/auth/providers/auth_provider.dart';
import 'package:meeple_hearth/features/profile/data/user_repository.dart';
import 'package:meeple_hearth/features/profile/presentation/widgets/avatar_picker.dart';
import 'package:meeple_hearth/features/profile/providers/profile_provider.dart';
import 'package:meeple_hearth/features/settings/presentation/widgets/settings_widgets.dart';
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
  User? _user;
  final _displayName = TextEditingController();
  final _username = TextEditingController();
  final _bio = TextEditingController();
  final _location = TextEditingController();
  bool _saving = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    // Opened by a deep link the session may still be loading: fill the form
    // once the user arrives (never overwrite what was typed).
    ref.listenManual(authNotifierProvider, (_, next) {
      final user = next.valueOrNull;
      if (_user != null || user == null) return;
      void fill() {
        _user = user;
        _displayName.text = user.displayName;
        _username.text = user.username;
        _bio.text = user.bio ?? '';
        _location.text = user.location ?? '';
      }

      _initialized ? setState(fill) : fill();
    }, fireImmediately: true);
    _initialized = true;
  }

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
        compactTitle: true,
        fallbackRoute: AppRoutes.settings,
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: settingsPagePadding,
          children: [
            Center(
              child: AvatarPicker(
                size: 96,
                showBadge: false,
                label: l10n.avatarChange,
              ),
            ),
            const SizedBox(height: 20),
            SettingsField(
              fieldKey: const Key('edit-display-name'),
              label: l10n.profileDisplayName,
              controller: _displayName,
              maxLength: 50,
              validator: (v) => (v ?? '').trim().length < 2
                  ? l10n.profileDisplayNameTooShort
                  : null,
            ),
            const SizedBox(height: 20),
            SettingsField(
              fieldKey: const Key('edit-username'),
              label: l10n.profileUsername,
              controller: _username,
              enabled: daysLeft == 0,
              maxLength: 20,
              prefixText: '@',
              helper: daysLeft > 0
                  ? l10n.profileUsernameChangeIn(daysLeft)
                  : l10n.profileUsernameOnce,
              validator: (v) {
                final value = (v ?? '').trim();
                if (value.length < 3) return l10n.profileUsernameInvalid;
                if (!_usernamePattern.hasMatch(value)) {
                  return l10n.profileUsernameInvalid;
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            SettingsField(
              fieldKey: const Key('edit-bio'),
              label: l10n.profileBio,
              controller: _bio,
              hint: l10n.profileBioHint,
              maxLength: 200,
              maxLines: 3,
              showCounter: true,
            ),
            const SizedBox(height: 20),
            SettingsField(
              fieldKey: const Key('edit-location'),
              label: l10n.profileLocation,
              controller: _location,
              hint: l10n.profileLocationHint,
              maxLength: 100,
            ),
            AppSpacing.vGapLg,
            SettingsNote(l10n.profileEmailNote),
          ],
        ),
      ),
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: ColoredBox(
            color: AppColors.surface.withValues(alpha: 0.9),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                child: AppButton(
                  key: const Key('edit-save'),
                  label: l10n.commonSave,
                  isLoading: _saving,
                  onPressed: _save,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
