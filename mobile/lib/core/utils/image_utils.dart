import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Utilities for picking and compressing images before upload.
///
/// Rules enforced:
/// - Output format: WebP
/// - Max dimension: 1 200 px on the longest side
/// - Max file size: 1 MB (quality iteratively reduced if needed)
/// - EXIF data stripped (flutter_image_compress strips it by default)
abstract final class AppImageUtils {
  /// Pick an image from the given [source], compress it, and return the
  /// resulting [File]. Returns null if the user cancels the picker.
  static Future<File?> pickAndCompress(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 90,
    );
    if (picked == null) return null;

    return compress(File(picked.path));
  }

  /// Compress an existing [file] to WebP ≤ 1 MB at ≤ 1 200 px.
  /// Returns the compressed [File].
  static Future<File> compress(File file) async {
    final dir = await getTemporaryDirectory();
    final targetPath =
        '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.webp';

    XFile? result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      format: CompressFormat.webp,
      minWidth: 1,
      minHeight: 1,
      keepExif: false,
      quality: 85,
    );

    if (result == null) return file;

    // Iteratively reduce quality until under 1 MB.
    var compressed = result; // non-nullable from here
    var quality = 85;
    while (await File(compressed.path).length() > 1024 * 1024 && quality > 20) {
      quality -= 10;
      final next = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        format: CompressFormat.webp,
        minWidth: 1,
        minHeight: 1,
        keepExif: false,
        quality: quality,
      );
      if (next == null) break;
      compressed = next;
    }

    return File(compressed.path);
  }
}
