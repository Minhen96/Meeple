import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:go_router/go_router.dart';
import 'package:meeple_hearth/core/push/push_permission_screen.dart';
import 'package:meeple_hearth/core/router/router_notifier.dart';
import 'package:meeple_hearth/features/auth/presentation/forgot_password_screen.dart';
import 'package:meeple_hearth/features/auth/presentation/login_screen.dart';
import 'package:meeple_hearth/features/auth/presentation/reactivate_screen.dart';
import 'package:meeple_hearth/features/auth/presentation/register_screen.dart';
import 'package:meeple_hearth/features/auth/presentation/reset_password_screen.dart';
import 'package:meeple_hearth/features/auth/presentation/verify_email_screen.dart';
import 'package:meeple_hearth/features/auth/providers/auth_provider.dart';
import 'package:meeple_hearth/features/events/presentation/create_event_screen.dart';
import 'package:meeple_hearth/features/events/presentation/event_detail_screen.dart';
import 'package:meeple_hearth/features/events/presentation/events_screen.dart';
import 'package:meeple_hearth/features/home/presentation/home_screen.dart';
import 'package:meeple_hearth/features/library/presentation/game_detail_screen.dart';
import 'package:meeple_hearth/features/library/presentation/library_screen.dart';
import 'package:meeple_hearth/features/matching/presentation/matching_screen.dart';
import 'package:meeple_hearth/features/notifications/presentation/notification_prefs_screen.dart';
import 'package:meeple_hearth/features/notifications/presentation/notifications_screen.dart';
import 'package:meeple_hearth/features/onboarding/presentation/onboarding_add_game_screen.dart';
import 'package:meeple_hearth/features/onboarding/presentation/onboarding_bgg_screen.dart';
import 'package:meeple_hearth/features/onboarding/presentation/onboarding_friends_screen.dart';
import 'package:meeple_hearth/features/onboarding/presentation/onboarding_profile_screen.dart';
import 'package:meeple_hearth/features/onboarding/presentation/onboarding_welcome_screen.dart';
import 'package:meeple_hearth/features/posts/presentation/bookmarks_screen.dart';
import 'package:meeple_hearth/features/posts/presentation/create_post_screen.dart';
import 'package:meeple_hearth/features/posts/presentation/post_detail_screen.dart';
import 'package:meeple_hearth/features/profile/presentation/own_profile_screen.dart';
import 'package:meeple_hearth/features/profile/presentation/user_profile_screen.dart';
import 'package:meeple_hearth/features/search/presentation/search_screen.dart';
import 'package:meeple_hearth/features/settings/presentation/account_screens.dart';
import 'package:meeple_hearth/features/settings/presentation/bgg_import_screen.dart';
import 'package:meeple_hearth/features/settings/presentation/edit_profile_screen.dart';
import 'package:meeple_hearth/features/settings/presentation/settings_screen.dart';
import 'package:meeple_hearth/features/shell/main_shell.dart';
import 'package:meeple_hearth/features/social/presentation/blocked_users_screen.dart';
import 'package:meeple_hearth/features/social/presentation/friends_screen.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_router.g.dart';

/// Typed route paths — use these instead of raw strings. Paths match the
/// deep-link schema (FEATURES §12.3, with `/library/{gameId}` per GAP C8).
abstract final class AppRoutes {
  static const login = '/auth/login';
  static const register = '/auth/register';
  static const verifyEmail = '/auth/verify-email';
  static const forgotPassword = '/auth/forgot-password';
  static const resetPassword = '/auth/reset-password';
  static const reactivate = '/auth/reactivate';

  static const onboardingWelcome = '/onboarding/welcome';
  static const onboardingProfile = '/onboarding/profile';
  static const onboardingBgg = '/onboarding/bgg-import';
  static const onboardingFriends = '/onboarding/find-friends';
  static const onboardingAddGame = '/onboarding/add-game';

  static const home = '/';
  static const library = '/library';
  static const events = '/events';
  static const profile = '/profile';

  static const notifications = '/notifications';
  static const pushPermission = '/push-permission';
  static const search = '/search';
  static const friends = '/friends';
  static const matching = '/matching';
  static const bookmarks = '/bookmarks';

  static const settings = '/settings';
  static const editProfile = '/settings/profile';
  static const changeEmail = '/settings/change-email';
  static const changePassword = '/settings/change-password';
  static const bggImport = '/settings/bgg-import';
  static const sessions = '/settings/sessions';
  static const deleteAccount = '/settings/delete-account';
  static const notificationPrefs = '/settings/notifications';
  static const blockedUsers = '/settings/blocked';

  static const createPost = '/posts/create';
  static String postDetail(String postId) => '/posts/$postId';
  static String editPost(String postId) => '/posts/$postId/edit';

  static String gameDetail(String gameId) => '/library/$gameId';

  static const createEvent = '/events/create';
  static String eventDetail(String eventId) => '/events/$eventId';
  static String editEvent(String eventId) => '/events/$eventId/edit';
  static String createEventFromMatch(String groupId) =>
      '/events/create?matchGroupId=$groupId';

