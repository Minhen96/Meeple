import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/core/constants/text_style_weight.dart';
import 'package:meeple_hearth/core/router/app_router.dart';
import 'package:meeple_hearth/features/auth/providers/auth_provider.dart';
import 'package:meeple_hearth/features/profile/providers/profile_provider.dart';
import 'package:meeple_hearth/features/social/domain/social_model.dart';
import 'package:meeple_hearth/features/social/presentation/friend_button.dart';
import 'package:meeple_hearth/features/social/presentation/widgets/people_widgets.dart';
import 'package:meeple_hearth/features/social/providers/social_provider.dart';
import 'package:meeple_hearth/l10n/l10n.dart';
import 'package:meeple_hearth/shared/models/user_summary.dart';
import 'package:meeple_hearth/shared/widgets/app_card.dart';
import 'package:meeple_hearth/shared/widgets/app_text_field.dart';
import 'package:meeple_hearth/shared/widgets/app_toast.dart';
import 'package:meeple_hearth/shared/widgets/confirm_sheet.dart';
import 'package:meeple_hearth/shared/widgets/error_state.dart';
import 'package:meeple_hearth/shared/widgets/meeple_app_bar.dart';
import 'package:meeple_hearth/shared/widgets/skeleton_widget.dart';
import 'package:meeple_hearth/shared/widgets/status_banners.dart';
import 'package:meeple_hearth/shared/widgets/user_widgets.dart';

