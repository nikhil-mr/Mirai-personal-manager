import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:personal_manager/app/app.dart';
import 'package:personal_manager/app/theme/theme_controller.dart';
import 'package:personal_manager/features/money/application/money_providers.dart';
import 'package:personal_manager/features/money/data/money_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('first launch shows welcome before the six feature slides', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final database = MoneyDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          moneyDatabaseProvider.overrideWithValue(database),
        ],
        child: const LifePartnerApp(),
      ),
    );
    expect(find.text('Mirai'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image == const AssetImage('assets/images/1.png'),
      ),
      findsOneWidget,
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome to'), findsOneWidget);
    expect(find.text('Mirai!'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image == const AssetImage('assets/images/2.png'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    const slides = [
      ('Money Manager', 'assets/images/3.png'),
      ('To-do Manager', 'assets/images/4.png'),
      ('Places & Trips', 'assets/images/5.png'),
      ('Grocery Basket', 'assets/images/6.png'),
      ('Budget Planner', 'assets/images/7.png'),
      ('Everything Together', 'assets/images/8.png'),
    ];
    Future<void> expectSlide(int index) async {
      expect(find.text(slides[index].$1), findsOneWidget);
      expect(find.text('${index + 1}/6'), findsOneWidget);
      final viewport = tester.getRect(find.byType(PageView));
      final imageFinder = find.descendant(
        of: find.byType(PageView),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Image && widget.image == AssetImage(slides[index].$2),
        ),
      );
      final visible = <int>[];
      for (
        var imageIndex = 0;
        imageIndex < imageFinder.evaluate().length;
        imageIndex++
      ) {
        if (viewport.contains(tester.getCenter(imageFinder.at(imageIndex)))) {
          visible.add(imageIndex);
        }
      }
      expect(
        visible,
        hasLength(1),
        reason: 'Expected ${slides[index].$2} on ${slides[index].$1}.',
      );
    }

    await expectSlide(0);

    for (var index = 1; index < slides.length; index++) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await expectSlide(index);
    }

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Import Your Existing Data'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image == const AssetImage('assets/images/0.png'),
      ),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('Skip for now'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Skip for now'), findsOneWidget);
  });
}
