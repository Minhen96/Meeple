import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meeple_hearth/core/network/api_exception.dart';
import 'package:meeple_hearth/core/network/auth_session.dart';
import 'package:meeple_hearth/core/network/dio_client.dart';
import 'package:meeple_hearth/core/network/upload_repository.dart';
import 'package:meeple_hearth/features/auth/domain/user_model.dart';
import 'package:meeple_hearth/features/events/domain/event_model.dart';
import 'package:meeple_hearth/features/library/domain/game_model.dart';
import 'package:meeple_hearth/features/library/domain/user_game_model.dart';
import 'package:meeple_hearth/features/posts/domain/post_model.dart';
import 'package:meeple_hearth/shared/models/pagination_model.dart';

const _game = {
  'id': 'g1',
  'bggId': 13,
  'title': 'Catan',
  'thumbnailUrl': null,
  'yearPublished': 1995,
  'minPlayers': 3,
  'maxPlayers': 4,
  'playTime': 90,
  'minAge': 10,
  'rank': 500,
  'usersRated': 1000,
  'bggRating': 7.1,
};

Response<dynamic> _response(Object? data,
        {Map<String, List<String>>? headers}) =>
    Response<dynamic>(
      requestOptions: RequestOptions(path: '/x'),
      data: data,
      statusCode: 200,
      headers: Headers.fromMap(headers ?? {}),
    );

