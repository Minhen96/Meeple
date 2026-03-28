import 'package:flutter/material.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/shared/widgets/app_button.dart';

/// Create post screen — Phase 1 stub.
///
/// Full implementation supports text, image upload to R2, and game tagging.
class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _contentController = TextEditingController();
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
              onPressed: _isSubmitting
                  ? null
                  : () => _submit(context),
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
                    onPressed: () {},
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

  Future<void> _submit(BuildContext context) async {
    final content = _contentController.text.trim();
    if (content.isEmpty) return;
    final navigator = Navigator.of(context);
    setState(() => _isSubmitting = true);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    navigator.pop();
  }
}
