import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';

/// Global test setup: no runtime font fetching, in-memory secure storage.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  AppTypography.useGoogleFonts = false;
  FlutterSecureStorage.setMockInitialValues({});
  await testMain();
}
