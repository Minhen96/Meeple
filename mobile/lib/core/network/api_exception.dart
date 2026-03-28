import 'package:dio/dio.dart';

/// Typed API errors surfaced to the presentation layer.
///
/// Use [ApiException.from] to convert any raw error into a typed exception.
/// Each subtype carries a user-facing [message] appropriate for display.
sealed class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => 'ApiException: $message';

  /// Converts a [DioException] or any other error into a typed [ApiException].
  factory ApiException.from(Object error) {
    if (error is DioException) {
      return switch (error.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.sendTimeout =>
          const TimeoutException(),
        DioExceptionType.connectionError => const NetworkException(),
        DioExceptionType.badResponse => _fromStatusCode(
          error.response?.statusCode,
          error.response?.data,
        ),
        _ => UnexpectedException(error.message ?? 'An unexpected error occurred'),
      };
    }
    if (error is ApiException) return error;
    return UnexpectedException(error.toString());
  }

  static ApiException _fromStatusCode(int? code, dynamic data) {
    final serverMessage = data is Map ? data['message'] as String? : null;
    return switch (code) {
      400 => BadRequestException(serverMessage ?? 'Invalid request.'),
      401 => const UnauthorizedException(),
      403 => const ForbiddenException(),
      404 => const NotFoundException(),
      409 => ConflictException(serverMessage ?? 'Conflict.'),
      422 => ValidationException(serverMessage ?? 'Validation failed.'),
      429 => const RateLimitException(),
      500 || 502 || 503 => const ServerException(),
      _ => UnexpectedException(serverMessage ?? 'An unexpected error occurred.'),
    };
  }
}

final class NetworkException extends ApiException {
  const NetworkException()
      : super('No internet connection. Please check your network.');
}

final class TimeoutException extends ApiException {
  const TimeoutException()
      : super('Request timed out. Please try again.');
}

final class UnauthorizedException extends ApiException {
  const UnauthorizedException()
      : super('Your session has expired. Please log in again.');
}

final class ForbiddenException extends ApiException {
  const ForbiddenException()
      : super('You do not have permission to perform this action.');
}

final class NotFoundException extends ApiException {
  const NotFoundException()
      : super('The requested resource was not found.');
}

final class BadRequestException extends ApiException {
  const BadRequestException(super.message);
}

final class ConflictException extends ApiException {
  const ConflictException(super.message);
}

final class ValidationException extends ApiException {
  const ValidationException(super.message);
}

final class RateLimitException extends ApiException {
  const RateLimitException()
      : super('Too many requests. Please slow down and try again.');
}

final class ServerException extends ApiException {
  const ServerException()
      : super('Something went wrong on our end. Please try again later.');
}

final class UnexpectedException extends ApiException {
  const UnexpectedException(super.message);
}
