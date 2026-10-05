import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:meeple_hearth/core/locale/locale_provider.dart';
import 'package:meeple_hearth/core/push/push_providers.dart';
import 'package:meeple_hearth/core/router/app_router.dart';
import 'package:meeple_hearth/core/security/app_lock.dart';
import 'package:meeple_hearth/core/theme/app_theme.dart';
import 'package:meeple_hearth/features/notifications/data/realtime_service.dart';
import 'package:meeple_hearth/l10n/l10n.dart';

class MeepleApp extends ConsumerStatefulWidget {
  const MeepleApp({super.key});

  @override
  ConsumerState<MeepleApp> createState() => _MeepleAppState();
}

class _MeepleAppState extends ConsumerState<MeepleApp> {
  StreamSubscription<String>? _pushTaps;

  @override
  void initState() {
    super.initState();
    // Notification taps (FCM or local) deep-link into the app.
    _pushTaps = ref.read(pushServiceProvider).navigationRequests.listen(
          (path) => ref.read(appRouterProvider).go(path),
        );
  }

  @override
  void dispose() {
    _pushTaps?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final language = ref.watch(appLocaleProvider);
    Intl.defaultLocale = language.locale.languageCode;
    // Opens/closes the authenticated STOMP session with the auth state.
    ref.watch(realtimeServiceProvider);

    return MaterialApp.router(
      onGenerateTitle: (context) => context.l10n.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: router,
      locale: language.locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => AppLock(child: child ?? const SizedBox()),
    );
  }
}
