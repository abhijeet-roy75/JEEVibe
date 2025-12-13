/// Unit tests for ChemistryFormatter
import 'package:flutter_test/flutter_test.dart';
import 'package:jeevibe_mobile/utils/chemistry_formatter.dart';

void main() {
  group('ChemistryFormatter', () {
    test('formatFormula - formats simple formula', () {
      final formula = 'H2O';
      final formatted = ChemistryFormatter.formatFormula(formula);
      expect(formatted, isNotEmpty);
      expect(formatted, contains('₂')); // Should have subscript
    });

    test('formatFormula - handles complex formula', () {
      final formula = 'C6H12O6';
      final formatted = ChemistryFormatter.formatFormula(formula);
      expect(formatted, isNotEmpty);
    });

    test('formatFormula - handles ionic charges', () {
      final formula = 'Ca^2+';
      final formatted = ChemistryFormatter.formatFormula(formula);
      expect(formatted, isNotEmpty);
    });

    test('formatFormula - handles empty string', () {
      final formatted = ChemistryFormatter.formatFormula('');
      expect(formatted, '');
    });

    test('formatFormula - handles formulas with parentheses', () {
      final formula = 'NH4+';
      final formatted = ChemistryFormatter.formatFormula(formula);
      expect(formatted, isNotEmpty);
    });
  });
}

