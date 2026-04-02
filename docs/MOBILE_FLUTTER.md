# Meeple — Mobile (Flutter) Complete Plan

> Phase 3 implementation. Same Spring Boot backend, same design system translated to Flutter.

---

## 1. Platform Targets

| Platform | Minimum Version | Notes |
|----------|----------------|-------|
| Android | API 24 (Android 7.0) | Covers 95%+ of active Android devices |
| iOS | iOS 15.0 | Covers 97%+ of active iOS devices |

---

## 2. Package Decisions (Final)

All packages chosen and locked. No switching mid-project.

### Core

| Need | Package | Version | Notes |
|------|---------|---------|-------|
| State management | `flutter_riverpod` | ^2.x | Code-gen with `riverpod_generator` |
| Navigation | `go_router` | ^14.x | Declarative, deep links, nested shells |
| HTTP client | `dio` | ^5.x | Interceptors for JWT refresh |
| Secure storage | `flutter_secure_storage` | ^9.x | Tokens in Keychain/Keystore |
| Local DB / cache | `isar` | ^3.x | Fast NoSQL, great Flutter support |
| WebSocket/STOMP | `stomp_dart_client` | ^2.x | STOMP over WebSocket |

### Firebase & Notifications

| Need | Package | Notes |
|------|---------|-------|
| Push notifications | `firebase_messaging` | FCM for background + killed state |
| Firebase core | `firebase_core` | Required by all Firebase packages |
| Local notifications | `flutter_local_notifications` | Show in-app notification banners when foreground |

### Media & Files

| Need | Package | Notes |
|------|---------|-------|
| Image picker | `image_picker` | Gallery + camera, multi-select |
| Image compression | `flutter_image_compress` | WebP output, max 1200px, max 1MB |
| Image cropping | `image_cropper` | Avatar crop only (1:1) |
| Cached images | `cached_network_image` | Disk + memory cache for feed images |
| Share | `share_plus` | Native share sheet |
| File picker | `file_picker` | For non-image attachments (future) |

### UI & UX

| Need | Package | Notes |
|------|---------|-------|
| Animations | `flutter_animate` | Declarative animations |
| Pull to refresh | Built-in `RefreshIndicator` | Standard Flutter widget |
| Infinite scroll | `infinite_scroll_pagination` | PagingController pattern |
| Calendar UI | `table_calendar` | Events calendar view |
| Date/time picker | `omni_datetime_picker` | Combined date + time in one |
| Shimmer loading | `shimmer` | Skeleton screens |

### Device & Platform

| Need | Package | Notes |
|------|---------|-------|
| Connectivity | `connectivity_plus` | Detect online/offline |
| Deep links | `go_router` + `app_links` | Universal Links (iOS) + App Links (Android) |
| Biometric auth | `local_auth` | FaceID, TouchID, fingerprint |
| URL launcher | `url_launcher` | Open external links (BGG, etc.) |
| Permissions | `permission_handler` | Camera, notifications, storage |
| Location | `geolocator` + `geocoding` | Phase 4 — map-based location |
| Haptics | `flutter_haptic_feedback` | Tactile feedback on key actions |

### Code Quality

| Need | Package | Notes |
|------|---------|-------|
| Code generation | `build_runner` | For Riverpod + Isar + Freezed |
| Immutable models | `freezed` + `json_serializable` | Type-safe models with `copyWith` |
| Crash reporting | `sentry_flutter` | Error monitoring |
| Analytics | `posthog_flutter` | User analytics |

---

## 3. Project Structure

