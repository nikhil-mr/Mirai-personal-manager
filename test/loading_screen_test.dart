import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_manager/features/onboarding/presentation/onboarding_flow.dart';

void main() {
  group('Mirai Loading Screen Widget Tests', () {
    testWidgets(
      'Renders Mirai branding, tagline, progress bar and LOADING... text',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: MiraiLoadingView(progress: 0.5)),
        );
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.text('Mirai'), findsOneWidget);
        expect(
          find.text('Organize today.\nBuild a better tomorrow.'),
          findsOneWidget,
        );
        expect(find.text('LOADING...'), findsOneWidget);
      },
    );

    testWidgets(
      'Displays error state and retry button on initialization failure',
      (tester) async {
        var retried = false;
        await tester.pumpWidget(
          MaterialApp(
            home: MiraiLoadingView(
              progress: 0.0,
              error: 'Failed to connect to local database',
              onRetry: () => retried = true,
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));

        expect(
          find.text('Failed to connect to local database'),
          findsOneWidget,
        );
        expect(find.text('Retry'), findsOneWidget);

        await tester.tap(find.text('Retry'));
        expect(retried, isTrue);
      },
    );
  });
}
