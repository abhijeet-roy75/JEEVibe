/// JEE Exam Paper LaTeX Test Cases
/// Based on JEE 2nd April Shift 2 exam paper (pages 1-10)
/// This tests real-world LaTeX patterns from actual JEE questions

import 'package:flutter_test/flutter_test.dart';
import 'package:jeevibe_mobile/utils/latex_parser.dart';
import 'package:jeevibe_mobile/utils/latex_normalizer.dart';
import 'package:jeevibe_mobile/utils/latex_to_text.dart';

void main() {
  // ==========================================================================
  // CHEMISTRY QUESTIONS (Q1-Q25)
  // ==========================================================================
  group('JEE Chemistry Questions', () {
    group('Q1: Molar Mass and Units', () {
      test('parses gmol^{-1} unit notation', () {
        final input = r'gmol^{-1}';
        expect(LaTeXParser.containsLatex(input), true);
        final result = LaTeXToText.convert(input);
        expect(result.contains('gmol'), true);
      });

      test('parses element mass notation', () {
        final input = r'H : 1, C : 12, N : 14, O : 16, S : 32';
        // Plain text, should pass through
        final segments = LaTeXParser.parse(input);
        expect(segments.isNotEmpty, true);
      });
    });

    group('Q2: Coordination Compounds', () {
      test('parses [Co(en)_3]^{3+} complex', () {
        final input = r'[Co(en)_3]^{3+}';
        expect(LaTeXParser.containsLatex(input), true);
        final result = LaTeXToText.convert(input);
        expect(result.contains('Co'), true);
        expect(result.contains('en'), true);
      });

      test('parses [CoF_6]^{3-} complex', () {
        final input = r'[CoF_6]^{3-}';
        expect(LaTeXParser.containsLatex(input), true);
        final result = LaTeXToText.convert(input);
        expect(result.contains('Co'), true);
        expect(result.contains('F'), true);
      });

      test('parses [Mn(H_2O)_6]^{2+} aqua complex', () {
        final input = r'[Mn(H_2O)_6]^{2+}';
        expect(LaTeXParser.containsLatex(input), true);
        final result = LaTeXToText.convert(input);
        expect(result.contains('Mn'), true);
        expect(result.contains('H'), true);
        expect(result.contains('O'), true);
      });

      test('parses t_{2g}^6 e_g^0 electron configuration', () {
        final input = r't_{2g}^6 e_g^0';
        expect(LaTeXParser.containsLatex(input), true);
        final result = LaTeXToText.convert(input);
        expect(result.isNotEmpty, true);
      });

      test('parses t_{2g}^3 e_g^2 configuration', () {
        final input = r't_{2g}^3 e_g^2';
        expect(LaTeXParser.containsLatex(input), true);
      });
    });

    group('Q4: Hybridization', () {
      test('parses sp^3 d hybridization', () {
        final input = r'sp^3 d';
        expect(LaTeXParser.containsLatex(input), true);
        final result = LaTeXToText.convert(input);
        expect(result.contains('sp'), true);
      });

      test('parses PF_5 molecular formula', () {
        final input = r'PF_5';
        expect(LaTeXParser.containsLatex(input), true);
        final result = LaTeXToText.convert(input);
        expect(result.contains('PF'), true);
      });

      test('parses XeF_4 and XeF_2', () {
        expect(LaTeXParser.containsLatex(r'XeF_4'), true);
        expect(LaTeXParser.containsLatex(r'XeF_2'), true);
      });

      test('parses SF_4 molecular formula', () {
        final input = r'SF_4';
        expect(LaTeXParser.containsLatex(input), true);
      });
    });

    group('Q5: Complex Compound', () {
      test('parses Na_4[Fe(CN)_5 NOS] nitroprusside', () {
        final input = r'Na_4[Fe(CN)_5 NOS]';
        expect(LaTeXParser.containsLatex(input), true);
        final result = LaTeXToText.convert(input);
        expect(result.contains('Na'), true);
        expect(result.contains('Fe'), true);
        expect(result.contains('CN'), true);
      });
    });

    group('Q6: Hybridization Types', () {
      test('parses sp^3, sp^2, sp hybridization', () {
        expect(LaTeXParser.containsLatex(r'sp^3'), true);
        expect(LaTeXParser.containsLatex(r'sp^2'), true);
        expect(LaTeXParser.containsLatex(r'sp'), false); // No special chars
      });
    });

    group('Q7: Orbital Notation', () {
      test('parses 2p_x orbital', () {
        final input = r'2p_x';
        expect(LaTeXParser.containsLatex(input), true);
        final result = LaTeXToText.convert(input);
        expect(result.contains('2p'), true);
      });
    });

    group('Q8: MnCl Complex', () {
      test('parses [MnCl_6]^{3-} complex', () {
        final input = r'[MnCl_6]^{3-}';
        expect(LaTeXParser.containsLatex(input), true);
        final result = LaTeXToText.convert(input);
        expect(result.contains('Mn'), true);
        expect(result.contains('Cl'), true);
      });

      test('parses d^2 sp^3 hybridization', () {
        final input = r'd^2 sp^3';
        expect(LaTeXParser.containsLatex(input), true);
      });

      test('parses sp^3 d^2 hybridization', () {
        final input = r'sp^3 d^2';
        expect(LaTeXParser.containsLatex(input), true);
      });
    });

    group('Q9: Organic Reactions', () {
      test('parses R-C triple bond N notation', () {
        final input = r'R - C \equiv N';
        expect(LaTeXParser.containsLatex(input), true);
      });

      test('parses reaction arrow with conditions', () {
        final input = r'\xrightarrow{(i)H^+/H_2O}';
        expect(LaTeXParser.containsLatex(input), true);
      });

      test('parses Grignard notation R-MgX', () {
        final input = r'R - MgX';
        final segments = LaTeXParser.parse(input);
        expect(segments.isNotEmpty, true);
      });
    });

    group('Q10: Electronic Configuration', () {
      test('parses 1s^2 2s^2 2p^3', () {
        final input = r'1s^2 2s^2 2p^3';
        expect(LaTeXParser.containsLatex(input), true);
        final result = LaTeXToText.convert(input);
        expect(result.contains('1s'), true);
        expect(result.contains('2s'), true);
        expect(result.contains('2p'), true);
      });

      test('parses 1s^2 2s^2 2p^4', () {
        final input = r'1s^2 2s^2 2p^4';
        expect(LaTeXParser.containsLatex(input), true);
      });

      test('parses 1s^2 2s^2 2p^5', () {
        final input = r'1s^2 2s^2 2p^5';
        expect(LaTeXParser.containsLatex(input), true);
      });
    });

    group('Q12: NaCl Temperature', () {
      test('parses NaCl notation', () {
        final input = r'NaCl';
        // No special LaTeX
        final segments = LaTeXParser.parse(input);
        expect(segments.isNotEmpty, true);
      });

      test('parses temperature 1°C to 25°C', () {
        final input = r'1°C to 25°C';
        final segments = LaTeXParser.parse(input);
        expect(segments.isNotEmpty, true);
      });
    });

    group('Q13: Work Done', () {
      test('parses |w_{reversible}| notation', () {
        final input = r'|w_{reversible}|';
        expect(LaTeXParser.containsLatex(input), true);
      });

      test('parses |W_{irreversible}| notation', () {
        final input = r'|W_{irreversible}|';
        expect(LaTeXParser.containsLatex(input), true);
      });
    });

    group('Q14: Reaction Mechanism', () {
      test('parses A -> B reaction arrow', () {
        final input = r'A \to B';
        expect(LaTeXParser.containsLatex(input), true);
        final result = LaTeXToText.convert(input);
        expect(result.contains('→'), true);
      });

      test('parses delta H notation', () {
        final input = r'\Delta H = + ve';
        expect(LaTeXParser.containsLatex(input), true);
        final result = LaTeXToText.convert(input);
        expect(result.contains('Δ') || result.contains('Delta'), true);
      });
    });

    group('Q15: Tellurium Compounds', () {
      test('parses TeO_2 oxide', () {
        final input = r'TeO_2';
        expect(LaTeXParser.containsLatex(input), true);
        final result = LaTeXToText.convert(input);
        expect(result.contains('Te'), true);
        expect(result.contains('O'), true);
      });

      test('parses TeH_2 hydride', () {
        final input = r'TeH_2';
        expect(LaTeXParser.containsLatex(input), true);
      });
    });

    group('Q17: Equilibrium', () {
      test('parses A(g) equilibrium B(g) + C(g)', () {
        final input = r'A(g) \rightleftharpoons B(g) + C(g)';
        expect(LaTeXParser.containsLatex(input), true);
      });

      test('parses K_p equilibrium constant', () {
        final input = r'K_p';
        expect(LaTeXParser.containsLatex(input), true);
      });

      test('parses alpha dissociation', () {
        final input = r'\alpha';
        expect(LaTeXParser.containsLatex(input), true);
        final result = LaTeXToText.convert(input);
        expect(result.contains('α'), true);
      });
    });

    group('Q18: Thermodynamic Properties', () {
      test('parses -Delta H_R^0 / T notation', () {
        final input = r'-\Delta H_R^0 / T';
        expect(LaTeXParser.containsLatex(input), true);
      });

      test('parses Delta G_R^0 / T notation', () {
        final input = r'\Delta G_R^0 / T';
        expect(LaTeXParser.containsLatex(input), true);
      });

      test('parses Delta S_R^0 notation', () {
        final input = r'\Delta S_R^0';
        expect(LaTeXParser.containsLatex(input), true);
      });
    });

    group('Q20: Dumas Method', () {
      test('parses 300 K temperature', () {
        final input = r'300 K';
        final segments = LaTeXParser.parse(input);
        expect(segments.isNotEmpty, true);
      });

      test('parses mmHg pressure unit', () {
        final input = r'715 mm Hg';
        final segments = LaTeXParser.parse(input);
        expect(segments.isNotEmpty, true);
      });
    });

    group('Q21: Reaction Kinetics', () {
      test('parses A -> B reaction', () {
        final input = r'A \to B';
        expect(LaTeXParser.containsLatex(input), true);
      });

      test('parses concentration g L^{-1}', () {
        final input = r'2.5 g L^{-1}';
        expect(LaTeXParser.containsLatex(input), true);
      });

      test('parses log 2 = 0.3010', () {
        final input = r'\log 2 = 0.3010';
        expect(LaTeXParser.containsLatex(input), true);
      });
    });

    group('Q22: Molar Conductivity', () {
      test('parses 0.2%(w/v) NaOH', () {
        final input = r'0.2\%(w/v) NaOH';
        expect(LaTeXParser.containsLatex(input), true);
      });

      test('parses resistivity mOmega m', () {
        final input = r'870.0 m\Omega m';
        expect(LaTeXParser.containsLatex(input), true);
      });

      test('parses mS dm^2 mol^{-1} unit', () {
        final input = r'\times 10^2 mS dm^2 mol^{-1}';
        expect(LaTeXParser.containsLatex(input), true);
      });
    });

    group('Q23: Organic Synthesis', () {
      test('parses KOH alcoholic reaction', () {
        final input = r'Br \xrightarrow{alcoholic KOH} P';
        expect(LaTeXParser.containsLatex(input), true);
      });

      test('parses yield percentage 80%', () {
        final input = r'80\%';
        expect(LaTeXParser.containsLatex(input), true);
      });
    });

    group('Q24: Colligative Properties', () {
      test('parses AB and AB_2 compounds', () {
        expect(LaTeXParser.containsLatex(r'AB_2'), true);
      });

      test('parses molal elevation constant', () {
        final input = r'0.5 K kg mol^{-1}';
        expect(LaTeXParser.containsLatex(input), true);
      });
    });

    group('Q25: Transition Metal Complexes', () {
      test('parses M^{n+} ion', () {
        final input = r'M^{n+}';
        expect(LaTeXParser.containsLatex(input), true);
      });

      test('parses K_2[NiCl_4] complex', () {
        final input = r'K_2[NiCl_4]';
        expect(LaTeXParser.containsLatex(input), true);
        final result = LaTeXToText.convert(input);
        expect(result.contains('K'), true);
        expect(result.contains('Ni'), true);
        expect(result.contains('Cl'), true);
      });

      test('parses [Zn(H_2O)_6]Cl_2 complex', () {
        final input = r'[Zn(H_2O)_6]Cl_2';
        expect(LaTeXParser.containsLatex(input), true);
      });

      test('parses K_3[Mn(CN)_6] complex', () {
        final input = r'K_3[Mn(CN)_6]';
        expect(LaTeXParser.containsLatex(input), true);
      });

      test('parses [Cu(PPh_3)_3I] complex', () {
        final input = r'[Cu(PPh_3)_3I]';
        expect(LaTeXParser.containsLatex(input), true);
      });
    });
  });

  // ==========================================================================
  // PHYSICS QUESTIONS (Q26-Q50)
  // ==========================================================================
  group('JEE Physics Questions', () {
    group('Q27: Galvanometer', () {
      test('parses R_1 = 5 Omega', () {
        final input = r'R_1 = 5\Omega';
        expect(LaTeXParser.containsLatex(input), true);
        final result = LaTeXToText.convert(input);
        expect(result.contains('Ω') || result.contains('Omega'), true);
      });

      test('parses A_1 = 3.6 times 10^{-3} m^2', () {
        final input = r'A_1 = 3.6 \times 10^{-3} m^2';
        expect(LaTeXParser.containsLatex(input), true);
        final result = LaTeXToText.convert(input);
        expect(result.contains('×'), true);
      });

      test('parses B_1 = 0.25 T magnetic field', () {
        final input = r'B_1 = 0.25 T';
        expect(LaTeXParser.containsLatex(input), true);
      });
    });

    group('Q28: Moment of Inertia', () {
      test('parses (1/2)Mr^2', () {
        final input = r'\frac{1}{2}Mr^2';
        expect(LaTeXParser.containsLatex(input), true);
        final result = LaTeXToText.convert(input);
        expect(result.contains('/'), true);
      });

      test('parses (3/8)Mr^2', () {
        final input = r'\frac{3}{8}Mr^2';
        expect(LaTeXParser.containsLatex(input), true);
      });

      test('parses 2Mr^2', () {
        final input = r'2Mr^2';
        expect(LaTeXParser.containsLatex(input), true);
      });
    });

    group('Q29: Surface Energy', () {
      test('parses 4 pi r^2 T surface energy formula', () {
        final input = r'4\pi r^2 T[2 - 2^{\frac{2}{3}}]';
        expect(LaTeXParser.containsLatex(input), true);
        final result = LaTeXToText.convert(input);
        expect(result.contains('π'), true);
      });

      test('parses square root notation', () {
        final input = r'4\pi r^2 T[1 + \sqrt{2}]';
        expect(LaTeXParser.containsLatex(input), true);
      });
    });

    group('Q30: de Broglie Wavelength', () {
      test('parses vector v notation', () {
        final input = r'\vec{v} = v_0 \hat{i}';
        expect(LaTeXParser.containsLatex(input), true);
      });

      test('parses magnetic field B vector', () {
        final input = r'\vec{B} = B_0 \hat{j}';
        expect(LaTeXParser.containsLatex(input), true);
      });

      test('parses lambda_0 wavelength', () {
        final input = r'\lambda_0';
        expect(LaTeXParser.containsLatex(input), true);
        final result = LaTeXToText.convert(input);
        expect(result.contains('λ'), true);
      });

      test('parses complex fraction with square root', () {
        final input = r'\frac{\lambda_0}{\sqrt{1 - \frac{e^2 B_0^2 t^2}{m^2}}}';
        expect(LaTeXParser.containsLatex(input), true);
      });
    });

    group('Q31: Wave Equation', () {
      test('parses y = 2 cos(0.83x - 3.35t) cm', () {
        final input = r'y = 2 \cos(0.83x - 3.35t) cm';
        expect(LaTeXParser.containsLatex(input), true);
      });

      test('parses y = 2 sin(0.83x - 3.5t) cm', () {
        final input = r'y = 2 \sin(0.83x - 3.5t) cm';
        expect(LaTeXParser.containsLatex(input), true);
      });
    });

    group('Q32: Dimensional Analysis', () {
      test('parses mu_0 permeability', () {
        final input = r'\mu_0';
        expect(LaTeXParser.containsLatex(input), true);
        final result = LaTeXToText.convert(input);
        expect(result.contains('μ'), true);
      });

      test('parses qI/mu_0 expression', () {
        final input = r'qI/\mu_0';
        expect(LaTeXParser.containsLatex(input), true);
      });

      test('parses q mu_0 I expression', () {
        final input = r'q\mu_0 I';
        expect(LaTeXParser.containsLatex(input), true);
      });
    });

    group('Q33: Solenoid Energy', () {
      test('parses B^2 Al / mu_0 formula', () {
        final input = r'\frac{B^2 Al}{\mu_0}';
        expect(LaTeXParser.containsLatex(input), true);
      });

      test('parses B^2 Al / (2 mu_0) formula', () {
        final input = r'\frac{B^2 Al}{2\mu_0}';
        expect(LaTeXParser.containsLatex(input), true);
      });

      test('parses B^2 Al / (4 mu_0) formula', () {
        final input = r'\frac{B^2 Al}{4\mu_0}';
        expect(LaTeXParser.containsLatex(input), true);
      });
    });

    group('Q34: Potential Difference', () {
      test('parses (1/4)V voltage', () {
        final input = r'\frac{1}{4}V';
        expect(LaTeXParser.containsLatex(input), true);
      });

      test('parses (2/5)V voltage', () {
        final input = r'\frac{2}{5}V';
        expect(LaTeXParser.containsLatex(input), true);
      });

      test('parses (3/4)V voltage', () {
        final input = r'\frac{3}{4}V';
        expect(LaTeXParser.containsLatex(input), true);
      });
    });

    group('Q35: Adiabatic Process', () {
      test('parses T_1 to T_2 temperature change', () {
        final input = r'T_1 \text{ to } T_2';
        expect(LaTeXParser.containsLatex(input), true);
      });

      test('parses (T_2 - T_1) difference', () {
        final input = r'(T_2 - T_1)';
        expect(LaTeXParser.containsLatex(input), true);
      });
    });

    group('Q36: Bohr Model', () {
      test('parses Li^{++} ion', () {
        final input = r'Li^{++}';
        expect(LaTeXParser.containsLatex(input), true);
      });

      test('parses (1/X)a_0 Bohr radius', () {
        final input = r'\frac{1}{X}a_0';
        expect(LaTeXParser.containsLatex(input), true);
      });
    });

    group('Q37: Nuclear Physics', () {
      test('parses deuteron notation _1H^2', () {
        final input = r'_1H^2';
        expect(LaTeXParser.containsLatex(input), true);
      });

      test('parses helium notation _2He^4', () {
        final input = r'_2He^4';
        expect(LaTeXParser.containsLatex(input), true);
      });

      test('parses binding energy 1.1 MeV', () {
        final input = r'1.1 MeV';
        final segments = LaTeXParser.parse(input);
        expect(segments.isNotEmpty, true);
      });

      test('parses energy 23.6 MeV', () {
        final input = r'23.6 MeV';
        final segments = LaTeXParser.parse(input);
        expect(segments.isNotEmpty, true);
      });
    });

    group('Q40: Circular Motion', () {
      test('parses 2r, 3 pi r distance', () {
        final input = r'2r, 3\pi r';
        expect(LaTeXParser.containsLatex(input), true);
        final result = LaTeXToText.convert(input);
        expect(result.contains('π'), true);
      });

      test('parses pi r, 3r notation', () {
        final input = r'\pi r, 3r';
        expect(LaTeXParser.containsLatex(input), true);
      });
    });

    group('Q41: Tension Forces', () {
      test('parses 5 sqrt(3) tension', () {
        final input = r'5\sqrt{3}';
        expect(LaTeXParser.containsLatex(input), true);
        final result = LaTeXToText.convert(input);
        expect(result.contains('√') || result.contains('sqrt'), true);
      });
    });

    group('Q42: Lens Curvature', () {
      test('parses (1/6) cm radius', () {
        final input = r'\frac{1}{6} cm';
        expect(LaTeXParser.containsLatex(input), true);
      });

      test('parses (1/3) cm radius', () {
        final input = r'\frac{1}{3} cm';
        expect(LaTeXParser.containsLatex(input), true);
      });

      test('parses R_1 neq R_2 condition', () {
        final input = r'R_1 \neq R_2';
        expect(LaTeXParser.containsLatex(input), true);
        final result = LaTeXToText.convert(input);
        expect(result.contains('≠'), true);
      });
    });

    group('Q43: Electromagnetic Constants', () {
      test('parses 1/(mu_0 epsilon_0) expression', () {
        final input = r'\frac{1}{\mu_0 \epsilon_0}';
        expect(LaTeXParser.containsLatex(input), true);
      });

      test('parses L/T^2 dimensions', () {
        final input = r'L/T^2';
        expect(LaTeXParser.containsLatex(input), true);
      });

      test('parses L^2/T^{-2} dimensions', () {
        final input = r'L^2/T^{-2}';
        expect(LaTeXParser.containsLatex(input), true);
      });
    });

    group('Q44: Thermal Properties Units', () {
      test('parses J kg^{-1} heat capacity unit', () {
        final input = r'J kg^{-1}';
        expect(LaTeXParser.containsLatex(input), true);
      });

      test('parses J kg^{-1} K^{-1} specific heat unit', () {
        final input = r'J kg^{-1} K^{-1}';
        expect(LaTeXParser.containsLatex(input), true);
      });

      test('parses Jm^{-1}K^{-1}s^{-1} thermal conductivity', () {
        final input = r'Jm^{-1}K^{-1}s^{-1}';
        expect(LaTeXParser.containsLatex(input), true);
      });
    });

    group('Q45: Electric Field', () {
      test('parses a sqrt(2) radius', () {
        final input = r'a\sqrt{2}';
        expect(LaTeXParser.containsLatex(input), true);
      });

      test('parses a/sqrt(2) position', () {
        final input = r'\frac{a}{\sqrt{2}}';
        expect(LaTeXParser.containsLatex(input), true);
      });

      test('parses a/2 position', () {
        final input = r'\frac{a}{2}';
        expect(LaTeXParser.containsLatex(input), true);
      });
    });

    group('Q46: Moment of Inertia', () {
      test('parses 2 rad/s^2 angular acceleration', () {
        final input = r'2 rad/s^2';
        expect(LaTeXParser.containsLatex(input), true);
      });

      test('parses kgm^2 unit', () {
        final input = r'kgm^2';
        expect(LaTeXParser.containsLatex(input), true);
      });
    });

    group('Q47: Internal Energy', () {
      test('parses 4m x 4m x 3m dimensions', () {
        final input = r'4 m \times 4 m \times 3 m';
        expect(LaTeXParser.containsLatex(input), true);
        final result = LaTeXToText.convert(input);
        expect(result.contains('×'), true);
      });

      test('parses 10^6 J energy', () {
        final input = r'\times 10^6 J';
        expect(LaTeXParser.containsLatex(input), true);
      });
    });

    group('Q48: Prism Optics', () {
      test('parses 60 degree angle', () {
        final input = r'60°';
        final segments = LaTeXParser.parse(input);
        expect(segments.isNotEmpty, true);
      });

      test('parses sqrt(2) refractive index', () {
        final input = r'\sqrt{2}';
        expect(LaTeXParser.containsLatex(input), true);
      });
    });

    group('Q50: Satellite Mechanics', () {
      test('parses 6 x 10^{24} kg Earth mass', () {
        final input = r'6 \times 10^{24} kg';
        expect(LaTeXParser.containsLatex(input), true);
      });

      test('parses 6.4 x 10^6 m Earth radius', () {
        final input = r'6.4 \times 10^6 m';
        expect(LaTeXParser.containsLatex(input), true);
      });

      test('parses gravitational constant', () {
        final input = r'6.67 \times 10^{-11} Nm^2 kg^{-2}';
        expect(LaTeXParser.containsLatex(input), true);
      });
    });
  });

  // ==========================================================================
  // MATHEMATICS QUESTIONS (Q51-Q75)
  // ==========================================================================
  group('JEE Mathematics Questions', () {
    group('Q51: Coordinate Geometry', () {
      test('parses P(1, 0, 3) point notation', () {
        final input = r'P(1, 0, 3)';
        final segments = LaTeXParser.parse(input);
        expect(segments.isNotEmpty, true);
      });

      test('parses A(4, 7, 1) point', () {
        final input = r'A(4, 7, 1)';
        final segments = LaTeXParser.parse(input);
        expect(segments.isNotEmpty, true);
      });

      test('parses Q(alpha, beta, gamma) point', () {
        final input = r'Q(\alpha, \beta, \gamma)';
        expect(LaTeXParser.containsLatex(input), true);
        final result = LaTeXToText.convert(input);
        expect(result.contains('α'), true);
        expect(result.contains('β'), true);
        expect(result.contains('γ'), true);
      });

      test('parses alpha + beta + gamma sum', () {
        final input = r'\alpha + \beta + \gamma';
        expect(LaTeXParser.containsLatex(input), true);
      });
    });

    group('Q52: Integral Functions', () {
      test('parses f : [1, infty) -> [2, infty) domain', () {
        final input = r'f : [1, \infty) \to [2, \infty)';
        expect(LaTeXParser.containsLatex(input), true);
        final result = LaTeXToText.convert(input);
        expect(result.contains('∞'), true);
        expect(result.contains('→'), true);
      });

      test('parses integral int_1^x f(t) dt', () {
        final input = r'\int_1^x f(t) dt';
        expect(LaTeXParser.containsLatex(input), true);
        final result = LaTeXToText.convert(input);
        expect(result.contains('∫'), true);
      });

      test('parses x^5 power', () {
        final input = r'x^5';
        expect(LaTeXParser.containsLatex(input), true);
      });

      test('parses x >= 1 inequality', () {
        final input = r'x \geq 1';
        expect(LaTeXParser.containsLatex(input), true);
        final result = LaTeXToText.convert(input);
        expect(result.contains('≥'), true);
      });
    });

    group('Q53: Arithmetic Progression', () {
      test('parses (21/2) fraction', () {
        final input = r'\frac{21}{2}';
        expect(LaTeXParser.containsLatex(input), true);
      });
    });

    group('Q54: Set Theory', () {
      test('parses A = {1, 2, 3, ..., 100} set', () {
        final input = r'A = \{1, 2, 3, \ldots, 100\}';
        expect(LaTeXParser.containsLatex(input), true);
      });

      test('parses R = {(a,b) : a = 2b + 1} relation', () {
        final input = r'R = \{(a, b) : a = 2b + 1\}';
        expect(LaTeXParser.containsLatex(input), true);
      });

      test('parses (a_1, a_2), (a_2, a_3) sequence', () {
        final input = r'(a_1, a_2), (a_2, a_3), \ldots, (a_k, a_{k+1})';
        expect(LaTeXParser.containsLatex(input), true);
      });
    });

    group('Q55: Ellipse Eccentricity', () {
      test('parses 4/sqrt(17) eccentricity', () {
        final input = r'\frac{4}{\sqrt{17}}';
        expect(LaTeXParser.containsLatex(input), true);
      });

      test('parses sqrt(3)/16 eccentricity', () {
        final input = r'\frac{\sqrt{3}}{16}';
        expect(LaTeXParser.containsLatex(input), true);
      });
    });

    group('Q56: 3D Vectors', () {
      test('parses vec{a} = -3i + 2j + 4k', () {
        final input = r'\vec{a} = -3\hat{i} + 2\hat{j} + 4\hat{k}';
        expect(LaTeXParser.containsLatex(input), true);
      });

      test('parses 23/sqrt(38) distance', () {
        final input = r'\frac{23}{\sqrt{38}}';
        expect(LaTeXParser.containsLatex(input), true);
      });

      test('parses 21/sqrt(57) distance', () {
        final input = r'\frac{21}{\sqrt{57}}';
        expect(LaTeXParser.containsLatex(input), true);
      });
    });

    group('Q57: Curve Intersection', () {
      test('parses x^2 = 2y parabola', () {
        final input = r'x^2 = 2y';
        expect(LaTeXParser.containsLatex(input), true);
      });

      test('parses integral int_a^b (9x^2)/(1+5^x) dx', () {
        final input = r'\int_a^b \frac{9x^2}{1+5^x} dx';
        expect(LaTeXParser.containsLatex(input), true);
      });
    });

    group('Q58: System of Equations', () {
      test('parses lambda^2 + mu^2 expression', () {
        final input = r'\lambda^2 + \mu^2';
        expect(LaTeXParser.containsLatex(input), true);
        final result = LaTeXToText.convert(input);
        expect(result.contains('λ'), true);
        expect(result.contains('μ'), true);
      });
    });

    group('Q59: Trigonometric Equations', () {
      test('parses theta in [-7pi/6, 4pi/3] domain', () {
        final input = r'\theta \in [-\frac{7\pi}{6}, \frac{4\pi}{3}]';
        expect(LaTeXParser.containsLatex(input), true);
      });

      test('parses sqrt(3) cosec^2 theta equation', () {
        final input = r'\sqrt{3} \csc^2 \theta - 2(\sqrt{3} - 1) \csc \theta - 4 = 0';
        expect(LaTeXParser.containsLatex(input), true);
      });
    });

    group('Q61: Statistics', () {
      test('parses a + b + ab expression', () {
        final input = r'a + b + ab';
        final segments = LaTeXParser.parse(input);
        expect(segments.isNotEmpty, true);
      });
    });

    group('Q62: Domain Function', () {
      test('parses 1/sqrt(10+3x-x^2) expression', () {
        final input = r'\frac{1}{\sqrt{10+3x-x^2}}';
        expect(LaTeXParser.containsLatex(input), true);
      });

      test('parses 1/sqrt(x+|x|) expression', () {
        final input = r'\frac{1}{\sqrt{x+|x|}}';
        expect(LaTeXParser.containsLatex(input), true);
      });

      test('parses (1+a)^2 + b^2 expression', () {
        final input = r'(1+a)^2 + b^2';
        expect(LaTeXParser.containsLatex(input), true);
      });
    });

    group('Q63: Integration', () {
      test('parses 4 int_0^1 expression', () {
        final input = r'4 \int_0^1 \left(\frac{1}{\sqrt{3+x^2}+\sqrt{1+x^2}}\right) dx';
        expect(LaTeXParser.containsLatex(input), true);
      });

      test('parses 3 log_e(sqrt(3)) expression', () {
        final input = r'3 \log_e(\sqrt{3})';
        expect(LaTeXParser.containsLatex(input), true);
      });

      test('parses 2 + sqrt(2) + log_e(1 + sqrt(2))', () {
        final input = r'2 + \sqrt{2} + \log_e(1 + \sqrt{2})';
        expect(LaTeXParser.containsLatex(input), true);
      });
    });

    group('Q64: Limits', () {
      test('parses lim_{x->0} limit notation', () {
        final input = r'\lim_{x \to 0} \frac{\cos(2x) + a\cos(4x) - b}{x^4}';
        expect(LaTeXParser.containsLatex(input), true);
      });
    });

    group('Q65: Summation', () {
      test('parses sum_{r=0}^{10} summation', () {
        final input = r'\sum_{r=0}^{10} \left(\frac{10^{r+1}-1}{10^r}\right) \cdot {^{11}C_{r+1}}';
        expect(LaTeXParser.containsLatex(input), true);
        final result = LaTeXToText.convert(input);
        expect(result.contains('Σ'), true);
      });

      test('parses (alpha^{11} - 11^{11})/10^{10} expression', () {
        final input = r'\frac{\alpha^{11} - 11^{11}}{10^{10}}';
        expect(LaTeXParser.containsLatex(input), true);
      });
    });

    group('Q67: Parabola', () {
      test('parses y^2 = 16x parabola', () {
        final input = r'y^2 = 16x';
        expect(LaTeXParser.containsLatex(input), true);
      });

      test('parses gcd(m, n) = 1 condition', () {
        final input = r'\gcd(m, n) = 1';
        expect(LaTeXParser.containsLatex(input), true);
      });

      test('parses m^2 + n^2 expression', () {
        final input = r'm^2 + n^2';
        expect(LaTeXParser.containsLatex(input), true);
      });
    });

    group('Q68: Vector Operations', () {
      test('parses vec{a} - vec{c} cross vec{b} expression', () {
        final input = r'(\vec{a} - \vec{c}) \times \vec{b} = -18\hat{i} - 3\hat{j} + 12\hat{k}';
        expect(LaTeXParser.containsLatex(input), true);
      });

      test('parses vec{a} dot vec{c} = 3 dot product', () {
        final input = r'\vec{a} \cdot \vec{c} = 3';
        expect(LaTeXParser.containsLatex(input), true);
      });

      test('parses |vec{a} dot vec{d}| absolute value', () {
        final input = r'|\vec{a} \cdot \vec{d}|';
        expect(LaTeXParser.containsLatex(input), true);
      });
    });

    group('Q69: Line Equation', () {
      test('parses L: x + by + c = 0 line', () {
        final input = r'L : x + by + c = 0';
        final segments = LaTeXParser.parse(input);
        expect(segments.isNotEmpty, true);
      });

      test('parses 45 degree angle', () {
        final input = r'45°';
        final segments = LaTeXParser.parse(input);
        expect(segments.isNotEmpty, true);
      });

      test('parses b^2 + c^2 expression', () {
        final input = r'b^2 + c^2';
        expect(LaTeXParser.containsLatex(input), true);
      });
    });

    group('Q70: Matrix Equations', () {
      test('parses A^2(A - 2I) - 4(A - I) = O matrix equation', () {
        final input = r'A^2(A - 2I) - 4(A - I) = O';
        expect(LaTeXParser.containsLatex(input), true);
      });

      test('parses A^5 = alpha A^2 + beta A + gamma I', () {
        final input = r'A^5 = \alpha A^2 + \beta A + \gamma I';
        expect(LaTeXParser.containsLatex(input), true);
      });

      test('parses alpha + beta + gamma sum', () {
        final input = r'\alpha + \beta + \gamma';
        expect(LaTeXParser.containsLatex(input), true);
      });
    });

    group('Q71: Differential Equations', () {
      test('parses dy/dx differential', () {
        final input = r'\frac{dy}{dx}';
        expect(LaTeXParser.containsLatex(input), true);
      });

      test('parses sec^2 x trigonometric', () {
        final input = r'\sec^2 x';
        expect(LaTeXParser.containsLatex(input), true);
      });

      test('parses tan x * sec^2 x expression', () {
        final input = r'\tan x \cdot \sec^2 x';
        expect(LaTeXParser.containsLatex(input), true);
      });

      test('parses y(pi/4) - e^{-2} expression', () {
        final input = r'y\left(\frac{\pi}{4}\right) - e^{-2}';
        expect(LaTeXParser.containsLatex(input), true);
      });
    });

    group('Q72: Series', () {
      test('parses (4.1)/(1+4.1^4) series term', () {
        final input = r'\frac{4.1}{1+4.1^4}';
        expect(LaTeXParser.containsLatex(input), true);
      });

      test('parses m/n fraction with gcd', () {
        final input = r'\frac{m}{n}';
        expect(LaTeXParser.containsLatex(input), true);
      });
    });

    group('Q73: Inverse Trigonometry', () {
      test('parses cos(pi/3 + cos^{-1}(x/2))', () {
        final input = r'\cos\left(\frac{\pi}{3} + \cos^{-1}\frac{x}{2}\right)';
        expect(LaTeXParser.containsLatex(input), true);
      });

      test('parses (x-y)^2 + 3y^2 expression', () {
        final input = r'(x-y)^2 + 3y^2';
        expect(LaTeXParser.containsLatex(input), true);
      });
    });

    group('Q74: Triangle Area', () {
      test('parses A(4, -2), B(1, 1), C(9, -3) vertices', () {
        final input = r'A(4, -2), B(1, 1), C(9, -3)';
        final segments = LaTeXParser.parse(input);
        expect(segments.isNotEmpty, true);
      });
    });

    group('Q75: Quadratic Equations', () {
      test('parses (1-a)x^2 + 2(a-3)x + 9 = 0', () {
        final input = r'(1-a)x^2 + 2(a-3)x + 9 = 0';
        expect(LaTeXParser.containsLatex(input), true);
      });

      test('parses (-infty, -alpha] U [beta, gamma) set notation', () {
        final input = r'(-\infty, -\alpha] \cup [\beta, \gamma)';
        expect(LaTeXParser.containsLatex(input), true);
        final result = LaTeXToText.convert(input);
        expect(result.contains('∞'), true);
        expect(result.contains('∪'), true);
      });

      test('parses 2 alpha + beta + gamma expression', () {
        final input = r'2\alpha + \beta + \gamma';
        expect(LaTeXParser.containsLatex(input), true);
      });
    });
  });

  // ==========================================================================
  // FULL QUESTION INTEGRATION TESTS
  // ==========================================================================
  group('Full Question Integration', () {
    test('Q2 Full: Complex with CFSE configuration', () {
      final question = r'The d-orbital electronic configuration of the complex among $[Co(en)_3]^{3+}$, $[CoF_6]^{3-}$, $[Mn(H_2O)_6]^{2+}$ and $[Zn(H_2O)_6]^{2+}$ that has the highest CFSE is: (A) $t_{2g}^6 e_g^0$ (B) $t_{2g}^6 e_g^4$';

      expect(LaTeXParser.containsLatex(question), true);
      final segments = LaTeXParser.parse(question);
      expect(segments.isNotEmpty, true);

      // Should have multiple LaTeX segments
      final latexSegments = segments.where((s) => s.isLatex);
      expect(latexSegments.length, greaterThan(0));
    });

    test('Q30 Full: de Broglie wavelength with vectors', () {
      final question = r'An electron with mass m with an initial velocity $(t = 0)$ $\vec{v} = v_0 \hat{i}$ $(v_0 > 0)$ enters a magnetic field $\vec{B} = B_0 \hat{j}$. If the initial de-Broglie wavelength at $t = 0$ is $\lambda_0$ then its value after time t would be:';

      expect(LaTeXParser.containsLatex(question), true);
      final segments = LaTeXParser.parse(question);
      expect(segments.isNotEmpty, true);
    });

    test('Q52 Full: Integral function with domain', () {
      final question = r'Let $f : [1, \infty) \to [2, \infty)$ be a differentiable function. If $10 \int_1^x f(t) dt = 5xf(x) - x^5 - 9$ for all $x \geq 1$, then the value of $f(3)$ is:';

      expect(LaTeXParser.containsLatex(question), true);
      final segments = LaTeXParser.parse(question);
      expect(segments.isNotEmpty, true);
    });

    test('Q68 Full: Vector cross product equation', () {
      final question = r'Let $\vec{a} = 2\hat{i} - 3\hat{j} + \hat{k}$, $\vec{b} = 3\hat{i} + 2\hat{j} + 5\hat{k}$ and a vector $\vec{c}$ be such that $(\vec{a} - \vec{c}) \times \vec{b} = -18\hat{i} - 3\hat{j} + 12\hat{k}$ and $\vec{a} \cdot \vec{c} = 3$. If $\vec{b} \times \vec{c} = \vec{d}$, then $|\vec{a} \cdot \vec{d}|$ is equal to:';

      expect(LaTeXParser.containsLatex(question), true);
      final segments = LaTeXParser.parse(question);
      expect(segments.isNotEmpty, true);
    });
  });
}
