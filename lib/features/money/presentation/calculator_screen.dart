import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/brutal_card.dart';

class CalculatorEvaluator {
  static double evaluate(String expression) {
    final clean = expression.trim();
    if (clean.isEmpty) return 0.0;

    final normalized = clean
        .replaceAll('×', '*')
        .replaceAll('÷', '/')
        .replaceAll('−', '-')
        .replaceAll(' ', '');

    final tokens = _tokenize(normalized);
    if (tokens.isEmpty) return 0.0;

    return _parseExpression(tokens);
  }

  static List<String> _tokenize(String str) {
    final tokens = <String>[];
    var numberBuffer = StringBuffer();

    for (var i = 0; i < str.length; i++) {
      final char = str[i];
      final code = char.codeUnitAt(0);
      if ((code >= 48 && code <= 57) || char == '.') {
        numberBuffer.write(char);
      } else if (char == '+' ||
          char == '-' ||
          char == '*' ||
          char == '/' ||
          char == '%') {
        if (numberBuffer.isNotEmpty) {
          tokens.add(numberBuffer.toString());
          numberBuffer.clear();
        } else if (char == '-' &&
            (tokens.isEmpty || _isOperator(tokens.last))) {
          numberBuffer.write(char);
          continue;
        }
        tokens.add(char);
      }
    }
    if (numberBuffer.isNotEmpty) {
      tokens.add(numberBuffer.toString());
    }
    return tokens;
  }

  static bool _isOperator(String token) {
    return token == '+' ||
        token == '-' ||
        token == '*' ||
        token == '/' ||
        token == '%';
  }

