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

  testWidgets('event list: heading, upcoming / past scopes and community',
      (tester) async {
    api.get('/api/v1/events/community', {
      'items': [eventJson(id: 'e9', title: 'Public Night')],
      'nextCursor': 'c2',
      'hasMore': true,
    });
    await pumpApp(tester, api: api, location: '/events');
    expect(find.text('Game Nights'), findsOneWidget);
    expect(find.text('Catan Night'), findsOneWidget);
    // Fred is going and the viewer accepted: avatar + "You're going".
    expect(find.text("You're going"), findsOneWidget);

    await tester.tap(find.text('Past'));
    await settle(tester);
    await tester.tap(find.text('Community'));
    await settle(tester);
    expect(find.text('Public Night'), findsOneWidget);

    final scopes = api
        .calls('GET', '/api/v1/events')
        .map((r) => r.queryParameters['scope'])
        .toSet();
    expect(scopes, containsAll(['upcoming', 'past']));

    await tester.tap(find.byKey(const Key('events-load-more')));
    await settle(tester);
    final pages = api.calls('GET', '/api/v1/events/community');
    expect(pages.last.queryParameters['cursor'], 'c2');
  });

  testWidgets('invited events say so on the card', (tester) async {
    api.get('/api/v1/events', [eventJson(myRsvp: 'INVITED')]);
    await pumpApp(tester, api: api, location: '/events');
    expect(find.text("You're invited"), findsOneWidget);
  });

  testWidgets('empty upcoming list offers to create an event', (tester) async {
    api.get('/api/v1/events', []);
    await pumpApp(tester, api: api, location: '/events');
    expect(find.text('No upcoming events.'), findsWidgets);
    await tester.tap(find.byKey(const Key('events-empty-create')));
    await settle(tester);
    expect(find.text('New Event'), findsOneWidget);
  });

  testWidgets('empty community tab', (tester) async {
    api.get('/api/v1/events/community', {'items': <Object>[], 'hasMore': false});
    await pumpApp(tester, api: api, location: '/events');
    await tester.tap(find.text('Community'));
    await settle(tester);
    expect(find.text('No public events yet.'), findsOneWidget);
  });

  testWidgets('calendar view loads the month and lists events of a day',
      (tester) async {
    final now = DateTime.now();
    final noon = DateTime(now.year, now.month, now.day, 12);
    api.get('/api/v1/events/calendar', [eventJson(at: noon)]);
    await pumpApp(tester, api: api, location: '/events?view=calendar');

    expect(find.byKey(const Key('events-calendar')), findsOneWidget);
    expect(api.called('GET', '/api/v1/events/calendar'), isTrue);
    final req = api.calls('GET', '/api/v1/events/calendar').first;
    expect(req.queryParameters.keys, containsAll(['from', 'to']));

    await tester.tap(find.byKey(ValueKey('calendar-day-${now.month}-${now.day}')));
    await settle(tester);
    expect(find.text('Catan Night'), findsOneWidget);
    await tester.tapAt(const Offset(20, 20));
    await settle(tester);

    // Other months: next, then back to today.
    await tester.tap(find.byKey(const Key('calendar-next')));
    await settle(tester);
    expect(find.byKey(const Key('calendar-today')), findsOneWidget);
    await tester.tap(find.byKey(const Key('calendar-today')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('calendar-prev')));
    await settle(tester);
    expect(api.calls('GET', '/api/v1/events/calendar').length, greaterThan(1));

    await tester.tap(find.text('List'));
    await settle(tester);
    expect(find.text('Upcoming'), findsOneWidget);
  });

  testWidgets('event detail: hero, info tiles, players and leaving',
      (tester) async {
    api.delete('/api/v1/events/e1/rsvp', const FakeResponse.noContent());
    await pumpApp(tester, api: api, location: '/events/e1');

    expect(find.text('Hosted by Fred'), findsOneWidget);
    expect(find.text('Friends only'), findsOneWidget);
    expect(find.text('WHEN'), findsOneWidget);
    expect(find.text('Cafe'), findsOneWidget);
    expect(find.text('2 going · 4 spots left'), findsOneWidget);
    // Fred hosts; nobody else has accepted.
    expect(find.text('No one else yet. Invite some friends!'), findsOneWidget);

    await tester.tap(find.byKey(const Key('rsvp-leave')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('confirm-sheet-confirm')));
    await settle(tester);
    expect(api.called('DELETE', '/api/v1/events/e1/rsvp'), isTrue);
  });

  testWidgets('going players other than the host are listed', (tester) async {
    api.get('/api/v1/events/e1', eventJson(participants: [
      {...summaryJson('f1', 'Fred'), 'status': 'ACCEPTED'},
      {...summaryJson('f3', 'Gus'), 'status': 'ACCEPTED'},
    ]));
    await pumpApp(tester, api: api, location: '/events/e1');
    expect(find.byKey(const ValueKey('participant-f3')), findsOneWidget);
    expect(find.byKey(const ValueKey('participant-f1')), findsNothing);
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

  testWidgets('invited user can decline', (tester) async {
    api
      ..get('/api/v1/events/e1', eventJson(myRsvp: 'INVITED'))
      ..post('/api/v1/events/e1/rsvp', eventJson(myRsvp: 'DECLINED'));
    await pumpApp(tester, api: api, location: '/events/e1');

    await tester.tap(find.byKey(const Key('rsvp-decline')));
    await settle(tester);
    final rsvp = api.calls('POST', '/api/v1/events/e1/rsvp').single;
    expect(rsvp.queryParameters['status'], 'DECLINED');
    expect(find.text('Change to Going'), findsOneWidget);
  });

  testWidgets('cancelled events show a banner and no actions', (tester) async {
    api.get('/api/v1/events/e1', eventJson(status: 'CANCELLED'));
    await pumpApp(tester, api: api, location: '/events/e1');

    expect(find.text('This event has been cancelled.'), findsOneWidget);
    expect(find.byKey(const Key('rsvp-leave')), findsNothing);
  });

  testWidgets('host can invite friends from the manage sheet',
      (tester) async {
    api
      ..get('/api/v1/events/e1', eventJson(isHost: true, participants: [
        {...summaryJson('f1', 'Fred'), 'status': 'ACCEPTED'},
      ]))
      ..post('/api/v1/events/e1/invites', const FakeResponse.noContent());
    await pumpApp(tester, api: api, location: '/events/e1');

    await tester.tap(find.byKey(const Key('event-manage')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('manage-invite')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('friend-pick-f2')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('friend-picker-done')));
    await settle(tester);
    final invite = api.calls('POST', '/api/v1/events/e1/invites').single;
    expect((invite.data as Map)['userIds'], ['f2']);
  });

  testWidgets('host can cancel the event from the manage sheet',
      (tester) async {
    api
      ..get('/api/v1/events/e1', eventJson(isHost: true))
      ..post('/api/v1/events/e1/cancel', const FakeResponse.noContent());
    await pumpApp(tester, api: api, location: '/events/e1');

    await tester.tap(find.byKey(const Key('event-manage')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('manage-cancel')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('confirm-sheet-confirm')));
    await settle(tester);
    expect(api.called('POST', '/api/v1/events/e1/cancel'), isTrue);
  });

  testWidgets('host can remove a player from the participants sheet',
      (tester) async {
    api
      ..get('/api/v1/events/e1', eventJson(isHost: true, participants: [
        {...summaryJson('f1', 'Fred'), 'status': 'ACCEPTED'},
        {...summaryJson('f4', 'Lea'), 'status': 'DECLINED'},
      ]))
      ..delete('/api/v1/events/e1/participants/f1', const FakeResponse.noContent());
    await pumpApp(tester, api: api, location: '/events/e1');

    await tester.tap(find.byKey(const Key('event-manage')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('manage-participants')));
    await settle(tester);
    expect(find.text('Participants'), findsOneWidget);
    expect(find.text('Declined'), findsOneWidget);
    expect(find.byKey(const ValueKey('kick-f4')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('kick-f1')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('confirm-sheet-confirm')));
    await settle(tester);
    expect(api.called('DELETE', '/api/v1/events/e1/participants/f1'), isTrue);
  });

  testWidgets('host can open the edit form from the manage sheet',
      (tester) async {
    api.get('/api/v1/events/e1', eventJson(isHost: true));
    await pumpApp(tester, api: api, location: '/events/e1');
    await tester.tap(find.byKey(const Key('event-manage')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('manage-edit')));
    await settle(tester);
    expect(find.text('Edit Event'), findsOneWidget);
  });

  testWidgets('unknown event shows not found', (tester) async {
    await pumpApp(tester, api: api, location: '/events/missing');
    expect(find.text("This event doesn't exist or was removed."), findsOneWidget);
  });

  testWidgets('create event validates the title', (tester) async {
    await pumpApp(tester, api: api, location: '/events/create');
    expect(find.text('New Event'), findsOneWidget);
    expect(find.text('GATHER YOUR PARTY'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('event-title')), 'ab');
    await tester.tap(find.byKey(const Key('event-submit')));
    await settle(tester);

    expect(find.text('Title must be at least 3 characters'), findsOneWidget);
    expect(api.called('POST', '/api/v1/events'), isFalse);
  });

  testWidgets('create event submits the form with invites', (tester) async {
    api.post('/api/v1/events', eventJson());
    await pumpApp(tester, api: api, location: '/events/create');

    await tester.enterText(find.byKey(const Key('event-title')), 'Game night');
    await tester.enterText(find.byKey(const Key('event-description')), 'Snacks');
    await tester.pump();
    expect(find.text('6/1000'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('invite-pick-f1')));
    await tester.tap(find.byKey(const ValueKey('invite-pick-f1')));
    await tester.pump();
    expect(find.text('1 selected'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('event-invite-search')), 'zzz');
    await tester.pump();
    expect(find.byKey(const ValueKey('invite-pick-f2')), findsNothing);
    await tester.tap(find.byKey(const Key('event-submit')));
    await settle(tester);

    final body = api.calls('POST', '/api/v1/events').single.data as Map;
    expect(body['title'], 'Game night');
    expect(body['visibility'], 'INVITE_ONLY');
    expect(body['maxParticipants'], 8);
    expect(body['invitedUserIds'], ['f1']);
  });

  testWidgets('create event from a match pre-fills game and invitees',
      (tester) async {
    await pumpApp(
      tester,
      api: api,
      location: '/events/create?matchGroupId=mg1',
    );

    expect(find.text('Catan'), findsOneWidget);
    expect(find.byKey(const ValueKey('invitee-f1')), findsOneWidget);
    expect(find.text('Catan Night'), findsOneWidget);
    expect(find.text('PRE-FILLED FROM YOUR MATCH'), findsOneWidget);

    // Removing the game and the invitee.
    await tester.tap(find.byKey(const Key('event-remove-game')));
    await tester.pump();
    expect(find.byKey(const Key('event-pick-game')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('invitee-f1')));
    await tester.pump();
    expect(find.byKey(const ValueKey('invitee-f1')), findsNothing);
  });

  testWidgets('visibility options and player stepper', (tester) async {
    await pumpApp(tester, api: api, location: '/events/create');

    await tester.ensureVisible(find.text('Public'));
    await tester.tap(find.text('Public'));
    await settle(tester, 3);
    expect(find.text('Anyone can see and join'), findsOneWidget);

    await tester.tap(find.byTooltip('More'));
    await tester.pump();
    expect(find.text('9 players'), findsOneWidget);
    await tester.tap(find.byTooltip('Fewer'));
    await tester.tap(find.byTooltip('Fewer'));
    await tester.pump();
    expect(find.text('7 players'), findsOneWidget);
  });

  testWidgets('edit event loads the current values', (tester) async {
    api.put('/api/v1/events/e1', eventJson());
    await pumpApp(tester, api: api, location: '/events/e1/edit');
    expect(find.text('Edit Event'), findsOneWidget);
    expect(find.text('Catan Night'), findsOneWidget);
    expect(find.text('Save Changes'), findsOneWidget);
  });
}
