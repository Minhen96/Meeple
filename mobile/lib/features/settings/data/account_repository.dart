import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:meeple_hearth/core/constants/api_constants.dart';
import 'package:meeple_hearth/core/network/api_exception.dart';
import 'package:meeple_hearth/core/network/auth_session.dart';
import 'package:meeple_hearth/core/network/dio_client.dart';
import 'package:meeple_hearth/features/auth/domain/user_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'account_repository.g.dart';

@riverpod
AccountRepository accountRepository(Ref ref) => AccountRepository(
      ref.read(dioProvider),
      ref.read(authSessionManagerProvider),
    );

/// Account management (GAP §6.1 [WP5]).
final class AccountRepository {
  const AccountRepository(this._dio, this._session);

  final Dio _dio;
  final AuthSessionManager _session;

  /// The backend tells this device's session apart from the others by its
  /// refresh-token cookie, which a native client must send explicitly.
  Future<Options> _sessionOptions() async =>
      Options(headers: await _session.sessionCookieHeader());

  /// `DELETE /users/me {password?, confirm?}` — soft delete with a 30-day
  /// grace period. Password accounts confirm with [password] (400
  /// `PASSWORD_REQUIRED` / `INVALID_PASSWORD`); passwordless (Google)
  /// accounts send `confirm: "DELETE"` (400 `CONFIRMATION_REQUIRED`).
  Future<void> deleteAccount({String? password, String? confirm}) => guardApi(
        () => _dio.delete<void>(
          ApiConstants.me,
          data: {
            if (password != null) 'password': password,
            if (confirm != null) 'confirm': confirm,
          },
        ),
      );

  /// `POST /users/me/change-email {currentPassword, newEmail}` — sends a
  /// verification link to the new address. 400 `INVALID_PASSWORD` /
  /// `EMAIL_UNCHANGED`, 409 `EMAIL_TAKEN`.
  Future<void> changeEmail({
    required String currentPassword,
    required String newEmail,
  }) =>
      guardApi(
        () => _dio.post<void>(
          '${ApiConstants.me}/change-email',
          data: {'currentPassword': currentPassword, 'newEmail': newEmail},
        ),
      );

  /// Password changes go through the reset email (as on the web).
  Future<void> sendPasswordReset(String email) => guardApi(
        () => _dio.post<void>(
          ApiConstants.forgotPassword,
          data: {'email': email},
        ),
      );

  /// `GET /auth/sessions` — signed-in devices; `current` marks this one.
  Future<List<ActiveSession>> getSessions() => guardApi(() async {
        final res = await _dio.get<Object?>(
          ApiConstants.sessions,
          options: await _sessionOptions(),
        );
        return (res.data as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(ActiveSession.fromJson)
            .toList();
      });

  /// `DELETE /auth/sessions/{id}` — signs one other device out; [sessionId]
  /// is the opaque id from [getSessions] (400
  /// `CANNOT_REVOKE_CURRENT_SESSION` for this one).
  Future<void> revokeSession(String sessionId) => guardApi(
        () async => _dio.delete<void>(
          '${ApiConstants.sessions}/${Uri.encodeComponent(sessionId)}',
          options: await _sessionOptions(),
        ),
      );

  /// `POST /auth/sessions/revoke-others` → `{revoked}`. Every other device is
  /// signed out and all access tokens are invalidated; the reissued access
  /// token for this device (`Set-Cookie`) is stored. Returns the number of
  /// sessions ended.
  Future<int> revokeOtherSessions() => guardApi(() async {
        final res = await _dio.post<Object?>(
          '${ApiConstants.sessions}/revoke-others',
          options: await _sessionOptions(),
        );
        final access = extractAccessToken(res);
        if (access != null) await _session.replaceAccessToken(access);
        final body = res.data;
        return body is Map ? (body['revoked'] as num?)?.toInt() ?? 0 : 0;
      });

  /// `GET /users/me/export` → 202 `{id, status, createdAt, completedAt}`;
  /// the archive link is emailed.
  Future<void> requestExport() =>
      guardApi(() => _dio.get<void>('${ApiConstants.me}/export'));
}
