import 'package:century_ai/cubit/auth/auth_cubit.dart';
import 'package:century_ai/data/models/auth_session.dart';
import 'package:century_ai/data/repositories/auth_repository.dart';
import 'package:century_ai/features/auth/presentation/pages/login_page.dart';
import 'package:century_ai/features/auth/presentation/pages/otp_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _AuthRepository extends Fake implements AuthRepository {
  @override
  Stream<AuthSession> get autoSignIns => const Stream.empty();

  @override
  Stream<String> get autoCodes => const Stream.empty();
}

void main() {
  for (final otp in [false, true]) {
    final screen = otp ? 'OTP' : 'Phone';
    testWidgets('$screen accepts input as the keyboard opens', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(393, 852);
      addTearDown(tester.view.reset);

      final repository = _AuthRepository();
      await tester.pumpWidget(
        RepositoryProvider<AuthRepository>.value(
          value: repository,
          child: BlocProvider(
            create: (_) => AuthCubit(repository),
            child: MaterialApp(
              home: otp ? const OtpPage(phone: '9876543210') : const LoginPage(),
            ),
          ),
        ),
      );
      await tester.pump();
      if (!otp) {
        await tester.tap(find.byType(TextField));
        await tester.pump();
      }
      final editor = tester.widget<EditableText>(find.byType(EditableText));
      expect(editor.focusNode.hasFocus, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
      tester.testTextInput.enterText('9');
      for (final height in [40.0, 180.0, 295.0]) {
        tester.view.viewInsets = FakeViewPadding(bottom: height);
        await tester.pump();
        await tester.pump();
        expect(editor.focusNode.hasFocus, isTrue);
        expect(tester.testTextInput.isVisible, isTrue);
      }
      tester.testTextInput.enterText('98');
      await tester.pump();
      expect(editor.controller.text, '98');
    });
  }
}
