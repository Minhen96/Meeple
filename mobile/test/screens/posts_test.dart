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
      ..get('/api/v1/posts/p1', postJson())
      ..get('/api/v1/posts/p1/comments', cursor([
        commentJson(),
        commentJson(id: 'c2', authorId: 'f1'),
      ]))
      ..post('/api/v1/posts/p1/comments', commentJson(id: 'c3'))
      ..put('/api/v1/posts/p1/comments/c1', {...commentJson(), 'body': 'Edited!'})
      ..delete('/api/v1/posts/p1/comments/c1', const FakeResponse.noContent())
      ..post('/api/v1/posts/p1/bookmark', const FakeResponse.noContent())
      ..post('/api/v1/reports', const FakeResponse(null, status: 201));
  });

  testWidgets('post detail shows caption, tags, comments', (tester) async {
    await pumpApp(tester, api: api, location: '/posts/p1');

    expect(find.text('Great game night'), findsOneWidget);
    expect(find.text('With:'), findsOneWidget);
    expect(find.textContaining('Nice!', findRichText: true), findsNWidgets(2));
  });

  testWidgets('adding a comment appends it and bumps the counter',
      (tester) async {
    await pumpApp(tester, api: api, location: '/posts/p1');

    await tester.enterText(find.byKey(const Key('comment-input')), 'Fun!');
    await tester.tap(find.byKey(const Key('comment-send')));
    await settle(tester);

    expect((api.calls('POST', '/api/v1/posts/p1/comments').single.data as Map)['body'], 'Fun!');
    expect(find.text('2 comments'), findsOneWidget);
  });

  testWidgets('own comment can be edited and deleted', (tester) async {
    await pumpApp(tester, api: api, location: '/posts/p1');

    await tester.tap(find.byKey(const ValueKey('comment-menu-c1')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('comment-edit')));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('comment-edit-field')), 'Edited!');
    await tester.tap(find.byKey(const Key('comment-edit-save')));
    await settle(tester);
    expect(find.textContaining('Edited!', findRichText: true), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('comment-menu-c1')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('comment-delete')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('confirm-sheet-confirm')));
    await settle(tester);
    expect(api.called('DELETE', '/api/v1/posts/p1/comments/c1'), isTrue);
  });

  testWidgets("others' comments can be reported", (tester) async {
    await pumpApp(tester, api: api, location: '/posts/p1');

    await tester.tap(find.byKey(const ValueKey('comment-menu-c2')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('comment-report')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('report-spam')));
    await settle(tester);

    final report = api.calls('POST', '/api/v1/reports').single.data as Map;
    expect(report, {'targetType': 'comment', 'targetId': 'c2', 'reason': 'spam'});
  });

  testWidgets('bookmarking a post', (tester) async {
    await pumpApp(tester, api: api, location: '/posts/p1');

    await tester.tap(find.byKey(const ValueKey('bookmark-p1')).first);
    await settle(tester);
    expect(api.called('POST', '/api/v1/posts/p1/bookmark'), isTrue);
  });

  testWidgets('removed post shows a message', (tester) async {
    await pumpApp(tester, api: api, location: '/posts/gone');
    expect(find.text('This post has been removed.'), findsOneWidget);
  });

  testWidgets('own post menu offers edit and delete', (tester) async {
    api
      ..get('/api/v1/posts/p9', postJson(id: 'p9', authorId: 'me'))
      ..get('/api/v1/posts/p9/comments', cursor([]))
      ..put('/api/v1/posts/p9', postJson(id: 'p9', authorId: 'me', caption: 'Updated'))
      ..delete('/api/v1/posts/p9', const FakeResponse.noContent());
    await pumpApp(tester, api: api, location: '/posts/p9');

    expect(find.text('Be the first to comment!'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('post-menu-p9')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('post-menu-edit')));
    await settle(tester);

    expect(find.text('Edit post'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('post-caption')), 'Updated');
    await tester.tap(find.byKey(const Key('post-submit')));
    await settle(tester);
    final put = api.calls('PUT', '/api/v1/posts/p9').single.data as Map;
    expect(put['caption'], 'Updated');
    expect(find.text('Updated'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('post-menu-p9')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('post-menu-delete')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('confirm-sheet-confirm')));
    await settle(tester);
    expect(api.called('DELETE', '/api/v1/posts/p9'), isTrue);
  });

  testWidgets('creating a text post goes home with a toast', (tester) async {
    api.post('/api/v1/posts', postJson(id: 'p5', authorId: 'me', caption: 'Hello'));
    await pumpApp(tester, api: api, location: '/posts/create');

    await tester.enterText(find.byKey(const Key('post-caption')), 'Hello');
    await tester.tap(find.byKey(const Key('post-submit')));
    await settle(tester);

    final body = api.calls('POST', '/api/v1/posts').single.data as Map;
    expect(body['caption'], 'Hello');
    expect(find.text('Posted!'), findsOneWidget);
    expect(find.text('Hello'), findsOneWidget);
  });

  testWidgets('empty post is rejected', (tester) async {
    await pumpApp(tester, api: api, location: '/posts/create');
    await tester.tap(find.byKey(const Key('post-submit')));
    await settle(tester);
    expect(find.text('Add a photo or a caption.'), findsOneWidget);
  });

  testWidgets('bookmarks screen lists saved posts', (tester) async {
    api.get('/api/v1/users/me/bookmarks', cursor([postJson()]));
    await pumpApp(tester, api: api, location: '/bookmarks');
    expect(find.text('Great game night'), findsOneWidget);
  });
}
