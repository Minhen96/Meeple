import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meeple_hearth/core/constants/api_constants.dart';
import 'package:meeple_hearth/core/network/api_exception.dart';
import 'package:meeple_hearth/core/network/dio_client.dart';

final uploadRepositoryProvider = Provider<UploadRepository>(
  (ref) => UploadRepository(ref.read(dioProvider)),
);

/// An image stored in R2.
final class UploadedImage {
  const UploadedImage({required this.key, required this.publicUrl});

  /// Object key (`uploads/<userId>/<uuid>.<ext>`) — what posts reference in
  /// `imageKeys`.
  final String key;
  final String publicUrl;
}

/// Uploads images straight to R2 through a presigned PUT.
///
/// The presign request declares `{contentType, size}`; both are part of the
/// signature, so the PUT sends exactly that `Content-Type` and
/// `Content-Length`. Only JPEG, PNG, WebP and GIF up to 10 MB are accepted.
final class UploadRepository {
  UploadRepository(this._api, {Dio? storageClient})
      : _storage = storageClient ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(
                  milliseconds: ApiConstants.connectTimeoutMs,
                ),
                sendTimeout: const Duration(seconds: 120),
                receiveTimeout: const Duration(
                  milliseconds: ApiConstants.receiveTimeoutMs,
                ),
              ),
            );

  final Dio _api;

  /// Bare client for the presigned URL — it must never carry the API's
  /// Authorization header.
  final Dio _storage;

  Future<UploadedImage> uploadImage(File file) async {
    final Uint8List bytes = await file.readAsBytes();
    final contentType = detectImageContentType(bytes);
    if (contentType == null) {
      throw const BadRequestException(
        'Only JPEG, PNG, WebP and GIF images are allowed.',
        code: 'UNSUPPORTED_CONTENT_TYPE',
      );
    }
    if (bytes.isEmpty) {
      throw const BadRequestException('File is empty.', code: 'EMPTY_FILE');
    }
    if (bytes.length > ApiConstants.maxUploadBytes) {
      throw const PayloadTooLargeException(
        'Images must be 10 MB or smaller.',
        code: 'FILE_TOO_LARGE',
      );
    }

    try {
      final presign = await _api.post<Map<String, dynamic>>(
        ApiConstants.uploadPresign,
        data: {'contentType': contentType, 'size': bytes.length},
      );
      final body = presign.data!;
      final uploadUrl = body['uploadUrl'] as String;

      await _storage.put<void>(
        uploadUrl,
        data: Stream<List<int>>.value(bytes),
        options: Options(
          headers: {
            Headers.contentTypeHeader: contentType,
            Headers.contentLengthHeader: bytes.length,
          },
        ),
      );

      return UploadedImage(
        key: body['key'] as String,
        publicUrl: body['publicUrl'] as String,
      );
    } catch (e) {
      throw ApiException.from(e);
    }
  }
}

/// Image MIME type from the file's magic bytes, or null when the format is
/// not one the backend accepts.
String? detectImageContentType(Uint8List b) {
  bool startsWith(List<int> sig, [int offset = 0]) {
    if (b.length < offset + sig.length) return false;
    for (var i = 0; i < sig.length; i++) {
      if (b[offset + i] != sig[i]) return false;
    }
    return true;
  }

  if (startsWith(const [0xFF, 0xD8, 0xFF])) return 'image/jpeg';
  if (startsWith(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) {
    return 'image/png';
  }
  if (startsWith(const [0x47, 0x49, 0x46, 0x38])) return 'image/gif';
  if (startsWith(const [0x52, 0x49, 0x46, 0x46]) &&
      startsWith(const [0x57, 0x45, 0x42, 0x50], 8)) {
    return 'image/webp';
  }
  return null;
}
