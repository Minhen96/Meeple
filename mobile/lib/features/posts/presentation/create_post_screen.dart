import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_shadows.dart';
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
import 'package:meeple_hearth/shared/widgets/user_widgets.dart';
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

  /// Edit mode: the post as loaded, to tell unsaved edits apart.
  _EditSnapshot? _original;

  /// Edit mode: whether the user picked a different play date. Only then is
  /// `playedAt` sent, so saving never rewrites the stored date (or turns a
  /// missing one into the creation time).
  bool _playedAtChanged = false;
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
          _original = _EditSnapshot.of(
            caption: post.caption,
            location: post.location ?? '',
            gameId: post.game?.id,
            tagged: post.taggedUsers,
          );
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

  bool get _dirty {
    if (!widget.isEdit) {
      return _caption.text.trim().isNotEmpty ||
          _images.isNotEmpty ||
          _game != null ||
          _tagged.isNotEmpty;
    }
    final original = _original;
    if (original == null) return false; // still loading / failed to load
    return _playedAtChanged ||
        original !=
            _EditSnapshot.of(
              caption: _caption.text,
              location: _location.text,
              gameId: _game?.id,
              tagged: _tagged,
            );
  }

  Future<void> _addPhotos({required bool camera}) async {
    final remaining = CreatePostScreen.maxImages - _images.length;
    if (remaining <= 0) return;
    final picker = ImagePicker();
    final picked = camera
        ? [
            if (await picker.pickImage(
                    source: ImageSource.camera, maxWidth: 2400)
                case final x?)
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
    if (picked == null || !mounted || DateUtils.isSameDay(picked, _playedAt)) {
      return;
    }
    setState(() {
      _playedAt = picked;
      _playedAtChanged = true;
    });
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
            playedAt: _playedAtChanged ? _playedAt : null,
            gameId: _game?.id,
            taggedUserIds: [for (final u in _tagged) u.id],
          ),
        );
        if (!mounted) return;
        _original = null; // saved: leaving no longer asks
        showToast(context, l10n.postUpdated, type: ToastType.success);
        context.pop();
        return;
      }
      final uploads = ref.read(uploadRepositoryProvider);
      final keys = <String>[];
      for (var i = 0; i < _images.length; i++) {
        if (!mounted) return;
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
      title:
          widget.isEdit ? l10n.postDiscardChangesTitle : l10n.postDiscardTitle,
      message: widget.isEdit
          ? l10n.postDiscardChangesMessage
          : l10n.postDiscardMessage,
      confirmLabel: l10n.postDiscard,
    );
    if (leave && mounted) {
      _images.clear();
      _caption.clear();
      setState(() {
        _game = null;
        _tagged = [];
        _original = null;
        _playedAtChanged = false;
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
          centerTitle: true,
          leading: _SquareBackButton(
            tooltip: l10n.commonClose,
            onPressed: () => _dirty
                ? _confirmLeave()
                : context.canPop()
                    ? context.pop()
                    : context.go(AppRoutes.home),
          ),
          // Balances the back button so the title is centred like the web.
          actions: const [SizedBox(width: 44)],
          titleWidget: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.isEdit ? l10n.postEditTitle : l10n.postNewTitle,
                style: AppTypography.headlineMedium.copyWith(
                  fontWeight: FontWeight.w900,
                  height: widget.eventId == null ? null : 1.1,
                ),
              ),
              if (widget.eventId != null && !widget.isEdit)
                Text(
                  l10n.postForEvent.toUpperCase(),
                  style: AppTypography.overline.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w400,
                    color: AppColors.tertiary,
                    height: 1.2,
                  ),
                ),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.xxl,
                ),
                children: [
                  if (!widget.isEdit) ...[
                    _PhotosPanel(
                      images: _images,
                      compressing: _compressing,
                      onRemove: (i) => setState(() => _images.removeAt(i)),
                      onGallery: () => _addPhotos(camera: false),
                      onCamera: () => _addPhotos(camera: true),
                    ),
                    AppSpacing.vGapXl,
                  ],
                  _CaptionCard(
                      controller: _caption, onChanged: () => setState(() {})),
                  AppSpacing.vGapXl,
                  _OptionRow(
                    key: const Key('post-tag-game'),
                    icon: Icons.casino_outlined,
                    tint: AppColors.primary,
                    title: _game?.name ?? l10n.postTagGame,
                    hint: l10n.postWhichGame,
                    onTap: () async {
                      final g = await showGamePicker(context);
                      if (g != null && mounted) setState(() => _game = g);
                    },
                    trailing: _game == null
                        ? null
                        : IconButton(
                            key: const Key('post-clear-game'),
                            tooltip: l10n.commonClose,
                            iconSize: 16,
                            color: AppColors.onSurfaceVariant
                                .withValues(alpha: 0.6),
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => setState(() => _game = null),
                          ),
                  ),
                  AppSpacing.vGapMd,
                  _OptionRow(
                    key: const Key('post-tag-friends'),
                    icon: Icons.group_outlined,
                    tint: AppColors.secondary,
                    title: _tagged.isEmpty
                        ? l10n.postTagFriends
                        : l10n.postTaggedCount(_tagged.length),
                    hint: l10n.postWhoPlayed,
                    onTap: () async {
                      final picked = await showFriendPicker(
                        context,
                        title: l10n.postTagFriends,
                        initial: _tagged,
                      );
                      if (picked != null && mounted) {
                        setState(() => _tagged = picked);
                      }
                    },
                    trailing: _tagged.isEmpty
                        ? null
                        : AvatarStack(users: _tagged, max: 3),
                  ),
                  AppSpacing.vGapMd,
                  _FieldRow(
                    icon: Icons.location_on_outlined,
                    tint: AppColors.tertiary,
                    label: l10n.postLocationLabel,
                    child: TextField(
                      key: const Key('post-location'),
                      controller: _location,
                      maxLength: 100,
                      onChanged: (_) => setState(() {}),
                      style: AppTypography.titleSmall,
                      decoration: InputDecoration(
                        hintText: l10n.postLocationHint,
                        hintStyle: AppTypography.bodyMedium.copyWith(
                          color:
                              AppColors.onSurfaceVariant.withValues(alpha: 0.4),
                        ),
                        counterText: '',
                        filled: false,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),
                  ),
                  AppSpacing.vGapMd,
                  _FieldRow(
                    key: const Key('post-played-at'),
                    icon: Icons.schedule_rounded,
                    tint: AppColors.onSurfaceVariant,
                    neutral: true,
                    label: l10n.postDatePlayed,
                    onTap: _pickDate,
                    child: Text(
                      AppDateUtils.formatDate(_playedAt),
                      style: AppTypography.titleSmall,
                    ),
                  ),
                  if (_progress != null) ...[
                    AppSpacing.vGapLg,
                    const LinearProgressIndicator(),
                    AppSpacing.vGapXs,
                    Text(_progress!, style: AppTypography.bodySmall),
                  ],
                  const SizedBox(height: AppSpacing.xl + AppSpacing.lg),
                  AppButton(
                    key: const Key('post-submit'),
                    label: widget.isEdit ? l10n.commonSave : l10n.postShare,
                    icon: widget.isEdit ? null : Icons.send_rounded,
                    height: 64,
                    size: AppButtonSize.lg,
                    isLoading: _submitting,
                    onPressed: _compressing ? null : _submit,
                  ),
                ],
              ),
      ),
    );
  }
}

