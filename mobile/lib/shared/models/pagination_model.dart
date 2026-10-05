/// A paginated API response.
///
/// Parses both page shapes the backend returns:
///
/// * `PageResponse` (feed, comments, user search):
///   `{ "data": [...], "meta": { "page": 1, "limit": 20, "total": 150, "hasMore": true } }`
///   — `meta.page` is 1-based.
/// * Spring `Page` serialised via DTO (game browse), after the `{ "data": … }`
///   envelope was unwrapped:
///   `{ "content": [...], "page": { "size": 20, "number": 0, "totalElements": 100, "totalPages": 5 } }`
///
/// [page] is always 0-based, matching the `page` query parameter the backend
/// accepts.
final class PaginatedResult<T> {
  const PaginatedResult({
    required this.content,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
    required this.last,
  });

  final List<T> content;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;
  final bool last;

  factory PaginatedResult.fromJson(
    Map<String, dynamic> json,
    T Function(Object?) fromJsonT,
  ) {
    final meta = json['meta'];
    if (meta is Map) {
      final items =
          (json['data'] as List<dynamic>? ?? const []).map(fromJsonT).toList();
      final size = (meta['limit'] as num?)?.toInt() ?? items.length;
      final total = (meta['total'] as num?)?.toInt() ?? items.length;
      return PaginatedResult(
        content: items,
        page: ((meta['page'] as num?)?.toInt() ?? 1) - 1,
        size: size,
        totalElements: total,
        totalPages: size > 0 ? (total + size - 1) ~/ size : 0,
        last: !(meta['hasMore'] as bool? ?? false),
      );
    }

    final items =
        (json['content'] as List<dynamic>? ?? const []).map(fromJsonT).toList();
    final pageInfo = json['page'];
    if (pageInfo is Map) {
      final number = (pageInfo['number'] as num?)?.toInt() ?? 0;
      final totalPages = (pageInfo['totalPages'] as num?)?.toInt() ?? 0;
      return PaginatedResult(
        content: items,
        page: number,
        size: (pageInfo['size'] as num?)?.toInt() ?? items.length,
        totalElements:
            (pageInfo['totalElements'] as num?)?.toInt() ?? items.length,
        totalPages: totalPages,
        last: number + 1 >= totalPages,
      );
    }

    // Legacy Spring PageImpl shape.
    return PaginatedResult(
      content: items,
      page: (json['number'] as num?)?.toInt() ?? 0,
      size: (json['size'] as num?)?.toInt() ?? items.length,
      totalElements: (json['totalElements'] as num?)?.toInt() ?? items.length,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 0,
      last: json['last'] as bool? ?? true,
    );
  }

  /// Wraps a complete (unpaginated) list.
  factory PaginatedResult.single(List<T> items) => PaginatedResult(
        content: items,
        page: 0,
        size: items.length,
        totalElements: items.length,
        totalPages: 1,
        last: true,
      );

  bool get hasMore => !last;
  bool get isEmpty => content.isEmpty;
  bool get isNotEmpty => content.isNotEmpty;
}

/// Query parameters for paginated requests (0-based page).
final class PageParams {
  const PageParams({this.page = 0, this.size = 20});

  final int page;
  final int size;

  Map<String, dynamic> toQueryParams() => {'page': page, 'size': size};

  PageParams nextPage() => PageParams(page: page + 1, size: size);
}