```
lib/
├── main.dart                        # Entry point, Firebase init, ProviderScope
├── app.dart                         # MaterialApp.router, GoRouter, theme
│
├── core/
│   ├── constants/
│   │   ├── app_colors.dart          # Color tokens (matches Tailwind config)
│   │   ├── app_typography.dart      # TextStyle definitions
│   │   ├── app_spacing.dart         # Spacing constants (8, 12, 16, 24px)
│   │   └── api_constants.dart       # Base URLs, endpoints
│   ├── theme/
│   │   └── app_theme.dart           # ThemeData (light + dark)
│   ├── router/
│   │   └── app_router.dart          # GoRouter config, all routes, deep links
│   ├── network/
│   │   ├── dio_client.dart          # Dio instance with interceptors
│   │   ├── auth_interceptor.dart    # JWT refresh interceptor
│   │   └── api_exception.dart       # ApiException from error codes
│   ├── storage/
│   │   ├── secure_storage.dart      # flutter_secure_storage wrapper
│   │   └── isar_service.dart        # Isar DB initialization
│   └── utils/
│       ├── date_utils.dart          # Relative time, format helpers
│       ├── image_utils.dart         # Compression, EXIF strip
│       └── logger.dart              # Structured logging
│
├── features/
│   ├── auth/
│   │   ├── data/
│   │   │   ├── auth_repository.dart
│   │   │   └── auth_local_storage.dart    # Secure token storage
│   │   ├── domain/
│   │   │   └── user_model.dart            # @freezed
│   │   ├── presentation/
│   │   │   ├── login_screen.dart
│   │   │   ├── register_screen.dart
│   │   │   ├── verify_email_screen.dart
│   │   │   ├── forgot_password_screen.dart
│   │   │   └── reset_password_screen.dart
│   │   └── providers/
│   │       └── auth_provider.dart         # @riverpod
│   │
│   ├── onboarding/
│   │   ├── presentation/
│   │   │   ├── onboarding_welcome_screen.dart
│   │   │   ├── onboarding_profile_screen.dart
│   │   │   ├── onboarding_bgg_screen.dart
│   │   │   ├── onboarding_friends_screen.dart
│   │   │   └── onboarding_game_screen.dart
│   │   └── providers/
│   │       └── onboarding_provider.dart
│   │
│   ├── home/
│   │   ├── data/
│   │   │   └── feed_repository.dart
│   │   ├── domain/
│   │   │   └── feed_item_model.dart
│   │   ├── presentation/
│   │   │   ├── home_screen.dart
│   │   │   ├── widgets/
│   │   │   │   ├── match_suggestion_card.dart
│   │   │   │   ├── upcoming_events_row.dart
│   │   │   │   ├── post_card.dart
│   │   │   │   └── activity_item_card.dart
│   │   └── providers/
│   │       ├── feed_provider.dart
│   │       └── home_provider.dart
│   │
│   ├── library/
│   │   ├── data/
│   │   │   ├── game_repository.dart
│   │   │   └── collection_repository.dart
│   │   ├── domain/
│   │   │   ├── game_model.dart
│   │   │   └── user_game_model.dart
│   │   ├── presentation/
│   │   │   ├── library_screen.dart          # Tabs
│   │   │   ├── game_detail_screen.dart
│   │   │   └── widgets/
│   │   │       ├── game_card.dart
│   │   │       └── game_info_bar.dart
│   │   └── providers/
│   │       ├── library_provider.dart
│   │       └── game_detail_provider.dart
│   │
│   ├── events/
│   │   ├── data/
│   │   │   └── event_repository.dart
│   │   ├── domain/
│   │   │   └── event_model.dart
│   │   ├── presentation/
│   │   │   ├── events_screen.dart
│   │   │   ├── event_detail_screen.dart
│   │   │   ├── create_event_screen.dart
│   │   │   └── widgets/
│   │   │       ├── event_card.dart
│   │   │       └── event_calendar_view.dart
│   │   └── providers/
│   │       └── events_provider.dart
│   │
│   ├── posts/
│   │   ├── data/
│   │   │   └── post_repository.dart
│   │   ├── domain/
│   │   │   └── post_model.dart
│   │   ├── presentation/
│   │   │   ├── post_detail_screen.dart
│   │   │   ├── create_post_screen.dart
│   │   │   └── widgets/
│   │   │       ├── image_carousel.dart
│   │   │       └── comment_tile.dart
│   │   └── providers/
│   │       └── post_provider.dart
│   │
│   ├── profile/
│   ├── notifications/
│   ├── matching/
│   ├── settings/
│   └── ai/
│
└── shared/
    ├── widgets/
    │   ├── app_button.dart          # Primary, secondary, tertiary buttons
    │   ├── app_avatar.dart          # CachedNetworkImage avatar
    │   ├── app_chip.dart            # Status chips
    │   ├── app_bottom_nav.dart      # Bottom navigation bar
    │   ├── app_bar.dart             # Custom top app bar
    │   ├── skeleton_widget.dart     # Shimmer skeleton
    │   ├── empty_state.dart         # Empty state with illustration + CTA
    │   ├── error_state.dart         # Error state with retry
    │   └── glass_container.dart     # Glassmorphic container
    └── models/
        └── pagination_model.dart    # Cursor pagination wrapper
```