/// Friends, friend requests (received + sent) and people search — the web
/// `/profile/friends` and `/people` pages as three pill tabs.
class FriendsScreen extends ConsumerWidget {
  const FriendsScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final me = ref.watch(authNotifierProvider).valueOrNull;
    final total = me == null
        ? null
        : ref.watch(userStatsProvider(me.id)).valueOrNull?.friends;
    final received = (ref.watch(receivedRequestsProvider).valueOrNull ??
            const <FriendRequest>[])
        .where((r) => r.status == 'PENDING')
        .length;
    return DefaultTabController(
      length: 3,
      initialIndex: initialTab,
      child: Scaffold(
        appBar: MeepleAppBar(
          title: l10n.friendsTitle,
          showBackButton: true,
          fallbackRoute: AppRoutes.profile,
          titleWidget: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.friendsTitle,
                style: AppTypography.headlineSmall
                    .weight(FontWeight.w900)
                    .copyWith(height: 1.2),
              ),
              if (total != null && total > 0)
                Text(
                  l10n.friendsCount(total),
                  style: AppTypography.labelMedium
                      .weight(FontWeight.w400)
                      .copyWith(
                        height: 1.3,
                        color: AppColors.onSurfaceVariant,
                      ),
                ),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: PillTabBar(
                tabs: [
                  l10n.friendsTabFriends,
                  received > 0
                      ? l10n.friendsTabRequestsCount(received)
                      : l10n.friendsTabRequests,
                  l10n.friendsTabFind,
                ],
              ),
            ),
            const Expanded(
              child: TabBarView(
                children: [_FriendsTab(), _RequestsTab(), _FindTab()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _listPadding = EdgeInsets.fromLTRB(
  AppSpacing.lg,
  0,
  AppSpacing.lg,
  AppSpacing.xxxl,
);

/// Loading placeholder: three pulsing rows (web `h-16 animate-pulse`).
class _RowsSkeleton extends StatelessWidget {
  const _RowsSkeleton();

  @override
  Widget build(BuildContext context) => ListView(
        padding: _listPadding,
        children: [
          for (var i = 0; i < 3; i++) ...[
            const SkeletonBox(
              height: 72,
              borderRadius: BorderRadius.all(Radius.circular(AppRadius.tile)),
            ),
            AppSpacing.vGapSm,
          ],
        ],
      );
}

class _FriendsTab extends ConsumerWidget {
  const _FriendsTab();

  Future<void> _unfriend(
      BuildContext context, WidgetRef ref, UserSummary u) async {
    final l10n = context.l10n;
    final ok = await showConfirmSheet(
      context,
      title: l10n.friendsUnfriendTitle(displayNameOf(context, u)),
      message: l10n.friendsUnfriendBody,
      confirmLabel: l10n.friendUnfriend,
      icon: Icons.person_remove_outlined,
    );
    if (!ok) return;
    try {
      await ref.read(friendsListProvider.notifier).unfriend(u.id);
      if (context.mounted) {
        showToast(context, l10n.friendsRemoved, type: ToastType.success);
      }
    } catch (e) {
      if (context.mounted) showErrorToast(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return ref.watch(friendsListProvider).when(
          loading: () => const _RowsSkeleton(),
          error: (e, _) => ErrorState(
            error: e,
            onRetry: () => ref.invalidate(friendsListProvider),
          ),
          data: (s) => s.items.isEmpty
              ? _NoFriends(
                  onFind: () => DefaultTabController.of(context).animateTo(2),
                )
              : RefreshIndicator(
                  onRefresh: () => ref.refresh(friendsListProvider.future),
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (n) {
                      if (n.metrics.pixels >= n.metrics.maxScrollExtent * 0.8) {
                        ref.read(friendsListProvider.notifier).loadMore();
                      }
                      return false;
                    },
                    child: ListView.separated(
                      padding: _listPadding,
                      itemCount: s.items.length + 1,
                      separatorBuilder: (_, __) => AppSpacing.vGapMd,
                      itemBuilder: (_, i) => i == s.items.length
                          ? ListFooter(
                              isLoading: s.isLoadingMore,
                              hasMore: s.hasMore,
                              error: s.loadMoreError,
                              endLabel: '',
                            )
                          : PersonCard(
                              key: ValueKey('friend-${s.items[i].id}'),
                              user: s.items[i],
                              style: PersonCardStyle.friend,
                              trailing: CircleIconButton(
                                key: ValueKey('unfriend-${s.items[i].id}'),
                                icon: Icons.person_remove_outlined,
                                iconSize: 20,
                                tooltip: l10n.friendUnfriend,
                                color: AppColors.surfaceContainerHighest,
                                onPressed: () =>
                                    _unfriend(context, ref, s.items[i]),
                              ),
                            ),
                    ),
                  ),
                ),
        );
  }
}

/// Web friends empty state: faded `group_off`, bold message, "Find people".
class _NoFriends extends StatelessWidget {
  const _NoFriends({required this.onFind});

  final VoidCallback onFind;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListView(
      padding:
          const EdgeInsets.symmetric(vertical: 80, horizontal: AppSpacing.lg),
      children: [
        Icon(
          Icons.group_off_outlined,
          size: 48,
          color: AppColors.onSurfaceVariant.withValues(alpha: 0.4),
        ),
        AppSpacing.vGapLg,
        Text(
          l10n.friendsEmptyTitle,
          textAlign: TextAlign.center,
          style: AppTypography.titleLarge
              .copyWith(color: AppColors.onSurfaceVariant),
        ),
        AppSpacing.vGapSm,
        Center(
          child: TextButton(
            key: const Key('friends-find-people'),
            onPressed: onFind,
            child: Text(
              l10n.friendsFindPeople,
              style:
                  AppTypography.titleSmall.copyWith(color: AppColors.primary),
            ),
          ),
        ),
      ],
    );
  }
}

/// Uppercase section overline (web `font-label text-xs font-bold uppercase
/// tracking-widest`) with the web's empty panel underneath when [empty].
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children, this.empty});

  final String title;
  final List<Widget> children;
  final String? empty;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(title,
            padding: const EdgeInsets.fromLTRB(4, 0, 4, AppSpacing.md)),
        if (children.isEmpty && empty != null)
          Container(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppRadius.tile),
            ),
            child: Text(
              empty!,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.onSurfaceVariant),
            ),
          ),
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) AppSpacing.vGapSm,
          children[i],
        ],
      ],
    );
  }
}

class _RequestsTab extends ConsumerWidget {
  const _RequestsTab();

