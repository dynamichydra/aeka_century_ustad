import 'package:century_ai/core/constants/colors.dart';
import 'package:century_ai/features/camera_pages/presentation/pages/camera_tips_page.dart';
import 'package:century_ai/router/app_routes.dart';
import 'package:century_ai/router/shell_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('app bar menu highlights the current route', (tester) async {
    final router = GoRouter(
      routes: [
        ShellRoute(
          builder: (context, state, child) => NavWrapper(child: child),
          routes: [
            GoRoute(
              path: AppRoutes.tips,
              builder: (context, state) => const CameraTipsPage(),
            ),
            for (final route in [
              AppRoutes.home,
              AppRoutes.home2,
              AppRoutes.heart,
            ])
              GoRoute(
                path: route,
                builder: (context, state) => const SizedBox.expand(),
              ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    Color? labelColor(String label) =>
        tester.widget<Text>(find.text(label)).style?.color;

    Future<void> openMenu() async {
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
    }

    await openMenu();
    expect(labelColor('Home'), TColors.vividRed);
    expect(labelColor('Profile'), TColors.pureBlack);
    expect(find.byIcon(Icons.call), findsOneWidget);
    expect(find.byIcon(Icons.email), findsOneWidget);
    expect(find.text('Favorite'), findsNothing);

    await tester.tap(find.byTooltip('Close navigation menu'));
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsNothing);

    await openMenu();
    await tester.tap(find.text('Tips'));
    await tester.pumpAndSettle();
    expect(router.routerDelegate.currentConfiguration.uri.path, AppRoutes.tips);
    expect(find.text('Tips to capture best images'), findsOneWidget);
    expect(find.text("Don't Show Again"), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Avoid cluttered backgrounds.'),
      150,
    );
    expect(find.text('Avoid cluttered backgrounds.'), findsOneWidget);
    await openMenu();
    expect(labelColor('Tips'), TColors.vividRed);
    expect(labelColor('Home'), TColors.pureBlack);
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();

    for (final path in [AppRoutes.heart, '${AppRoutes.home2}?source=test']) {
      router.go(path);
      await tester.pumpAndSettle();
      await openMenu();
      expect(labelColor('Home'), TColors.vividRed);
      expect(labelColor('Logout'), TColors.pureBlack);
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        AppRoutes.home,
      );
    }
  });
}