  static String userProfile(String userId) => '/profile/$userId';
}

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  final notifier = ref.watch(routerNotifierProvider.notifier);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.home,
    debugLogDiagnostics: false,
    refreshListenable: notifier,
    redirect: (context, state) {
      final authState = ref.read(authNotifierProvider);
      final location = state.matchedLocation;

      // Still loading — stay put to avoid premature redirects.
      if (authState.isLoading) return null;

      // Legacy/alias deep links.
      if (location == '/home') return AppRoutes.home;
      if (location.startsWith('/library/games/')) {
        return location.replaceFirst('/library/games/', '/library/');
      }

      final user = authState.valueOrNull;
      final isLoggedIn = user != null;
      final needsOnboarding = isLoggedIn && !user.onboardingCompleted;
      final isOnAuthPage = location.startsWith('/auth');
      final isOnOnboarding = location.startsWith('/onboarding');

      if (!isLoggedIn && !isOnAuthPage) {
        final target = state.uri.toString();
        return target == AppRoutes.home
            ? AppRoutes.login
            : '${AppRoutes.login}?redirect=${Uri.encodeComponent(target)}';
      }
      if (isLoggedIn && needsOnboarding && !isOnOnboarding) {
        return AppRoutes.onboardingWelcome;
      }
      if (isLoggedIn && isOnAuthPage) {
        final redirect = state.uri.queryParameters['redirect'];
        if (needsOnboarding) return AppRoutes.onboardingWelcome;
        return redirect != null && redirect.startsWith('/')
            ? redirect
            : AppRoutes.home;
      }
      return null;
    },
    routes: [
      // ── Auth ─────────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.login,
        builder: (_, state) => LoginScreen(
          redirect: state.uri.queryParameters['redirect'],
        ),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (_, __) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.verifyEmail,
        builder: (_, state) => VerifyEmailScreen(
          email: state.extra is String ? state.extra! as String : null,
          token: state.uri.queryParameters['token'],
        ),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (_, __) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.resetPassword,
        builder: (_, state) => ResetPasswordScreen(
          token: state.uri.queryParameters['token'] ?? '',
        ),
      ),
      GoRoute(
        path: AppRoutes.reactivate,
        builder: (_, state) => ReactivateScreen(
          emailOrUsername: state.extra is String ? state.extra! as String : '',
        ),
      ),

      // ── Onboarding ───────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.onboardingWelcome,
        builder: (_, __) => const OnboardingWelcomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboardingProfile,
        builder: (_, __) => const OnboardingProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboardingBgg,
        builder: (_, __) => const OnboardingBggScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboardingFriends,
        builder: (_, __) => const OnboardingFriendsScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboardingAddGame,
        builder: (_, __) => const OnboardingAddGameScreen(),
      ),

      // ── Main tabs — StatefulShellRoute keeps each tab's stack ───────────
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => MainShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (_, __) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.library,
                builder: (_, state) => LibraryScreen(
                  initialTab: state.uri.queryParameters['filter'],
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.events,
                builder: (_, state) => EventsScreen(
                  calendarView: state.uri.queryParameters['view'] == 'calendar',
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (_, __) => const OwnProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      // ── Full-screen routes (no bottom nav) ───────────────────────────────
      GoRoute(
        path: AppRoutes.notifications,
        builder: (_, __) => const NotificationsScreen(),
      ),
      GoRoute(
        path: AppRoutes.pushPermission,
        builder: (_, __) => const PushPermissionScreen(),
      ),
      GoRoute(
        path: AppRoutes.search,
        builder: (_, __) => const SearchScreen(),
      ),
      GoRoute(
        path: AppRoutes.friends,
        builder: (_, state) => FriendsScreen(
          initialTab: state.uri.queryParameters['tab'] == 'requests' ? 1 : 0,
        ),
      ),
      GoRoute(
        path: AppRoutes.matching,
        builder: (_, __) => const MatchingScreen(),
      ),
      GoRoute(
        path: AppRoutes.bookmarks,
        builder: (_, __) => const BookmarksScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (_, __) => const SettingsScreen(),
        routes: [
          GoRoute(
            path: 'profile',
            builder: (_, __) => const EditProfileScreen(),
          ),
          GoRoute(
            path: 'change-email',
            builder: (_, __) => const ChangeEmailScreen(),
          ),
          GoRoute(
            path: 'change-password',
            builder: (_, __) => const ChangePasswordScreen(),
          ),
          GoRoute(
            path: 'bgg-import',
            builder: (_, __) => const BggImportScreen(),
          ),
          GoRoute(
            path: 'sessions',
            builder: (_, __) => const ActiveSessionsScreen(),
          ),
          GoRoute(
            path: 'delete-account',
            builder: (_, __) => const DeleteAccountScreen(),
          ),
          GoRoute(
            path: 'notifications',
            builder: (_, __) => const NotificationPrefsScreen(),
          ),
          GoRoute(
            path: 'blocked',
            builder: (_, __) => const BlockedUsersScreen(),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.createPost,
        builder: (_, state) => CreatePostScreen(
          gameId: state.uri.queryParameters['gameId'],
          eventId: state.uri.queryParameters['eventId'],
        ),
      ),
      GoRoute(
        path: '/posts/:postId',
        builder: (_, state) => PostDetailScreen(
          postId: state.pathParameters['postId']!,
        ),
        routes: [
          GoRoute(
            path: 'edit',
            builder: (_, state) => CreatePostScreen(
              editPostId: state.pathParameters['postId'],
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/library/:gameId',
        builder: (_, state) => GameDetailScreen(
          gameId: state.pathParameters['gameId']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.createEvent,
        builder: (_, state) => CreateEventScreen(
          matchGroupId: state.uri.queryParameters['matchGroupId'],
          gameId: state.uri.queryParameters['gameId'],
        ),
      ),
      GoRoute(
        path: '/events/:eventId',
        builder: (_, state) => EventDetailScreen(
          eventId: state.pathParameters['eventId']!,
        ),
        routes: [
          GoRoute(
            path: 'edit',
            builder: (_, state) => CreateEventScreen(
              editEventId: state.pathParameters['eventId'],
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/profile/:userId',
        builder: (_, state) => UserProfileScreen(
          userId: state.pathParameters['userId']!,
        ),
      ),
    ],
  );
}