---

## 4. State Management (Riverpod)

### Philosophy

- One `Provider` per data source (repository-level)
- One `AsyncNotifierProvider` per screen/feature for business logic
- No God providers — each feature is self-contained

### Key Providers

```dart
// Auth state — available app-wide
@riverpod
class AuthNotifier extends _$AuthNotifier {
  @override
  Future<User?> build() async {
    return _authRepo.getCurrentUser(); // reads from secure storage
  }

  Future<void> login(String emailOrUsername, String password) async { ... }
  Future<void> logout() async { ... }
  Future<void> refreshToken() async { ... }
}

// Feed — home screen
@riverpod
class FeedNotifier extends _$FeedNotifier {
  @override
  Future<List<FeedItem>> build() async {
    return _feedRepo.getFeed(cursor: null, limit: 20);
  }

  Future<void> loadMore(String cursor) async { ... }
  Future<void> refresh() async { ... }
}

// Notification unread count — displayed in BottomNav badge
@riverpod
Stream<int> unreadNotificationCount(Ref ref) {
  // Updated via WebSocket events + initial fetch
}

// WebSocket connection state
@riverpod
class WebSocketNotifier extends _$WebSocketNotifier {
  @override
  WebSocketState build() => WebSocketState.disconnected;

  void connect(String token) { ... }
  void disconnect() { ... }
}
```

### Optimistic Updates

For like/unlike and follow/unfollow:
```dart
// Immediately update local state, revert on error
Future<void> toggleLike(String postId) async {
  // 1. Optimistically update
  state = state.copyWith(isLiked: !state.isLiked,
    likeCount: state.isLiked ? state.likeCount - 1 : state.likeCount + 1);

  // 2. API call
  try {
    if (state.isLiked) {
      await _postRepo.likePost(postId);
    } else {
      await _postRepo.unlikePost(postId);
    }
  } catch (e) {
    // 3. Revert on failure
    state = state.copyWith(isLiked: !state.isLiked,
      likeCount: state.isLiked ? state.likeCount - 1 : state.likeCount + 1);
    ref.read(toastProvider.notifier).show("Failed to update like", type: ToastType.error);
  }
}
```

---

## 5. Navigation (go_router)

### Route Structure

