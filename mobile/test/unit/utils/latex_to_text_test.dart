/// Unit tests for LaTeXToText utility
import 'package:flutter_test/flutter_test.dart';
import 'package:jeevibe_mobile/utils/latex_to_text.dart';

void main() {
  group('LaTeXToText', () {
    test('convert - simple math', () {
      final latex = r'\\(x^2 + y^2\\)';
      final text = LaTeXToText.convert(latex);
      expect(text, isNotEmpty);
    });

    test('convert - fractions', () {
      final latex = r'\\(\\frac{a}{b}\\)';
      final text = LaTeXToText.convert(latex);
      expect(text, isNotEmpty);
    });

    test('convert - empty string', () {
      final text = LaTeXToText.convert('');
      expect(text, '');
    });

    test('convert - no LaTeX', () {
      final text = LaTeXToText.convert('Simple text');
      expect(text, 'Simple text');
    });

    test('convert - removes delimiters', () {
      final latex = r'\\(x\\)';
      final text = LaTeXToText.convert(latex);
      expect(text, isNot(contains('\\(')));
      expect(text, isNot(contains('\\)')));
    });
  });
}

