import 'package:flutter_test/flutter_test.dart';
import 'package:jeevibe_mobile/utils/latex_parser.dart';
import 'package:jeevibe_mobile/utils/latex_normalizer.dart';
import 'package:jeevibe_mobile/utils/latex_to_text.dart';

void main() {
  group('LaTeXParser', () {
    // =========================================================================
    // BASIC DELIMITER TESTS
    // =========================================================================
    group('Basic Delimiters', () {
      test('parses inline math with \\(...\\)', () {
        final segments = LaTeXParser.parse(r'The value is \(x^2\) here');

        expect(segments.length, 3);
        expect(segments[0].isLatex, false);
        expect(segments[0].content, 'The value is ');
        expect(segments[1].isLatex, true);
        expect(segments[1].content, 'x^2');
        expect(segments[1].isDisplayMode, false);
        expect(segments[2].isLatex, false);
        expect(segments[2].content, ' here');
      });

      test('parses display math with \\[...\\]', () {
        final segments = LaTeXParser.parse(r'Formula: \[E = mc^2\]');

        expect(segments.length, 2);
        expect(segments[0].content, 'Formula: ');
        expect(segments[1].isLatex, true);
        expect(segments[1].content, 'E = mc^2');
        expect(segments[1].isDisplayMode, true);
      });

      test('parses inline math with \$...\$', () {
        final segments = LaTeXParser.parse(r'The value is $x^2$ here');

        expect(segments.length, 3);
        expect(segments[1].isLatex, true);
        expect(segments[1].content, 'x^2');
        expect(segments[1].isDisplayMode, false);
      });

      test('parses display math with \$\$...\$\$', () {
        final segments = LaTeXParser.parse(r'Formula: $$E = mc^2$$');

        expect(segments.length, 2);
        expect(segments[1].isLatex, true);
        expect(segments[1].content, 'E = mc^2');
        expect(segments[1].isDisplayMode, true);
      });

      test('handles pure LaTeX without surrounding text', () {
        final segments = LaTeXParser.parse(r'\(x^2 + y^2\)');

        expect(segments.length, 1);
        expect(segments[0].isLatex, true);
        expect(segments[0].content, 'x^2 + y^2');
      });

      test('handles plain text without LaTeX', () {
        final segments = LaTeXParser.parse('Just plain text here');

        expect(segments.length, 1);
        expect(segments[0].isLatex, false);
        expect(segments[0].content, 'Just plain text here');
      });

      test('handles empty string', () {
        final segments = LaTeXParser.parse('');
        expect(segments.isEmpty, true);
      });
    });

    // =========================================================================
    // CONSECUTIVE LATEX BLOCKS (THE BUG FROM SCREENSHOT)
    // =========================================================================
    group('Consecutive LaTeX Blocks', () {
      test('merges \\(Cr\\)\\(^{2+}\\) into single block', () {
        final input = r'\(\mathrm{Cr}\)\(^{2+}\)';
        final segments = LaTeXParser.parse(input);

        // Should merge into one segment
        expect(segments.length, 1);
        expect(segments[0].isLatex, true);
        // Content should be merged
        expect(segments[0].content.contains('Cr'), true);
        expect(segments[0].content.contains('2+'), true);
      });

      test('merges multiple consecutive inline blocks', () {
        final input = r'\(\mathrm{Fe}\)\(^{2+}\)\(\mathrm{O}\)';
        final segments = LaTeXParser.parse(input);

        expect(segments.length, 1);
        expect(segments[0].isLatex, true);
      });

      test('merges consecutive blocks with whitespace', () {
        final input = r'\(a\) \(b\)';
        final segments = LaTeXParser.parse(input);

        expect(segments.length, 1);
        expect(segments[0].isLatex, true);
      });

      test('handles chemistry ion notation', () {
        // Real example from screenshot
        final input = r'\(\mathrm{Cr}\)\(^{2+}\)\) has 4 unpaired electrons';
        final segments = LaTeXParser.parse(input);

        // Should have LaTeX part and text part
        expect(segments.any((s) => s.isLatex), true);
        expect(segments.any((s) => !s.isLatex && s.content.contains('unpaired')), true);
      });
    });

    // =========================================================================
    // REAL JEE CHEMISTRY PATTERNS
    // =========================================================================
    group('Chemistry Patterns', () {
      test('handles mathrm for element symbols', () {
        final segments = LaTeXParser.parse(r'\(\mathrm{H}_2\mathrm{O}\)');

        expect(segments.length, 1);
        expect(segments[0].isLatex, true);
        expect(segments[0].content.contains('H'), true);
      });

      test('handles chemical equations with arrows', () {
        final input = r'\(\mathrm{H}_2 + \mathrm{O}_2 \rightarrow \mathrm{H}_2\mathrm{O}\)';
        final segments = LaTeXParser.parse(input);

        expect(segments.length, 1);
        expect(segments[0].isLatex, true);
      });

      test('handles mhchem syntax', () {
        final input = r'\ce{H2O -> H+ + OH-}';
        // Parser should detect this as containing LaTeX
        expect(LaTeXParser.containsLatex(input), true);
      });

      test('handles hybridization notation', () {
        final input = r'The hybridization is \(\mathrm{sp}^3\)';
        final segments = LaTeXParser.parse(input);

        expect(segments.length, 2);
        expect(segments[1].isLatex, true);
        expect(segments[1].content.contains('sp'), true);
      });

      test('handles electron configuration', () {
        final input = r'\([Ar] 3d^{10} 4s^2\)';
        final segments = LaTeXParser.parse(input);

        expect(segments[0].isLatex, true);
      });
    });

    // =========================================================================
    // REAL JEE PHYSICS PATTERNS
    // =========================================================================
    group('Physics Patterns', () {
      test('handles magnetic moment formula (from screenshot)', () {
        final input = r'\(\mathrm{BM}\) = \sqrt{n(n+2)}';
        final segments = LaTeXParser.parse(input);

        expect(segments.any((s) => s.isLatex), true);
      });

      test('handles vector notation', () {
        final input = r'\(\vec{F} = m\vec{a}\)';
        final segments = LaTeXParser.parse(input);

        expect(segments.length, 1);
        expect(segments[0].isLatex, true);
      });

      test('handles partial derivatives', () {
        final input = r'\(\frac{\partial f}{\partial x}\)';
        final segments = LaTeXParser.parse(input);

        expect(segments[0].isLatex, true);
        expect(segments[0].content.contains('partial'), true);
      });

      test('handles integrals', () {
        final input = r'\(\int_0^{\infty} e^{-x} dx\)';
        final segments = LaTeXParser.parse(input);

        expect(segments[0].isLatex, true);
      });
    });

    // =========================================================================
    // REAL JEE MATHEMATICS PATTERNS
    // =========================================================================
    group('Mathematics Patterns', () {
      test('handles fractions', () {
        final input = r'\(\frac{a+b}{c+d}\)';
        final segments = LaTeXParser.parse(input);

        expect(segments[0].isLatex, true);
        expect(segments[0].content.contains('frac'), true);
      });

      test('handles nested fractions', () {
        final input = r'\(\frac{1}{\frac{1}{x}+1}\)';
        final segments = LaTeXParser.parse(input);

        expect(segments[0].isLatex, true);
      });

      test('handles matrix notation', () {
        final input = r'\(\begin{pmatrix} a & b \\ c & d \end{pmatrix}\)';
        final segments = LaTeXParser.parse(input);

        expect(segments[0].isLatex, true);
        expect(segments[0].content.contains('pmatrix'), true);
      });

      test('handles summation', () {
        final input = r'\(\sum_{i=1}^{n} i^2\)';
        final segments = LaTeXParser.parse(input);

        expect(segments[0].isLatex, true);
      });

      test('handles limits', () {
        final input = r'\(\lim_{x \to 0} \frac{\sin x}{x}\)';
        final segments = LaTeXParser.parse(input);

        expect(segments[0].isLatex, true);
      });

      test('handles Greek letters', () {
        final input = r'\(\alpha + \beta = \gamma\)';
        final segments = LaTeXParser.parse(input);

        expect(segments[0].isLatex, true);
        expect(segments[0].content.contains('alpha'), true);
      });

      test('handles trigonometric functions', () {
        final input = r'\(\sin^2\theta + \cos^2\theta = 1\)';
        final segments = LaTeXParser.parse(input);

        expect(segments[0].isLatex, true);
      });

      test('handles square roots', () {
        final input = r'\(\sqrt{a^2 + b^2}\)';
        final segments = LaTeXParser.parse(input);

        expect(segments[0].isLatex, true);
      });

      test('handles nth roots', () {
        final input = r'\(\sqrt[3]{8} = 2\)';
        final segments = LaTeXParser.parse(input);

        expect(segments[0].isLatex, true);
      });
    });

    // =========================================================================
    // MIXED CONTENT PATTERNS
    // =========================================================================
    group('Mixed Content', () {
      test('handles text with multiple LaTeX segments', () {
        final input = r'If \(x = 2\) and \(y = 3\), then \(x + y = 5\)';
        final segments = LaTeXParser.parse(input);

        // Should have alternating text and LaTeX
        expect(segments.length, greaterThan(3));
        expect(segments.where((s) => s.isLatex).length, 3);
      });

      test('handles question with options', () {
        final input = r'Which is correct? (A) \(x^2\) (B) \(x^3\) (C) \(x^4\)';
        final segments = LaTeXParser.parse(input);

        expect(segments.where((s) => s.isLatex).length, 3);
      });

      test('handles assertion-reason format', () {
        final input = r'Statement I: \(\vec{F}\) is conservative. Statement II: \(\nabla \times \vec{F} = 0\)';
        final segments = LaTeXParser.parse(input);

        expect(segments.where((s) => s.isLatex).length, 2);
      });
    });

    // =========================================================================
    // EDGE CASES AND ERROR HANDLING
    // =========================================================================
    group('Edge Cases', () {
      test('handles unclosed delimiter gracefully', () {
        final input = r'The value is \(x^2';
        final segments = LaTeXParser.parse(input);

        // Should not crash, should return something
        expect(segments.isNotEmpty, true);
      });

      test('handles unmatched closing delimiter', () {
        final input = r'The value is x^2\)';
        final segments = LaTeXParser.parse(input);

        expect(segments.isNotEmpty, true);
      });

      test('handles empty delimiters', () {
        final input = r'\(\)';
        final segments = LaTeXParser.parse(input);

        // Should handle gracefully
        expect(() => LaTeXParser.parse(input), returnsNormally);
      });

      test('handles dollar sign in regular text', () {
        final input = r'The price is $50 USD';
        final segments = LaTeXParser.parse(input);

        // This might be interpreted as LaTeX, but should not crash
        expect(() => LaTeXParser.parse(input), returnsNormally);
      });

      test('handles very long LaTeX content', () {
        final input = r'\(' + 'x + ' * 100 + r'y\)';
        final segments = LaTeXParser.parse(input);

        expect(segments.isNotEmpty, true);
        expect(segments[0].isLatex, true);
      });

      test('handles special characters', () {
        final input = r'\(\{ a \in \mathbb{R} | a > 0 \}\)';
        final segments = LaTeXParser.parse(input);

        expect(segments[0].isLatex, true);
      });

      test('handles newlines in LaTeX', () {
        final input = '\\(a +\nb\\)';
        final segments = LaTeXParser.parse(input);

        expect(segments.isNotEmpty, true);
      });
    });

    // =========================================================================
    // CONTAINSLATEX DETECTION
    // =========================================================================
    group('containsLatex', () {
      test('detects \\frac', () {
        expect(LaTeXParser.containsLatex(r'\frac{1}{2}'), true);
      });

      test('detects \\mathrm', () {
        expect(LaTeXParser.containsLatex(r'\mathrm{H}'), true);
      });

      test('detects subscripts', () {
        expect(LaTeXParser.containsLatex(r'H_{2}O'), true);
      });

      test('detects superscripts', () {
        expect(LaTeXParser.containsLatex(r'x^{2}'), true);
      });

      test('detects Greek letters', () {
        expect(LaTeXParser.containsLatex(r'\alpha'), true);
        expect(LaTeXParser.containsLatex(r'\theta'), true);
        expect(LaTeXParser.containsLatex(r'\lambda'), true);
      });

      test('detects operators', () {
        expect(LaTeXParser.containsLatex(r'\times'), true);
        expect(LaTeXParser.containsLatex(r'\div'), true);
      });

      test('returns false for plain text', () {
        expect(LaTeXParser.containsLatex('Just plain text'), false);
      });

      test('detects dollar delimiters', () {
        expect(LaTeXParser.containsLatex(r'$x$'), true);
      });

      test('detects backslash-paren delimiters', () {
        expect(LaTeXParser.containsLatex(r'\(x\)'), true);
      });
    });
  });

  // ===========================================================================
  // LATEX NORMALIZER TESTS
  // ===========================================================================
  group('LaTeXNormalizer', () {
    group('Truncated Command Recovery', () {
      test('fixes rac{ to \\frac{', () {
        final input = 'rac{1}{2}';
        final normalized = LaTeXNormalizer.normalize(input);
        expect(normalized.contains('\\frac'), true);
      });

      test('fixes mathrm{ to \\mathrm{', () {
        final input = 'mathrm{H}';
        final normalized = LaTeXNormalizer.normalize(input);
        expect(normalized.contains('\\mathrm'), true);
      });

      test('fixes sqrt{ to \\sqrt{', () {
        final input = 'sqrt{2}';
        final normalized = LaTeXNormalizer.normalize(input);
        expect(normalized.contains('\\sqrt'), true);
      });

      test('preserves already correct commands', () {
        final input = r'\frac{1}{2}';
        final normalized = LaTeXNormalizer.normalize(input);
        expect(normalized, contains('\\frac'));
      });
    });

    group('Brace Balancing', () {
      test('adds missing closing brace', () {
        final input = r'\frac{1}{2';
        final normalized = LaTeXNormalizer.normalize(input);
        // Count braces
        final openCount = '{'.allMatches(normalized).length;
        final closeCount = '}'.allMatches(normalized).length;
        expect(openCount, closeCount);
      });

      test('handles multiple missing braces', () {
        final input = r'\frac{1{2';
        final normalized = LaTeXNormalizer.normalize(input);
        final openCount = '{'.allMatches(normalized).length;
        final closeCount = '}'.allMatches(normalized).length;
        expect(openCount, closeCount);
      });
    });

    group('Empty Group Removal', () {
      test('removes empty subscript', () {
        final input = r'x_{}';
        final normalized = LaTeXNormalizer.normalize(input);
        expect(normalized.contains('_{}'), false);
      });

      test('removes empty superscript', () {
        final input = r'x^{}';
        final normalized = LaTeXNormalizer.normalize(input);
        expect(normalized.contains('^{}'), false);
      });
    });

    group('Delimiter Removal', () {
      test('removes nested \\( \\)', () {
        final input = r'\(\(x\)\)';
        final normalized = LaTeXNormalizer.normalize(input);
        expect(normalized.contains(r'\('), false);
        expect(normalized.contains(r'\)'), false);
      });
    });

    group('Validity Check', () {
      test('valid simple LaTeX passes', () {
        expect(LaTeXNormalizer.isLikelyValid(r'x^2 + y^2'), true);
      });

      test('valid fraction passes', () {
        expect(LaTeXNormalizer.isLikelyValid(r'\frac{1}{2}'), true);
      });

      test('unbalanced braces fails', () {
        expect(LaTeXNormalizer.isLikelyValid(r'\frac{1}{2'), false);
      });

      test('empty input fails', () {
        expect(LaTeXNormalizer.isLikelyValid(''), false);
      });
    });
  });

  // ===========================================================================
  // LATEX TO TEXT TESTS
  // ===========================================================================
  group('LaTeXToText', () {
    group('Greek Letters', () {
      test('converts alpha to α', () {
        expect(LaTeXToText.convert(r'\alpha'), 'α');
      });

      test('converts theta to θ', () {
        expect(LaTeXToText.convert(r'\theta'), 'θ');
      });

      test('converts lambda to λ', () {
        expect(LaTeXToText.convert(r'\lambda'), 'λ');
      });

      test('converts pi to π', () {
        expect(LaTeXToText.convert(r'\pi'), 'π');
      });

      test('converts multiple Greek letters', () {
        final result = LaTeXToText.convert(r'\alpha + \beta = \gamma');
        expect(result.contains('α'), true);
        expect(result.contains('β'), true);
        expect(result.contains('γ'), true);
      });
    });

    group('Operators', () {
      test('converts times to ×', () {
        final result = LaTeXToText.convert(r'2 \times 3');
        expect(result.contains('×'), true);
      });

      test('converts div to ÷', () {
        final result = LaTeXToText.convert(r'6 \div 2');
        expect(result.contains('÷'), true);
      });

      test('converts pm to ±', () {
        final result = LaTeXToText.convert(r'x \pm 1');
        expect(result.contains('±'), true);
      });

      test('converts infty to ∞', () {
        final result = LaTeXToText.convert(r'\infty');
        expect(result.contains('∞'), true);
      });

      test('converts rightarrow to →', () {
        final result = LaTeXToText.convert(r'\rightarrow');
        expect(result.contains('→'), true);
      });
    });

    group('Fractions', () {
      test('converts simple fraction', () {
        final result = LaTeXToText.convert(r'\frac{1}{2}');
        expect(result.contains('/'), true);
        expect(result.contains('1'), true);
        expect(result.contains('2'), true);
      });

      test('converts complex fraction', () {
        final result = LaTeXToText.convert(r'\frac{a+b}{c+d}');
        expect(result.contains('/'), true);
      });
    });

    group('Subscripts and Superscripts', () {
      test('converts subscript to Unicode', () {
        final result = LaTeXToText.convert(r'H_{2}O');
        expect(result.contains('₂'), true);
      });

      test('converts superscript to Unicode', () {
        final result = LaTeXToText.convert(r'x^{2}');
        expect(result.contains('²'), true);
      });

      test('converts simple subscript', () {
        final result = LaTeXToText.convert(r'x_1');
        expect(result.contains('₁'), true);
      });

      test('converts simple superscript', () {
        final result = LaTeXToText.convert(r'x^2');
        expect(result.contains('²'), true);
      });
    });

    group('Chemistry', () {
      test('removes mathrm and keeps content', () {
        final result = LaTeXToText.convert(r'\mathrm{H}_{2}\mathrm{O}');
        expect(result.contains('H'), true);
        expect(result.contains('₂'), true);
        expect(result.contains('O'), true);
      });
    });

    group('Delimiters', () {
      test('removes inline delimiters', () {
        final result = LaTeXToText.convert(r'\(x^2\)');
        expect(result.contains(r'\('), false);
        expect(result.contains(r'\)'), false);
      });

      test('removes display delimiters', () {
        final result = LaTeXToText.convert(r'\[x^2\]');
        expect(result.contains(r'\['), false);
        expect(result.contains(r'\]'), false);
      });
    });

    group('Calculus', () {
      test('converts integral', () {
        final result = LaTeXToText.convert(r'\int');
        expect(result.contains('∫'), true);
      });

      test('converts sum', () {
        final result = LaTeXToText.convert(r'\sum');
        expect(result.contains('Σ'), true);
      });

      test('converts product', () {
        final result = LaTeXToText.convert(r'\prod');
        expect(result.contains('Π'), true);
      });
    });

    group('Matrix Conversion', () {
      test('converts simple matrix', () {
        final result = LaTeXToText.convert(r'\begin{pmatrix} 1 & 2 \\ 3 & 4 \end{pmatrix}');
        expect(result.contains('['), true);
        expect(result.contains(']'), true);
      });
    });

    group('Real-World Examples', () {
      test('converts magnetic moment formula', () {
        final result = LaTeXToText.convert(r'\sqrt{n(n+2)}');
        expect(result.isNotEmpty, true);
        expect(result.contains('√') || result.contains('sqrt'), true);
      });

      test('converts chemistry ion notation', () {
        final result = LaTeXToText.convert(r'\mathrm{Fe}^{2+}');
        expect(result.contains('Fe'), true);
        expect(result.contains('²'), true);
        expect(result.contains('⁺'), true);
      });
    });
  });

  // ===========================================================================
  // INTEGRATION TESTS - FULL PIPELINE
  // ===========================================================================
  group('Full Pipeline Integration', () {
    test('processes problematic screenshot example', () {
      // The exact pattern from the screenshot
      final input = r'\(\mathrm{Cr}\)\(^{2+}\)\) has 4 unpaired electrons';

      // Parser should handle it
      final segments = LaTeXParser.parse(input);
      expect(segments.isNotEmpty, true);

      // If there's a LaTeX segment, normalizer should handle it
      for (final segment in segments) {
        if (segment.isLatex) {
          final normalized = LaTeXNormalizer.normalize(segment.content);
          expect(normalized.isNotEmpty, true);

          // And converter should produce readable text
          final text = LaTeXToText.convert(segment.content);
          expect(text.isNotEmpty, true);
        }
      }
    });

    test('processes BM formula from screenshot', () {
      final input = r'\(\mathrm{BM}\) = \sqrt{n(n+2)}{4}';

      final segments = LaTeXParser.parse(input);
      expect(segments.isNotEmpty, true);

      // Should have both LaTeX and text parts
      final hasLatex = segments.any((s) => s.isLatex);
      expect(hasLatex, true);
    });

    test('handles full question with options', () {
      final input = '''The spin-only magnetic moment can be calculated using the formula \\(\\mathrm{BM} = \\sqrt{n(n+2)}\\), where n is the number of unpaired electrons.

For \\(\\mathrm{Cr}^{2+}\\), \\(\\mathrm{BM} = \\sqrt{4(4+2)} = \\sqrt{24}\\)''';

      final segments = LaTeXParser.parse(input);
      expect(segments.isNotEmpty, true);

      // Should detect multiple LaTeX regions
      final latexCount = segments.where((s) => s.isLatex).length;
      expect(latexCount, greaterThan(0));
    });
  });

  // ===========================================================================
  // JEE ADVANCED 2024 PAPER-1 REAL QUESTIONS
  // ===========================================================================
  group('JEE Advanced 2024 Paper-1 Real Questions', () {
    // =========================================================================
    // MATHEMATICS SECTION
    // =========================================================================
    group('Mathematics - Calculus & Limits', () {
      test('Q1: Limit expression with f(x) and f(t)', () {
        // Let f(x) be a continuously differentiable function on (0, ∞) such that f(1) = 2 and
        // lim (t^10 f(x) - x^10 f(t))/(t^9 - x^9) = 1
        final input = r'$\lim_{t \to x} \frac{t^{10}f(x) - x^{10}f(t)}{t^9 - x^9} = 1$';

        expect(LaTeXParser.containsLatex(input), true);
        final segments = LaTeXParser.parse(input);
        expect(segments.isNotEmpty, true);
        expect(segments.any((s) => s.isLatex), true);
      });

      test('Q1: Option expressions with fractions and powers', () {
        // Options from Q1
        final optionA = r'\frac{31}{11x} - \frac{9}{11}x^{10}';
        final optionB = r'\frac{9}{11x} + \frac{13}{11}x^{10}';
        final optionC = r'\frac{-9}{11x} + \frac{31}{11}x^{10}';
        final optionD = r'\frac{13}{11x} + \frac{9}{11}x^{10}';

        for (final option in [optionA, optionB, optionC, optionD]) {
          expect(LaTeXParser.containsLatex(option), true);
          final segments = LaTeXParser.parse(option);
          expect(segments.isNotEmpty, true);
        }
      });

      test('Q1: Solution with integral and derivatives', () {
        final solution = r'''f'(x) - \frac{10}{x}f(x) = -\frac{9}{x^2}
IF = e^{-\int\frac{10}{x}dx} = \frac{1}{x^{10}}
\frac{y}{x^{10}} = \int -\frac{9}{x^{10}} \times \frac{1}{x^2} dx = -9\int x^{-12}dx
\frac{y}{x^{10}} = \frac{9}{11}x^{-11} + C
y = \frac{9}{11x} + \frac{13}{11}x^{10}''';

        expect(LaTeXParser.containsLatex(solution), true);
        final segments = LaTeXParser.parse(solution);
        expect(segments.isNotEmpty, true);
      });
    });

    group('Mathematics - Probability', () {
      test('Q2: Probability question with fractions', () {
        // Probability of correct answer when guessed is 1/2
        // Probability of guessed given correct is 1/6
        final input = r"The probability of the student giving the correct answer for a question, given that he has guessed it, is $\frac{1}{2}$. The probability of the answer for a question being guessed, given that the student's answer is correct, is $\frac{1}{6}$.";

        expect(LaTeXParser.containsLatex(input), true);
        final segments = LaTeXParser.parse(input);
        expect(segments.where((s) => s.isLatex).length, greaterThanOrEqualTo(2));
      });

      test('Q2: Probability options', () {
        final options = [
          r'\frac{1}{12}',
          r'\frac{1}{7}',
          r'\frac{5}{7}',
          r'\frac{5}{12}',
        ];

        for (final opt in options) {
          expect(LaTeXParser.containsLatex(opt), true);
          final segments = LaTeXParser.parse(opt);
          expect(segments.isNotEmpty, true);
        }
      });

      test('Q2: Bayes theorem solution', () {
        final solution = r'''P(\text{knows answer}) = k
P(\text{guesses}) = 1 - k
P\left(\frac{\text{correct ans}}{\text{guessed}}\right) = \frac{1}{2}
P\left(\frac{\text{guessed}}{\text{correct answer}}\right) = \frac{P(\text{guessed}) \cdot P\left(\frac{\text{correct ans}}{\text{guessed}}\right)}{P(\text{guessed}) \cdot P\left(\frac{\text{correct ans}}{\text{guessed}}\right) + P(\text{knows}) \cdot P\left(\frac{\text{correct ans}}{\text{knows}}\right)}''';

        expect(LaTeXParser.containsLatex(solution), true);
      });
    });

    group('Mathematics - Trigonometry', () {
      test('Q3: Trigonometric expression with cot', () {
        // Let π/2 < x < π be such that cot x = -5/√11
        final input = r'Let $\frac{\pi}{2} < x < \pi$ be such that $\cot x = \frac{-5}{\sqrt{11}}$. Then $\left(\sin\frac{11x}{2}\right)(\sin 6x - \cos 6x) + \left(\cos\frac{11x}{2}\right)(\sin 6x + \cos 6x)$ is equal to';

        expect(LaTeXParser.containsLatex(input), true);
        final segments = LaTeXParser.parse(input);
        expect(segments.isNotEmpty, true);
      });

      test('Q3: Trigonometry answer options with sqrt', () {
        final options = [
          r'$\frac{\sqrt{11} - 1}{2\sqrt{3}}$',
          r'$\frac{\sqrt{11} + 1}{2\sqrt{3}}$',
          r'$\frac{\sqrt{11} + 1}{3\sqrt{2}}$',
          r'$\frac{\sqrt{11} - 1}{3\sqrt{2}}$',
        ];

        for (final opt in options) {
          expect(LaTeXParser.containsLatex(opt), true);
          final segments = LaTeXParser.parse(opt);
          expect(segments[0].isLatex, true);
          expect(segments[0].content.contains('sqrt'), true);
        }
      });

      test('Q3: Solution with sin and cos manipulation', () {
        final solution = r'''E = \sin 6x \cos\frac{11x}{2} - \cos 6x \sin\frac{11x}{2} + \cos 6x \cos\frac{11x}{2} + \sin 6x \sin\frac{11x}{2}
E = \sin\frac{x}{2} + \cos\frac{x}{2}
E^2 = 1 + \sin x
E = \sqrt{\frac{6 + \sqrt{11}}{6}} = \frac{\sqrt{11} + 1}{2\sqrt{3}}''';

        expect(LaTeXParser.containsLatex(solution), true);
      });
    });

    group('Mathematics - Coordinate Geometry (Ellipse)', () {
      test('Q4: Ellipse equation', () {
        final input = r'Consider the ellipse $\frac{x^2}{9} + \frac{y^2}{4} = 1$. Let $S(p, q)$ be a point in the first quadrant such that $\frac{p^2}{9} + \frac{q^2}{4} > 1$.';

        expect(LaTeXParser.containsLatex(input), true);
        final segments = LaTeXParser.parse(input);
        expect(segments.where((s) => s.isLatex).length, greaterThanOrEqualTo(2));
      });

      test('Q4: Area of triangle expression', () {
        final input = r'If the area of the triangle $\Delta ORT$ is $\frac{3}{2}$, then which of the following options is correct?';

        expect(LaTeXParser.containsLatex(input), true);
      });

      test('Q4: Options with sqrt(3)', () {
        final options = [
          r'q = 2, p = 3\sqrt{3}',
          r'q = 2, p = 4\sqrt{3}',
          r'q = 1, p = 5\sqrt{3}',
          r'q = 1, p = 6\sqrt{3}',
        ];

        for (final opt in options) {
          expect(LaTeXParser.containsLatex(opt), true);
        }
      });
    });

    group('Mathematics - Set Theory & Abstract Algebra', () {
      test('Q5: Set with sqrt(2) definition', () {
        final input = r'Let $S = \{a + b\sqrt{2} : a, b \in \mathbb{Z}\}$, $T_1 = \{(-1 + \sqrt{2})^n : n \in \mathbb{N}\}$ and $T_2 = \{(1 + \sqrt{2})^n : n \in \mathbb{N}\}$.';

        expect(LaTeXParser.containsLatex(input), true);
        final segments = LaTeXParser.parse(input);
        expect(segments.isNotEmpty, true);
      });

      test('Q5: Set operations and membership', () {
        final options = [
          r'\mathbb{Z} \cup T_1 \cup T_2 \subset S',
          r'T_1 \cap \left(0, \frac{1}{2024}\right) = \phi',
          r'T_2 \cap (2024, \infty) \neq \phi',
          r'\cos\left(\pi(a + b\sqrt{2})\right) + i\sin\left(\pi(a + b\sqrt{2})\right) \in \mathbb{Z}',
        ];

        for (final opt in options) {
          expect(LaTeXParser.containsLatex(opt), true);
        }
      });
    });

    group('Mathematics - Matrices & Determinants', () {
      test('Q10: Matrix definition with determinant constraint', () {
        final input = r'''Let $S = \left\{A = \begin{pmatrix} 0 & 1 & c \\ 1 & a & d \\ 1 & b & e \end{pmatrix} : a, b, c, d, e \in \{0, 1\} \text{ and } |A| \in \{-1, 1\}\right\}$, where $|A|$ denotes the determinant of $A$.''';

        expect(LaTeXParser.containsLatex(input), true);
        final segments = LaTeXParser.parse(input);
        expect(segments.isNotEmpty, true);
      });

      test('Q14: Matrix row/column sum constraints', () {
        final input = r'For a $3 \times 3$ matrix $M = (a_{ij})_{3 \times 3}$, define $R_i = a_{i1} + a_{i2} + a_{i3}$ and $C_j = a_{1j} + a_{2j} + a_{3j}$ for $i = 1, 2, 3$ and $j = 1, 2, 3$.';

        expect(LaTeXParser.containsLatex(input), true);
      });
    });

    group('Mathematics - 3D Geometry & Vectors', () {
      test('Q7: Distance formula in R^3', () {
        final input = r'Let $\mathbb{R}^3$ denote the three-dimensional space. Take two points $P = (1, 2, 3)$ and $Q = (4, 2, 7)$. Let $dist(X, Y)$ denote the distance between two points $X$ and $Y$ in $\mathbb{R}^3$.';

        expect(LaTeXParser.containsLatex(input), true);
      });

      test('Q7: Set definition with distance squared', () {
        final input = r'$S = \{X \in \mathbb{R}^3 : (dist(X, P))^2 - (dist(X, Q))^2 = 50\}$';

        expect(LaTeXParser.containsLatex(input), true);
        final segments = LaTeXParser.parse(input);
        expect(segments.isNotEmpty, true);
      });

      test('Q12: Vector notation with unit vectors', () {
        final input = r'Let $\vec{OP} = \frac{\alpha - 1}{\alpha}\hat{i} + \hat{j} + \hat{k}$, $\vec{OQ} = \hat{i} + \frac{\beta - 1}{\beta}\hat{j} + \hat{k}$ and $\vec{OR} = \hat{i} + \hat{j} + \frac{1}{2}\hat{k}$ be three vectors, where $\alpha, \beta \in \mathbb{R} - \{0\}$ and $O$ denotes the origin.';

        expect(LaTeXParser.containsLatex(input), true);
      });

      test('Q12: Cross product and dot product', () {
        final input = r'If $(\vec{OP} \times \vec{OQ}) \cdot \vec{OR} = 0$ and the point $(\alpha, \beta, 2)$ lies on the plane $3x + 3y - z + l = 0$';

        expect(LaTeXParser.containsLatex(input), true);
      });

      test('Q16: Line equations in 3D', () {
        final input = r'Let $\gamma \in \mathbb{R}$ be such that the lines $L_1 : \frac{x + 11}{1} = \frac{y + 21}{2} = \frac{z + 29}{3}$ and $L_2 : \frac{x + 16}{3} = \frac{y + 11}{2} = \frac{z + 4}{\gamma}$ intersect.';

        expect(LaTeXParser.containsLatex(input), true);
      });

      test('Q16: Unit normal vector', () {
        final input = r'$\hat{n} = \frac{1}{\sqrt{6}}\hat{i} - \frac{2}{\sqrt{6}}\hat{j} + \frac{1}{\sqrt{6}}\hat{k}$';

        expect(LaTeXParser.containsLatex(input), true);
        final segments = LaTeXParser.parse(input);
        expect(segments.any((s) => s.isLatex), true);
      });
    });

    group('Mathematics - Logarithms', () {
      test('Q8: Logarithmic equations', () {
        final input = r'Let $a = 3\sqrt{2}$ and $b = \frac{1}{5^{\frac{1}{6}}\sqrt{6}}$. If $x, y \in \mathbb{R}$ are such that $3x + 2y = \log_a(18)^{\frac{5}{4}}$ and $2x - y = \log_b(\sqrt{1080})$, then $4x + 5y$ is equal to';

        expect(LaTeXParser.containsLatex(input), true);
      });
    });

    group('Mathematics - Polynomials', () {
      test('Q9: Polynomial with complex roots', () {
        final input = r'Let $f(x) = x^4 + ax^3 + bx^2 + c$ be a polynomial with real coefficients such that $f(1) = -9$. Suppose that $i\sqrt{3}$ is a root of the equation $4x^3 + 3ax^2 + 2bx = 0$, where $i = \sqrt{-1}$. If $\alpha_1, \alpha_2, \alpha_3$, and $\alpha_4$ are all the roots of the equation $f(x) = 0$, then $|\alpha_1|^2 + |\alpha_2|^2 + |\alpha_3|^2 + |\alpha_4|^2$ is equal to';

        expect(LaTeXParser.containsLatex(input), true);
      });
    });

    group('Mathematics - Statistics', () {
      test('Q13: Random variable and probability', () {
        final input = r'Let $X$ be a random variable, and let $P(X = x)$ denote the probability that $X$ takes the value $x$. Suppose that the points $(x, P(X = x))$, $x = 0, 1, 2, 3, 4$, lie on a fixed straight line in the $xy$-plane, and $P(X = x) = 0$ for all $x \in \mathbb{R} - \{0, 1, 2, 3, 4\}$. If the mean of $X$ is $\frac{5}{2}$, and the variance of $X$ is $\alpha$, then the value of $24\alpha$ is';

        expect(LaTeXParser.containsLatex(input), true);
      });

      test('Q13: Summation notation', () {
        final input = r'$\sum_{x=0}^{4} xP(x) = \frac{5}{2}$ and $\sum_{x=0}^{4} x^2P(x) = ?$';

        expect(LaTeXParser.containsLatex(input), true);
      });
    });

    // =========================================================================
    // PHYSICS SECTION
    // =========================================================================
    group('Physics - Dimensional Analysis', () {
      test('Q1: Dimensionless quantity', () {
        final input = r"A dimensionless quantity is constructed in terms of electronic charge $e$, permittivity of free space $\varepsilon_0$, Planck's constant $h$, and speed of light $c$. If the dimensionless quantity is written as $e^\alpha \varepsilon_0^\beta h^\gamma c^\delta$ and $n$ is a non-zero integer, then $(\alpha, \beta, \gamma, \delta)$ is given by";

        expect(LaTeXParser.containsLatex(input), true);
      });

      test('Q1: Dimensional formula', () {
        final input = r'$[AT]^\alpha [M^{-1}L^{-3}T^4A^2]^\beta [ML^2T^{-1}]^\gamma [LT^{-1}]^\delta = 0$';

        expect(LaTeXParser.containsLatex(input), true);
      });
    });

    group('Physics - Electromagnetism', () {
      test('Q2: Magnetic field line integral', () {
        final input = r'An infinitely long wire, located on the $z$-axis, carries a current $I$ along the $+z$-direction and produces the magnetic field $\vec{B}$. The magnitude of the line integral $\int \vec{B} \cdot d\vec{l}$ along a straight line from the point $(-\sqrt{3}a, a, 0)$ to $(a, a, 0)$ is given by';

        expect(LaTeXParser.containsLatex(input), true);
      });

      test('Q2: Answer with mu_0', () {
        final options = [
          r'7\mu_0 I / 24',
          r'7\mu_0 I / 12',
          r'\mu_0 I / 8',
          r'\mu_0 I / 6',
        ];

        for (final opt in options) {
          expect(LaTeXParser.containsLatex(opt), true);
        }
      });
    });

    group('Physics - Oscillations', () {
      test('Q3: Angular frequency of oscillations', () {
        final input = r'Two beads, each with charge $q$ and mass $m$, are on a horizontal, frictionless, non-conducting, circular hoop of radius $R$. The square of the angular frequency of the small oscillations is given by';

        expect(LaTeXParser.containsLatex(input), true);
      });

      test('Q3: Answer options with epsilon_0', () {
        final options = [
          r'\omega^2 = \frac{q^2}{4\pi\varepsilon_0 R^3 m}',
          r'\omega^2 = \frac{q^2}{32\pi\varepsilon_0 R^3 m}',
          r'\omega^2 = \frac{q^2}{8\pi\varepsilon_0 R^3 m}',
          r'\omega^2 = \frac{q^2}{16\pi\varepsilon_0 R^3 m}',
        ];

        for (final opt in options) {
          expect(LaTeXParser.containsLatex(opt), true);
        }
      });
    });

    group('Physics - Kinematics', () {
      test('Q4: Force equation with position', () {
        final input = r'A block of mass 5 kg moves along the $x$-direction subject to the force $F = (-20x + 10)$ N, with the value of $x$ in metre. At time $t = 0$ s, it is at rest at position $x = 1$ m. The position and momentum of the block at $t = (\pi/4)$ s are';

        expect(LaTeXParser.containsLatex(input), true);
      });

      test('Q4: Solution with differential equation', () {
        final solution = r'''a = \frac{vdv}{dx} = -4x + 2
v = -2\sqrt{x - x^2}
\frac{dx}{dt} = -2\sqrt{x - x^2}
\sin^{-1}[2x - 1]_1^x = -\frac{\pi}{2}
x = \frac{1}{2} = 0.5 \text{ m}''';

        expect(LaTeXParser.containsLatex(solution), true);
      });
    });

    group('Physics - Quantum Mechanics (Bohr Model)', () {
      test('Q5: Angular momentum quantization', () {
        final input = r"According to the Bohr's quantization rule, the angular momentum of the particle is given by $L = n\hbar$, where $\hbar = h/(2\pi)$, $h$ is the Planck's constant, and $n$ a positive integer.";

        expect(LaTeXParser.containsLatex(input), true);
      });

      test('Q5: Energy and radius expressions', () {
        final options = [
          r'r^2 = n\hbar\sqrt{\frac{1}{mk}}',
          r'v^2 = n\hbar\sqrt{\frac{k}{m^3}}',
          r'\frac{L}{mr^2} = \sqrt{\frac{k}{m}}',
          r'E = \frac{n\hbar}{2}\sqrt{\frac{k}{m}}',
        ];

        for (final opt in options) {
          expect(LaTeXParser.containsLatex(opt), true);
        }
      });
    });

    group('Physics - Waves', () {
      test('Q6: String wave frequency', () {
        final input = r'Two uniform strings of mass per unit length $\mu$ and $4\mu$, and length $L$ and $2L$, respectively, are joined at point $O$, and tied at two fixed ends $P$ and $Q$. The strings are under a uniform tension $T$. If we define the frequency $v_0 = \frac{1}{2L}\sqrt{\frac{T}{\mu}}$';

        expect(LaTeXParser.containsLatex(input), true);
      });
    });

    group('Physics - Optics', () {
      test('Q7: Refraction through sphere', () {
        final input = r'A glass beaker has a solid, plano-convex base of refractive index 1.60. The radius of curvature of the convex surface (SPU) is 9 cm. This beaker is filled with a liquid of refractive index $n$ up to the level QPR. For $n = 1.42$, $h = 50$ cm.';

        expect(LaTeXParser.containsLatex(input), true);
      });

      test('Q7: Lens formula', () {
        final formula = r'\frac{1}{f_{\text{net}}} = 2\left(\frac{1}{f_{\text{liq}}}\right) + 2\left(\frac{1}{f_{\text{lens}}}\right) + \left(\frac{-1}{f_{\text{mirror}}}\right)';

        expect(LaTeXParser.containsLatex(formula), true);
      });
    });

    group('Physics - Thermodynamics', () {
      test('Q8: Heat capacity formula', () {
        final input = r'The specific heat capacity of a substance is temperature dependent and is given by the formula $C = kT$, where $k$ is a constant of suitable dimensions in SI units, and $T$ is the absolute temperature.';

        expect(LaTeXParser.containsLatex(input), true);
      });

      test('Q8: Heat integral', () {
        final solution = r'''dQ = m \cdot C \cdot dT = 1 \cdot kT \cdot dT
Q = \int_{200}^{300} kT \, dT = \frac{k}{2}[300^2 - 200^2] = \frac{10^4 \cdot 5}{2} \cdot k = 25000k''';

        expect(LaTeXParser.containsLatex(solution), true);
      });
    });

    group('Physics - Rotational Mechanics', () {
      test('Q9: Moment of inertia', () {
        final input = r"A disc of mass $M$ and radius $R$ is free to rotate about its vertical axis. Another disc of the same mass $M$ and radius $R/2$ is fixed to the motor's thin shaft. The angular speed at which the large disc rotates is $\omega/n$.";

        expect(LaTeXParser.containsLatex(input), true);
      });

      test('Q9: Conservation of angular momentum', () {
        final solution = r'\frac{MR^2}{2}\omega\prime + M \cdot R\omega\prime \cdot R + \frac{M(R/2)^2}{2}\omega = 0';

        expect(LaTeXParser.containsLatex(solution), true);
      });

      test('Q13: Impulse and angular impulse', () {
        final input = r'If a horizontal impulse $P$ is imparted to the rod at a distance $x = L/n$ from the mid-point of the rod, the angular impulse about point O is $P\left(x + \frac{3L}{2}\right) = I_0\omega_0$';

        expect(LaTeXParser.containsLatex(input), true);
      });
    });

    group('Physics - Fluid Mechanics', () {
      test('Q12: Efflux velocity', () {
        final input = r'$a\sqrt{2gh} = -A\frac{dh}{dt}$';

        expect(LaTeXParser.containsLatex(input), true);
      });

      test('Q12: Time to empty tank', () {
        final solution = r'T = \int dt = \frac{-2A}{a\sqrt{2g}}(\sqrt{h_f} - \sqrt{h_i}) = \frac{2A}{a\sqrt{2g}}(\sqrt{h_i} - \sqrt{h_f})';

        expect(LaTeXParser.containsLatex(solution), true);
      });
    });

    group('Physics - Polarization', () {
      test('Q10: Malus law', () {
        final input = r'$I_B\prime = \frac{I_B}{2}\cos^2 45° = \frac{I_B}{4}$';

        expect(LaTeXParser.containsLatex(input), true);
      });
    });

    group('Physics - Doppler Effect', () {
      test('Q11: Frequency formula', () {
        final input = r'$f_{\text{app}} = f\left(\frac{c + v}{c - v}\right)$ when moving towards each other';

        expect(LaTeXParser.containsLatex(input), true);
      });
    });

    group('Physics - Electric Circuits', () {
      test('Q17: LC oscillation', () {
        final input = r'$\omega = \frac{1}{\sqrt{LC}} = \frac{1}{\sqrt{25 \times 10^{-3} \times 10 \times 10^{-6}}} = 2000$ rad/s';

        expect(LaTeXParser.containsLatex(input), true);
      });

      test('Q17: Charge and voltage amplitude', () {
        final solution = r'''Q_0 = \frac{i_0}{\omega} = \frac{4}{2 \times 10^3} = 2 \text{ mC}
V_0 = \frac{Q_0}{C} = \frac{2 \times 10^{-3}}{10} = 200 \text{ V}''';

        expect(LaTeXParser.containsLatex(solution), true);
      });
    });

    group('Physics - Thermodynamic Cycles', () {
      test('Q14: PV diagram process', () {
        final input = r'One mole of a monatomic ideal gas undergoes the cyclic process $J \to K \to L \to M \to J$.';

        expect(LaTeXParser.containsLatex(input), true);
      });

      test('Q14: Work and heat calculations', () {
        final solution = r'''W_{\text{net}} = RT_0\ln 2 + 2RT_0 - 3RT_0\ln 2 - 2RT_0 = -2RT_0\ln 2
\Delta U = nC_v\Delta T = \frac{3R}{2} \times 2T_0 = 3RT_0
Q = -3RT_0\ln 2''';

        expect(LaTeXParser.containsLatex(solution), true);
      });
    });

    group('Physics - Capacitors', () {
      test('Q15: Capacitance formula', () {
        final input = r'Let $C_0 = \varepsilon_0 a^2/d$, where $\varepsilon_0$ is the permittivity of free space.';

        expect(LaTeXParser.containsLatex(input), true);
      });

      test('Q15: Equivalent capacitance', () {
        final options = [
          r'C_{\text{eq}} = \frac{C_0}{3}',
          r'C_{\text{eq}} = \frac{C_0}{2}',
          r'C_{\text{eq}} = \frac{2C_0}{3}',
          r'C_{\text{eq}} = 3C_0',
        ];

        for (final opt in options) {
          expect(LaTeXParser.containsLatex(opt), true);
        }
      });
    });

    // =========================================================================
    // CHEMISTRY SECTION
    // =========================================================================
    group('Chemistry - Gases', () {
      test('Q1: Root mean square velocity', () {
        // Plain text question without LaTeX - tests that containsLatex returns false for pure text
        final input = r'A closed vessel contains 10 g of an ideal gas X at 300 K, which exerts 2 atm pressure. 80 g of another ideal gas Y is added to it. The ratio of root mean square velocities of X and Y at 300 K is';

        expect(LaTeXParser.containsLatex(input), false);
      });

      test('Q1: Vrms formula', () {
        final solution = r'''V_{\text{rms}} = \sqrt{\frac{3RT}{M}}
\frac{(V_{\text{rms}})_X}{(V_{\text{rms}})_Y} = \sqrt{\frac{M_Y}{M_X}} = \sqrt{\frac{80}{4} \times \frac{2}{10}} = \sqrt{4} = \frac{2}{1} = 2:1''';

        expect(LaTeXParser.containsLatex(solution), true);
      });
    });

    group('Chemistry - Ionic Equilibrium', () {
      test('Q2: Disproportionation of HNO2', () {
        final input = r'At room temperature, disproportionation of an aqueous solution of in situ generated nitrous acid ($\mathrm{HNO}_2$) gives the species $\mathrm{H}_3\mathrm{O}^+$, $\mathrm{NO}_3^-$ and NO.';

        expect(LaTeXParser.containsLatex(input), true);
      });

      test('Q2: Ionic species', () {
        final species = [
          r'\mathrm{H}_3\mathrm{O}^+',
          r'\mathrm{NO}_3^-',
          r'\mathrm{NO}_2^-',
          r'\mathrm{NO}_2',
          r'\mathrm{N}_2\mathrm{O}',
        ];

        for (final sp in species) {
          expect(LaTeXParser.containsLatex(sp), true);
        }
      });
    });

    group('Chemistry - Coordination Compounds', () {
      test('Q4: Coordination complex formulas', () {
        final complexes = [
          r'[\mathrm{Ni}(\mathrm{CO})_4]',
          r'[\mathrm{PdCl}_2(\mathrm{PPh}_3)_2]',
          r'[\mathrm{Co}(\mathrm{NH}_3)_5\mathrm{Cl}]\mathrm{SO}_4',
          r'[\mathrm{Co}(\mathrm{NH}_3)_5(\mathrm{SO}_4)]\mathrm{Cl}',
          r'[\mathrm{Co}(\mathrm{en})(\mathrm{NH}_3)_2\mathrm{Cl}_2]',
        ];

        for (final complex in complexes) {
          expect(LaTeXParser.containsLatex(complex), true);
        }
      });

      test('Q13: Diamagnetic complexes', () {
        final complexes = [
          r'[\mathrm{Mn}(\mathrm{NH}_3)_6]^{3+}',
          r'[\mathrm{MnCl}_6]^{3-}',
          r'[\mathrm{FeF}_6]^{3-}',
          r'[\mathrm{CoF}_6]^{3-}',
          r'[\mathrm{Fe}(\mathrm{NH}_3)_6]^{3+}',
          r'[\mathrm{Co}(\mathrm{en})_3]^{3+}',
        ];

        for (final complex in complexes) {
          expect(LaTeXParser.containsLatex(complex), true);
        }
      });
    });

    group('Chemistry - Atomic Structure', () {
      test('Q5: Energy of electron', () {
        final input = r'The energy of an electron in 2s orbital of an atom is lower than the energy of an electron that is infinitely far away from the nucleus.';

        // This is plain text, should detect no LaTeX
        expect(LaTeXParser.containsLatex(input), false);
      });

      test('Q5: Bohr model energy formula', () {
        final formula = r'E = -13.6\frac{Z^2}{n^2} \text{ eV/atom}';

        expect(LaTeXParser.containsLatex(formula), true);
      });

      test('Q5: Velocity in Bohr model', () {
        final formula = r'V = V_0 \times \frac{Z}{n}';

        expect(LaTeXParser.containsLatex(formula), true);
      });
    });

    group('Chemistry - Organic Chemistry', () {
      test('Q6: Reaction sequence', () {
        final input = r'Reaction of iso-propylbenzene with $\mathrm{O}_2$ followed by the treatment with $\mathrm{H}_3\mathrm{O}^+$ forms phenol and a by-product P.';

        expect(LaTeXParser.containsLatex(input), true);
      });

      test('Q6: Chemical formulas in reactions', () {
        final formulas = [
          r'\mathrm{Ca}(\mathrm{OH})_2',
          r'\mathrm{Cl}_3\mathrm{CCH}_2\mathrm{OH}',
          r'\mathrm{Cl}_3\mathrm{CCOONa}',
          r'\mathrm{COCl}_2',
        ];

        for (final f in formulas) {
          expect(LaTeXParser.containsLatex(f), true);
        }
      });
    });

    group('Chemistry - VSEPR', () {
      test('Q15: Xenon compounds', () {
        final compounds = [
          r'\mathrm{XeF}_2',
          r'\mathrm{XeF}_4',
          r'\mathrm{XeO}_3',
          r'\mathrm{XeO}_3\mathrm{F}_2',
        ];

        for (final c in compounds) {
          expect(LaTeXParser.containsLatex(c), true);
        }
      });

      test('Q15: Hybridization notation', () {
        final hybridizations = [
          r'sp^3d',
          r'sp^3d^2',
          r'sp^3',
        ];

        for (final h in hybridizations) {
          expect(LaTeXParser.containsLatex(h), true);
        }
      });
    });

    group('Chemistry - Thermodynamics', () {
      test('Q8: Enthalpy change formula', () {
        final input = r'''X \to Y is an isothermal process, $\Delta H = 0$
Y \to Z is an isochoric process
$\Delta U = nC_{V,m}(T_2 - T_1) = 5 \times 12 \times (415 - 335) = 4800$ J
$\Delta H = \Delta U + \Delta(PV) = \Delta U + nR\Delta T = 4800 + 5 \times 8.3 \times (415 - 335) = 8120$ J''';

        expect(LaTeXParser.containsLatex(input), true);
      });
    });

    group('Chemistry - Kinetics', () {
      test('Q9: Rate law expression', () {
        final input = r'''$r = k_2[\mathrm{N}_2\mathrm{O}_2][\mathrm{H}_2]$
$\frac{k_1}{k_{-1}} = \frac{[\mathrm{N}_2\mathrm{O}_2]}{[\mathrm{NO}]^2}$
$[\mathrm{N}_2\mathrm{O}_2] = \frac{k_1}{k_{-1}}[\mathrm{NO}]^2$
$r = \frac{k_2 k_1}{k_{-1}}[\mathrm{NO}]^2[\mathrm{H}_2]$''';

        expect(LaTeXParser.containsLatex(input), true);
      });
    });

    group('Chemistry - Organometallic', () {
      test('Q11: Carbonyl complexes', () {
        final complexes = [
          r'\mathrm{V}(\mathrm{CO})_6',
          r'\mathrm{Cr}(\mathrm{CO})_5',
          r'\mathrm{Cu}(\mathrm{CO})_3',
          r'\mathrm{Mn}(\mathrm{CO})_5',
          r'\mathrm{Fe}(\mathrm{CO})_5',
          r'[\mathrm{Co}(\mathrm{CO})_3]^{3-}',
          r'[\mathrm{Cr}(\mathrm{CO})_4]^{4-}',
          r'\mathrm{Ir}(\mathrm{CO})_3',
          r'\mathrm{Ni}(\mathrm{CO})_4',
        ];

        for (final c in complexes) {
          expect(LaTeXParser.containsLatex(c), true);
        }
      });

      test('Q11: Electron count', () {
        final input = r'Total number of electrons in $\mathrm{Ni}(\mathrm{CO})_4 = 28 + 4 \times 14 = 84$';

        expect(LaTeXParser.containsLatex(input), true);
      });
    });

    group('Chemistry - Conductometry', () {
      test('Q14: Limiting molar conductivity', () {
        final input = r'The limiting ionic conductivity ($\Lambda_0$) values (in mS m$^2$ mol$^{-1}$) for different ions: Ag$^+$ = 6.2, K$^+$ = 7.4, Na$^+$ = 5.0, H$^+$ = 35.0, NO$_3^-$ = 7.2, Cl$^-$ = 7.6, SO$_4^{2-}$ = 16.0, OH$^-$ = 19.9, CH$_3$COO$^-$ = 4.1';

        expect(LaTeXParser.containsLatex(input), true);
      });
    });
  });

  // ===========================================================================
  // COMPLEX MULTI-PART JEE QUESTIONS
  // ===========================================================================
  group('Complex JEE Question Patterns', () {
    test('handles assertion-reason format from JEE', () {
      final input = r'''Statement I: The energy of an electron in the $2s$ orbital of a hydrogen atom is lower than that of an electron at infinity.

Statement II: According to Bohr\'s model, the energy is given by $E_n = -13.6\frac{Z^2}{n^2}$ eV.''';

      final segments = LaTeXParser.parse(input);
      expect(segments.isNotEmpty, true);
      expect(segments.where((s) => s.isLatex).length, greaterThan(0));
    });

    test('handles matching type question with matrices', () {
      final input = r'''Match List-I with List-II:

(P) The number of matrices $M = (a_{ij})_{3 \times 3}$ with $R_i = C_j = 0$ for all $i, j$ is $\to$ (1) 1

(Q) The number of symmetric matrices $M = (a_{ij})_{3 \times 3}$ with all entries in $T$ such that $C_j = 0$ for all $j$ is $\to$ (2) 12

(R) Let $M = (a_{ij})_{3 \times 3}$ be a skew symmetric matrix with $|M| = 0$ $\to$ (3) Infinite''';

      expect(LaTeXParser.containsLatex(input), true);
    });

    test('handles integer type answer question', () {
      final input = r'''Let $a = 3\sqrt{2}$ and $b = \frac{1}{5^{1/6}\sqrt{6}}$. If $x, y \in \mathbb{R}$ are such that

$3x + 2y = \log_a(18)^{5/4}$ and $2x - y = \log_b(\sqrt{1080})$,

then $4x + 5y$ is equal to _______.''';

      expect(LaTeXParser.containsLatex(input), true);
      final segments = LaTeXParser.parse(input);
      expect(segments.where((s) => s.isLatex).length, greaterThan(3));
    });

    test('handles multi-correct option question', () {
      final input = r'''Which of the following statements is(are) TRUE?

(A) $\mathbb{Z} \cup T_1 \cup T_2 \subset S$

(B) $T_1 \cap \left(0, \frac{1}{2024}\right) = \phi$, where $\phi$ denotes the empty set

(C) $T_2 \cap (2024, \infty) \neq \phi$

(D) For any given $a, b \in \mathbb{Z}$, $\cos\left(\pi(a + b\sqrt{2})\right) + i\sin\left(\pi(a + b\sqrt{2})\right) \in \mathbb{Z}$ if and only if $b = 0$, where $i = \sqrt{-1}$''';

      expect(LaTeXParser.containsLatex(input), true);
    });

    test('handles chemistry reaction sequence', () {
      final input = r'''The major product P is formed in the following reaction sequence:

$\ce{H-C#C-(CH2)15-CO-Et ->[\text{(i) Hg}^{2+}, \mathrm{H}_3\mathrm{O}^+][\text{(ii) Zn-Hg/HCl}][\text{(iii) } \mathrm{H}_3\mathrm{O}^+, \Delta]} \mathbf{P}$

Glycerol reacts completely with excess P in the presence of an acid catalyst to form Q.''';

      expect(LaTeXParser.containsLatex(input), true);
    });

    test('handles physics circuit with multiple components', () {
      final input = r'''The circuit contains an inductor $L = 25$ mH, a capacitor $C_0 = 10$ $\mu$F, a resistor $R_0 = 5$ $\Omega$ and an ideal battery of 20 V.

Initially, $I_1 = 0$ A (just after closing $K_1$).
After a long time, $I_2 = \frac{20}{5} = 4$ A.
Angular frequency: $\omega_0 = \frac{1}{\sqrt{LC}} = \frac{1}{\sqrt{25 \times 10^{-3} \times 10 \times 10^{-6}}} = 2$ krad/s.
Voltage amplitude: $V_0 = \frac{Q_0}{C} = 200$ V.''';

      expect(LaTeXParser.containsLatex(input), true);
    });
  });

  // Additional JEE Advanced 2024 Paper-1 Tests - Extended Coverage
  group('JEE Advanced 2024 Paper-1 - Extended Coverage', () {
    // Mathematics - Combinatorics and Binomial Coefficients
    test('handles combinatorics with binomial coefficients Q11', () {
      final input = r'''Let $S_n$ denote the sum of the first $n$ terms of an arithmetic progression. If $S_{10} = 390$ and the ratio of the tenth and the fifth terms is $15:7$, then $S_{15} - S_5$ is equal to:

(A) $800$
(B) $890$
(C) $790$
(D) $690$''';

      expect(LaTeXParser.containsLatex(input), true);
      final segments = LaTeXParser.parse(input);
      expect(segments.any((s) => s.isLatex && s.content.contains('S_n')), true);
    });

    test('handles permutation and combination notation', () {
      final input = r'''The number of ways to arrange $n$ objects in $r$ positions is given by $^nP_r = \frac{n!}{(n-r)!}$ and combinations by $\binom{n}{r} = \frac{n!}{r!(n-r)!}$''';

      expect(LaTeXParser.containsLatex(input), true);
      final segments = LaTeXParser.parse(input);
      expect(segments.any((s) => s.isLatex && s.content.contains('binom')), true);
    });

    // Mathematics - Piecewise Functions
    test('handles piecewise function definition Q17', () {
      final input = r'Let $f: \mathbb{R} \to \mathbb{R}$ be defined by $f(x) = x^2 + 1$ for $x \leq 0$ and $f(x) = 2x - 1$ for $x > 0$. Find $f(f(-1))$.';

      expect(LaTeXParser.containsLatex(input), true);
      final segments = LaTeXParser.parse(input);
      expect(segments.any((s) => s.isLatex && s.content.contains('mathbb')), true);
    });

    test('handles floor and ceiling functions', () {
      final input = r'''If $\lfloor x \rfloor$ denotes the greatest integer function, evaluate $\int_0^2 \lfloor x^2 \rfloor dx$''';

      expect(LaTeXParser.containsLatex(input), true);
      final segments = LaTeXParser.parse(input);
      expect(segments.any((s) => s.isLatex && s.content.contains('lfloor')), true);
    });

    // Mathematics - Matrix Operations
    test('handles matrix determinant calculation', () {
      final input = r'''If $A = \begin{pmatrix} 1 & 2 & 3 \\ 4 & 5 & 6 \\ 7 & 8 & 9 \end{pmatrix}$, then $\det(A) = 0$''';

      expect(LaTeXParser.containsLatex(input), true);
      final segments = LaTeXParser.parse(input);
      expect(segments.any((s) => s.isLatex && s.content.contains('begin{pmatrix}')), true);
    });

    test('handles matrix transpose and inverse', () {
      final input = r'''For an invertible matrix $A$, $(A^T)^{-1} = (A^{-1})^T$ and $|A^{-1}| = \frac{1}{|A|}$''';

      expect(LaTeXParser.containsLatex(input), true);
      final segments = LaTeXParser.parse(input);
      expect(segments.any((s) => s.isLatex && s.content.contains('^T')), true);
    });

    // Mathematics - Complex Integration
    test('handles definite integral with limits', () {
      final input = r'''Evaluate $\int_0^{\pi/2} \frac{\sin^n x}{\sin^n x + \cos^n x} dx = \frac{\pi}{4}$ for any positive integer $n$''';

      expect(LaTeXParser.containsLatex(input), true);
      final segments = LaTeXParser.parse(input);
      expect(segments.any((s) => s.isLatex && s.content.contains('int_0')), true);
    });

    test('handles double integral', () {
      final input = r'''The area can be computed as $\iint_R dA = \int_0^1 \int_0^{\sqrt{1-x^2}} dy\, dx = \frac{\pi}{4}$''';

      expect(LaTeXParser.containsLatex(input), true);
      final segments = LaTeXParser.parse(input);
      expect(segments.any((s) => s.isLatex && s.content.contains('iint')), true);
    });

    // Physics - Dimensional Analysis
    test('handles dimensional formula with MLT notation', () {
      final input = r'''The dimensional formula of pressure is $[P] = [M L^{-1} T^{-2}]$ and that of energy density is also $[M L^{-1} T^{-2}]$''';

      expect(LaTeXParser.containsLatex(input), true);
      final segments = LaTeXParser.parse(input);
      expect(segments.any((s) => s.isLatex && s.content.contains('M L^{-1}')), true);
    });

    test('handles physics constants with units', () {
      final input = r'''The Planck constant $h = 6.626 \times 10^{-34}$ J·s and the speed of light $c = 3 \times 10^8$ m/s give $hc = 1.989 \times 10^{-25}$ J·m''';

      expect(LaTeXParser.containsLatex(input), true);
      final segments = LaTeXParser.parse(input);
      expect(segments.any((s) => s.isLatex && s.content.contains('times 10^')), true);
    });

    // Physics - Wave Motion and Optics
    test('handles wave equation with phase', () {
      final input = r'''A wave is described by $y = A \sin(kx - \omega t + \phi)$ where $k = \frac{2\pi}{\lambda}$ is the wave number and $\omega = 2\pi f$ is the angular frequency''';

      expect(LaTeXParser.containsLatex(input), true);
      final segments = LaTeXParser.parse(input);
      expect(segments.any((s) => s.isLatex && s.content.contains('omega t')), true);
    });

    test('handles optical path difference', () {
      final input = r'''For constructive interference, the path difference must satisfy $\Delta = n\lambda$ where $n \in \mathbb{Z}$. For thin film, $2\mu t \cos r = n\lambda$''';

      expect(LaTeXParser.containsLatex(input), true);
      final segments = LaTeXParser.parse(input);
      expect(segments.any((s) => s.isLatex && s.content.contains('Delta')), true);
    });

    // Physics - Thermodynamics Cycles
    test('handles Carnot efficiency formula', () {
      final input = r'''The efficiency of a Carnot engine is $\eta = 1 - \frac{T_C}{T_H} = \frac{T_H - T_C}{T_H}$ where $T_H$ and $T_C$ are hot and cold reservoir temperatures''';

      expect(LaTeXParser.containsLatex(input), true);
      final segments = LaTeXParser.parse(input);
      expect(segments.any((s) => s.isLatex && s.content.contains('eta')), true);
    });

    test('handles adiabatic process equations', () {
      final input = r'''For an adiabatic process, $PV^\gamma = \text{constant}$ and $TV^{\gamma-1} = \text{constant}$ where $\gamma = \frac{C_p}{C_v}$''';

      expect(LaTeXParser.containsLatex(input), true);
      final segments = LaTeXParser.parse(input);
      expect(segments.any((s) => s.isLatex && s.content.contains('gamma')), true);
    });

    // Chemistry - VSEPR Geometries
    test('handles VSEPR molecular geometry notation Q15', () {
      final input = r'''According to VSEPR theory, $\mathrm{SF}_6$ has octahedral geometry, $\mathrm{XeF}_4$ has square planar geometry with two lone pairs, and $\mathrm{IF}_7$ has pentagonal bipyramidal structure''';

      expect(LaTeXParser.containsLatex(input), true);
      final segments = LaTeXParser.parse(input);
      expect(segments.any((s) => s.isLatex && s.content.contains('mathrm{SF}')), true);
    });

    test('handles hybridization notation', () {
      final input = r'''The hybridization of central atom in $\mathrm{PCl}_5$ is $sp^3d$, in $\mathrm{SF}_6$ is $sp^3d^2$, and in $\mathrm{IF}_7$ is $sp^3d^3$''';

      expect(LaTeXParser.containsLatex(input), true);
      final segments = LaTeXParser.parse(input);
      expect(segments.any((s) => s.isLatex && s.content.contains('sp^3d')), true);
    });

    // Chemistry - Conductometric Titration
    test('handles conductometric titration Q14', () {
      final input = r'''In conductometric titration of $\mathrm{HCl}$ with $\mathrm{NaOH}$, the conductance first decreases (replacement of $\mathrm{H}^+$ by $\mathrm{Na}^+$) and then increases (excess $\mathrm{OH}^-$)''';

      expect(LaTeXParser.containsLatex(input), true);
      final segments = LaTeXParser.parse(input);
      expect(segments.any((s) => s.isLatex && s.content.contains('mathrm{HCl}')), true);
    });

    test('handles molar conductivity formula', () {
      final input = r'''Molar conductivity $\Lambda_m = \frac{\kappa}{c}$ where $\kappa$ is conductivity and $c$ is concentration. At infinite dilution, $\Lambda_m^\infty = \lambda^+_\infty + \lambda^-_\infty$''';

      expect(LaTeXParser.containsLatex(input), true);
      final segments = LaTeXParser.parse(input);
      expect(segments.any((s) => s.isLatex && s.content.contains('Lambda_m')), true);
    });

    // Chemistry - Organic Synthesis
    test('handles aldol condensation mechanism Q10', () {
      final input = r'''In crossed aldol reaction between $\mathrm{HCHO}$ and $\mathrm{CH}_3\mathrm{CHO}$ in presence of dilute $\mathrm{NaOH}$:
$\mathrm{HCHO} + \mathrm{CH}_3\mathrm{CHO} \xrightarrow{\mathrm{NaOH}} \mathrm{HOCH}_2\mathrm{CH}_2\mathrm{CHO}$''';

      expect(LaTeXParser.containsLatex(input), true);
      final segments = LaTeXParser.parse(input);
      expect(segments.any((s) => s.isLatex && s.content.contains('xrightarrow')), true);
    });

    test('handles multi-step organic synthesis Q16', () {
      final input = r'''Benzene $\xrightarrow[\mathrm{AlCl}_3]{\mathrm{CH}_3\mathrm{Cl}}$ Toluene $\xrightarrow[\mathrm{h}\nu]{\mathrm{Cl}_2}$ Benzyl chloride $\xrightarrow{\mathrm{KCN}}$ Benzyl cyanide''';

      expect(LaTeXParser.containsLatex(input), true);
      final segments = LaTeXParser.parse(input);
      expect(segments.any((s) => s.isLatex && s.content.contains('xrightarrow')), true);
    });

    // Chemistry - Equilibrium Constants
    test('handles equilibrium constant expressions', () {
      final input = r'''For the reaction $\mathrm{N}_2 + 3\mathrm{H}_2 \rightleftharpoons 2\mathrm{NH}_3$, the equilibrium constant is $K_p = \frac{p_{\mathrm{NH}_3}^2}{p_{\mathrm{N}_2} \cdot p_{\mathrm{H}_2}^3}$''';

      expect(LaTeXParser.containsLatex(input), true);
      final segments = LaTeXParser.parse(input);
      expect(segments.any((s) => s.isLatex && s.content.contains('rightleftharpoons')), true);
    });

    test('handles pH and pKa relationships', () {
      final input = r'''Henderson-Hasselbalch equation: $\mathrm{pH} = \mathrm{p}K_a + \log\frac{[\mathrm{A}^-]}{[\mathrm{HA}]}$ where $\mathrm{p}K_a = -\log K_a$''';

      expect(LaTeXParser.containsLatex(input), true);
      final segments = LaTeXParser.parse(input);
      expect(segments.any((s) => s.isLatex && s.content.contains('log')), true);
    });

    // Chemistry - Thermodynamics
    test('handles Gibbs free energy equation', () {
      final input = r'''The Gibbs free energy is given by $\Delta G = \Delta H - T\Delta S$ and at equilibrium $\Delta G^\circ = -RT\ln K$''';

      expect(LaTeXParser.containsLatex(input), true);
      final segments = LaTeXParser.parse(input);
      expect(segments.any((s) => s.isLatex && s.content.contains('Delta G')), true);
    });

    test('handles Nernst equation', () {
      final input = r'''Nernst equation: $E = E^\circ - \frac{RT}{nF}\ln Q = E^\circ - \frac{0.059}{n}\log Q$ at 298 K''';

      expect(LaTeXParser.containsLatex(input), true);
      final segments = LaTeXParser.parse(input);
      expect(segments.any((s) => s.isLatex && s.content.contains('frac{RT}')), true);
    });

    // Chemistry - Coordination Compounds
    test('handles crystal field splitting', () {
      final input = r'''In octahedral field, $\Delta_o$ is the crystal field splitting energy. For $[\mathrm{Co}(\mathrm{NH}_3)_6]^{3+}$, the CFSE is $-\frac{12}{5}\Delta_o + 3P$''';

      expect(LaTeXParser.containsLatex(input), true);
      final segments = LaTeXParser.parse(input);
      expect(segments.any((s) => s.isLatex && s.content.contains('Delta_o')), true);
    });

    test('handles magnetic moment formula', () {
      final input = r'''Magnetic moment $\mu = \sqrt{n(n+2)}$ BM where $n$ is the number of unpaired electrons. For $\mathrm{Fe}^{2+}$ (high spin), $n = 4$ and $\mu = \sqrt{24} \approx 4.9$ BM''';

      expect(LaTeXParser.containsLatex(input), true);
      final segments = LaTeXParser.parse(input);
      expect(segments.any((s) => s.isLatex && s.content.contains('sqrt{n(n+2)}')), true);
    });

    // Complex Mathematical Expressions
    test('handles summation with indices', () {
      final input = r'''The sum $\sum_{k=1}^{n} k^2 = \frac{n(n+1)(2n+1)}{6}$ and $\sum_{k=1}^{n} k^3 = \left(\frac{n(n+1)}{2}\right)^2$''';

      expect(LaTeXParser.containsLatex(input), true);
      final segments = LaTeXParser.parse(input);
      expect(segments.any((s) => s.isLatex && s.content.contains('sum_{k=1}')), true);
    });

    test('handles product notation', () {
      final input = r'''Factorial can be written as $n! = \prod_{k=1}^{n} k$ and the gamma function satisfies $\Gamma(n+1) = n!$ for positive integers''';

      expect(LaTeXParser.containsLatex(input), true);
      final segments = LaTeXParser.parse(input);
      expect(segments.any((s) => s.isLatex && s.content.contains('prod_{k=1}')), true);
    });

    test('handles set builder notation', () {
      final input = r'''The set $S = \{x \in \mathbb{R} : x^2 - 5x + 6 = 0\} = \{2, 3\}$ and $|S| = 2$''';

      expect(LaTeXParser.containsLatex(input), true);
      final segments = LaTeXParser.parse(input);
      expect(segments.any((s) => s.isLatex && s.content.contains('mathbb{R}')), true);
    });

    test('handles complex fractions and nested structures', () {
      final input = r'''Continued fraction: $\cfrac{1}{1+\cfrac{1}{1+\cfrac{1}{1+\cdots}}} = \frac{\sqrt{5}-1}{2} = \phi - 1$''';

      expect(LaTeXParser.containsLatex(input), true);
      final segments = LaTeXParser.parse(input);
      expect(segments.any((s) => s.isLatex && s.content.contains('cfrac')), true);
    });

    // Edge Cases and Special Patterns
    test('handles subscript and superscript together', () {
      final input = r'''The coefficient $a_n^{(k)}$ denotes the $n$-th term at iteration $k$, and $x_{i,j}^{2}$ represents squared matrix element''';

      expect(LaTeXParser.containsLatex(input), true);
      final segments = LaTeXParser.parse(input);
      expect(segments.any((s) => s.isLatex && s.content.contains('a_n^{(k)}')), true);
    });

    test('handles chemical isotope notation', () {
      final input = r'''Radioactive decay: ${}^{238}_{92}\mathrm{U} \to {}^{234}_{90}\mathrm{Th} + {}^{4}_{2}\mathrm{He}$ (alpha decay)''';

      expect(LaTeXParser.containsLatex(input), true);
      final segments = LaTeXParser.parse(input);
      expect(segments.any((s) => s.isLatex && s.content.contains('{}^{238}')), true);
    });

    test('handles vector cross and dot products', () {
      final input = r'''For vectors, $\vec{a} \cdot \vec{b} = |\vec{a}||\vec{b}|\cos\theta$ and $|\vec{a} \times \vec{b}| = |\vec{a}||\vec{b}|\sin\theta$''';

      expect(LaTeXParser.containsLatex(input), true);
      final segments = LaTeXParser.parse(input);
      expect(segments.any((s) => s.isLatex && s.content.contains('vec{a}')), true);
    });

    test('handles limit with multiple variables', () {
      final input = r'''The limit $\lim_{(x,y) \to (0,0)} \frac{xy}{x^2 + y^2}$ does not exist as it depends on the path of approach''';

      expect(LaTeXParser.containsLatex(input), true);
      final segments = LaTeXParser.parse(input);
      expect(segments.any((s) => s.isLatex && s.content.contains('lim_{(x,y)')), true);
    });

    test('handles partial derivatives', () {
      final input = r'''For $f(x,y) = x^2y + xy^2$, we have $\frac{\partial f}{\partial x} = 2xy + y^2$ and $\frac{\partial^2 f}{\partial x \partial y} = 2x + 2y$''';

      expect(LaTeXParser.containsLatex(input), true);
      final segments = LaTeXParser.parse(input);
      expect(segments.any((s) => s.isLatex && s.content.contains('partial f')), true);
    });

    test('handles text within math mode', () {
      final input = r'''The probability $P(\text{at least one success}) = 1 - P(\text{no success}) = 1 - (1-p)^n$''';

      expect(LaTeXParser.containsLatex(input), true);
      final segments = LaTeXParser.parse(input);
      expect(segments.any((s) => s.isLatex && s.content.contains('text{at least')), true);
    });

    test('handles complex chemistry reaction with conditions', () {
      final input = r'''Haber process: $\mathrm{N}_2(g) + 3\mathrm{H}_2(g) \xrightleftharpoons[450°\mathrm{C}]{\mathrm{Fe}/\mathrm{Mo}} 2\mathrm{NH}_3(g)$, $\Delta H = -92$ kJ/mol''';

      expect(LaTeXParser.containsLatex(input), true);
      final segments = LaTeXParser.parse(input);
      expect(segments.any((s) => s.isLatex && s.content.contains('xrightleftharpoons')), true);
    });
  });

  // =========================================================================
  // CORRUPTED DATA HANDLING
  // =========================================================================
  group('Corrupted Data Handling', () {
    test('cleans __LATEX_BLOCK_X__ placeholders (2 underscores)', () {
      final input = 'Let k ∈ ℝ. If lim__LATEX_BLOCK_1__frac__LATEX_BLOCK_11__{x³} = 2';

      final segments = LaTeXParser.parse(input);
      final fullText = segments.map((s) => s.content).join('');

      expect(fullText.contains('__LATEX_BLOCK_'), false);
      expect(fullText.contains('[formula]'), true);
    });

    test('cleans ___LATEX_BLOCK_X___ placeholders (3 underscores)', () {
      final input = 'Calculate ___LATEX_BLOCK_0___ where x = 5';

      final segments = LaTeXParser.parse(input);
      final fullText = segments.map((s) => s.content).join('');

      expect(fullText.contains('___LATEX_BLOCK_'), false);
      expect(fullText.contains('[formula]'), true);
    });

    test('handles mixed placeholders and real LaTeX', () {
      final input = r'Find __LATEX_BLOCK_1__ when $x = \sqrt{2}$';

      final segments = LaTeXParser.parse(input);
      final fullText = segments.map((s) => s.content).join('');

      expect(fullText.contains('__LATEX_BLOCK_'), false);
      expect(fullText.contains('[formula]'), true);
      expect(segments.any((s) => s.isLatex && s.content.contains('sqrt')), true);
    });
  });
}
