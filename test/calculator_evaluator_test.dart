import 'package:flutter_test/flutter_test.dart';
import 'package:personal_manager/features/money/presentation/calculator_screen.dart';

void main() {
  group('CalculatorEvaluator Tests', () {
    test('Addition and Subtraction', () {
      expect(CalculatorEvaluator.evaluate('10 + 20'), 30.0);
      expect(CalculatorEvaluator.evaluate('50 − 15'), 35.0);
      expect(CalculatorEvaluator.evaluate('100 + 50 − 25'), 125.0);
    });

    test('Multiplication and Division', () {
      expect(CalculatorEvaluator.evaluate('10 × 5'), 50.0);
      expect(CalculatorEvaluator.evaluate('100 ÷ 4'), 25.0);
      expect(CalculatorEvaluator.evaluate('10 + 5 × 2'), 20.0);
    });

    test('Decimals and Percentages', () {
      expect(CalculatorEvaluator.evaluate('12.50 + 2.50'), 15.0);
      expect(CalculatorEvaluator.evaluate('50 %'), 0.5);
    });

    test('Division by zero throws FormatException', () {
      expect(
        () => CalculatorEvaluator.evaluate('10 ÷ 0'),
        throwsA(isA<FormatException>()),
      );
    });

    test('Empty expression returns 0.0', () {
      expect(CalculatorEvaluator.evaluate(''), 0.0);
    });
  });
}
