import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/theme/app_theme.dart';
import 'package:meeple_hearth/l10n/gen/app_localizations.dart';
import 'package:meeple_hearth/shared/widgets/app_button.dart';
import 'package:meeple_hearth/shared/widgets/app_card.dart';
import 'package:meeple_hearth/shared/widgets/app_chip.dart';
import 'package:meeple_hearth/shared/widgets/app_text_field.dart';
import 'package:meeple_hearth/shared/widgets/empty_state.dart';
import 'package:meeple_hearth/shared/widgets/meeple_app_bar.dart';

/// Hosts [child] in a themed, localised MaterialApp.
Widget host(Widget child) => MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Center(child: child)),
    );

/// Two-route GoRouter app: `/` and a pushed `/sub` page built by [sub].
Widget routerHost(Widget Function(BuildContext) sub, {String initial = '/'}) {
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const Scaffold(body: Text('root page')),
      ),
      GoRoute(path: '/sub', builder: (context, _) => sub(context)),
      GoRoute(
        path: '/search',
        builder: (_, __) => const Scaffold(body: Text('search page')),
      ),
      GoRoute(
        path: '/notifications',
        builder: (_, __) => const Scaffold(body: Text('notifications page')),
      ),
    ],
  );
  return ProviderScope(
    child: MaterialApp.router(
      theme: AppTheme.light(),
      routerConfig: router,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

BoxDecoration decorationOf(WidgetTester tester, Finder finder) =>
    tester
        .widget<Container>(
          find.descendant(of: finder, matching: find.byType(Container)).first,
        )
        .decoration! as BoxDecoration;

void main() {
  group('AppButton', () {
    testWidgets('primary is a gradient pill and fires onPressed',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        host(AppButton(label: 'Go', onPressed: () => taps++, minWidth: 0)),
      );
      final deco = decorationOf(tester, find.byType(AppButton));
      expect(deco.gradient, AppColors.primaryGradient);
      expect(deco.boxShadow, isNotEmpty);
      await tester.tap(find.text('Go'));
      expect(taps, 1);
    });

    testWidgets('variants use their web fills', (tester) async {
      const expected = {
        AppButtonVariant.secondary: AppColors.surfaceContainerHigh,
        AppButtonVariant.tertiary: AppColors.tertiaryContainer,
        AppButtonVariant.solid: AppColors.primary,
        AppButtonVariant.danger: AppColors.error,
      };
      for (final entry in expected.entries) {
        await tester.pumpWidget(
          host(
            AppButton(
              label: entry.key.name,
              onPressed: () {},
              variant: entry.key,
              size: AppButtonSize.sm,
              icon: Icons.add,
              minWidth: 0,
            ),
          ),
        );
        expect(decorationOf(tester, find.byType(AppButton)).color, entry.value);
        expect(find.byIcon(Icons.add), findsOneWidget);
      }
      await tester.pumpWidget(
        host(
          AppButton(
            label: 'ghost',
            onPressed: () {},
            variant: AppButtonVariant.ghost,
            size: AppButtonSize.lg,
            minWidth: 0,
          ),
        ),
      );
      expect(find.text('ghost'), findsOneWidget);
    });

    testWidgets('disabled is half opacity and ignores taps; loading spins',
        (tester) async {
      await tester.pumpWidget(
        host(const AppButton(label: 'Off', onPressed: null, minWidth: 0)),
      );
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 0.5);

      var taps = 0;
      await tester.pumpWidget(
        host(
          AppButton(
            label: 'Busy',
            onPressed: () => taps++,
            isLoading: true,
            minWidth: 0,
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.text('Busy'));
      expect(taps, 0);
    });

    testWidgets('press animates scale down and back', (tester) async {
      await tester.pumpWidget(
        host(AppButton(label: 'Press', onPressed: () {}, minWidth: 0)),
      );
      final gesture =
          await tester.startGesture(tester.getCenter(find.text('Press')));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump(const Duration(milliseconds: 150));
      final scale = tester.widget<ScaleTransition>(
        find.descendant(
          of: find.byType(AppButton),
          matching: find.byType(ScaleTransition),
        ),
      );
      expect(scale.scale.value, lessThan(1));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(scale.scale.value, 1);
    });

    testWidgets('AppOutlinedButton is a filled secondary pill; links work',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        host(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppOutlinedButton(label: 'Second', onPressed: () => taps++),
              AppTextButton(label: 'Text', onPressed: () => taps++),
              AppLinkButton(label: 'View all', onPressed: () => taps++),
              AppLinkButton(
                label: 'Forgot',
                small: true,
                onPressed: () => taps++,
              ),
            ],
          ),
        ),
      );
      expect(
        tester
            .widget<AppButton>(find.byType(AppButton))
            .variant,
        AppButtonVariant.secondary,
      );
      expect(find.text('VIEW ALL'), findsOneWidget);
      await tester.tap(find.text('Second'));
      await tester.tap(find.text('Text'));
      await tester.tap(find.text('VIEW ALL'));
      await tester.tap(find.text('FORGOT'));
      expect(taps, 4);
    });
  });

  group('chips and tabs', () {
    testWidgets('AppChip colours per variant, uppercase and tap',
        (tester) async {
      for (final v in AppChipVariant.values) {
        await tester.pumpWidget(
          host(AppChip(label: 'Open', variant: v, icon: Icons.star)),
        );
        expect(find.textContaining('Open'), findsOneWidget);
      }
      var taps = 0;
      await tester.pumpWidget(
        host(
          AppChip(
            label: 'Thursday',
            uppercase: true,
            dense: true,
            isSelected: true,
            onTap: () => taps++,
          ),
        ),
      );
      expect(find.textContaining('THURSDAY'), findsOneWidget);
      final container = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      expect(
        (container.decoration! as BoxDecoration).color,
        AppColors.primary,
      );
      await tester.tap(find.byType(AppChip));
      expect(taps, 1);
    });

    testWidgets('AppFilterPill fills primary when selected', (tester) async {
      String? tapped;
      await tester.pumpWidget(
        host(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppFilterPill(
                label: 'Upcoming',
                selected: true,
                icon: Icons.event,
                onTap: () => tapped = 'up',
              ),
              AppFilterPill(
                label: 'Past',
                selected: false,
                onTap: () => tapped = 'past',
              ),
            ],
          ),
        ),
      );
      final fills = tester
          .widgetList<Material>(
            find.descendant(
              of: find.byType(AppFilterPill),
              matching: find.byType(Material),
            ),
          )
          .map((m) => m.color)
          .toList();
      expect(fills, [AppColors.primary, AppColors.surfaceContainerHigh]);
      await tester.tap(find.text('Past'));
      expect(tapped, 'past');
    });

    testWidgets('AppSegmentedControl reports the tapped segment',
        (tester) async {
      String? picked;
      await tester.pumpWidget(
        host(
          AppSegmentedControl<String>(
            segments: const [
              AppSegment(value: 'list', label: 'List', icon: Icons.list),
              AppSegment(value: 'cal', label: 'Calendar'),
            ],
            selected: 'list',
            onChanged: (v) => picked = v,
          ),
        ),
      );
      await tester.tap(find.text('Calendar'));
      expect(picked, 'cal');
      expect(find.byIcon(Icons.list), findsOneWidget);
    });
  });

  group('cards and tiles', () {
    testWidgets('AppCard tones, shadow and tap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        host(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppCard(
                tone: AppCardTone.elevated,
                width: 200,
                margin: const EdgeInsets.all(4),
                onTap: () => taps++,
                child: const Text('feed'),
              ),
              const AppCard(tone: AppCardTone.lowest, child: Text('white')),
              const AppCard(
                tone: AppCardTone.container,
                clip: false,
                child: Text('nested'),
              ),
              const AppCard(child: Text('low')),
            ],
          ),
        ),
      );
      final colors = tester
          .widgetList<Material>(
            find.descendant(
              of: find.byType(AppCard),
              matching: find.byType(Material),
            ),
          )
          .map((m) => m.color)
          .toList();
      expect(colors, [
        AppColors.surfaceContainerLowest,
        AppColors.surfaceContainerLowest,
        AppColors.surfaceContainer,
        AppColors.surfaceContainerLow,
      ]);
      await tester.tap(find.text('feed'));
      expect(taps, 1);
    });

    testWidgets('AppTileGroup renders label, tiles, chevrons and danger',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        host(
          AppTileGroup(
            label: 'Account',
            children: [
              AppTile(
                title: 'Edit Profile',
                icon: Icons.person,
                subtitle: 'Name and photo',
                onTap: () => taps++,
              ),
              AppTile(
                title: 'Delete Account',
                icon: Icons.delete,
                danger: true,
                onTap: () => taps++,
              ),
              const AppTile(
                title: 'Biometric lock',
                trailing: Switch(value: false, onChanged: null),
              ),
            ],
          ),
        ),
      );
      expect(find.text('ACCOUNT'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsNWidgets(2));
      expect(
        tester.widget<Text>(find.text('Delete Account')).style!.color,
        AppColors.error,
      );
      await tester.tap(find.text('Edit Profile'));
      await tester.tap(find.text('Delete Account'));
      expect(taps, 2);
    });

    testWidgets('boxed EmptyState shows icon, texts and a small CTA',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        host(
          EmptyState(
            boxed: true,
            icon: Icons.feed,
            title: 'Nothing yet',
            subtitle: 'Post something',
            actionLabel: 'Create',
            onAction: () => taps++,
          ),
        ),
      );
      expect(find.text('Nothing yet'), findsOneWidget);
      expect(find.text('Post something'), findsOneWidget);
      await tester.tap(find.text('Create'));
      expect(taps, 1);
    });
  });

  group('inputs', () {
    testWidgets('AppTextField: uppercase label, action, validation, toggle',
        (tester) async {
      final key = GlobalKey<FormState>();
      await tester.pumpWidget(
        host(
          Form(
            key: key,
            child: AppTextField(
              label: 'Password',
              hint: 'Your password',
              isPassword: true,
              labelAction: const Text('forgot'),
              validator: (v) => (v ?? '').isEmpty ? 'Required' : null,
            ),
          ),
        ),
      );
      expect(find.text('PASSWORD'), findsOneWidget);
      expect(find.text('forgot'), findsOneWidget);
      expect(find.text('Your password'), findsOneWidget);
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pump();
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
      expect(key.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Required'), findsOneWidget);
    });

    testWidgets('AppTextField without label uses the hint; action only row',
        (tester) async {
      await tester.pumpWidget(
        host(
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(hint: 'Bare', prefixIcon: Icons.mail),
              AppTextField(labelAction: Text('only action')),
            ],
          ),
        ),
      );
      expect(find.text('Bare'), findsOneWidget);
      expect(find.byIcon(Icons.mail), findsOneWidget);
      expect(find.text('only action'), findsOneWidget);
    });

    testWidgets('AppSearchField is a filled pill that reports changes',
        (tester) async {
      String? query;
      await tester.pumpWidget(
        host(
          AppSearchField(
            hint: 'Search games',
            fieldKey: const Key('s'),
            onChanged: (v) => query = v,
          ),
        ),
      );
      await tester.enterText(find.byKey(const Key('s')), 'cat');
      expect(query, 'cat');
      final field = tester.widget<TextField>(find.byKey(const Key('s')));
      expect(field.decoration!.fillColor, AppColors.surfaceContainerLow);
      expect(field.decoration!.enabledBorder!.borderSide, BorderSide.none);
    });
  });

  group('headers and bars', () {
    testWidgets('MeepleAppBar back circle pops to the previous page',
        (tester) async {
      await tester.pumpWidget(
        routerHost(
          (_) => Scaffold(
            appBar: MeepleAppBar(
              title: 'Settings',
              eyebrow: 'Account',
              showBackButton: true,
              actions: [TextButton(onPressed: () {}, child: const Text('A'))],
            ),
          ),
        ),
      );
      final context = tester.element(find.text('root page'));
      GoRouter.of(context).push('/sub');
      await tester.pumpAndSettle();
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('ACCOUNT'), findsOneWidget);
      expect(find.byType(CircleBackButton), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();
      expect(find.text('root page'), findsOneWidget);
    });

    testWidgets('MeepleAppBar back goes to the fallback after a deep link',
        (tester) async {
      await tester.pumpWidget(
        routerHost(
          (_) => const Scaffold(
            appBar: MeepleAppBar(
              title: 'Deep',
              showBackButton: true,
              compactTitle: true,
              centerTitle: true,
              bottom: PreferredSize(
                preferredSize: Size.fromHeight(10),
                child: SizedBox(height: 10),
              ),
            ),
          ),
          initial: '/sub',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Deep'), findsOneWidget);
      await tester.tap(find.byType(CircleBackButton));
      await tester.pumpAndSettle();
      expect(find.text('root page'), findsOneWidget);
    });

    testWidgets('PageHeader and CircleIconButton', (tester) async {
      var backs = 0;
      var more = 0;
      await tester.pumpWidget(
        host(
          PageHeader(
            title: 'Edit Profile',
            eyebrow: 'Settings',
            onBack: () => backs++,
            trailing: CircleIconButton(
              icon: Icons.more_horiz,
              tooltip: 'More',
              onPressed: () => more++,
            ),
          ),
        ),
      );
      expect(find.text('SETTINGS'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.tap(find.byTooltip('More'));
      expect((backs, more), (1, 1));
    });

    testWidgets('MeepleBrandBar shows the logo, wordmark, search and bell',
        (tester) async {
      await tester.pumpWidget(
        routerHost(
          (_) => Scaffold(
            appBar: MeepleBrandBar(
              actions: [
                BarIconButton(
                  icon: Icons.settings,
                  tooltip: 'Settings',
                  onPressed: () {},
                ),
              ],
              bottom: const PreferredSize(
                preferredSize: Size.fromHeight(10),
                child: SizedBox(height: 10),
              ),
            ),
          ),
          initial: '/sub',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(MeepleLogo), findsOneWidget);
      expect(find.text('Meeple'), findsOneWidget);
      expect(find.byIcon(Icons.settings), findsOneWidget);
      await tester.tap(find.byKey(const Key('top-bar-search')));
      await tester.pumpAndSettle();
      expect(find.text('search page'), findsOneWidget);
    });

    testWidgets('MeepleLogo falls back to an icon without the asset',
        (tester) async {
      await tester.pumpWidget(host(const MeepleLogo(size: 64, angle: -6)));
      await tester.pumpAndSettle();
      expect(find.byType(MeepleLogo), findsOneWidget);
    });
  });
}
