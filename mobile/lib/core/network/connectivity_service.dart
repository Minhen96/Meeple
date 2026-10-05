import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:meeple_hearth/core/network/api_exception.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'connectivity_service.g.dart';

/// Emits `true` while any network interface is up.
@Riverpod(keepAlive: true)
Stream<bool> connectivityStream(Ref ref) async* {
  final connectivity = Connectivity();
  bool online(List<ConnectivityResult> r) =>
      r.any((c) => c != ConnectivityResult.none);
  try {
    yield online(await connectivity.checkConnectivity());
    yield* connectivity.onConnectivityChanged.map(online);
  } catch (_) {
    // Plugin unavailable (tests, unsupported platform): assume online and
    // let API errors speak for themselves.
    yield true;
  }
}

/// True only when the device is known to be offline (unknown counts as
/// online).
@Riverpod(keepAlive: true)
bool isOffline(Ref ref) =>
    ref.watch(connectivityStreamProvider).valueOrNull == false;

/// Write-action guard (docs/MOBILE_FLUTTER.md §11): throws
/// [OfflineException] while offline so no request is attempted.
void ensureOnline(Ref ref) {
  if (ref.read(isOfflineProvider)) throw const OfflineException();
}