```dart
final router = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    final authState = ref.read(authProvider);
    final isLoggedIn = authState.valueOrNull != null;
    final isOnboarding = authState.valueOrNull?.onboardingCompleted == false;

    if (!isLoggedIn && !state.matchedLocation.startsWith('/auth')) {
      return '/auth/login?redirect=${state.matchedLocation}';
    }
    if (isLoggedIn && isOnboarding && !state.matchedLocation.startsWith('/onboarding')) {
      return '/onboarding/welcome';
    }
    return null;
  },
  routes: [
    // Auth
    GoRoute(path: '/auth/login', builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/auth/register', builder: (_, __) => const RegisterScreen()),
    GoRoute(path: '/auth/verify-email', builder: (_, __) => const VerifyEmailScreen()),
    GoRoute(path: '/auth/forgot-password', builder: (_, __) => const ForgotPasswordScreen()),
    GoRoute(path: '/auth/reset-password', builder: (context, state) =>
      ResetPasswordScreen(token: state.uri.queryParameters['token'] ?? '')),

    // Onboarding
    GoRoute(path: '/onboarding/welcome', builder: (_, __) => const OnboardingWelcomeScreen()),
    GoRoute(path: '/onboarding/profile', builder: (_, __) => const OnboardingProfileScreen()),
    GoRoute(path: '/onboarding/bgg-import', builder: (_, __) => const OnboardingBggScreen()),
    GoRoute(path: '/onboarding/find-friends', builder: (_, __) => const OnboardingFriendsScreen()),
    GoRoute(path: '/onboarding/add-game', builder: (_, __) => const OnboardingAddGameScreen()),

    // Main app — StatefulShellRoute for per-tab stack preservation
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => MainShell(shell: shell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/library',
            builder: (_, __) => const LibraryScreen(),
            routes: [
              GoRoute(path: 'games/:gameId', builder: (context, state) =>
                GameDetailScreen(gameId: state.pathParameters['gameId']!)),
            ],
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/events',
            builder: (_, __) => const EventsScreen(),
            routes: [
              GoRoute(path: ':eventId', builder: (context, state) =>
                EventDetailScreen(eventId: state.pathParameters['eventId']!)),
              GoRoute(path: 'create', builder: (_, state) =>
                CreateEventScreen(matchGroupId: state.uri.queryParameters['matchGroupId'])),
            ],
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/profile',
            builder: (_, __) => const OwnProfileScreen(),
            routes: [
              GoRoute(path: ':userId', builder: (context, state) =>
                UserProfileScreen(userId: state.pathParameters['userId']!)),
              GoRoute(path: 'followers', builder: (_, __) => const FollowersScreen()),
              GoRoute(path: 'following', builder: (_, __) => const FollowingScreen()),
            ],
          ),
        ]),
      ],
    ),

    // Full-screen routes (no BottomNav)
    GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),
    GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen(),
      routes: [
        GoRoute(path: 'profile', builder: (_, __) => const EditProfileScreen()),
        GoRoute(path: 'notifications', builder: (_, __) => const NotificationPrefsScreen()),
        GoRoute(path: 'sessions', builder: (_, __) => const ActiveSessionsScreen()),
        GoRoute(path: 'delete-account', builder: (_, __) => const DeleteAccountScreen()),
      ]),
    GoRoute(path: '/posts/create', builder: (_, __) => const CreatePostScreen()),
    GoRoute(path: '/posts/:postId', builder: (context, state) =>
      PostDetailScreen(postId: state.pathParameters['postId']!)),
    GoRoute(path: '/search', builder: (_, __) => const SearchScreen()),
  ],
);
```

### Deep Link Handling (from Push Notification)

```dart
// In main.dart, after Firebase.initializeApp():
FirebaseMessaging.onMessageOpenedApp.listen((message) {
  final path = message.data['path'] as String?;
  if (path != null) {
    router.go(path);
  }
});

// App launched from killed state via notification:
final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
if (initialMessage != null) {
  final path = initialMessage.data['path'] as String?;
  if (path != null) {
    // GoRouter's initialLocation handles this:
    router = GoRouter(initialLocation: path, ...);
  }
}
```

---

## 6. Local Storage (Isar)

### Cached Models

```dart
// Collection cache — browsable offline
@collection
class CachedGame {
  Id id = Isar.autoIncrement;
  late String serverId;         // UUID from server
  late String name;
  String? imageUrl;
  int? minPlayers;
  int? maxPlayers;
  late DateTime cachedAt;
}

@collection
class CachedUserGame {
  Id id = Isar.autoIncrement;
  late String gameId;
  late bool isOwned;
  late bool isWishlisted;
  late bool isFavorited;
  int playCount = 0;
  int? personalRating;
  late DateTime updatedAt;
}

// Feed cache — last 50 items
@collection
class CachedFeedItem {
  Id id = Isar.autoIncrement;
  late String serverId;
  late String type;     // 'post' | 'activity'
  late String jsonData; // Full JSON as string
  late DateTime createdAt;
  late DateTime cachedAt;
}

// Notification cache
@collection
class CachedNotification {
  Id id = Isar.autoIncrement;
  late String serverId;
  late String type;
  late String title;
  late String body;
  late bool isRead;
  late DateTime createdAt;
}
```

