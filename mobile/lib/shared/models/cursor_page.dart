/// A cursor-paginated list (`{items, nextCursor, hasMore}`, GAP §6.1).
///
/// [CursorPage.fromJson] also accepts the legacy `PageResponse` shape
/// (`{data, meta:{page, hasMore}}`) that endpoints return until their cursor
/// version ships; the next page number is then carried in [nextCursor]
/// prefixed with `page:` (see [legacyPageOf]).
final class CursorPage<T> {
  const CursorPage({
    required this.items,
    this.nextCursor,
    this.hasMore = false,
  });

  const CursorPage.empty()
      : items = const [],
        nextCursor = null,
        hasMore = false;

  final List<T> items;
  final String? nextCursor;
  final bool hasMore;

  static const _legacyPrefix = 'page:';

  factory CursorPage.fromJson(
    Object? json,
    T Function(Map<String, dynamic> item) fromItem,
  ) {
    List<T> parse(Object? list) => (list as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(fromItem)
        .toList();

    if (json is List) {
      return CursorPage(items: parse(json));
    }
    if (json is! Map<String, dynamic>) return CursorPage<T>.empty();

    if (json.containsKey('items')) {
      final next = json['nextCursor'] as String?;
      return CursorPage(
        items: parse(json['items']),
        nextCursor: next,
        hasMore: (json['hasMore'] as bool?) ?? next != null,
      );
    }

    final meta = json['meta'];
    if (meta is Map) {
      final hasMore = meta['hasMore'] as bool? ?? false;
      // meta.page is 1-based; the `page` query parameter is 0-based.
      final page = (meta['page'] as num?)?.toInt() ?? 1;
      return CursorPage(
        items: parse(json['data']),
        nextCursor: hasMore ? '$_legacyPrefix$page' : null,
        hasMore: hasMore,
      );
    }
    return CursorPage<T>.empty();
  }

  /// The 0-based page number encoded by a legacy cursor, or null for a real
  /// (timestamp) cursor.
  static int? legacyPageOf(String? cursor) =>
      cursor != null && cursor.startsWith(_legacyPrefix)
          ? int.tryParse(cursor.substring(_legacyPrefix.length))
          : null;

  /// Query parameters for fetching the page after [cursor].
  static Map<String, dynamic> query(String? cursor, int limit) {
    final legacyPage = legacyPageOf(cursor);
    return {
      'limit': limit,
      'size': limit,
      if (legacyPage != null) 'page': legacyPage,
      if (cursor != null && legacyPage == null) 'cursor': cursor,
    };
  }

  CursorPage<T> append(CursorPage<T> next) => CursorPage(
        items: [...items, ...next.items],
        nextCursor: next.nextCursor,
        hasMore: next.hasMore,
      );

  CursorPage<T> copyWithItems(List<T> newItems) =>
      CursorPage(items: newItems, nextCursor: nextCursor, hasMore: hasMore);

  Map<String, dynamic> toJson(Object? Function(T item) toItem) => {
        'items': items.map(toItem).toList(),
        'nextCursor': nextCursor,
        'hasMore': hasMore,
      };
}
