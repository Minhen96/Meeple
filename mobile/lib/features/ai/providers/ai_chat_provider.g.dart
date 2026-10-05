// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_chat_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$aiChatHash() => r'0bfe3cafb6d4538a5501234de5dd452bf610ba41';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

abstract class _$AiChat extends BuildlessAutoDisposeNotifier<List<AiMessage>> {
  late final String gameId;

  List<AiMessage> build(
    String gameId,
  );
}

/// AI Rules Assistant conversation for one game (SCREENS §12).
///
/// Conversation mode (CLAUDE.md): the client keeps the transcript and sends
/// the last 3 answered Q&A pairs with every question.
///
/// Copied from [AiChat].
@ProviderFor(AiChat)
const aiChatProvider = AiChatFamily();

/// AI Rules Assistant conversation for one game (SCREENS §12).
///
/// Conversation mode (CLAUDE.md): the client keeps the transcript and sends
/// the last 3 answered Q&A pairs with every question.
///
/// Copied from [AiChat].
class AiChatFamily extends Family<List<AiMessage>> {
  /// AI Rules Assistant conversation for one game (SCREENS §12).
  ///
  /// Conversation mode (CLAUDE.md): the client keeps the transcript and sends
  /// the last 3 answered Q&A pairs with every question.
  ///
  /// Copied from [AiChat].
  const AiChatFamily();

  /// AI Rules Assistant conversation for one game (SCREENS §12).
  ///
  /// Conversation mode (CLAUDE.md): the client keeps the transcript and sends
  /// the last 3 answered Q&A pairs with every question.
  ///
  /// Copied from [AiChat].
  AiChatProvider call(
    String gameId,
  ) {
    return AiChatProvider(
      gameId,
    );
  }

  @override
  AiChatProvider getProviderOverride(
    covariant AiChatProvider provider,
  ) {
    return call(
      provider.gameId,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'aiChatProvider';
}

/// AI Rules Assistant conversation for one game (SCREENS §12).
///
/// Conversation mode (CLAUDE.md): the client keeps the transcript and sends
/// the last 3 answered Q&A pairs with every question.
///
/// Copied from [AiChat].
class AiChatProvider
    extends AutoDisposeNotifierProviderImpl<AiChat, List<AiMessage>> {
  /// AI Rules Assistant conversation for one game (SCREENS §12).
  ///
  /// Conversation mode (CLAUDE.md): the client keeps the transcript and sends
  /// the last 3 answered Q&A pairs with every question.
  ///
  /// Copied from [AiChat].
  AiChatProvider(
    String gameId,
  ) : this._internal(
          () => AiChat()..gameId = gameId,
          from: aiChatProvider,
          name: r'aiChatProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$aiChatHash,
          dependencies: AiChatFamily._dependencies,
          allTransitiveDependencies: AiChatFamily._allTransitiveDependencies,
          gameId: gameId,
        );

  AiChatProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.gameId,
  }) : super.internal();

  final String gameId;

  @override
  List<AiMessage> runNotifierBuild(
    covariant AiChat notifier,
  ) {
    return notifier.build(
      gameId,
    );
  }

  @override
  Override overrideWith(AiChat Function() create) {
    return ProviderOverride(
      origin: this,
      override: AiChatProvider._internal(
        () => create()..gameId = gameId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        gameId: gameId,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<AiChat, List<AiMessage>> createElement() {
    return _AiChatProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is AiChatProvider && other.gameId == gameId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, gameId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin AiChatRef on AutoDisposeNotifierProviderRef<List<AiMessage>> {
  /// The parameter `gameId` of this provider.
  String get gameId;
}

class _AiChatProviderElement
    extends AutoDisposeNotifierProviderElement<AiChat, List<AiMessage>>
    with AiChatRef {
  _AiChatProviderElement(super.provider);

  @override
  String get gameId => (origin as AiChatProvider).gameId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