### Cache Strategy

| Data | Cache Duration | Offline Read |
|------|---------------|--------------|
| My Collection | 24h | ✅ Yes |
| Feed (last 50 items) | 1h | ✅ Yes (stale banner shown) |
| Upcoming Events | 30min | ✅ Yes |
| Notifications | 30min | ✅ Yes |
| Game Detail | 7 days | ✅ Yes |
| User profiles | 1h | ✅ Yes |

**Stale data indicator:**
```dart
if (isCacheStale && isOffline) {
  // Show banner: "Showing cached data from X hours ago"
}
```

---

## 7. Token Storage & JWT Refresh

### Secure Storage Keys

```dart
const _accessTokenKey = 'access_token';
const _refreshTokenKey = 'refresh_token';
const _userIdKey = 'user_id';
const _fcmTokenKey = 'fcm_token';
```

### Dio Auth Interceptor

```dart
class AuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _secureStorage.read(_accessTokenKey);
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      try {
        // Attempt token refresh
        final refreshToken = await _secureStorage.read(_refreshTokenKey);
        final response = await _dio.post('/api/v1/auth/refresh',
          data: {'refreshToken': refreshToken});

        final newAccessToken = response.data['accessToken'];
        await _secureStorage.write(_accessTokenKey, newAccessToken);

        // Retry the original request
        final opts = err.requestOptions;
        opts.headers['Authorization'] = 'Bearer $newAccessToken';
        final retryResponse = await _dio.fetch(opts);
        handler.resolve(retryResponse);
      } catch (e) {
        // Refresh failed — force logout
        ref.read(authProvider.notifier).logout();
        handler.reject(err);
      }
    } else {
      handler.next(err);
    }
  }
}
```

---

## 8. Push Notifications (FCM)

### Setup

```dart
// main.dart
await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

// Request permission (iOS only — Android auto-granted)
final settings = await FirebaseMessaging.instance.requestPermission(
  alert: true, badge: true, sound: true,
);

// Get FCM token and register with backend
final fcmToken = await FirebaseMessaging.instance.getToken();
if (fcmToken != null) {
  await _userRepo.registerFcmToken(fcmToken, platform: Platform.isIOS ? 'ios' : 'android');
}

// Listen for token refresh
FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
  _userRepo.registerFcmToken(newToken, platform: ...);
});
```

### Message Handling

```dart
// Background & killed state handler (top-level function, @pragma required)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Store notification in Isar for display when app opens
  // Do NOT show local notification here — FCM shows system notification automatically
}

// Foreground handler (app is open)
FirebaseMessaging.onMessage.listen((message) {
  // Show in-app notification banner using flutter_local_notifications
  _localNotifications.show(
    message.hashCode,
    message.notification?.title,
    message.notification?.body,
    _notificationDetails,
    payload: message.data['path'],
  );
  // Also update notification count in Riverpod state
  ref.read(unreadCountProvider.notifier).increment();
});
```

### Android Notification Channels

```dart
const channel = AndroidNotificationChannel(
  'meeple_hearth_events',
  'Events & Game Nights',
  description: 'Invites, reminders, and match notifications',
  importance: Importance.high,
);

const channel2 = AndroidNotificationChannel(
  'meeple_hearth_social',
  'Social Activity',
  description: 'Likes, comments, and followers',
  importance: Importance.defaultImportance,
);
```

### iOS Pre-Permission Prompt

Before requesting system permission, show a custom screen:
```dart
class NotificationPermissionScreen extends StatelessWidget {
  // "Stay in the loop about your game nights"
  // Icon, description, "Allow Notifications" button, "Not now" button
  // "Allow" taps → request system permission
}
```

---

## 9. Camera & Image Handling

### Image Picker Flow (Create Post)

