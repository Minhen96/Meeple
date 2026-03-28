import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'connectivity_service.g.dart';

/// Emits `true` when any non-none connectivity result is present.
@Riverpod(keepAlive: true)
Stream<bool> connectivityStream(ConnectivityStreamRef ref) {
  return Connectivity().onConnectivityChanged.map(
    (results) => results.any((r) => r != ConnectivityResult.none),
  );
}

/// One-shot check for current connectivity.
@riverpod
Future<bool> isConnected(IsConnectedRef ref) async {
  final results = await Connectivity().checkConnectivity();
  return results.any((r) => r != ConnectivityResult.none);
}
