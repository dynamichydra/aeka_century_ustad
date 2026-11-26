import 'package:century_ai/core/constants/final_save_credits.dart';
import 'package:century_ai/features/camera_pages/presentation/widgets/toolbar/credit_usage_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('each successive debit can display its updated usage', (tester) async {
    const limit = FinalSaveCredits.limit;
    late BuildContext page;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) {
        page = context;
        return const Scaffold();
      }),
    ));

    for (var used = 1; used <= limit; used++) {
      final dismissed = showCreditUsageDialog(page, used);
      await tester.pumpAndSettle();
      expect(find.text('$used of $limit used'), findsOneWidget);
      expect(find.text('${(100 * used / limit).round()}%'), findsOneWidget);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      await dismissed;
    }
  });
}
