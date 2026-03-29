import 'package:go_router/go_router.dart';
import 'package:meeple_hearth/core/router/router_notifier.dart';
import 'package:meeple_hearth/features/auth/presentation/forgot_password_screen.dart';
import 'package:meeple_hearth/features/auth/presentation/login_screen.dart';
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
import 'package:meeple_hearth/features/notifications/presentation/notifications_screen.dart';
import 'package:meeple_hearth/features/onboarding/presentation/onboarding_add_game_screen.dart';
import 'package:meeple_hearth/features/onboarding/presentation/onboarding_bgg_screen.dart';
import 'package:meeple_hearth/features/onboarding/presentation/onboarding_friends_screen.dart';
import 'package:meeple_hearth/features/onboarding/presentation/onboarding_profile_screen.dart';
import 'package:meeple_hearth/features/onboarding/presentation/onboarding_welcome_screen.dart';
import 'package:meeple_hearth/features/posts/presentation/create_post_screen.dart';
import 'package:meeple_hearth/features/posts/presentation/post_detail_screen.dart';
import 'package:meeple_hearth/features/profile/presentation/own_profile_screen.dart';
import 'package:meeple_hearth/features/search/presentation/search_screen.dart';
import 'package:meeple_hearth/features/settings/presentation/settings_screen.dart';
import 'package:meeple_hearth/features/shell/main_shell.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_router.g.dart';

/// Typed route path constants — use these instead of raw strings.
abstract final class AppRoutes {
  static const login = '/auth/login';
  static const register = '/auth/register';
  static const verifyEmail = '/auth/verify-email';
  static const forgotPassword = '/auth/forgot-password';
  static const resetPassword = '/auth/reset-password';

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
  static const settings = '/settings';
  static const createPost = '/posts/create';
  static const search = '/search';

  /// Build a post detail path — e.g. `AppRoutes.postDetail('abc123')`.
  static String postDetail(String postId) => '/posts/$postId';

  /// Build a game detail path — e.g. `AppRoutes.gameDetail('abc123')`.
  static String gameDetail(String gameId) => '/library/$gameId';

  static const createEvent = '/events/create';

  /// Build an event detail path — e.g. `AppRoutes.eventDetail('abc123')`.
  static String eventDetail(String eventId) => '/events/$eventId';
}

@Riverpod(keepAlive: true)
GoRouter appRouter(AppRouterRef ref) {
  final notifier = ref.watch(routerNotifierProvider.notifier);

  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: false,
    refreshListenable: notifier,
    redirect: (context, state) {
      final authState = ref.read(authNotifierProvider);
      final location = state.matchedLocation;

      // Still loading — stay put to avoid premature redirects.
      if (authState.isLoading) return null;

      final user = authState.valueOrNull;
      final isLoggedIn = user != null;
      final needsOnboarding = isLoggedIn && !user.onboardingCompleted;
      final isOnAuthPage = location.startsWith('/auth');
      final isOnOnboarding = location.startsWith('/onboarding');

      if (!isLoggedIn && !isOnAuthPage) {
        final encoded = Uri.encodeComponent(location);
        return '/auth/login?redirect=$encoded';
      }
      if (isLoggedIn && needsOnboarding && !isOnOnboarding) {
        return '/onboarding/welcome';
      }
      if (isLoggedIn && !needsOnboarding && isOnAuthPage) {
        return '/';
      }
      return null;
    },
    routes: [
      // ── Auth ─────────────────────────────────────────────────────────────────
      GoRoute(
        path: '/auth/login',
        builder: (_, state) => LoginScreen(
          redirect: state.uri.queryParameters['redirect'],
        ),
      ),
      GoRoute(
        path: '/auth/register',
        builder: (_, __) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/auth/verify-email',
        builder: (_, __) => const VerifyEmailScreen(),
      ),
      GoRoute(
        path: '/auth/forgot-password',
        builder: (_, __) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/auth/reset-password',
        builder: (_, state) => ResetPasswordScreen(
          token: state.uri.queryParameters['token'] ?? '',
        ),
      ),

      // ── Onboarding ───────────────────────────────────────────────────────────
      GoRoute(
        path: '/onboarding/welcome',
        builder: (_, __) => const OnboardingWelcomeScreen(),
      ),
      GoRoute(
        path: '/onboarding/profile',
        builder: (_, __) => const OnboardingProfileScreen(),
      ),
      GoRoute(
        path: '/onboarding/bgg-import',
        builder: (_, __) => const OnboardingBggScreen(),
      ),
      GoRoute(
        path: '/onboarding/find-friends',
        builder: (_, __) => const OnboardingFriendsScreen(),
      ),
      GoRoute(
        path: '/onboarding/add-game',
        builder: (_, __) => const OnboardingAddGameScreen(),
      ),

      // ── Main app — StatefulShellRoute preserves per-tab navigation stacks ───
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => MainShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
          ],),
          StatefulShellBranch(routes: [
            GoRoute(path: '/library', builder: (_, __) => const LibraryScreen(),),
          ],),
          StatefulShellBranch(routes: [
            GoRoute(path: '/events', builder: (_, __) => const EventsScreen(),),
          ],),
          StatefulShellBranch(routes: [
            GoRoute(path: '/profile', builder: (_, __) => const OwnProfileScreen(),),
          ],),
        ],
      ),

      // ── Full-screen routes (no bottom nav) ───────────────────────────────────
      GoRoute(
        path: '/notifications',
        builder: (_, __) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (_, __) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/posts/create',
        builder: (_, __) => const CreatePostScreen(),
      ),
      GoRoute(
        path: '/posts/:postId',
        builder: (_, state) => PostDetailScreen(
          postId: state.pathParameters['postId']!,
        ),
      ),
      GoRoute(
        path: '/search',
        builder: (_, __) => const SearchScreen(),
      ),
      GoRoute(
        path: '/library/:gameId',
        builder: (_, state) => GameDetailScreen(
          gameId: state.pathParameters['gameId']!,
        ),
      ),
      GoRoute(
        path: '/events/create',
        builder: (_, __) => const CreateEventScreen(),
      ),
      GoRoute(
        path: '/events/:eventId',
        builder: (_, state) => EventDetailScreen(
          eventId: state.pathParameters['eventId']!,
        ),
      ),
    ],
  );
}
