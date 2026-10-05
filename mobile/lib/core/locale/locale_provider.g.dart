// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'locale_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$appLocaleHash() => r'1a8566b64791fc92c44cc9b1d5a4dbadadc7fc0c';

/// The app language.
///
/// Starts from the device-stored choice (or the system language), follows the
/// signed-in user's `preferredLanguage`, and [select] persists the choice on
/// the device and on the server (`PUT /users/me {preferredLanguage}`).
///
/// Copied from [AppLocale].
@ProviderFor(AppLocale)
final appLocaleProvider = NotifierProvider<AppLocale, AppLanguage>.internal(
  AppLocale.new,
  name: r'appLocaleProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$appLocaleHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$AppLocale = Notifier<AppLanguage>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
