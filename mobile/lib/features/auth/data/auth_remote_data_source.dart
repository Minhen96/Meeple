import 'package:dio/dio.dart';
import 'package:meeple_hearth/core/constants/api_constants.dart';
import 'package:meeple_hearth/core/network/api_exception.dart';
import 'package:meeple_hearth/core/network/auth_session.dart';
import 'package:meeple_hearth/core/network/dio_client.dart';
import 'package:meeple_hearth/features/auth/domain/user_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_remote_data_source.g.dart';

@riverpod
AuthRemoteDataSource authRemoteDataSource(AuthRemoteDataSourceRef ref) =>
    AuthRemoteDataSource(ref.read(dioProvider));

/// Result of an endpoint that signs the user in.
final class AuthResult {
  const AuthResult({required this.user, required this.tokens});

  final User user;
  final AuthTokens tokens;
}

final class AuthRemoteDataSource {
  const AuthRemoteDataSource(this._dio);

  final Dio _dio;

  /// `POST /auth/login` → `AuthResponse` body + token cookies.
  ///
  /// Throws [EmailNotVerifiedException] (only after a correct password),
  /// [UnauthorizedException] for invalid credentials, and
  /// [RateLimitException] while the account is locked for this device's IP.
  Future<AuthResult> login({
    required String emailOrUsername,
    required String password,
  }) =>
      _signIn(
        ApiConstants.login,
        {'emailOrUsername': emailOrUsername, 'password': password},
      );

  /// `POST /auth/register` — creates the account and emails a verification
  /// link. Issues no tokens: the user signs in after verifying.
  Future<void> register({
    required String username,
    required String email,
    required String password,
  }) async {
    try {
      await _dio.post<dynamic>(
        ApiConstants.register,
        data: {'username': username, 'email': email, 'password': password},
      );
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  /// `POST /auth/verify-email` — verifies and signs the user in.
  Future<AuthResult> verifyEmail({required String token}) =>
      _signIn(ApiConstants.verifyEmail, {'token': token});

  /// `POST /auth/google` with a Google ID token.
  ///
  /// Throws [UnauthorizedException] with code `GOOGLE_EMAIL_NOT_VERIFIED` /
  /// `INVALID_GOOGLE_TOKEN`, or [ConflictException] with code
  /// `GOOGLE_ACCOUNT_CONFLICT` when the email belongs to another account.
  Future<AuthResult> googleLogin({required String idToken}) =>
      _signIn(ApiConstants.googleLogin, {'idToken': idToken});

  Future<void> resendVerification({required String email}) async {
    try {
      await _dio.post<dynamic>(
        ApiConstants.resendVerification,
        data: {'email': email},
      );
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  /// `POST /auth/logout` — the backend revokes the refresh token sent as the
  /// `refresh_token` cookie.
  Future<void> logout({String? refreshToken}) async {
    try {
      await _dio.post<dynamic>(
        ApiConstants.logout,
        options: Options(
          headers: {
            if (refreshToken != null) 'Cookie': 'refresh_token=$refreshToken',
          },
        ),
      );
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  Future<void> forgotPassword({required String email}) async {
    try {
      await _dio.post<dynamic>(
        ApiConstants.forgotPassword,
        data: {'email': email},
      );
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    try {
      await _dio.post<dynamic>(
        ApiConstants.resetPassword,
        data: {'token': token, 'newPassword': newPassword},
      );
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  Future<User> getMe() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(ApiConstants.me);
      return User.fromJson(res.data!);
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  Future<AuthResult> _signIn(String path, Map<String, dynamic> body) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(path, data: body);
      final tokens = extractAuthTokens(res);
      if (tokens == null) {
        throw const UnexpectedException('Sign-in response carried no session.');
      }
      return AuthResult(user: User.fromJson(res.data!), tokens: tokens);
    } catch (e) {
      throw ApiException.from(e);
    }
  }
}