```dart
Future<List<File>> pickImages() async {
  final List<XFile> images = await _picker.pickMultiImage(
    maxWidth: 2400,  // allow high-res, will compress after
    imageQuality: 100,
  );

  if (images.isEmpty) return [];

  // Compress each image
  final List<File> compressed = [];
  for (final image in images.take(10)) {  // enforce max 10
    final compressedBytes = await FlutterImageCompress.compressWithFile(
      image.path,
      minWidth: 800,
      minHeight: 800,
      quality: 85,
      format: CompressFormat.webp,
    );

    if (compressedBytes != null) {
      final tempFile = await _saveTempFile(compressedBytes, '${image.name}.webp');
      compressed.add(tempFile);
    }
  }
  return compressed;
}
```

### Avatar Picker + Crop

```dart
Future<File?> pickAvatar() async {
  final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
  if (image == null) return null;

  // Crop to 1:1
  final croppedFile = await ImageCropper().cropImage(
    sourcePath: image.path,
    aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
    uiSettings: [
      AndroidUiSettings(toolbarTitle: 'Crop Photo', lockAspectRatio: true),
      IOSUiSettings(title: 'Crop Photo', aspectRatioLockEnabled: true),
    ],
  );

  if (croppedFile == null) return null;

  // Compress to max 200×200 WebP
  final compressed = await FlutterImageCompress.compressWithFile(
    croppedFile.path,
    minWidth: 400, minHeight: 400,
    quality: 90,
    format: CompressFormat.webp,
  );
  return compressed != null ? File(croppedFile.path)..writeAsBytesSync(compressed) : null;
}
```

### EXIF Stripping

```dart
// FlutterImageCompress strips EXIF by default when re-encoding
// Verify: check that GPS data is not present in output
// For extra safety, use exifinterface on Android via platform channel
```

---

## 10. WebSocket Management

### Connection Lifecycle

```dart
class WebSocketNotifier extends _$WebSocketNotifier {
  StompClient? _client;

  void connect(String accessToken) {
    _client = StompClient(
      config: StompConfig(
        url: '${ApiConstants.wsUrl}/ws',
        onConnect: _onConnect,
        onDisconnect: _onDisconnect,
        onStompError: _onError,
        stompConnectHeaders: {'Authorization': 'Bearer $accessToken'},
        heartbeatOutgoing: const Duration(seconds: 10),
        heartbeatIncoming: const Duration(seconds: 10),
        // Reconnect with exponential backoff
        reconnectDelay: const Duration(seconds: 2),
      ),
    );
    _client!.activate();
    state = WebSocketState.connecting;
  }

  void _onConnect(StompFrame frame) {
    state = WebSocketState.connected;

    // Subscribe to personal notification channel
    _client!.subscribe(
      destination: '/user/queue/notifications',
      callback: (frame) {
        if (frame.body == null) return;
        final notification = NotificationDto.fromJson(jsonDecode(frame.body!));
        ref.read(notificationsProvider.notifier).addNotification(notification);
        ref.read(unreadCountProvider.notifier).increment();
        _showLocalBanner(notification);
      },
    );
  }

  void disconnect() {
    _client?.deactivate();
    state = WebSocketState.disconnected;
  }
}
```

### App Lifecycle Integration

```dart
class AppLifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // Reconnect WebSocket
        ref.read(webSocketProvider.notifier).connect(accessToken);
        // Refresh access token proactively if expiring within 5 min
        _refreshTokenIfExpiringSoon();
        // Refresh unread count
        ref.read(unreadCountProvider.notifier).refresh();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        // Don't disconnect immediately — user might just switch apps briefly
        // Schedule disconnect after 30s of background
        Future.delayed(const Duration(seconds: 30), () {
          if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
            ref.read(webSocketProvider.notifier).disconnect();
          }
        });
        break;
      default:
        break;
    }
  }
}
```

---

## 11. Offline Mode

### Detection

```dart
@riverpod
Stream<ConnectivityResult> connectivity(Ref ref) {
  return Connectivity().onConnectivityChanged
    .map((results) => results.first);
}

@riverpod
bool isOffline(Ref ref) {
  final connectivity = ref.watch(connectivityProvider);
  return connectivity.valueOrNull == ConnectivityResult.none;
}
```

