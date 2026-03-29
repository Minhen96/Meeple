// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'events_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$eventDetailHash() => r'8b47f46075ba003bf01f905b84607571400307c6';

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

/// Single event detail.
///
/// Copied from [eventDetail].
@ProviderFor(eventDetail)
const eventDetailProvider = EventDetailFamily();

/// Single event detail.
///
/// Copied from [eventDetail].
class EventDetailFamily extends Family<AsyncValue<Event>> {
  /// Single event detail.
  ///
  /// Copied from [eventDetail].
  const EventDetailFamily();

  /// Single event detail.
  ///
  /// Copied from [eventDetail].
  EventDetailProvider call(
    String eventId,
  ) {
    return EventDetailProvider(
      eventId,
    );
  }

  @override
  EventDetailProvider getProviderOverride(
    covariant EventDetailProvider provider,
  ) {
    return call(
      provider.eventId,
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
  String? get name => r'eventDetailProvider';
}

/// Single event detail.
///
/// Copied from [eventDetail].
class EventDetailProvider extends AutoDisposeFutureProvider<Event> {
  /// Single event detail.
  ///
  /// Copied from [eventDetail].
  EventDetailProvider(
    String eventId,
  ) : this._internal(
          (ref) => eventDetail(
            ref as EventDetailRef,
            eventId,
          ),
          from: eventDetailProvider,
          name: r'eventDetailProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$eventDetailHash,
          dependencies: EventDetailFamily._dependencies,
          allTransitiveDependencies:
              EventDetailFamily._allTransitiveDependencies,
          eventId: eventId,
        );

  EventDetailProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.eventId,
  }) : super.internal();

  final String eventId;

  @override
  Override overrideWith(
    FutureOr<Event> Function(EventDetailRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: EventDetailProvider._internal(
        (ref) => create(ref as EventDetailRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        eventId: eventId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<Event> createElement() {
    return _EventDetailProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is EventDetailProvider && other.eventId == eventId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, eventId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin EventDetailRef on AutoDisposeFutureProviderRef<Event> {
  /// The parameter `eventId` of this provider.
  String get eventId;
}

class _EventDetailProviderElement
    extends AutoDisposeFutureProviderElement<Event> with EventDetailRef {
  _EventDetailProviderElement(super.provider);

  @override
  String get eventId => (origin as EventDetailProvider).eventId;
}

String _$eventsNotifierHash() => r'c5ba552aa7c96aa2a045a46e2dd699e82b3bf04c';

/// Upcoming public events (default tab).
///
/// Copied from [EventsNotifier].
@ProviderFor(EventsNotifier)
final eventsNotifierProvider = AutoDisposeAsyncNotifierProvider<EventsNotifier,
    PaginatedResult<Event>>.internal(
  EventsNotifier.new,
  name: r'eventsNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$eventsNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$EventsNotifier = AutoDisposeAsyncNotifier<PaginatedResult<Event>>;
String _$myEventsNotifierHash() => r'6f4bfb4fb5d77f1ef24e9ad6e8cfe88b8fbc351f';

/// Events the current user is attending or has organised (My Events tab).
///
/// Copied from [MyEventsNotifier].
@ProviderFor(MyEventsNotifier)
final myEventsNotifierProvider = AutoDisposeAsyncNotifierProvider<
    MyEventsNotifier, PaginatedResult<Event>>.internal(
  MyEventsNotifier.new,
  name: r'myEventsNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$myEventsNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$MyEventsNotifier = AutoDisposeAsyncNotifier<PaginatedResult<Event>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
