import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:meeple_hearth/core/network/api_exception.dart';
import 'package:meeple_hearth/core/network/connectivity_service.dart';
import 'package:meeple_hearth/features/auth/domain/user_model.dart';
import 'package:meeple_hearth/features/auth/providers/auth_provider.dart';
import 'package:meeple_hearth/features/settings/data/account_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'settings_provider.g.dart';

/// Active sessions (refresh tokens) of the account.
@riverpod
class ActiveSessions extends _$ActiveSessions {
  @override
  Future<List<ActiveSession>> build() =>
      ref.read(accountRepositoryProvider).getSessions();

  Future<void> revoke(String sessionId) async {
    ensureOnline(ref);
    await ref.read(accountRepositoryProvider).revokeSession(sessionId);
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncValue.data(current.where((s) => s.id != sessionId).toList());
    }
  }

  /// 401 `SESSION_INVALID` from `revoke-others`: the server could not match
  /// this device's refresh cookie to a live session.
  static bool isSessionInvalid(Object error) =>
      error is UnauthorizedException && error.code == 'SESSION_INVALID';

  /// Signs every other device out. On `SESSION_INVALID` the list is reloaded
  /// (it is likely stale) and the error rethrown for a friendly message.
  Future<void> revokeOthers() async {
    ensureOnline(ref);
    try {
      await ref.read(accountRepositoryProvider).revokeOtherSessions();
    } catch (e) {
      if (isSessionInvalid(e)) ref.invalidateSelf();
      rethrow;
    }
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncValue.data(current.where((s) => s.current).toList());
    }
  }
}

@riverpod
AccountActions accountActions(Ref ref) => AccountActions(ref);

final class AccountActions {
  AccountActions(this._ref);

  final Ref _ref;

  AccountRepository get _repo => _ref.read(accountRepositoryProvider);

  /// Soft-deletes the account (30-day grace) and signs out locally — the
  /// server has already revoked every session.
  Future<void> deleteAccount({String? password}) async {
    ensureOnline(_ref);
    await _repo.deleteAccount(
      password: password,
      confirm: password == null ? 'DELETE' : null,
    );
    await _ref.read(authNotifierProvider.notifier).signOutLocally();
  }

  Future<void> changeEmail({
    required String currentPassword,
    required String newEmail,
  }) {
    ensureOnline(_ref);
    return _repo.changeEmail(
      currentPassword: currentPassword,
      newEmail: newEmail,
    );
  }

  Future<void> sendPasswordReset(String email) {
    ensureOnline(_ref);
    return _repo.sendPasswordReset(email);
  }

  Future<void> requestExport() {
    ensureOnline(_ref);
    return _repo.requestExport();
  }
}
