import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meeple_hearth/core/config/app_config.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/core/network/api_exception.dart';
import 'package:meeple_hearth/core/router/app_router.dart';
import 'package:meeple_hearth/core/utils/app_date_utils.dart';
import 'package:meeple_hearth/features/events/domain/event_model.dart';
import 'package:meeple_hearth/features/events/presentation/widgets/event_card.dart';
import 'package:meeple_hearth/features/events/providers/events_provider.dart';
import 'package:meeple_hearth/features/home/presentation/widgets/post_card.dart';
import 'package:meeple_hearth/features/posts/providers/post_provider.dart';
import 'package:meeple_hearth/features/social/presentation/friend_picker.dart';
import 'package:meeple_hearth/l10n/l10n.dart';
import 'package:meeple_hearth/shared/widgets/app_button.dart';
import 'package:meeple_hearth/shared/widgets/app_toast.dart';
import 'package:meeple_hearth/shared/widgets/confirm_sheet.dart';
import 'package:meeple_hearth/shared/widgets/empty_state.dart';
import 'package:meeple_hearth/shared/widgets/error_state.dart';
import 'package:meeple_hearth/shared/widgets/meeple_app_bar.dart';
import 'package:meeple_hearth/shared/widgets/user_widgets.dart';
import 'package:share_plus/share_plus.dart';

/// Event detail (SCREENS §6.4) with RSVP actions and host management
/// (edit, cancel, invite, kick).
class EventDetailScreen extends ConsumerWidget {
  const EventDetailScreen({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final event = ref.watch(eventDetailProvider(eventId));
    return Scaffold(
      appBar: MeepleAppBar(
        showBackButton: true,
        fallbackRoute: AppRoutes.events,
        actions: [
          if (event.hasValue)
            IconButton(
              tooltip: l10n.commonShare,
              icon: const Icon(Icons.share_outlined),
              onPressed: () =>
                  Share.share('${AppConfig.webOrigin}/events/$eventId'),
            ),
          if (event.valueOrNull?.isHost ?? false)
            _HostMenu(event: event.requireValue),
        ],
      ),
      body: event.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => e is NotFoundException
            ? EmptyState(
                icon: Icons.event_busy_outlined,
                title: l10n.eventNotFound,
              )
            : ErrorState(
                error: e,
                onRetry: () => ref.invalidate(eventDetailProvider(eventId)),
              ),
        data: (e) => RefreshIndicator(
          onRefresh: () => ref.refresh(eventDetailProvider(eventId).future),
          child: _Body(event: e),
        ),
      ),
      bottomNavigationBar: event.valueOrNull == null
          ? null
          : _ActionBar(event: event.requireValue),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final e = event;
    final host = e.host;
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      children: [
        SizedBox(
          height: 280,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (e.game?.heroUrl != null)
                CachedNetworkImage(imageUrl: e.game!.heroUrl!, fit: BoxFit.cover)
              else
                const DecoratedBox(
                  decoration: BoxDecoration(gradient: AppColors.primaryGradient),
                ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [AppColors.surface, AppColors.transparent],
                  ),
                ),
              ),
              Positioned(
                left: AppSpacing.xl,
                right: AppSpacing.xl,
                bottom: AppSpacing.lg,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    EventStatusChip(event: e),
                    AppSpacing.vGapSm,
                    Text(e.title, style: AppTypography.headlineMedium),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (e.isCancelled)
          _Banner(text: l10n.eventCancelledBanner, error: true)
        else if (e.isCompleted)
          _Banner(
            text: l10n.eventEndedBanner,
            action: TextButton(
              key: const Key('event-memories'),
              onPressed: () => _showMemories(context, e),
              child: Text(l10n.eventViewMemories),
            ),
          ),
        if (host != null)
          UserRow(
            user: host,
            subtitle: l10n.eventHostedBy(displayNameOf(context, host)),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            children: [
              _InfoTile(
                icon: Icons.schedule_rounded,
                title: AppDateUtils.formatFullDate(e.scheduledAt),
                subtitle: AppDateUtils.formatTime(e.scheduledAt),
              ),
              if (e.displayLocation != null)
                _InfoTile(
                  icon: Icons.location_on_outlined,
                  title: e.displayLocation!,
                ),
              _InfoTile(
                icon: Icons.groups_outlined,
                title: e.maxParticipants > 0
                    ? l10n.eventPlayersCount(e.participantCount, e.maxParticipants)
                    : l10n.eventGoingCount(e.participantCount),
                subtitle: _visibilityLabel(l10n, e.visibilityValue),
              ),
              if (e.game != null)
                _InfoTile(
                  icon: Icons.sports_esports_outlined,
                  title: e.game!.name,
                  onTap: () => context.push(AppRoutes.gameDetail(e.game!.id)),
                ),
            ],
          ),
        ),
        if (e.description != null && e.description!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(e.description!, style: AppTypography.bodyLarge),
          ),
        _Participants(event: e),
      ],
    );
  }

  Future<void> _showMemories(BuildContext context, Event e) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        useSafeArea: true,
        backgroundColor: AppColors.background,
        builder: (_) => FractionallySizedBox(
          heightFactor: 0.9,
          child: _Memories(eventId: e.id),
        ),
      );
}