void main() {
  group('response envelope', () {
    test('unwraps {data: T} but keeps paged {data, meta}', () {
      final interceptor = ApiResponseUnwrapInterceptor();
      final single = _response({
        'data': {'id': 'x'}
      });
      interceptor.onResponse(single, ResponseInterceptorHandler());
      expect(single.data, {'id': 'x'});

      final paged = _response({
        'data': <Object>[],
        'meta': {'page': 1}
      });
      interceptor.onResponse(paged, ResponseInterceptorHandler());
      expect((paged.data as Map).containsKey('meta'), isTrue);
    });

    test('PageResponse meta is converted to a 0-based page', () {
      final page = PaginatedResult<int>.fromJson(
        {
          'data': [1, 2],
          'meta': {'page': 1, 'limit': 2, 'total': 5, 'hasMore': true},
        },
        (e) => e! as int,
      );
      expect(page.page, 0);
      expect(page.hasMore, isTrue);
      expect(page.totalPages, 3);
    });

    test('Spring page DTO is parsed', () {
      final page = PaginatedResult<Game>.fromJson(
        {
          'content': [_game],
          'page': {
            'size': 20,
            'number': 0,
            'totalElements': 1,
            'totalPages': 1
          },
        },
        (e) => Game.fromJson(e! as Map<String, dynamic>),
      );
      expect(page.content.single.name, 'Catan');
      expect(page.hasMore, isFalse);
    });
  });

  group('errors', () {
    ApiException fromStatus(int status, Map<String, dynamic> body) =>
        ApiException.from(
          DioException(
            requestOptions: RequestOptions(path: '/x'),
            type: DioExceptionType.badResponse,
            response: Response<dynamic>(
              requestOptions: RequestOptions(path: '/x'),
              statusCode: status,
              data: body,
            ),
          ),
        );

    test('reads {error, code}', () {
      final e = fromStatus(
          400, {'error': 'Invalid image key', 'code': 'INVALID_IMAGE_KEY'});
      expect(e, isA<BadRequestException>());
      expect(e.message, 'Invalid image key');
      expect(e.code, 'INVALID_IMAGE_KEY');
    });

    test('maps specific codes and statuses', () {
      expect(
        fromStatus(400, {'error': 'verify', 'code': 'EMAIL_NOT_VERIFIED'}),
        isA<EmailNotVerifiedException>(),
      );
      expect(fromStatus(413, {'error': 'big', 'code': 'FILE_TOO_LARGE'}),
          isA<PayloadTooLargeException>());
      expect(fromStatus(503, {'error': 'down', 'code': 'BGG_UNAVAILABLE'}).code,
          'BGG_UNAVAILABLE');
      expect(fromStatus(409, {'error': 'c', 'code': 'GOOGLE_ACCOUNT_CONFLICT'}),
          isA<ConflictException>());
      expect(
          fromStatus(
                  401, {'error': 'Invalid credentials', 'code': 'UNAUTHORIZED'})
              .message,
          'Invalid credentials');
    });
  });

  group('tokens', () {
    test('extracts the token pair from Set-Cookie headers', () {
      final res = _response({
        'id': 'u'
      }, headers: {
        'set-cookie': [
          'access_token=aaa; Path=/; Max-Age=900; HttpOnly; SameSite=Lax',
          'refresh_token=rrr; Path=/; Max-Age=2592000; HttpOnly; SameSite=Lax',
        ],
      });
      final tokens = extractAuthTokens(res)!;
      expect(tokens.accessToken, 'aaa');
      expect(tokens.refreshToken, 'rrr');
    });

    test('ignores cleared cookies', () {
      final res = _response(null, headers: {
        'set-cookie': ['access_token=; Max-Age=0', 'refresh_token=; Max-Age=0'],
      });
      expect(extractAuthTokens(res), isNull);
    });

    test('decodes JWT expiry', () {
      String b64(Object o) =>
          base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
      final token = '${b64({'alg': 'HS256'})}.${b64({'exp': 2000000000})}.sig';
      expect(jwtExpiry(token)!.millisecondsSinceEpoch, 2000000000 * 1000);
    });
  });

  test('detects accepted image types by magic bytes', () {
    expect(detectImageContentType(Uint8List.fromList([0xFF, 0xD8, 0xFF, 0])),
        'image/jpeg');
    expect(
      detectImageContentType(Uint8List.fromList(
          [0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x45, 0x42, 0x50])),
      'image/webp',
    );
    expect(detectImageContentType(Uint8List.fromList([1, 2, 3, 4])), isNull);
  });

  group('models match backend DTOs', () {
    test('AuthResponse / UserProfileResponse', () {
      final user = User.fromJson({
        'id': 'u1',
        'username': 'meeple',
        'displayName': null,
        'avatarUrl': null,
        'onboardingCompleted': true,
        'isAdmin': false,
        'createdAt': '2026-01-01T00:00:00Z',
      });
      expect(user.displayName, 'meeple');
      expect(user.email, isNull);
    });

    test('UserGameResponse', () {
      final ug = UserGame.fromJson({
        'id': 'ug1',
        'game': _game,
        'isOwned': true,
        'isFavorited': false,
        'playCount': 3,
        'personalRating': 8.5,
        'notes': null,
      });
      expect(ug.gameId, 'g1');
      expect(ug.personalRating, 8.5);
    });

    test('PostResponse and PostCommentResponse', () {
      final post = Post.fromJson({
        'id': 'p1',
        'author': {
          'id': 'u1',
          'username': 'a',
          'displayName': 'A',
          'avatarUrl': null
        },
        'caption': null,
        'location': null,
        'playedAt': null,
        'imageUrls': ['https://cdn/x.jpg'],
        'game': _game,
        'taggedUsers': <Object>[],
        'likeCount': 2,
        'commentCount': 1,
        'likedByMe': true,
        'createdAt': '2026-01-01T00:00:00Z',
      });
      expect(post.author.id, 'u1');
      expect(post.caption, '');
      expect(post.game!.name, 'Catan');
      expect(post.likedByMe, isTrue);
      expect(post.isBookmarked, isFalse);

      final comment = Comment.fromJson({
        'id': 'c1',
        'authorId': 'u1',
        'authorUsername': 'a',
        'authorAvatarUrl': null,
        'body': 'nice',
        'createdAt': '2026-01-01T00:00:00Z',
      });
      expect(comment.content, 'nice');
    });

    test('EventResponse', () {
      final event = Event.fromJson({
        'id': 'e1',
        'host': {
          'id': 'u1',
          'username': 'h',
          'displayName': 'Host',
          'avatarUrl': null
        },
        'game': _game,
        'title': 'Game night',
        'description': null,
        'location': null,
        'scheduledAt': '2026-12-01T18:00:00Z',
        'maxParticipants': 8,
        'participantCount': 2,
        'visibility': 'INVITE_ONLY',
        'status': 'OPEN',
        'myRsvp': 'ACCEPTED',
        'createdAt': '2026-01-01T00:00:00Z',
      });
      expect(event.host!.displayName, 'Host');
      expect(event.isAttending, isTrue);
      expect(event.maxParticipants, 8);
      expect(event.game!.name, 'Catan');
      expect(event.participants, isEmpty);
    });
  });
}
