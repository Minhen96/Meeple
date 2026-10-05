import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/router/app_router.dart';
import 'package:meeple_hearth/features/social/domain/social_model.dart';
import 'package:meeple_hearth/features/social/presentation/friend_button.dart';
import 'package:meeple_hearth/features/social/providers/social_provider.dart';
import 'package:meeple_hearth/l10n/l10n.dart';
import 'package:meeple_hearth/shared/widgets/app_toast.dart';
import 'package:meeple_hearth/shared/widgets/empty_state.dart';
import 'package:meeple_hearth/shared/widgets/error_state.dart';
import 'package:meeple_hearth/shared/widgets/meeple_app_bar.dart';
import 'package:meeple_hearth/shared/widgets/status_banners.dart';
import 'package:meeple_hearth/shared/widgets/user_widgets.dart';

/// Friends, friend requests (received + sent) and people search.
class FriendsScreen extends StatelessWidget {
  const FriendsScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DefaultTabController(
      length: 3,
      initialIndex: initialTab,
      child: Scaffold(
        appBar: MeepleAppBar(
          title: l10n.friendsTitle,
          showBackButton: true,
          fallbackRoute: AppRoutes.profile,
        ),
        body: Column(
          children: [
            TabBar(
              dividerColor: AppColors.transparent,
              tabs: [
                Tab(text: l10n.friendsTabFriends),
                Tab(text: l10n.friendsTabRequests),
                Tab(text: l10n.friendsTabFind),
              ],
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

class _FriendsTab extends ConsumerWidget {
  const _FriendsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return ref.watch(friendsListProvider).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorState(
            error: e,
            onRetry: () => ref.invalidate(friendsListProvider),
          ),
          data: (s) => s.items.isEmpty
              ? EmptyState(
                  icon: Icons.group_outlined,
                  title: l10n.friendsEmptyTitle,
                  subtitle: l10n.friendsEmptyBody,
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
                    child: ListView.builder(
                      itemCount: s.items.length + 1,
                      itemBuilder: (_, i) => i == s.items.length
                          ? ListFooter(
                              isLoading: s.isLoadingMore,
                              hasMore: s.hasMore,
                              error: s.loadMoreError,
                              endLabel: '',
                            )
                          : UserRow(user: s.items[i]),
                    ),
                  ),
                ),
        );
  }
}

class _RequestsTab extends ConsumerWidget {
  const _RequestsTab();

  Future<void> _guard(BuildContext context, Future<void> Function() f) async {
    try {
      await f();
    } catch (e) {
      if (context.mounted) showErrorToast(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final received = ref.watch(receivedRequestsProvider);
    final sent = ref.watch(sentRequestsProvider);
    if (received.isLoading || sent.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (received.hasError) {
      return ErrorState(
        error: received.error!,
        onRetry: () => ref.invalidate(receivedRequestsProvider),
      );
    }
    final inbox = received.valueOrNull ?? const <FriendRequest>[];
    final outbox = (sent.valueOrNull ?? const <FriendRequest>[])
        .where((r) => r.status == 'PENDING')
        .toList();
    final pendingIn = inbox.where((r) => r.status == 'PENDING').toList();
    if (pendingIn.isEmpty && outbox.isEmpty) {
      return EmptyState(
        icon: Icons.mark_email_read_outlined,
        title: l10n.friendsNoRequests,
      );
    }
    return RefreshIndicator(
      onRefresh: () async {
        ref
          ..invalidate(receivedRequestsProvider)
          ..invalidate(sentRequestsProvider);
      },
      child: ListView(
        children: [
          if (pendingIn.isNotEmpty) ...[
            SectionHeader(title: l10n.friendsReceived),
            for (final r in pendingIn)
              UserRow(
                key: ValueKey('request-${r.id}'),
                user: r.sender,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FilledButton(
                      key: ValueKey('request-accept-${r.id}'),
                      onPressed: () => _guard(
                        context,
                        () => ref.read(receivedRequestsProvider.notifier).accept(r),
                      ),
                      child: Text(l10n.friendAccept),
                    ),
                    AppSpacing.hGapXs,
                    TextButton(
                      key: ValueKey('request-decline-${r.id}'),
                      onPressed: () => _guard(
                        context,
                        () =>
                            ref.read(receivedRequestsProvider.notifier).decline(r),
                      ),
                      child: Text(l10n.friendDecline),
                    ),
                  ],
                ),
              ),
          ],
          if (outbox.isNotEmpty) ...[
            SectionHeader(title: l10n.friendsSent),
            for (final r in outbox)
              UserRow(
                user: r.receiver,
                trailing: OutlinedButton(
                  onPressed: () => _guard(
                    context,
                    () => ref.read(sentRequestsProvider.notifier).cancel(r),
                  ),
                  child: Text(l10n.friendCancelRequest),
                ),
              ),
          ],
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: TextField(
            key: const Key('find-friends-search'),
            onChanged: (v) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 400), () {
                if (mounted) setState(() => _query = v.trim());
              });
            },
            decoration: InputDecoration(
              hintText: l10n.friendsSearchHint,
              prefixIcon: const Icon(Icons.search_rounded),
            ),
          ),
        ),
        Expanded(
          child: results.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ErrorState(
              error: e,
              onRetry: () => ref.invalidate(userSearchProvider(_query)),
            ),
            data: (users) => users.isEmpty
                ? EmptyState(
                    icon: Icons.person_search_outlined,
                    title: _query.isEmpty
                        ? l10n.friendsNoSuggestions
                        : l10n.searchNoResults(_query),
                  )
                : ListView(
                    children: [
                      if (_query.isEmpty)
                        SectionHeader(title: l10n.friendsSuggestions),
                      for (final u in users)
                        UserRow(
                          user: u,
                          trailing: FriendButton(
                            userId: u.id,
                            compact: true,
                            initial: u.friendshipStatus,
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