String _visibilityLabel(AppLocalizations l10n, EventVisibility v) =>
    switch (v) {
      EventVisibility.inviteOnly => l10n.visibilityInviteOnly,
      EventVisibility.friends => l10n.visibilityFriends,
      EventVisibility.public => l10n.visibilityPublic,
    };

class _Memories extends ConsumerWidget {
  const _Memories({required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return ref.watch(eventPostsProvider(eventId)).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorState(
            error: e,
            onRetry: () => ref.invalidate(eventPostsProvider(eventId)),
          ),
          data: (posts) => posts.isEmpty
              ? EmptyState(
                  icon: Icons.photo_library_outlined,
                  title: l10n.eventNoMemories,
                  actionLabel: l10n.homeCreatePost,
                  onAction: () {
                    Navigator.of(context).pop();
                    context.push('${AppRoutes.createPost}?eventId=$eventId');
                  },
                )
              : ListView(children: [for (final p in posts) PostCard(post: p)]),
        );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text, this.error = false, this.action});

  final String text;
  final bool error;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.all(AppSpacing.lg),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: error ? AppColors.errorContainer : AppColors.surfaceContainerHigh,
          borderRadius: AppSpacing.borderRadiusLg,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: AppTypography.titleSmall.copyWith(
                  color: error ? AppColors.onErrorContainer : AppColors.onSurface,
                ),
              ),
            ),
            if (action != null) action!,
          ],
        ),
      );
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Material(
          color: AppColors.surfaceContainerLow,
          borderRadius: AppSpacing.borderRadiusLg,
          child: ListTile(
            onTap: onTap,
            shape: const RoundedRectangleBorder(
              borderRadius: AppSpacing.borderRadiusLg,
            ),
            leading: Icon(icon, color: AppColors.primary),
            title: Text(title, style: AppTypography.titleSmall),
            subtitle: subtitle == null ? null : Text(subtitle!),
            trailing: onTap == null ? null : const Icon(Icons.chevron_right_rounded),
          ),
        ),
      );
}

class _Participants extends ConsumerWidget {
  const _Participants({required this.event});

  final Event event;

  Future<void> _kick(
    BuildContext context,
    WidgetRef ref,
    EventParticipant p,
  ) async {
    final l10n = context.l10n;
    final ok = await showConfirmSheet(
      context,
      title: l10n.eventKickTitle,
      message: l10n.eventKickMessage(p.displayName),
      confirmLabel: l10n.eventKick,
    );
    if (!ok || !context.mounted) return;
    try {
      await ref.read(eventDetailProvider(event.id).notifier).kick(p.id);
    } catch (e) {
      if (context.mounted) showErrorToast(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final going = event.acceptedParticipants;
    final invited = event.participants.where((p) => p.status == 'INVITED').toList();
    if (going.isEmpty && invited.isEmpty) return const SizedBox.shrink();
    final canKick = event.isHost && !event.isCancelled && !event.isCompleted;
    Widget row(EventParticipant p) => UserRow(
          key: ValueKey('participant-${p.id}'),
          user: p.asUser,
          trailing: canKick && p.id != event.host?.id
              ? IconButton(
                  key: ValueKey('kick-${p.id}'),
                  tooltip: l10n.eventKick,
                  icon: const Icon(Icons.person_remove_outlined),
                  onPressed: () => _kick(context, ref, p),
                )
              : null,
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (going.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.xs,
            ),
            child: Text(
              l10n.eventGoingCount(going.length),
              style: AppTypography.titleMedium,
            ),
          ),
          for (final p in going) row(p),
        ],
        if (invited.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.xs,
            ),
            child: Text(
              l10n.eventInvitedCount(invited.length),
              style: AppTypography.titleMedium,
            ),
          ),
          for (final p in invited) row(p),
        ],
      ],
    );
  }
}

