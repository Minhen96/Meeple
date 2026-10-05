// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'events_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$eventsListHash() => r'15d135e7bc1c029642cfd89784d39c7eaebb0780';

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

/// Events of a list tab. Upcoming events are cached for 30 min.
///
/// Copied from [eventsList].
@ProviderFor(eventsList)
const eventsListProvider = EventsListFamily();

/// Events of a list tab. Upcoming events are cached for 30 min.
///
/// Copied from [eventsList].
class EventsListFamily extends Family<AsyncValue<CachedResult<List<Event>>>> {
  /// Events of a list tab. Upcoming events are cached for 30 min.
  ///
  /// Copied from [eventsList].
  const EventsListFamily();

  /// Events of a list tab. Upcoming events are cached for 30 min.
  ///
  /// Copied from [eventsList].
  EventsListProvider call(
    EventScope scope,
  ) {
    return EventsListProvider(
      scope,
    );
  }

  @override
  EventsListProvider getProviderOverride(
    covariant EventsListProvider provider,
  ) {
    return call(
      provider.scope,
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
  String? get name => r'eventsListProvider';
}

/// Events of a list tab. Upcoming events are cached for 30 min.
///
/// Copied from [eventsList].
class EventsListProvider
    extends AutoDisposeFutureProvider<CachedResult<List<Event>>> {
  /// Events of a list tab. Upcoming events are cached for 30 min.
  ///
  /// Copied from [eventsList].
  EventsListProvider(
    EventScope scope,
  ) : this._internal(
          (ref) => eventsList(
            ref as EventsListRef,
            scope,
          ),
          from: eventsListProvider,
          name: r'eventsListProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$eventsListHash,
          dependencies: EventsListFamily._dependencies,
          allTransitiveDependencies:
              EventsListFamily._allTransitiveDependencies,
          scope: scope,
        );

  EventsListProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.scope,
  }) : super.internal();

  final EventScope scope;

