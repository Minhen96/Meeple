import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:meeple_hearth/core/constants/api_constants.dart';
import 'package:meeple_hearth/core/network/api_exception.dart';
import 'package:meeple_hearth/core/network/dio_client.dart';
import 'package:meeple_hearth/features/auth/domain/user_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'account_repository.g.dart';

@riverpod
AccountRepository accountRepository(Ref ref) =>
    AccountRepository(ref.read(dioProvider));

/// Account management (GAP §6.1 [WP5]).
final class AccountRepository {
  const AccountRepository(this._dio);

  final Dio _dio;

  /// `DELETE /users/me {password?, confirm?}` — soft delete with a 30-day
  /// grace period. Password accounts confirm with [password];
  /// passwordless (Google) accounts send `confirm: "DELETE"`.
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
  /// verification link to the new address.
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

  Future<List<ActiveSession>> getSessions() => guardApi(() async {
        final res = await _dio.get<Object?>(ApiConstants.sessions);
        return (res.data as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(ActiveSession.fromJson)
            .toList();
      });

  Future<void> revokeSession(String sessionId) => guardApi(
        () => _dio.delete<void>('${ApiConstants.sessions}/$sessionId'),
      );

  Future<void> revokeOtherSessions() => guardApi(
        () => _dio.post<void>('${ApiConstants.sessions}/revoke-others'),
      );

  /// `GET /users/me/export` → 202; the archive link is emailed.
  Future<void> requestExport() =>
      guardApi(() => _dio.get<void>('${ApiConstants.me}/export'));
}
