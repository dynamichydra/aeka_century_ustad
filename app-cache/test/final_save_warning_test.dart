import 'package:century_ai/core/constants/final_save_credits.dart';
import 'package:century_ai/features/camera_pages/presentation/widgets/toolbar/credit_usage_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('credit button fits the editor toolbar height', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: CreditUsageButton(used: 15, size: 40)),
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(CreditUsageButton)),
      const Size.square(40),
    );
  });

  testWidgets('each successive debit can display its updated usage', (
    tester,
  ) async {
    const limit = FinalSaveCredits.limit;
    late BuildContext page;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            page = context;
            return const Scaffold();
          },
        ),
      ),
    );

    for (var used = 1; used <= limit; used++) {
      final dismissed = showCreditUsageDialog(page, used);
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Total: $limit coins | Used: $used coins | '
          'Remaining: ${limit - used} coins',
        ),
        findsOneWidget,
      );
      expect(
        find.byIcon(Icons.warning_rounded),
        used / limit > 0.70 ? findsOneWidget : findsNothing,
      );
      expect(find.text('${(100 * used / limit).round()}%'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await dismissed;
    }
  });
}
