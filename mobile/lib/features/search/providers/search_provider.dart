import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:meeple_hearth/core/storage/secure_storage.dart';
import 'package:meeple_hearth/features/auth/providers/auth_provider.dart';
import 'package:meeple_hearth/features/search/data/search_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'search_provider.g.dart';

/// Unified search results for a (debounced) query.
@riverpod
Future<SearchResults> searchResults(Ref ref, String query) {
  final q = query.trim();
  if (q.isEmpty) return Future.value(const SearchResults());
  return ref.read(searchRepositoryProvider).search(q);
}

/// The last 8 searches, stored on the device per account (SCREENS §13).
///
/// Rebuilds when the signed-in account changes, so one account never sees
/// another's searches; nothing is stored or shown while signed out.
@Riverpod(keepAlive: true)
class RecentSearches extends _$RecentSearches {
  /// Pre-scoping key shared by every account; removed on first load.
  static const _legacyPrefKey = 'recent_searches';
  static const max = 8;

  static String prefKeyFor(String userId) => 'recent_searches_$userId';

  String? _userId;

  @override
  Future<List<String>> build() async {
    final userId = _userId = ref.watch(authUserIdProvider);
    if (userId == null) return const [];
    try {
      final storage = ref.read(secureStorageProvider);
      await storage.deletePref(_legacyPrefKey);
      final raw = await storage.readPref(prefKeyFor(userId));
      if (raw == null) return const [];
      return (jsonDecode(raw) as List<dynamic>).whereType<String>().toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> add(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    final current = state.valueOrNull ?? const [];
    final next = [q, ...current.where((s) => s.toLowerCase() != q.toLowerCase())]
        .take(max)
        .toList();
    state = AsyncValue.data(next);
    await _persist(next);
  }

  Future<void> remove(String query) async {
    final next = [...?state.valueOrNull]..remove(query);
    state = AsyncValue.data(next);
    await _persist(next);
  }

  Future<void> clear() async {
    state = const AsyncValue.data([]);
    await _persist(const []);
  }

  Future<void> _persist(List<String> items) async {
    final userId = _userId;
    if (userId == null) return;
    try {
      await ref
          .read(secureStorageProvider)
          .writePref(prefKeyFor(userId), jsonEncode(items));
    } catch (_) {
      // Best effort.
    }
  }
}