  Future<void> _guard(
    BuildContext context,
    Future<void> Function() f, {
    String? success,
  }) async {
    try {
      await f();
      if (success != null && context.mounted) {
        showToast(context, success, type: ToastType.success);
      }
    } catch (e) {
      if (context.mounted) showErrorToast(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final received = ref.watch(receivedRequestsProvider);
    final sent = ref.watch(sentRequestsProvider);
    if (received.isLoading || sent.isLoading) return const _RowsSkeleton();
    if (received.hasError) {
      return ErrorState(
        error: received.error!,
        onRetry: () => ref.invalidate(receivedRequestsProvider),
      );
    }
    final inbox = (received.valueOrNull ?? const <FriendRequest>[])
        .where((r) => r.status == 'PENDING')
        .toList();
    final outbox = (sent.valueOrNull ?? const <FriendRequest>[])
        .where((r) => r.status == 'PENDING')
        .toList();
    return RefreshIndicator(
      onRefresh: () async {
        ref
          ..invalidate(receivedRequestsProvider)
          ..invalidate(sentRequestsProvider);
      },
      child: ListView(
        padding: _listPadding,
        children: [
          _Section(
            title: l10n.friendsReceived,
            empty: l10n.friendsNoReceived,
            children: [
              for (final r in inbox)
                PersonCard(
                  key: ValueKey('request-${r.id}'),
                  user: r.sender,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PeoplePillButton.primary(
                        key: ValueKey('request-accept-${r.id}'),
                        label: l10n.friendAccept,
                        onTap: () => _guard(
                          context,
                          () => ref
                              .read(receivedRequestsProvider.notifier)
                              .accept(r),
                          success: l10n.friendAccepted,
                        ),
                      ),
                      AppSpacing.hGapSm,
                      PeoplePillButton(
                        key: ValueKey('request-decline-${r.id}'),
                        label: l10n.friendDecline,
                        onTap: () => _guard(
                          context,
                          () => ref
                              .read(receivedRequestsProvider.notifier)
                              .decline(r),
                          success: l10n.friendDeclined,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          AppSpacing.vGapXl,
          _Section(
            title: l10n.friendsSent,
            empty: l10n.friendsNoSent,
            children: [
              for (final r in outbox)
                PersonCard(
                  key: ValueKey('sent-${r.id}'),
                  user: r.receiver,
                  subtitle: l10n.friendPending,
                  trailing: PeoplePillButton(
                    key: ValueKey('request-cancel-${r.id}'),
                    label: l10n.friendCancelRequest,
                    onTap: () => _guard(
                      context,
                      () => ref.read(sentRequestsProvider.notifier).cancel(r),
                      success: l10n.friendCancelled,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FindTab extends ConsumerStatefulWidget {
  const _FindTab();

  @override
  ConsumerState<_FindTab> createState() => _FindTabState();
}

class _FindTabState extends ConsumerState<_FindTab> {
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final results = ref.watch(userSearchProvider(_query));
    return ListView(
      padding: _listPadding,
      children: [
        AppSearchField(
          fieldKey: const Key('find-friends-search'),
          hint: l10n.friendsSearchHint,
          onChanged: (v) {
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 400), () {
              if (mounted) setState(() => _query = v.trim());
            });
          },
        ),
        AppSpacing.vGapXl,
        ...results.when(
          loading: () => [
            for (var i = 0; i < 3; i++) ...[
              const SkeletonBox(
                height: 72,
                borderRadius: BorderRadius.all(Radius.circular(AppRadius.tile)),
              ),
              AppSpacing.vGapSm,
            ],
          ],
          error: (e, _) => [
            ErrorState(
              error: e,
              onRetry: () => ref.invalidate(userSearchProvider(_query)),
            ),
          ],
          data: (users) => [
            if (_query.isEmpty)
              _Section(
                title: l10n.friendsSuggestions,
                empty: l10n.friendsNoSuggestions,
                children: [for (final u in users) _personRow(u)],
              )
            else if (users.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
                child: Column(
                  children: [
                    const Icon(
                      Icons.person_off_outlined,
                      size: 36,
                      color: AppColors.onSurfaceVariant,
                    ),
                    AppSpacing.vGapSm,
                    Text(
                      l10n.searchNoResults(_query),
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyMedium
                          .copyWith(color: AppColors.onSurfaceVariant),
                    ),
                  ],
                ),
              )
            else
              for (final u in users) ...[_personRow(u), AppSpacing.vGapSm],
          ],
        ),
      ],
    );
  }

  Widget _personRow(UserSummary u) => PersonCard(
        user: u,
        trailing: FriendButton(
          userId: u.id,
          compact: true,
          initial: u.friendshipStatus,
        ),
      );
}