/// RSVP actions per SCREENS §6.4 table.
class _ActionBar extends ConsumerStatefulWidget {
  const _ActionBar({required this.event});

  final Event event;

  @override
  ConsumerState<_ActionBar> createState() => _ActionBarState();
}

class _ActionBarState extends ConsumerState<_ActionBar> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() f, {String? success}) async {
    setState(() => _busy = true);
    try {
      await f();
      if (success != null && mounted) {
        showToast(context, success, type: ToastType.success);
      }
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final e = widget.event;
    final notifier = ref.read(eventDetailProvider(e.id).notifier);
    if (e.isCancelled || e.isCompleted || e.isHost) {
      return const SizedBox.shrink();
    }
    Widget child;
    if (e.isInvited) {
      child = Row(
        children: [
          Expanded(
            child: AppButton(
              key: const Key('rsvp-accept'),
              label: l10n.eventAccept,
              isLoading: _busy,
              onPressed: e.isFull
                  ? null
                  : () => _run(() => notifier.rsvp('ACCEPTED'),
                      success: l10n.eventJoined),
            ),
          ),
          AppSpacing.hGapSm,
          Expanded(
            child: AppOutlinedButton(
              key: const Key('rsvp-decline'),
              label: l10n.eventDecline,
              onPressed: _busy ? null : () => _run(() => notifier.rsvp('DECLINED')),
            ),
          ),
        ],
      );
    } else if (e.isAttending) {
      child = AppOutlinedButton(
        key: const Key('rsvp-leave'),
        label: l10n.eventLeave,
        isLoading: _busy,
        onPressed: () async {
          final ok = await showConfirmSheet(
            context,
            title: l10n.eventLeaveTitle,
            message: l10n.eventLeaveMessage,
            confirmLabel: l10n.eventLeave,
          );
          if (ok) await _run(notifier.leave);
        },
      );
    } else if (e.myRsvp == 'KICKED') {
      child = Text(
        l10n.eventYouWereRemoved,
        textAlign: TextAlign.center,
        style: AppTypography.bodyMedium,
      );
    } else if (e.isFull) {
      child = AppButton(label: l10n.eventFull, onPressed: null);
    } else {
      child = AppButton(
        key: const Key('rsvp-join'),
        label: e.hasDeclined ? l10n.eventChangeToGoing : l10n.eventJoin,
        isLoading: _busy,
        onPressed: () =>
            _run(() => notifier.rsvp('ACCEPTED'), success: l10n.eventJoined),
      );
    }
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: child,
      ),
    );
  }
}

class _HostMenu extends ConsumerWidget {
  const _HostMenu({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final notifier = ref.read(eventDetailProvider(event.id).notifier);
    final active = !event.isCancelled && !event.isCompleted;
    return PopupMenuButton<String>(
      key: const Key('event-manage'),
      tooltip: l10n.eventManage,
      icon: const Icon(Icons.more_vert_rounded),
      onSelected: (choice) async {
        switch (choice) {
          case 'edit':
            await context.push(AppRoutes.editEvent(event.id));
          case 'invite':
            final picked = await showFriendPicker(
              context,
              title: l10n.eventInviteFriends,
              exclude: {for (final p in event.participants) p.id},
            );
            if (picked == null || picked.isEmpty) return;
            try {
              await notifier.invite([for (final u in picked) u.id]);
              if (context.mounted) {
                showToast(context, l10n.eventInvitesSent, type: ToastType.success);
              }
            } catch (e) {
              if (context.mounted) showErrorToast(context, e);
            }
          case 'cancel':
            final ok = await showConfirmSheet(
              context,
              title: l10n.eventCancelTitle,
              message: l10n.eventCancelMessage,
              confirmLabel: l10n.eventCancelConfirm,
            );
            if (!ok) return;
            try {
              await notifier.cancel();
            } catch (e) {
              if (context.mounted) showErrorToast(context, e);
            }
        }
      },
      itemBuilder: (_) => [
        if (active) PopupMenuItem(value: 'edit', child: Text(l10n.eventEdit)),
        if (active)
          PopupMenuItem(value: 'invite', child: Text(l10n.eventInviteFriends)),
        if (active)
          PopupMenuItem(
            value: 'cancel',
            child: Text(
              l10n.eventCancelConfirm,
              style: const TextStyle(color: AppColors.error),
            ),
          ),
      ],
    );
  }
}
