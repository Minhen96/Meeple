import 'package:dio/dio.dart';

/// Typed API error.
///
/// Backend error bodies have the shape `{ "error": "Human message", "code": "SNAKE_CASE" }`
/// (see `common/dto/ErrorResponse` in the backend). [code] carries the machine-readable
/// code so callers can branch on it (e.g. `EMAIL_NOT_VERIFIED`, `INVALID_IMAGE_KEY`).
sealed class ApiException implements Exception {
  const ApiException(this.message, {this.code});

  final String message;

  /// Backend error code, when the server returned one.
  final String? code;

  @override
  String toString() => 'ApiException(${code ?? '-'}): $message';

  factory ApiException.from(Object error) {
    if (error is ApiException) return error;
    if (error is DioException) {
      if (error.error is ApiException) return error.error! as ApiException;
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
        _ => const UnexpectedException('An unexpected error occurred.'),
      };
    }
    return const UnexpectedException('An unexpected error occurred.');
  }

  static ApiException _fromStatusCode(int? status, dynamic data) {
    final body = data is Map ? data : null;
    final serverMessage =
        body?['error'] is String ? body!['error'] as String : null;
    final code = body?['code'] is String ? body!['code'] as String : null;
    return switch (status) {
      400 => switch (code) {
          'EMAIL_NOT_VERIFIED' => EmailNotVerifiedException(
              serverMessage ??
                  'Please verify your email address before logging in.',
            ),
          'VALIDATION_ERROR' => ValidationException(
              serverMessage ?? 'Validation failed.',
              code: code),
          _ => BadRequestException(serverMessage ?? 'Invalid request.',
              code: code),
        },
      401 => UnauthorizedException(
          message:
              // The generic entry-point message is not user friendly; specific
              // ones ("Invalid credentials", Google errors) are shown as-is.
              serverMessage == null ||
                      code == 'UNAUTHORIZED' &&
                          serverMessage == 'Authentication required'
                  ? UnauthorizedException.defaultMessage
                  : serverMessage,
          code: code,
        ),
      403 => ForbiddenException(code: code),
      404 => NotFoundException(code: code),
      409 => ConflictException(serverMessage ?? 'Conflict.', code: code),
      413 => PayloadTooLargeException(
          serverMessage ?? 'The file is too large.',
          code: code,
        ),
      422 =>
        ValidationException(serverMessage ?? 'Validation failed.', code: code),
      429 => RateLimitException(
          message: serverMessage ?? RateLimitException.defaultMessage,
          code: code,
        ),
      503 => ServiceUnavailableException(
          message: serverMessage ?? ServiceUnavailableException.defaultMessage,
          code: code,
        ),
      500 || 502 || 504 => ServerException(code: code),
      _ => UnexpectedException(
          serverMessage ?? 'An unexpected error occurred.',
          code: code,
        ),
    };
  }
}

final class NetworkException extends ApiException {
  const NetworkException()
      : super('No internet connection. Please check your network.');
}

final class TimeoutException extends ApiException {
  const TimeoutException() : super('Request timed out. Please try again.');
}

/// 401 — invalid credentials, expired session, or a rejected Google sign-in
/// (`GOOGLE_EMAIL_NOT_VERIFIED`, `INVALID_GOOGLE_TOKEN`).
final class UnauthorizedException extends ApiException {
  const UnauthorizedException({String message = defaultMessage, String? code})
      : super(message, code: code);

  static const defaultMessage =
      'Your session has expired. Please log in again.';
}

/// 400 `EMAIL_NOT_VERIFIED` — returned by password login only after the
/// password was verified.
final class EmailNotVerifiedException extends ApiException {
  const EmailNotVerifiedException(super.message)
      : super(code: 'EMAIL_NOT_VERIFIED');
}

final class ForbiddenException extends ApiException {
  const ForbiddenException({String? code})
      : super(
          'You do not have permission to perform this action.',
          code: code,
        );
}

/// 404 — also returned for events/posts the caller is not allowed to see.
final class NotFoundException extends ApiException {
  const NotFoundException({String? code})
      : super('The requested resource was not found.', code: code);
}

final class BadRequestException extends ApiException {
  const BadRequestException(super.message, {super.code});
}

/// 409 — e.g. `EMAIL_TAKEN`, `USERNAME_TAKEN`, `GOOGLE_ACCOUNT_CONFLICT`.
final class ConflictException extends ApiException {
  const ConflictException(super.message, {super.code});
}

/// 413 `FILE_TOO_LARGE` — uploads are limited to 10 MB.
final class PayloadTooLargeException extends ApiException {
  const PayloadTooLargeException(super.message, {super.code});
}

final class ValidationException extends ApiException {
  const ValidationException(super.message, {super.code});
}

/// 429 — rate limits (AI generate / how-to-play, email sends) and the
/// temporary login lockout.
final class RateLimitException extends ApiException {
  const RateLimitException({String message = defaultMessage, String? code})
      : super(message, code: code);

  static const defaultMessage =
      'Too many requests. Please slow down and try again.';
}

/// 503 — e.g. `BGG_UNAVAILABLE` when BoardGameGeek cannot be reached.
final class ServiceUnavailableException extends ApiException {
  const ServiceUnavailableException({
    String message = defaultMessage,
    String? code,
  }) : super(message, code: code);

  static const defaultMessage =
      'This service is temporarily unavailable. Please try again later.';
}

final class ServerException extends ApiException {
  const ServerException({String? code})
      : super(
          'Something went wrong on our end. Please try again later.',
          code: code,
        );
}

final class UnexpectedException extends ApiException {
  const UnexpectedException(super.message, {super.code});
}
