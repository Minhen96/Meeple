import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/core/network/api_exception.dart';
import 'package:meeple_hearth/core/network/upload_repository.dart';
import 'package:meeple_hearth/core/utils/image_utils.dart';
import 'package:meeple_hearth/features/home/providers/feed_provider.dart';
import 'package:meeple_hearth/features/posts/data/post_repository.dart';
import 'package:meeple_hearth/shared/widgets/app_button.dart';

/// Create post screen — caption plus up to [_maxImages] photos.
///
/// Photos are uploaded to R2 via presigned URLs on submit; the returned keys
/// are sent as `imageKeys`.
class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({super.key});

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  static const _maxImages = 4;

  final _contentController = TextEditingController();
  final _images = <File>[];
  bool _isSubmitting = false;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('New Post', style: AppTypography.titleMedium),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: AppButton(
              label: 'Post',
              onPressed: _isSubmitting ? null : () => _submit(context),
              isLoading: _isSubmitting,
              minWidth: 72,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: AppSpacing.pagePadding,
                child: TextField(
                  controller: _contentController,
                  maxLines: null,
                  expands: true,
                  autofocus: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: AppTypography.bodyLarge,
                  decoration: InputDecoration(
                    hintText: "What's on your board today?",
                    hintStyle: AppTypography.bodyLarge.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                  ),
                ),
              ),
            ),
            if (_images.isNotEmpty)
              SizedBox(
                height: 72,
                child: ListView.separated(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  scrollDirection: Axis.horizontal,
                  itemCount: _images.length,
                  separatorBuilder: (_, __) => AppSpacing.hGapSm,
                  itemBuilder: (_, i) => GestureDetector(
                    onTap: _isSubmitting
                        ? null
                        : () => setState(() => _images.removeAt(i)),
                    child: ClipRRect(
                      borderRadius: AppSpacing.borderRadiusMd,
                      child: Image.file(
                        _images[i],
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),
            // Attachment toolbar
            const Divider(color: AppColors.outlineVariant, height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.image_outlined),
                    tooltip: 'Add photo',
                    color: AppColors.onSurfaceVariant,
                    onPressed: _isSubmitting || _images.length >= _maxImages
                        ? null
                        : _addPhoto,
                  ),
                  IconButton(
                    icon: const Icon(Icons.casino_outlined),
                    tooltip: 'Tag a game',
                    color: AppColors.onSurfaceVariant,
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: const Icon(Icons.event_outlined),
                    tooltip: 'Link an event',
                    color: AppColors.onSurfaceVariant,
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addPhoto() async {
    final file = await AppImageUtils.pickAndCompress(ImageSource.gallery);
    if (file == null || !mounted) return;
    setState(() => _images.add(file));
  }

  Future<void> _submit(BuildContext context) async {
    final content = _contentController.text.trim();
    if (content.isEmpty && _images.isEmpty) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isSubmitting = true);
    try {
      final uploads = ref.read(uploadRepositoryProvider);
      final keys = <String>[];
      for (final image in _images) {
        keys.add((await uploads.uploadImage(image)).key);
      }
      await ref.read(postRepositoryProvider).createPost(
            caption: content,
            imageKeys: keys,
          );
      ref.invalidate(feedNotifierProvider);
      if (!mounted) return;
      navigator.pop();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e is ApiException
                ? e.message
                : 'Could not publish your post. Please try again.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