### Offline UI

```dart
// AppShell wraps all screens
class AppShell extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOffline = ref.watch(isOfflineProvider);
    return Column(
      children: [
        if (isOffline) const OfflineBanner(),
        Expanded(child: child),
      ],
    );
  }
}

class OfflineBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    height: 32,
    color: AppColors.inverseOnSurface,
    alignment: Alignment.center,
    child: Text('No internet connection',
      style: AppTypography.labelSmall.copyWith(color: AppColors.inverseSurface)),
  );
}
```

### Write Action Guard

```dart
// All write actions (like, post, join event) check connectivity first
Future<void> likePost(String postId) async {
  if (ref.read(isOfflineProvider)) {
    ref.read(toastProvider.notifier).show(
      "You're offline. Action will sync when reconnected.",
      type: ToastType.warning,
    );
    return;
  }
  // ... proceed with API call
}
```

Phase 4 enhancement: offline action queue (store write actions in Isar, replay on reconnect).

---

## 12. Biometric Authentication

```dart
Future<void> enableBiometric() async {
  final localAuth = LocalAuthentication();
  final canCheck = await localAuth.canCheckBiometrics;
  if (!canCheck) {
    // Show: "Biometric auth not available on this device"
    return;
  }

  final authenticated = await localAuth.authenticate(
    localizedReason: 'Verify your identity to enable biometric login',
    options: const AuthenticationOptions(biometricOnly: false),
  );

  if (authenticated) {
    // Save a flag in secure storage
    await _secureStorage.write('biometric_enabled', 'true');
    // Show: "Biometric login enabled!"
  }
}

// On app start, if biometric_enabled = true:
Future<bool> authenticateWithBiometric() async {
  final localAuth = LocalAuthentication();
  return localAuth.authenticate(
    localizedReason: 'Log in to Meeple',
    options: const AuthenticationOptions(
      stickyAuth: true,   // Don't show if biometrics fail mid-auth
      biometricOnly: false,  // Allow device PIN as fallback
    ),
  );
}
```

---

## 13. Flutter Theme (Design System in Code)

```dart
// core/constants/app_colors.dart
class AppColors {
  static const primary = Color(0xFF895100);
  static const primaryContainer = Color(0xFFFF9F1C);
  static const primaryFixed = Color(0xFFFFDCBC);
  static const onPrimary = Color(0xFFFFFFFF);
  static const onPrimaryContainer = Color(0xFF683C00);
  static const secondary = Color(0xFF835401);
  static const secondaryContainer = Color(0xFFFDBD68);
  static const onSecondaryContainer = Color(0xFF764B00);
  static const tertiary = Color(0xFF006A62);
  static const tertiaryContainer = Color(0xFF36C9BB);
  static const onTertiaryContainer = Color(0xFF005049);
  static const background = Color(0xFFF8F9FA);
  static const surface = Color(0xFFF8F9FA);
  static const surfaceContainerLowest = Color(0xFFFFFFFF);
  static const surfaceContainerLow = Color(0xFFF3F4F5);
  static const surfaceContainer = Color(0xFFEDEEEF);
  static const surfaceContainerHigh = Color(0xFFE7E8E9);
  static const surfaceContainerHighest = Color(0xFFE1E3E4);
  static const onSurface = Color(0xFF191C1D);
  static const onSurfaceVariant = Color(0xFF544434);
  static const outlineVariant = Color(0xFFDAC2AE);
  static const error = Color(0xFFBA1A1A);
  static const inverseSurface = Color(0xFF2E3132);
  static const inverseOnSurface = Color(0xFFF0F1F2);
}

// core/theme/app_theme.dart
ThemeData get lightTheme => ThemeData(
  useMaterial3: true,
  colorScheme: const ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.primary,
    onPrimary: AppColors.onPrimary,
    secondary: AppColors.secondary,
    onSecondary: Colors.white,
    tertiary: AppColors.tertiary,
    onTertiary: Colors.white,
    surface: AppColors.surface,
    onSurface: AppColors.onSurface,
    error: AppColors.error,
    onError: Colors.white,
  ),
  fontFamily: 'PlusJakartaSans',
  textTheme: AppTypography.textTheme,
  scaffoldBackgroundColor: AppColors.background,
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xCCF8F9FA),  // #F8F9FA at 80% opacity
    elevation: 0,
    scrolledUnderElevation: 0,
  ),
);
```