/// 44px rounded-2xl frosted back button (web create-post header).
class _SquareBackButton extends StatelessWidget {
  const _SquareBackButton({required this.onPressed, required this.tooltip});

  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Material(
          key: const Key('post-close'),
          color: AppColors.surfaceContainerLow.withValues(alpha: 0.8),
          borderRadius: AppSpacing.borderRadiusLg,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: const SizedBox.square(
              dimension: 44,
              child: Icon(Icons.arrow_back_rounded, color: AppColors.onSurface),
            ),
          ),
        ),
      );
}

/// "PHOTOS (n/10)" with the big "Add Photos" panel, or the photo strip.
class _PhotosPanel extends StatelessWidget {
  const _PhotosPanel({
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
    final canAdd = !full && !compressing;
    final linkStyle = AppTypography.labelSmall.copyWith(
      fontWeight: FontWeight.w700,
      color: AppColors.primary,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  (compressing
                          ? l10n.postCompressing
                          : l10n.postPhotosCount(images.length))
                      .toUpperCase(),
                  style: AppTypography.eyebrow.copyWith(
                    color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              ),
              if (canAdd)
                InkWell(
                  key: const Key('post-take-photo'),
                  onTap: onCamera,
                  borderRadius: AppSpacing.borderRadiusFull,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.photo_camera_outlined,
                          size: 14,
                          color: AppColors.primary,
                        ),
                        AppSpacing.hGapXs,
                        Text(l10n.postTakePhoto.toUpperCase(),
                            style: linkStyle),
                      ],
                    ),
                  ),
                ),
              if (canAdd && images.isNotEmpty) ...[
                AppSpacing.hGapMd,
                InkWell(
                  onTap: onGallery,
                  child: Text(l10n.postAddMore.toUpperCase(), style: linkStyle),
                ),
              ],
            ],
          ),
        ),
        AppSpacing.vGapMd,
        if (images.isEmpty)
          Material(
            color: AppColors.surfaceContainerLow,
            borderRadius:
                const BorderRadius.all(Radius.circular(AppRadius.panel)),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: const Key('post-add-photos'),
              onTap: canAdd ? onGallery : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        color: AppColors.surfaceContainerHigh,
                        borderRadius: AppSpacing.borderRadiusLg,
                      ),
                      child: const Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 30,
                        color: AppColors.tertiary,
                      ),
                    ),
                    AppSpacing.vGapMd,
                    Text(
                      l10n.postAddPhotos,
                      style: AppTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.w900,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      l10n.postPickerHint.toUpperCase(),
                      style: AppTypography.labelSmall.copyWith(
                        letterSpacing: -0.3,
                        color:
                            AppColors.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          SizedBox(
            height: 128,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: images.length + (canAdd ? 1 : 0),
              separatorBuilder: (_, __) => AppSpacing.hGapMd,
              itemBuilder: (_, i) {
                if (i == images.length) {
                  return Material(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: AppSpacing.borderRadiusLg,
                    child: InkWell(
                      key: const Key('post-add-more'),
                      borderRadius: AppSpacing.borderRadiusLg,
                      onTap: onGallery,
                      child: const SizedBox.square(
                        dimension: 128,
                        child: Icon(
                          Icons.add_rounded,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  );
                }
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: AppSpacing.borderRadiusLg,
                      child: Image.file(
                        images[i],
                        width: 128,
                        height: 128,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Tooltip(
                        message: l10n.postRemovePhoto,
                        child: GestureDetector(
                          key: ValueKey('post-remove-photo-$i'),
                          onTap: () => onRemove(i),
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }
}

/// `rounded-[2rem] bg-surface-container-low p-6` caption card with a filled
/// textarea and a "n/2000" counter.
class _CaptionCard extends StatelessWidget {
  const _CaptionCard({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.panel)),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const Key('post-caption'),
            controller: controller,
            maxLength: 2000,
            minLines: 4,
            maxLines: 8,
            onChanged: (_) => onChanged(),
            style: AppTypography.bodyLarge,
            decoration: InputDecoration(
              hintText: l10n.postCaptionHint,
              hintStyle: AppTypography.bodyLarge.copyWith(
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.4),
              ),
              counterText: '',
              filled: true,
              fillColor: AppColors.surfaceContainerHighest,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              border: const OutlineInputBorder(
                borderRadius: AppSpacing.borderRadiusLg,
                borderSide: BorderSide.none,
              ),
              enabledBorder: const OutlineInputBorder(
                borderRadius: AppSpacing.borderRadiusLg,
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppSpacing.borderRadiusLg,
                borderSide: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
            ),
          ),
          AppSpacing.vGapSm,
          Text(
            l10n.postCaptionCount(controller.text.length),
            textAlign: TextAlign.right,
            style: AppTypography.labelSmall,
          ),
        ],
      ),
    );
  }
}

/// Round tinted icon tile (`w-10 h-10 rounded-xl bg-<tint>/10`).
class _IconTile extends StatelessWidget {
  const _IconTile({
    required this.icon,
    required this.tint,
    this.neutral = false,
  });

  final IconData icon;
  final Color tint;
  final bool neutral;

  @override
  Widget build(BuildContext context) => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: neutral
              ? AppColors.surfaceContainerHigh
              : tint.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: tint),
      );
}

/// Tag Game / Tag Friends row: icon tile, bold title and a tiny hint.
class _OptionRow extends StatelessWidget {
  const _OptionRow({
    super.key,
    required this.icon,
    required this.tint,
    required this.title,
    required this.hint,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final Color tint;
  final String title;
  final String hint;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.surfaceContainerLow,
        borderRadius: AppSpacing.borderRadiusLg,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                _IconTile(icon: icon, tint: tint),
                AppSpacing.hGapLg,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleSmall,
                      ),
                      Text(
                        hint.toUpperCase(),
                        style: AppTypography.labelSmall.copyWith(
                          letterSpacing: -0.3,
                          color:
                              AppColors.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
        ),
      );
}

/// Location / Date played row: icon tile with a tiny label over a value.
class _FieldRow extends StatelessWidget {
  const _FieldRow({
    super.key,
    required this.icon,
    required this.tint,
    required this.label,
    required this.child,
    this.neutral = false,
    this.onTap,
  });

  final IconData icon;
  final Color tint;
  final String label;
  final Widget child;
  final bool neutral;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          _IconTile(icon: icon, tint: tint, neutral: neutral),
          AppSpacing.hGapLg,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: AppTypography.labelSmall.copyWith(
                    letterSpacing: -0.3,
                    color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ),
                child,
              ],
            ),
          ),
        ],
      ),
    );
    return Material(
      color: AppColors.surfaceContainerLow,
      borderRadius: AppSpacing.borderRadiusLg,
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}

/// The editable fields of a post, compared to detect unsaved edits.
@immutable
final class _EditSnapshot {
  _EditSnapshot.of({
    required String caption,
    required String location,
    required this.gameId,
    required List<UserSummary> tagged,
  })  : caption = caption.trim(),
        location = location.trim(),
        taggedIds = {for (final u in tagged) u.id};

  final String caption;
  final String location;
  final String? gameId;
  final Set<String> taggedIds;

  @override
  bool operator ==(Object other) =>
      other is _EditSnapshot &&
      other.caption == caption &&
      other.location == location &&
      other.gameId == gameId &&
      other.taggedIds.length == taggedIds.length &&
      other.taggedIds.containsAll(taggedIds);

  @override
  int get hashCode => Object.hash(
      caption, location, gameId, Object.hashAllUnordered(taggedIds));
}
