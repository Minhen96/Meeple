import 'package:flutter/foundation.dart';
import 'package:meeple_hearth/features/auth/providers/auth_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'router_notifier.g.dart';

/// Bridges Riverpod auth state changes into a [Listenable] for GoRouter.
///
/// GoRouter calls [refreshListenable] after each navigation event. By watching
/// [authNotifierProvider] here, any auth state change (login, logout, token
/// refresh) automatically triggers GoRouter's redirect evaluation.
@Riverpod(keepAlive: true)
class RouterNotifier extends _$RouterNotifier implements Listenable {
  VoidCallback? _routerListener;

  @override
  void build() {
    // Listen to auth state — call the router listener whenever it changes.
    ref.listen<AsyncValue<Object?>>(
      authNotifierProvider,
      (_, __) => _routerListener?.call(),
    );
  }

  @override
  void addListener(VoidCallback listener) => _routerListener = listener;

  @override
  void removeListener(VoidCallback listener) => _routerListener = null;
}
