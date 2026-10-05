import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:meeple_hearth/core/storage/secure_storage.dart';
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

/// The last 8 searches, stored on the device (SCREENS §13).
@Riverpod(keepAlive: true)
class RecentSearches extends _$RecentSearches {
  static const _prefKey = 'recent_searches';
  static const max = 8;

  @override
  Future<List<String>> build() async {
    try {
      final raw = await ref.read(secureStorageProvider).readPref(_prefKey);
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
    try {
      await ref
          .read(secureStorageProvider)
          .writePref(_prefKey, jsonEncode(items));
    } catch (_) {
      // Best effort.
    }
  }
}
