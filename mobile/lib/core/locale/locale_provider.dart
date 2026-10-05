import 'dart:ui';

import 'package:intl/intl.dart';
import 'package:meeple_hearth/core/storage/secure_storage.dart';
import 'package:meeple_hearth/core/utils/app_logger.dart';
import 'package:meeple_hearth/features/auth/domain/user_model.dart';
import 'package:meeple_hearth/features/auth/providers/auth_provider.dart';
import 'package:meeple_hearth/features/profile/data/user_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'locale_provider.g.dart';

/// Languages offered in the app (FEATURES §0: English + Simplified Chinese).
enum AppLanguage {
  en('en', Locale('en')),
  zhCN('zh-CN', Locale('zh'));

  const AppLanguage(this.wire, this.locale);

  /// `preferredLanguage` value on the backend.
  final String wire;
  final Locale locale;

  static AppLanguage fromWire(String? raw) {
    final v = raw?.toLowerCase().replaceAll('_', '-');
    if (v == null) return en;
    return v.startsWith('zh') ? zhCN : en;
  }
}

/// The app language.
///
/// Starts from the device-stored choice (or the system language), follows the
/// signed-in user's `preferredLanguage`, and [select] persists the choice on
/// the device and on the server (`PUT /users/me {preferredLanguage}`).
@Riverpod(keepAlive: true)
class AppLocale extends _$AppLocale {
  static const _prefKey = 'app_language';

  @override
  AppLanguage build() {
    ref.listen<AsyncValue<User?>>(
      authNotifierProvider,
      (_, next) {
        final preferred = next.valueOrNull?.preferredLanguage;
        if (preferred != null) _apply(AppLanguage.fromWire(preferred));
      },
    );
    _restore();
    final system = PlatformDispatcher.instance.locale.languageCode;
    return system == 'zh' ? AppLanguage.zhCN : AppLanguage.en;
  }

  Future<void> _restore() async {
    try {
      final stored = await ref.read(secureStorageProvider).readPref(_prefKey);
      if (stored != null) _apply(AppLanguage.fromWire(stored));
    } catch (_) {
      // No stored choice (or storage unavailable): keep the default.
    }
  }

  void _apply(AppLanguage language) {
    Intl.defaultLocale = language.locale.languageCode;
    state = language;
  }

  /// In-app language switcher.
  Future<void> select(AppLanguage language) async {
    _apply(language);
    final storage = ref.read(secureStorageProvider);
    await storage.writePref(_prefKey, language.wire);
    final user = ref.read(authNotifierProvider).valueOrNull;
    if (user == null) return;
    try {
      final updated = await ref
          .read(userRepositoryProvider)
          .updateMe(ProfileUpdate(preferredLanguage: language.wire));
      ref.read(authNotifierProvider.notifier).updateUser(updated);
    } catch (e) {
      // The device choice still applies; the server copy syncs next time.
      AppLogger.warning('Saving preferredLanguage failed', error: e);
    }
  }
}
