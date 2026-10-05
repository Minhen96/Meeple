import 'package:isar/isar.dart';
import 'package:meeple_hearth/core/storage/cache_entry.dart';
import 'package:meeple_hearth/core/utils/app_logger.dart';
import 'package:path_provider/path_provider.dart';

/// Singleton managing the Isar local database (offline read cache).
///
/// Call [initialize] in `main()`. When it fails (or is never called, as in
/// tests) [isInitialized] stays false and the app reads from the network only.
///
/// **Schema generation:** `cache_entry.g.dart` is generated with
/// `isar_generator 3.1.0+1` in an isolated package (it pins an analyzer that
/// conflicts with riverpod_generator); see docs/MOBILE_FLUTTER.md §6.
final class IsarService {
  IsarService._();

  static final IsarService instance = IsarService._();

  Isar? _isar;

  Isar? get isarOrNull => _isar;

  bool get isInitialized => _isar != null;

  Future<void> initialize() async {
    if (_isar != null) return;
    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open(
      [CacheEntrySchema],
      directory: dir.path,
      name: 'meeple_hearth_cache',
    );
    AppLogger.info('Isar cache opened');
  }

  Future<void> close() async {
    await _isar?.close();
    _isar = null;
  }
}
