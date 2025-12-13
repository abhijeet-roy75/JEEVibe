/// Unit tests for TextPreprocessor
import 'package:flutter_test/flutter_test.dart';
import 'package:jeevibe_mobile/utils/text_preprocessor.dart';

void main() {
  group('TextPreprocessor', () {
    test('addSpacesToText - fixes concatenated words', () {
      final text = 'HelloWorld';
      final processed = TextPreprocessor.addSpacesToText(text);
      expect(processed, contains(' '));
    });

    test('addSpacesToText - handles empty string', () {
      final processed = TextPreprocessor.addSpacesToText('');
      expect(processed, '');
    });

    test('addSpacesToText - preserves LaTeX delimiters', () {
      final text = r'Text with \\(x^2\\) math';
      final processed = TextPreprocessor.addSpacesToText(text);
      expect(processed, contains('\\('));
    });

    test('validateLatexDelimiters - detects balanced delimiters', () {
      final text = r'\\(x^2\\)';
      final isValid = TextPreprocessor.validateLatexDelimiters(text);
      expect(isValid, true);
    });

    test('validateLatexDelimiters - detects unbalanced delimiters', () {
      final text = r'\\(x^2';
      final isValid = TextPreprocessor.validateLatexDelimiters(text);
      expect(isValid, false);
    });

    test('cleanLatexForFallback - removes LaTeX commands', () {
      final text = r'\\(x^2 + y^2\\)';
      final cleaned = TextPreprocessor.cleanLatexForFallback(text);
      expect(cleaned, isNot(contains('\\(')));
    });

    test('normalizeWhitespace - removes extra spaces', () {
      final text = '  Hello   World  ';
      final normalized = TextPreprocessor.normalizeWhitespace(text);
      expect(normalized, 'Hello World');
    });

    test('preprocessStepContent - fixes step formatting', () {
      final text = 'Step1:Description';
      final processed = TextPreprocessor.preprocessStepContent(text);
      expect(processed, contains('Step 1'));
    });

    test('extractStepTitle - extracts title from step', () {
      final step = 'Step 1: Calculate the derivative';
      final title = TextPreprocessor.extractStepTitle(step);
      expect(title, contains('Calculate'));
    });
  });
}

