import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/features/social/providers/social_provider.dart';
import 'package:meeple_hearth/l10n/l10n.dart';
import 'package:meeple_hearth/shared/models/user_summary.dart';
import 'package:meeple_hearth/shared/widgets/app_avatar.dart';
import 'package:meeple_hearth/shared/widgets/app_button.dart';
import 'package:meeple_hearth/shared/widgets/error_state.dart';

/// Multi-select of the viewer's friends (invite to event, tag in post).
/// Resolves to the selection, or null when dismissed.
Future<List<UserSummary>?> showFriendPicker(
  BuildContext context, {
  required String title,
  List<UserSummary> initial = const [],
  Set<String> exclude = const {},
}) =>
    showModalBottomSheet<List<UserSummary>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: AppColors.surfaceContainerLowest,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.85,
        child: FriendPicker(title: title, initial: initial, exclude: exclude),
      ),
    );

class FriendPicker extends ConsumerStatefulWidget {
  const FriendPicker({
    super.key,
    required this.title,
    this.initial = const [],
    this.exclude = const {},
  });

  final String title;
  final List<UserSummary> initial;
  final Set<String> exclude;

  @override
  ConsumerState<FriendPicker> createState() => _FriendPickerState();
}

class _FriendPickerState extends ConsumerState<FriendPicker> {
  late final Map<String, UserSummary> _selected = {
    for (final u in widget.initial) u.id: u,
  };
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final friends = ref.watch(friendsListProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Text(widget.title, style: AppTypography.titleLarge),
        ),
        if (_selected.isNotEmpty)
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              children: [
                for (final u in _selected.values)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.xs),
                    child: InputChip(
                      avatar: AppAvatar(
                        imageUrl: u.avatarUrl,
                        displayName: u.displayName,
                        size: AvatarSize.xs,
                      ),
                      label: Text(u.displayName),
                      side: BorderSide.none,
                      shape: const StadiumBorder(),
                      onDeleted: () => setState(() => _selected.remove(u.id)),
                    ),
                  ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: TextField(
            key: const Key('friend-picker-search'),
            onChanged: (v) => setState(() => _filter = v.trim().toLowerCase()),
            decoration: InputDecoration(
              hintText: l10n.friendPickerSearch,
              prefixIcon: const Icon(Icons.search_rounded),
            ),
          ),
        ),
        Expanded(
          child: friends.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ErrorState(
              error: e,
              onRetry: () => ref.invalidate(friendsListProvider),
            ),
            data: (state) {
              final list = state.items
                  .where((u) => !widget.exclude.contains(u.id))
                  .where(
                    (u) =>
                        _filter.isEmpty ||
                        u.displayName.toLowerCase().contains(_filter) ||
                        u.username.toLowerCase().contains(_filter),
                  )
                  .toList();
              if (list.isEmpty) {
                return Center(
                  child: Text(l10n.friendPickerEmpty, style: AppTypography.bodyMedium),
                );
              }
              return ListView.builder(
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final u = list[i];
                  final checked = _selected.containsKey(u.id);
                  return CheckboxListTile(
                    key: ValueKey('friend-pick-${u.id}'),
                    value: checked,
                    onChanged: (v) => setState(() {
                      v == true ? _selected[u.id] = u : _selected.remove(u.id);
                    }),
                    secondary: AppAvatar(
                      imageUrl: u.avatarUrl,
                      displayName: u.displayName,
                    ),
                    title: Text(u.displayName),
                    subtitle: Text('@${u.username}'),
                  );
                },
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: AppButton(
              key: const Key('friend-picker-done'),
              label: l10n.friendPickerDone(_selected.length),
              onPressed: () =>
                  Navigator.of(context).pop(_selected.values.toList()),
            ),
          ),
        ),
      ],
    );
  }
}
