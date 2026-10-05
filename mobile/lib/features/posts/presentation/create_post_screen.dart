import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/core/network/upload_repository.dart';
import 'package:meeple_hearth/core/router/app_router.dart';
import 'package:meeple_hearth/core/utils/app_date_utils.dart';
import 'package:meeple_hearth/core/utils/image_utils.dart';
import 'package:meeple_hearth/features/library/domain/game_model.dart';
import 'package:meeple_hearth/features/library/presentation/widgets/game_picker.dart';
import 'package:meeple_hearth/features/library/providers/library_provider.dart';
import 'package:meeple_hearth/features/posts/data/post_repository.dart';
import 'package:meeple_hearth/features/posts/providers/post_provider.dart';
import 'package:meeple_hearth/features/social/presentation/friend_picker.dart';
import 'package:meeple_hearth/l10n/l10n.dart';
import 'package:meeple_hearth/shared/models/user_summary.dart';
import 'package:meeple_hearth/shared/widgets/app_avatar.dart';
import 'package:meeple_hearth/shared/widgets/app_button.dart';
import 'package:meeple_hearth/shared/widgets/app_toast.dart';
import 'package:meeple_hearth/shared/widgets/confirm_sheet.dart';
import 'package:meeple_hearth/shared/widgets/meeple_app_bar.dart';

/// Create (or edit, within 48 h) a post (SCREENS §7.1): up to 10 photos
/// compressed client-side, caption, game tag, friend tags, location and
/// date played. Leaving with unsaved content asks for confirmation.
class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({
    super.key,
    this.editPostId,
    this.gameId,
    this.eventId,
  });

  final String? editPostId;
  final String? gameId;
  final String? eventId;

  static const maxImages = 10;

  bool get isEdit => editPostId != null;

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final _caption = TextEditingController();
  final _location = TextEditingController();
  final _images = <File>[];
  Game? _game;
  List<UserSummary> _tagged = [];
  DateTime _playedAt = DateTime.now();
  bool _submitting = false;
  bool _loading = false;
  bool _compressing = false;
  String? _progress;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prefill());
  }

  @override
  void dispose() {
    _caption.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _prefill() async {
    try {
      if (widget.isEdit) {
        setState(() => _loading = true);
        final post =
            await ref.read(postDetailProvider(widget.editPostId!).future);
        if (!mounted) return;
        setState(() {
          _caption.text = post.caption;
          _location.text = post.location ?? '';
          _game = post.game;
          _tagged = post.taggedUsers;
          _playedAt = post.playedAt ?? post.createdAt;
        });
      } else if (widget.gameId != null) {
        final game = await ref.read(gameDetailProvider(widget.gameId!).future);
        if (mounted) setState(() => _game = game.data);
      }
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _dirty =>
      !widget.isEdit &&
      (_caption.text.trim().isNotEmpty ||
          _images.isNotEmpty ||
          _game != null ||
          _tagged.isNotEmpty);

  Future<void> _addPhotos({required bool camera}) async {
    final remaining = CreatePostScreen.maxImages - _images.length;
    if (remaining <= 0) return;
    final picker = ImagePicker();
    final picked = camera
        ? [
            if (await picker.pickImage(source: ImageSource.camera,
                    maxWidth: 2400) case final x?)
              x,
          ]
        : await picker.pickMultiImage(maxWidth: 2400);
    if (picked.isEmpty || !mounted) return;
    setState(() => _compressing = true);
    try {
      for (final x in picked.take(remaining)) {
        final file = await AppImageUtils.compress(File(x.path));
        if (!mounted) return;
        setState(() => _images.add(file));
      }
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    } finally {
      if (mounted) setState(() => _compressing = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _playedAt,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _playedAt = picked);
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    final caption = _caption.text.trim();
    if (!widget.isEdit && caption.isEmpty && _images.isEmpty) {
      showToast(context, l10n.postEmptyError, type: ToastType.error);
      return;
    }
    setState(() => _submitting = true);
    try {
      final actions = ref.read(postActionsProvider);
      if (widget.isEdit) {
        await actions.update(
          widget.editPostId!,
          PostDraft(
            caption: caption,
            location: _location.text.trim(),
            playedAt: _playedAt,
            gameId: _game?.id,
            taggedUserIds: [for (final u in _tagged) u.id],
          ),
        );
        if (!mounted) return;
        showToast(context, l10n.postUpdated, type: ToastType.success);
        context.pop();
        return;
      }
      final uploads = ref.read(uploadRepositoryProvider);
      final keys = <String>[];
      for (var i = 0; i < _images.length; i++) {
        setState(() => _progress = l10n.postUploading(i + 1, _images.length));
        keys.add((await uploads.uploadImage(_images[i])).key);
      }
      await actions.create(
        PostDraft(
          caption: caption,
          location: _location.text.trim(),
          playedAt: _playedAt,
          gameId: _game?.id,
          eventId: widget.eventId,
          taggedUserIds: [for (final u in _tagged) u.id],
          imageKeys: keys,
        ),
      );
      if (!mounted) return;
      _images.clear();
      _caption.clear();
      _game = null;
      _tagged = [];
      showToast(context, l10n.postPosted, type: ToastType.success);
      context.go(AppRoutes.home);
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
          _progress = null;
        });
      }
    }
  }

  Future<void> _confirmLeave() async {
    final l10n = context.l10n;
    final leave = await showConfirmSheet(
      context,
      title: l10n.postDiscardTitle,
      message: l10n.postDiscardMessage,
      confirmLabel: l10n.postDiscard,
    );
    if (leave && mounted) {
      _images.clear();
      _caption.clear();
      setState(() {
        _game = null;
        _tagged = [];
      });
      context.canPop() ? context.pop() : context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        appBar: MeepleAppBar(
          title: widget.isEdit ? l10n.postEditTitle : l10n.postNewTitle,
          leading: IconButton(
            tooltip: l10n.commonClose,
            icon: const Icon(Icons.close_rounded),
            onPressed: () => _dirty
                ? _confirmLeave()
                : context.canPop()
                    ? context.pop()
                    : context.go(AppRoutes.home),
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  if (!widget.isEdit) ...[
                    _ImagesRow(
                      images: _images,
                      compressing: _compressing,
                      onRemove: (i) => setState(() => _images.removeAt(i)),
                      onGallery: () => _addPhotos(camera: false),
                      onCamera: () => _addPhotos(camera: true),
                    ),
                    AppSpacing.vGapLg,
                  ],
                  TextField(
                    key: const Key('post-caption'),
                    controller: _caption,
                    maxLength: 2000,
                    minLines: 3,
                    maxLines: 8,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(hintText: l10n.postCaptionHint),
                  ),
                  AppSpacing.vGapSm,
                  _OptionTile(
                    icon: Icons.sports_esports_outlined,
                    label: _game?.name ?? l10n.postTagGame,
                    onTap: () async {
                      final g = await showGamePicker(context);
                      if (g != null) setState(() => _game = g);
                    },
                    onClear: _game == null ? null : () => setState(() => _game = null),
                  ),
                  _OptionTile(
                    icon: Icons.group_add_outlined,
                    label: _tagged.isEmpty
                        ? l10n.postTagFriends
                        : l10n.postTaggedCount(_tagged.length),
                    onTap: () async {
                      final picked = await showFriendPicker(
                        context,
                        title: l10n.postTagFriends,
                        initial: _tagged,
                      );
                      if (picked != null) setState(() => _tagged = picked);
                    },
                    trailing: _tagged.isEmpty
                        ? null
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (final u in _tagged.take(3))
                                Padding(
                                  padding: const EdgeInsets.only(left: 2),
                                  child: AppAvatar(
                                    imageUrl: u.avatarUrl,
                                    displayName: u.displayName,
                                    size: AvatarSize.xs,
                                  ),
                                ),
                            ],
                          ),
                  ),
                  _OptionTile(
                    icon: Icons.calendar_month_outlined,
                    label: l10n.postPlayedOn(AppDateUtils.formatDate(_playedAt)),
                    onTap: _pickDate,
                  ),
                  AppSpacing.vGapSm,
                  TextField(
                    key: const Key('post-location'),
                    controller: _location,
                    maxLength: 255,
                    decoration: InputDecoration(
                      labelText: l10n.eventFieldLocation,
                      prefixIcon: const Icon(Icons.location_on_outlined),
                    ),
                  ),
                  if (_progress != null) ...[
                    AppSpacing.vGapSm,
                    const LinearProgressIndicator(),
                    AppSpacing.vGapXs,
                    Text(_progress!, style: AppTypography.bodySmall),
                  ],
                ],
              ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: AppButton(
              key: const Key('post-submit'),
              label: widget.isEdit ? l10n.commonSave : l10n.postPublish,
              isLoading: _submitting,
              onPressed: _compressing ? null : _submit,
            ),
          ),
        ),
      ),
    );
  }
}