---

## 14. Platform-Specific Configuration

### iOS

**Info.plist additions:**
```xml
<key>NSCameraUsageDescription</key>
<string>Meeple &amp; Hearth needs camera access to capture game night photos.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Meeple &amp; Hearth needs photo library access to share your game memories.</string>
<key>NSFaceIDUsageDescription</key>
<string>Use Face ID to quickly log in to Meeple &amp; Hearth.</string>
<key>NSUserTrackingUsageDescription</key>
<string>We use this to improve the app and understand how features are used.</string>
```

**Entitlements:**
```xml
<key>aps-environment</key>
<string>production</string>  <!-- 'development' for debug builds -->

<!-- Universal Links (deep links) -->
<key>com.apple.developer.associated-domains</key>
<array>
  <string>applinks:meeple-hearth.com</string>
</array>
```

**apple-app-site-association** (served by Spring Boot at `/.well-known/apple-app-site-association`):
```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "TEAMID.com.meeplehearth.app",
        "paths": ["/events/*", "/posts/*", "/profile/*", "/library/*"]
      }
    ]
  }
}
```

### Android

**AndroidManifest.xml:**
```xml
<intent-filter android:autoVerify="true">
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data android:scheme="https" android:host="meeple-hearth.com" />
</intent-filter>
```

**assetlinks.json** (served at `/.well-known/assetlinks.json`):
```json
[{
  "relation": ["delegate_permission/common.handle_all_urls"],
  "target": {
    "namespace": "android_app",
    "package_name": "com.meeplehearth.app",
    "sha256_cert_fingerprints": ["SHA256_OF_YOUR_SIGNING_CERT"]
  }
}]
```

**Edge-to-edge display (Android 15+):**
```dart
// In main.dart
SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  systemNavigationBarColor: Colors.transparent,
));
```

---

## 15. App Startup Sequence

```
Launch app
  → Firebase.initializeApp()
  → Isar.open() (local DB)
  → Read secure storage: access_token, refresh_token
  → IF tokens exist:
      → Try GET /api/v1/users/me (with access token)
      → IF 401: try refresh token → IF refresh OK: proceed → IF refresh fails: clear tokens, go to Login
      → IF success: check onboarding_completed → route to Home or Onboarding
  → IF no tokens: go to Login
  → Setup FCM token listener
  → Connect WebSocket
  → AppLifecycleObserver registered
```

---

## 16. Release Checklist

**Before first TestFlight / Play Store submission:**

- [ ] Replace all hardcoded URLs with environment-based config
- [ ] `flutter run --release` builds without errors on both platforms
- [ ] Push notifications work on physical device (not simulator)
- [ ] Deep links open correct screens on physical device
- [ ] Image compression tested on large photos
- [ ] Biometric auth tested on device with Face ID and device PIN
- [ ] App icons set via `flutter_launcher_icons` (1024×1024 PNG provided)
- [ ] Splash screen configured via `flutter_native_splash`
- [ ] Privacy manifest submitted to Apple (iOS 17+ requirement)
- [ ] ProGuard/R8 rules for release build on Android (keep model classes)
- [ ] `flutter analyze` passes with zero warnings
- [ ] Sentry DSN configured for crash reporting
- [ ] `android:label` in AndroidManifest updated to "Meeple"
- [ ] Bundle ID: `com.meeplehearth.app` on both platforms
- [ ] Signing certificates set up (iOS provisioning + Android keystore)
- [ ] Keystore file stored securely (NOT in git), documented in team password manager
