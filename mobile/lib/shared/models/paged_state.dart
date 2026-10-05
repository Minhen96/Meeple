import 'package:meeple_hearth/shared/models/cursor_page.dart';

/// State of an infinite list backed by a [CursorPage] endpoint.
final class PagedState<T> {
  const PagedState({
    this.items = const [],
    this.nextCursor,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.loadMoreError,
    this.cachedAt,
  });

  factory PagedState.fromPage(CursorPage<T> page, {DateTime? cachedAt}) =>
      PagedState(
        items: page.items,
        nextCursor: page.nextCursor,
        hasMore: page.hasMore,
        cachedAt: cachedAt,
      );

  final List<T> items;
  final String? nextCursor;
  final bool hasMore;
  final bool isLoadingMore;
  final Object? loadMoreError;

  /// Set when the first page came from the offline cache.
  final DateTime? cachedAt;

  bool get canLoadMore => hasMore && !isLoadingMore && nextCursor != null;

  PagedState<T> copyWith({
    List<T>? items,
    String? nextCursor,
    bool? hasMore,
    bool? isLoadingMore,
    Object? loadMoreError,
    bool clearError = false,
    DateTime? cachedAt,
    bool clearCachedAt = false,
  }) =>
      PagedState(
        items: items ?? this.items,
        nextCursor: nextCursor ?? this.nextCursor,
        hasMore: hasMore ?? this.hasMore,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        loadMoreError: clearError ? null : loadMoreError ?? this.loadMoreError,
        cachedAt: clearCachedAt ? null : cachedAt ?? this.cachedAt,
      );

  /// Replaces every item matching [test] with [update]'s result.
  PagedState<T> mapItems(bool Function(T) test, T Function(T) update) =>
      copyWith(items: [for (final i in items) test(i) ? update(i) : i]);

  PagedState<T> removeWhere(bool Function(T) test) =>
      copyWith(items: items.where((i) => !test(i)).toList());
}

/// Fetches the page after [current] and appends it; failures are kept in
/// `loadMoreError` (the list stays visible).
Future<void> loadNextPage<T>({
  required PagedState<T>? current,
  required void Function(PagedState<T>) emit,
  required PagedState<T>? Function() read,
  required Future<CursorPage<T>> Function(String cursor) fetch,
}) async {
  if (current == null || !current.canLoadMore) return;
  emit(current.copyWith(isLoadingMore: true, clearError: true));
  try {
    final next = await fetch(current.nextCursor!);
    final latest = read() ?? current;
    emit(
      latest.copyWith(
        items: [...latest.items, ...next.items],
        nextCursor: next.nextCursor,
        hasMore: next.hasMore && next.nextCursor != null,
        isLoadingMore: false,
      ),
    );
  } catch (e) {
    final latest = read() ?? current;
    emit(latest.copyWith(isLoadingMore: false, loadMoreError: e));
  }
}
