import 'package:dio/dio.dart';
import 'package:meeple_hearth/core/constants/api_constants.dart';
import 'package:meeple_hearth/core/network/api_exception.dart';
import 'package:meeple_hearth/core/network/dio_client.dart';
import 'package:meeple_hearth/features/auth/domain/auth_response.dart';
import 'package:meeple_hearth/features/auth/domain/user_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_remote_data_source.g.dart';

@riverpod
AuthRemoteDataSource authRemoteDataSource(AuthRemoteDataSourceRef ref) =>
    AuthRemoteDataSource(ref.read(dioProvider));

final class AuthRemoteDataSource {
  const AuthRemoteDataSource(this._dio);

  final Dio _dio;

  Future<AuthResponse> login({
    required String emailOrUsername,
    required String password,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        ApiConstants.login,
        data: {'emailOrUsername': emailOrUsername, 'password': password},
      );
      return AuthResponse.fromJson(res.data!);
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  Future<AuthResponse> register({
    required String username,
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        ApiConstants.register,
        data: {
          'username': username,
          'email': email,
          'password': password,
          'displayName': displayName,
        },
      );
      return AuthResponse.fromJson(res.data!);
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  Future<void> logout() async {
    try {
      await _dio.post<void>(ApiConstants.logout);
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  Future<AuthResponse> refreshToken({required String refreshToken}) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        ApiConstants.refresh,
        data: {'refreshToken': refreshToken},
      );
      return AuthResponse.fromJson(res.data!);
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  Future<void> forgotPassword({required String email}) async {
    try {
      await _dio.post<void>(
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
      await _dio.post<void>(
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
}