class _ImagesRow extends StatelessWidget {
  const _ImagesRow({
    required this.images,
    required this.compressing,
    required this.onRemove,
    required this.onGallery,
    required this.onCamera,
  });

  final List<File> images;
  final bool compressing;
  final ValueChanged<int> onRemove;
  final VoidCallback onGallery;
  final VoidCallback onCamera;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final full = images.length >= CreatePostScreen.maxImages;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('post-add-photos'),
                onPressed: full || compressing ? null : onGallery,
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(l10n.postAddPhotos),
              ),
            ),
            AppSpacing.hGapSm,
            IconButton.filledTonal(
              tooltip: l10n.postTakePhoto,
              onPressed: full || compressing ? null : onCamera,
              icon: const Icon(Icons.photo_camera_outlined),
            ),
          ],
        ),
        AppSpacing.vGapXs,
        Text(
          compressing
              ? l10n.postCompressing
              : '${images.length}/${CreatePostScreen.maxImages}',
          style: AppTypography.labelSmall,
        ),
        if (images.isNotEmpty) ...[
          AppSpacing.vGapSm,
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              separatorBuilder: (_, __) => AppSpacing.hGapSm,
              itemBuilder: (_, i) => Stack(
                children: [
                  ClipRRect(
                    borderRadius: AppSpacing.borderRadiusLg,
                    child: Image.file(
                      images[i],
                      width: 96,
                      height: 96,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: IconButton.filled(
                      tooltip: l10n.postRemovePhoto,
                      iconSize: 16,
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.inverseSurface,
                        minimumSize: const Size(28, 28),
                      ),
                      onPressed: () => onRemove(i),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.onClear,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Material(
          color: AppColors.surfaceContainerLow,
          borderRadius: AppSpacing.borderRadiusLg,
          child: ListTile(
            shape: const RoundedRectangleBorder(
              borderRadius: AppSpacing.borderRadiusLg,
            ),
            leading: Icon(icon, color: AppColors.primary),
            title: Text(label, style: AppTypography.bodyMedium),
            onTap: onTap,
            trailing: onClear != null
                ? IconButton(
                    tooltip: context.l10n.commonClose,
                    icon: const Icon(Icons.close_rounded),
                    onPressed: onClear,
                  )
                : trailing,
          ),
        ),
      );
}
