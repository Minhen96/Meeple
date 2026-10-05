import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/features/auth/providers/auth_provider.dart';
import 'package:meeple_hearth/features/profile/providers/profile_provider.dart';
import 'package:meeple_hearth/l10n/l10n.dart';
import 'package:meeple_hearth/shared/widgets/app_avatar.dart';
import 'package:meeple_hearth/shared/widgets/app_toast.dart';

/// Tap-to-change avatar: pick → 1:1 crop → WebP compress → upload
/// (MOBILE_FLUTTER §9), with a spinner overlay while uploading.
class AvatarPicker extends ConsumerStatefulWidget {
  const AvatarPicker({super.key, this.size = AvatarSize.xxl});

  final double size;

  @override
  ConsumerState<AvatarPicker> createState() => _AvatarPickerState();
}

class _AvatarPickerState extends ConsumerState<AvatarPicker> {
  bool _uploading = false;

  Future<File?> _pickCropCompress() async {
    final l10n = context.l10n;
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return null;
    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: l10n.avatarCropTitle,
          lockAspectRatio: true,
        ),
        IOSUiSettings(title: l10n.avatarCropTitle, aspectRatioLockEnabled: true),
      ],
    );
    if (cropped == null) return null;
    final bytes = await FlutterImageCompress.compressWithFile(
      cropped.path,
      minWidth: 400,
      minHeight: 400,
      quality: 90,
      format: CompressFormat.webp,
    );
    final out = File(cropped.path);
    if (bytes != null) await out.writeAsBytes(bytes);
    return out;
  }

  Future<void> _change() async {
    final l10n = context.l10n;
    try {
      final file = await _pickCropCompress();
      if (file == null || !mounted) return;
      setState(() => _uploading = true);
      await ref.read(profileActionsProvider).updateAvatar(file);
    } catch (e) {
      if (mounted) {
        showToast(context, l10n.avatarUploadFailed, type: ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider).valueOrNull;
    return Semantics(
      button: true,
      label: context.l10n.avatarChange,
      child: GestureDetector(
        key: const Key('avatar-picker'),
        onTap: _uploading ? null : _change,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AppAvatar(
              imageUrl: user?.avatarUrl,
              displayName: user?.displayName,
              size: widget.size,
            ),
            if (_uploading)
              SizedBox(
                width: widget.size,
                height: widget.size,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.glassBackground,
                    shape: BoxShape.circle,
                  ),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  size: 16,
                  color: AppColors.onPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