  @override
  Override overrideWith(
    FutureOr<CachedResult<List<Event>>> Function(EventsListRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: EventsListProvider._internal(
        (ref) => create(ref as EventsListRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        scope: scope,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<CachedResult<List<Event>>> createElement() {
    return _EventsListProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is EventsListProvider && other.scope == scope;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, scope.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin EventsListRef on AutoDisposeFutureProviderRef<CachedResult<List<Event>>> {
  /// The parameter `scope` of this provider.
  EventScope get scope;
}

class _EventsListProviderElement
    extends AutoDisposeFutureProviderElement<CachedResult<List<Event>>>
    with EventsListRef {
  _EventsListProviderElement(super.provider);

  @override
  EventScope get scope => (origin as EventsListProvider).scope;
}

String _$calendarEventsHash() => r'd847f38e2727de536f43e9af3f69df7084b044da';

/// Events of one calendar month (first day of [month] → first day of the
/// next month, within the 62-day API limit).
///
/// Copied from [calendarEvents].
@ProviderFor(calendarEvents)
const calendarEventsProvider = CalendarEventsFamily();

/// Events of one calendar month (first day of [month] → first day of the
/// next month, within the 62-day API limit).
///
/// Copied from [calendarEvents].
class CalendarEventsFamily extends Family<AsyncValue<List<Event>>> {
  /// Events of one calendar month (first day of [month] → first day of the
  /// next month, within the 62-day API limit).
  ///
  /// Copied from [calendarEvents].
  const CalendarEventsFamily();

  /// Events of one calendar month (first day of [month] → first day of the
  /// next month, within the 62-day API limit).
  ///
  /// Copied from [calendarEvents].
  CalendarEventsProvider call(
    DateTime month,
  ) {
    return CalendarEventsProvider(
      month,
    );
  }

  @override
  CalendarEventsProvider getProviderOverride(
    covariant CalendarEventsProvider provider,
  ) {
    return call(
      provider.month,
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
  String? get name => r'calendarEventsProvider';
}

/// Events of one calendar month (first day of [month] → first day of the
/// next month, within the 62-day API limit).
///
/// Copied from [calendarEvents].
class CalendarEventsProvider extends AutoDisposeFutureProvider<List<Event>> {
  /// Events of one calendar month (first day of [month] → first day of the
  /// next month, within the 62-day API limit).
  ///
  /// Copied from [calendarEvents].
  CalendarEventsProvider(
    DateTime month,
  ) : this._internal(
          (ref) => calendarEvents(
            ref as CalendarEventsRef,
            month,
          ),
          from: calendarEventsProvider,
          name: r'calendarEventsProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$calendarEventsHash,
          dependencies: CalendarEventsFamily._dependencies,
          allTransitiveDependencies:
              CalendarEventsFamily._allTransitiveDependencies,
          month: month,
        );

  CalendarEventsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.month,
  }) : super.internal();

  final DateTime month;

  @override
  Override overrideWith(
    FutureOr<List<Event>> Function(CalendarEventsRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: CalendarEventsProvider._internal(
        (ref) => create(ref as CalendarEventsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        month: month,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<Event>> createElement() {
    return _CalendarEventsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is CalendarEventsProvider && other.month == month;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, month.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin CalendarEventsRef on AutoDisposeFutureProviderRef<List<Event>> {
  /// The parameter `month` of this provider.
  DateTime get month;
}

class _CalendarEventsProviderElement
    extends AutoDisposeFutureProviderElement<List<Event>>
    with CalendarEventsRef {
  _CalendarEventsProviderElement(super.provider);

  @override
  DateTime get month => (origin as CalendarEventsProvider).month;
}

String _$eventActionsHash() => r'cadeefa764b06a5ddc5a88aae10fe59be39e8386';

/// Creating events (with invites in the same request).
///
/// Copied from [eventActions].
@ProviderFor(eventActions)
final eventActionsProvider = AutoDisposeProvider<EventActions>.internal(
  eventActions,
  name: r'eventActionsProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$eventActionsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef EventActionsRef = AutoDisposeProviderRef<EventActions>;
String _$eventDetailHash() => r'4d1ecf709ce44c7c4c7fabe237f0bd875c04f2d3';

abstract class _$EventDetail extends BuildlessAutoDisposeAsyncNotifier<Event> {
  late final String eventId;

  FutureOr<Event> build(
    String eventId,
  );
}

/// Event detail with RSVP and host actions.
///
/// Copied from [EventDetail].
@ProviderFor(EventDetail)
const eventDetailProvider = EventDetailFamily();

/// Event detail with RSVP and host actions.
///
/// Copied from [EventDetail].
class EventDetailFamily extends Family<AsyncValue<Event>> {
  /// Event detail with RSVP and host actions.
  ///
  /// Copied from [EventDetail].
  const EventDetailFamily();

  /// Event detail with RSVP and host actions.
  ///
  /// Copied from [EventDetail].
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

/// Event detail with RSVP and host actions.
///
/// Copied from [EventDetail].
class EventDetailProvider
    extends AutoDisposeAsyncNotifierProviderImpl<EventDetail, Event> {
  /// Event detail with RSVP and host actions.
  ///
  /// Copied from [EventDetail].
  EventDetailProvider(
    String eventId,
  ) : this._internal(
          () => EventDetail()..eventId = eventId,
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
  FutureOr<Event> runNotifierBuild(
    covariant EventDetail notifier,
  ) {
    return notifier.build(
      eventId,
    );
  }

  @override
  Override overrideWith(EventDetail Function() create) {
    return ProviderOverride(
      origin: this,
      override: EventDetailProvider._internal(
        () => create()..eventId = eventId,
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
  AutoDisposeAsyncNotifierProviderElement<EventDetail, Event> createElement() {
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
mixin EventDetailRef on AutoDisposeAsyncNotifierProviderRef<Event> {
  /// The parameter `eventId` of this provider.
  String get eventId;
}

class _EventDetailProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<EventDetail, Event>
    with EventDetailRef {
  _EventDetailProviderElement(super.provider);

  @override
  String get eventId => (origin as EventDetailProvider).eventId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
