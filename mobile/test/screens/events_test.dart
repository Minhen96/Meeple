import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_api.dart';
import '../helpers/fixtures.dart';
import '../helpers/harness.dart';

void main() {
  late FakeApi api;

  setUp(() {
    api = FakeApi();
    stubDefaults(api);
    api
      ..get('/api/v1/events/e1', eventJson())
      ..get('/api/v1/events/calendar', [eventJson()]);
  });

  testWidgets('event list tabs request upcoming, past and mine scopes',
      (tester) async {
    await pumpApp(tester, api: api, location: '/events');
    expect(find.text('Catan Night'), findsOneWidget);

    await tester.tap(find.text('Past'));
    await settle(tester);
    await tester.tap(find.text('Mine'));
    await settle(tester);

    final scopes = api
        .calls('GET', '/api/v1/events')
        .map((r) => r.queryParameters['scope'])
        .toSet();
    expect(scopes, containsAll(['upcoming', 'past', 'mine']));
  });

  testWidgets('empty upcoming list offers to create an event', (tester) async {
    api.get('/api/v1/events', []);
    await pumpApp(tester, api: api, location: '/events');
    expect(find.text('No upcoming events.'), findsWidgets);
  });

  testWidgets('calendar view loads the month and lists events of a day',
      (tester) async {
    await pumpApp(tester, api: api, location: '/events?view=calendar');

    expect(find.byKey(const Key('events-calendar')), findsOneWidget);
    expect(api.called('GET', '/api/v1/events/calendar'), isTrue);
    final req = api.calls('GET', '/api/v1/events/calendar').first;
    expect(req.queryParameters.keys, containsAll(['from', 'to']));
    expect(find.text('Catan Night'), findsOneWidget);

    await tester.tap(find.byKey(const Key('events-toggle-view')));
    await settle(tester);
    expect(find.text('Upcoming'), findsOneWidget);
  });

  testWidgets('event detail: participants and leaving', (tester) async {
    api.delete('/api/v1/events/e1/rsvp', const FakeResponse.noContent());
    await pumpApp(tester, api: api, location: '/events/e1');

    expect(find.text('Hosted by Fred'), findsWidgets);
    expect(find.text('1 going'), findsOneWidget);
    expect(find.text('1 invited'), findsOneWidget);

    await tester.tap(find.byKey(const Key('rsvp-leave')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('confirm-sheet-confirm')));
    await settle(tester);
    expect(api.called('DELETE', '/api/v1/events/e1/rsvp'), isTrue);
  });

  testWidgets('invited user can accept', (tester) async {
    api
      ..get('/api/v1/events/e1', eventJson(myRsvp: 'INVITED'))
      ..post('/api/v1/events/e1/rsvp', eventJson());
    await pumpApp(tester, api: api, location: '/events/e1');

    await tester.tap(find.byKey(const Key('rsvp-accept')));
    await settle(tester);

    final rsvp = api.calls('POST', '/api/v1/events/e1/rsvp').single;
    expect(rsvp.queryParameters['status'], 'ACCEPTED');
    expect(find.byKey(const Key('rsvp-leave')), findsOneWidget);
  });

  testWidgets('cancelled events show a banner and no actions', (tester) async {
    api.get('/api/v1/events/e1', eventJson(status: 'CANCELLED'));
    await pumpApp(tester, api: api, location: '/events/e1');

    expect(find.text('This event has been cancelled.'), findsOneWidget);
    expect(find.byKey(const Key('rsvp-leave')), findsNothing);
  });

  testWidgets('host can kick, invite and cancel', (tester) async {
    api
      ..get('/api/v1/events/e1', eventJson(isHost: true, participants: [
        {...summaryJson('f1', 'Fred'), 'status': 'ACCEPTED'},
      ]))
      ..delete('/api/v1/events/e1/participants/f1', const FakeResponse.noContent())
      ..post('/api/v1/events/e1/invites', const FakeResponse.noContent())
      ..post('/api/v1/events/e1/cancel', const FakeResponse.noContent());
    await pumpApp(tester, api: api, location: '/events/e1');

    await tester.tap(find.byKey(const ValueKey('kick-f1')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('confirm-sheet-confirm')));
    await settle(tester);
    expect(api.called('DELETE', '/api/v1/events/e1/participants/f1'), isTrue);

    await tester.tap(find.byKey(const Key('event-manage')));
    await settle(tester);
    await tester.tap(find.text('Invite friends'));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('friend-pick-f2')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('friend-picker-done')));
    await settle(tester);
    final invite = api.calls('POST', '/api/v1/events/e1/invites').single;
    expect((invite.data as Map)['userIds'], ['f2']);

    await tester.tap(find.byKey(const Key('event-manage')));
    await settle(tester);
    await tester.tap(find.text('Cancel event').last);
    await settle(tester);
    await tester.tap(find.byKey(const Key('confirm-sheet-confirm')));
    await settle(tester);
    expect(api.called('POST', '/api/v1/events/e1/cancel'), isTrue);
  });

  testWidgets('unknown event shows not found', (tester) async {
    await pumpApp(tester, api: api, location: '/events/missing');
    expect(find.text("This event doesn't exist or was removed."), findsOneWidget);
  });

  testWidgets('create event validates the date', (tester) async {
    await pumpApp(tester, api: api, location: '/events/create');

    await tester.enterText(find.byKey(const Key('event-title')), 'Game night');
    await tester.tap(find.byKey(const Key('event-submit')));
    await settle(tester);

    expect(find.text('Please pick a date and time.'), findsOneWidget);
    expect(api.called('POST', '/api/v1/events'), isFalse);
  });

  testWidgets('create event from a match pre-fills game and invitees',
      (tester) async {
    await pumpApp(
      tester,
      api: api,
      location: '/events/create?matchGroupId=mg1',
    );

    expect(find.text('Catan'), findsOneWidget);
    expect(find.text('Fred'), findsOneWidget);
    expect(find.text('Catan Night'), findsOneWidget);
  });

  testWidgets('visibility picker and player stepper', (tester) async {
    await pumpApp(tester, api: api, location: '/events/create');

    await tester.tap(find.text('Public'));
    await settle(tester, 3);
    expect(find.text('Anyone in the community can find and join.'), findsOneWidget);

    await tester.tap(find.byTooltip('More'));
    await tester.pump();
    expect(find.text('9'), findsOneWidget);
  });

  testWidgets('edit event loads the current values', (tester) async {
    await pumpApp(tester, api: api, location: '/events/e1/edit');
    expect(find.text('Edit event'), findsOneWidget);
    expect(find.text('Catan Night'), findsOneWidget);
  });
}
