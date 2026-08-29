/// Mirror of the backend `CursorPage<T>` envelope: `{ items, nextCursor, hasMore }`.
class PagedResult<T> {
  const PagedResult({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
  });

  final List<T> items;
  final String? nextCursor;
  final bool hasMore;

  factory PagedResult.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromItem,
  ) {
    final rawItems = (json['items'] as List?) ?? const [];
    return PagedResult<T>(
      items: rawItems
          .map((e) => fromItem(e as Map<String, dynamic>))
          .toList(),
      nextCursor: json['nextCursor'] as String?,
      hasMore: json['hasMore'] as bool? ?? false,
    );
  }

  static PagedResult<T> empty<T>() =>
      PagedResult<T>(items: const [], nextCursor: null, hasMore: false);
}