  static double _parseExpression(List<String> tokens) {
    final pass1 = <String>[];
    for (var i = 0; i < tokens.length; i++) {
      if (tokens[i] == '%') {
        if (pass1.isNotEmpty && !_isOperator(pass1.last)) {
          final val = double.tryParse(pass1.removeLast());
          if (val != null) {
            pass1.add((val / 100.0).toString());
          }
        }
      } else {
        pass1.add(tokens[i]);
      }
    }

    final pass2 = <String>[];
    var i = 0;
    while (i < pass1.length) {
      final token = pass1[i];
      if (token == '*' || token == '/') {
        if (pass2.isEmpty || i + 1 >= pass1.length) {
          throw const FormatException('Invalid expression');
        }
        final left = double.tryParse(pass2.removeLast());
        final right = double.tryParse(pass1[i + 1]);
        if (left == null || right == null) {
          throw const FormatException('Invalid expression');
        }
        if (token == '/' && right == 0) {
          throw const FormatException('Division by zero');
        }
        final result = token == '*' ? left * right : left / right;
        pass2.add(result.toString());
        i += 2;
      } else {
        pass2.add(token);
        i++;
      }
    }

    if (pass2.isEmpty) return 0.0;
    var result = double.tryParse(pass2[0]);
    if (result == null) throw const FormatException('Invalid expression');

    var j = 1;
    while (j < pass2.length) {
      final op = pass2[j];
      if (j + 1 >= pass2.length) break;
      final nextVal = double.tryParse(pass2[j + 1]);
      if (nextVal == null) throw const FormatException('Invalid expression');
      if (op == '+') {
        result = result! + nextVal;
      } else if (op == '-') {
        result = result! - nextVal;
      }
      j += 2;
    }
    return result!;
  }
}

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({this.initialValue = '', super.key});

  final String initialValue;

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  late String _expression;
  String _resultText = '0';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final initClean = widget.initialValue
        .trim()
        .replaceAll('₹', '')
        .replaceAll(',', '');
    final initVal = double.tryParse(initClean);
    if (initVal != null && initVal > 0) {
      _expression = initVal % 1 == 0
          ? initVal.toInt().toString()
          : initVal.toString();
      _evaluate();
    } else {
      _expression = '';
      _resultText = '0';
    }
  }

  void _evaluate() {
    if (_expression.trim().isEmpty) {
      setState(() {
        _resultText = '0';
        _errorMessage = null;
      });
      return;
    }
    try {
      final value = CalculatorEvaluator.evaluate(_expression);
      if (value.isNaN || value.isInfinite) {
        setState(() {
          _errorMessage = 'Invalid result';
        });
      } else {
        setState(() {
          _errorMessage = null;
          if (value % 1 == 0) {
            _resultText = value.toInt().toString();
          } else {
            _resultText = value.toStringAsFixed(2);
          }
        });
      }
    } on FormatException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
    } catch (_) {
      setState(() {
        _errorMessage = 'Error';
      });
    }
  }

  void _onKeyPress(String key) {
    setState(() {
      if (key == 'C') {
        _expression = '';
        _resultText = '0';
        _errorMessage = null;
      } else if (key == '⌫') {
        if (_expression.isNotEmpty) {
          _expression = _expression.substring(0, _expression.length - 1);
        }
        _evaluate();
      } else if (key == '=') {
        _evaluate();
        if (_errorMessage == null && _resultText != '0') {
          _expression = _resultText;
        }
      } else if (key == '+/-') {
        if (_expression.startsWith('-')) {
          _expression = _expression.substring(1);
        } else if (_expression.isNotEmpty) {
          _expression = '-$_expression';
        }
        _evaluate();
      } else {
        // Prevent multiple consecutive operators
        final isOp =
            key == '+' || key == '−' || key == '×' || key == '÷' || key == '%';
        if (isOp && _expression.isNotEmpty) {
          final lastChar = _expression[_expression.length - 1];
          if (lastChar == '+' ||
              lastChar == '−' ||
              lastChar == '×' ||
              lastChar == '÷' ||
              lastChar == '%') {
            _expression =
                _expression.substring(0, _expression.length - 1) + key;
            _evaluate();
            return;
          }
        }
        _expression += key;
        _evaluate();
      }
    });
  }

  void _useAmount() {
    _evaluate();
    if (_errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot use invalid amount: $_errorMessage')),
      );
      return;
    }
    final val = double.tryParse(_resultText);
    if (val == null || val <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an amount greater than 0')),
      );
      return;
    }
    final formatted = val % 1 == 0
        ? val.toInt().toString()
        : val.toStringAsFixed(2);
    Navigator.of(context).pop(formatted);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final keys = [
      ['C', '+/-', '%', '÷'],
      ['7', '8', '9', '×'],
      ['4', '5', '6', '−'],
      ['1', '2', '3', '+'],
      ['0', '.', '⌫', '='],
    ];

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text(
          'Calculator',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Display Card
              BrutalCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _expression.isEmpty ? ' ' : _expression,
                      style: TextStyle(
                        fontSize: 18,
                        color: isDark
                            ? AppColors.darkSecondaryText
                            : AppColors.lightSecondaryText,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage ?? _resultText,
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: _errorMessage != null
                            ? AppColors.error
                            : (isDark
                                  ? AppColors.darkText
                                  : AppColors.lightText),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Keypad
              Expanded(
                child: Column(
                  children: [
                    for (final row in keys)
                      Expanded(
                        child: Row(
                          children: [
                            for (final key in row)
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(4.0),
                                  child: _buildKeyButton(
                                    key,
                                    borderColor,
                                    isDark,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Use Amount Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: !isDark
                        ? const [
                            BoxShadow(
                              color: AppColors.lightText,
                              offset: Offset(4, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      foregroundColor: AppColors.lightText,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: borderColor, width: 2),
                      ),
                    ),
                    onPressed: _useAmount,
                    icon: const Icon(Icons.check, color: AppColors.lightText),
                    label: const Text(
                      'Use amount',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.lightText,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeyButton(String key, Color borderColor, bool isDark) {
    Color bg;
    Color fg;

    if (key == '=') {
      bg = AppColors.brand;
      fg = AppColors.lightText;
    } else if (key == 'C' || key == '⌫') {
      bg = AppColors.warning.withValues(alpha: 0.3);
      fg = isDark ? AppColors.darkText : AppColors.lightText;
    } else if (key == '+' ||
        key == '−' ||
        key == '×' ||
        key == '÷' ||
        key == '%' ||
        key == '+/-') {
      bg = AppColors.accent.withValues(alpha: 0.2);
      fg = isDark ? AppColors.darkText : AppColors.lightText;
    } else {
      bg = Theme.of(context).cardColor;
      fg = isDark ? AppColors.darkText : AppColors.lightText;
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: !isDark
            ? const [
                BoxShadow(color: AppColors.lightText, offset: Offset(2, 2)),
              ]
            : null,
      ),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _onKeyPress(key),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: 2),
            ),
            alignment: Alignment.center,
            child: Text(
              key,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: fg,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
