/// A paginated API response wrapper.
///
/// Mirrors the Spring Boot `Page<T>` response shape:
/// ```json
/// { "content": [...], "page": 0, "size": 20,
///   "totalElements": 100, "totalPages": 5, "last": false }
/// ```
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
    return PaginatedResult(
      content: (json['content'] as List<dynamic>).map(fromJsonT).toList(),
      page: (json['page'] as num?)?.toInt() ?? 0,
      size: (json['size'] as num?)?.toInt() ?? 20,
      totalElements: (json['totalElements'] as num?)?.toInt() ?? 0,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 0,
      last: json['last'] as bool? ?? true,
    );
  }

  bool get hasMore => !last;
  bool get isEmpty => content.isEmpty;
  bool get isNotEmpty => content.isNotEmpty;
}

/// Query parameters for paginated requests.
final class PageParams {
  const PageParams({this.page = 0, this.size = 20});

  final int page;
  final int size;

  Map<String, dynamic> toQueryParams() => {'page': page, 'size': size};

  PageParams nextPage() => PageParams(page: page + 1, size: size);
}
