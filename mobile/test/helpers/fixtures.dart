// JSON fixtures shaped like the backend DTOs / GAP §6.1 contracts.

Map<String, dynamic> userJson({
  String id = 'me',
  String username = 'meeple',
  String displayName = 'Mia Meeple',
  bool onboardingCompleted = true,
  String? preferredLanguage,
}) =>
    {
      'id': id,
      'username': username,
      'displayName': displayName,
      'email': '$username@example.com',
      'avatarUrl': null,
      'bio': 'Euro gamer',
      'location': 'KL',
      'onboardingCompleted': onboardingCompleted,
      'isAdmin': false,
      'isVerified': true,
      'preferredLanguage': preferredLanguage,
      'createdAt': '2026-01-01T00:00:00Z',
    };

Map<String, dynamic> summaryJson(String id, [String name = 'Friend']) => {
      'id': id,
      'username': name.toLowerCase(),
      'displayName': name,
      'avatarUrl': null,
      'deleted': false,
    };

Map<String, dynamic> gameJson({
  String id = 'g1',
  String title = 'Catan',
  bool hasRulebook = true,
}) =>
    {
      'id': id,
      'bggId': 13,
      'title': title,
      'thumbnailUrl': null,
      'imageUrl': null,
      'description': 'Trade &amp; build<br/>on an island.',
      'yearPublished': 1995,
      'minPlayers': 3,
      'maxPlayers': 4,
      'playTime': 90,
      'minAge': 10,
      'complexityWeight': 2.3,
      'bggRating': 7.1,
      'rank': 500,
      'usersRated': 1000,
      'categories': ['Strategy'],
      'mechanics': ['Trading'],
      'designers': ['Klaus Teuber'],
      'publishers': ['Kosmos'],
      'hasRulebook': hasRulebook,
      'friendAvgRating': 8.0,
      'friendRatingCount': 2,
      'ownedByFriends': [summaryJson('f1', 'Fred')],
    };

Map<String, dynamic> userGameJson({
  String gameId = 'g1',
  String title = 'Catan',
  bool owned = true,
  bool wishlisted = false,
  bool favorited = false,
}) =>
    {
      'id': 'ug-$gameId',
      'game': gameJson(id: gameId, title: title),
      'isOwned': owned,
      'isWishlisted': wishlisted,
      'isFavorited': favorited,
      'playCount': 3,
      'personalRating': 8.5,
      'notes': 'Great',
    };

Map<String, dynamic> postJson({
  String id = 'p1',
  String authorId = 'f1',
  String caption = 'Great game night',
  bool liked = false,
  int likes = 2,
  int comments = 1,
  String? createdAt,
}) =>
    {
      'id': id,
      'author': summaryJson(authorId, authorId == 'me' ? 'Mia Meeple' : 'Fred'),
      'caption': caption,
      'location': 'Cafe',
      'playedAt': '2026-09-01T10:00:00Z',
      'imageUrls': <String>[],
      'game': gameJson(),
      'taggedUsers': [summaryJson('f2', 'Tina')],
      'likeCount': likes,
      'commentCount': comments,
      'likedByMe': liked,
      'isBookmarked': false,
      'editedAt': null,
      'createdAt': createdAt ?? DateTime.now().toUtc().toIso8601String(),
    };

Map<String, dynamic> commentJson({String id = 'c1', String authorId = 'me'}) =>
    {
      'id': id,
      'authorId': authorId,
      'authorUsername': authorId == 'me' ? 'meeple' : 'fred',
      'authorAvatarUrl': null,
      'body': 'Nice!',
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    };

Map<String, dynamic> eventJson({
  String id = 'e1',
  String title = 'Catan Night',
  String? myRsvp = 'ACCEPTED',
  bool isHost = false,
  String status = 'OPEN',
  DateTime? at,
  List<Map<String, dynamic>>? participants,
}) =>
    {
      'id': id,
      'host': summaryJson(isHost ? 'me' : 'f1', isHost ? 'Mia Meeple' : 'Fred'),
      'game': gameJson(),
      'title': title,
      'description': 'Bring snacks',
      'location': 'Cafe',
      'locationDisplay': null,
      'scheduledAt': (at ?? DateTime.now().add(const Duration(days: 3)))
          .toUtc()
          .toIso8601String(),
      'maxParticipants': 6,
      'participantCount': 2,
      'visibility': 'FRIENDS',
      'status': status,
      'myRsvp': myRsvp,
      'isHost': isHost,
      'participants': participants ??
          [
            {...summaryJson('f1', 'Fred'), 'status': 'ACCEPTED'},
            {...summaryJson('f2', 'Tina'), 'status': 'INVITED'},
          ],
      'createdAt': '2026-01-01T00:00:00Z',
    };

Map<String, dynamic> notificationJson({
  String id = 'n1',
  String type = 'FRIEND_REQUEST',
  bool read = false,
  String? title,
  String? path = '/profile/f1',
  DateTime? at,
}) =>
    {
      'id': id,
      'type': type,
      'actor': summaryJson('f1', 'Fred'),
      'referenceId': 'f1',
      'referenceType': 'USER',
      'title': title,
      'body': null,
      'data': {if (path != null) 'path': path},
      'read': read,
      'createdAt': (at ?? DateTime.now()).toUtc().toIso8601String(),
    };

Map<String, dynamic> matchGroupJson({String id = 'mg1'}) => {
      'id': id,
      'game': gameJson(),
      'overlapStart': DateTime.now()
          .add(const Duration(days: 2))
          .toUtc()
          .toIso8601String(),
      'overlapEnd': DateTime.now()
          .add(const Duration(days: 2, hours: 3))
          .toUtc()
          .toIso8601String(),
      'status': 'PENDING',
      'members': [summaryJson('me', 'Mia Meeple'), summaryJson('f1', 'Fred')],
      'createdAt': '2026-01-01T00:00:00Z',
    };

Map<String, dynamic> cursor(List<Object?> items, {String? next}) => {
      'items': items,
      'nextCursor': next,
      'hasMore': next != null,
    };

Map<String, dynamic> springPage(List<Object?> items) => {
      'content': items,
      'page': {
        'size': 21,
        'number': 0,
        'totalElements': items.length,
        'totalPages': 1,
      },
    };
