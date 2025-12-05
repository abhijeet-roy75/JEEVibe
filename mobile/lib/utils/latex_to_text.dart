/// JEEVibe LaTeX-to-Plain-Text Converter
/// Ultimate fallback for when LaTeX rendering fails
/// Converts LaTeX markup to readable plain text using Unicode symbols where possible

class LaTeXToText {
  /// Convert LaTeX string to plain readable text
  /// This is the ultimate fallback when flutter_math_fork cannot parse the LaTeX
  static String convert(String latex) {
    if (latex.isEmpty) return latex;
    
    String result = latex;
    
    // Step 1: Remove LaTeX delimiters
    result = _removeDelimiters(result);
    
    // Step 2: Convert fractions
    result = _convertFractions(result);
    
    // Step 3: Convert Greek letters
    result = _convertGreekLetters(result);
    
    // Step 4: Convert subscripts and superscripts to Unicode
    result = _convertScriptsToUnicode(result);
    
    // Step 5: Convert chemical formulas
    result = _convertChemistry(result);
    
    // Step 6: Convert common math operators
    result = _convertMathOperators(result);
    
    // Step 7: Convert calculus notation
    result = _convertCalculus(result);
    
    // Step 8: Clean up remaining LaTeX commands
    result = _cleanupCommands(result);
    
    // Step 9: Final cleanup
    result = _finalCleanup(result);
    
    return result;
  }
  
  /// Remove LaTeX delimiters \( \) \[ \]
  static String _removeDelimiters(String text) {
    return text
        .replaceAll(RegExp(r'\\\('), '')
        .replaceAll(RegExp(r'\\\)'), '')
        .replaceAll(RegExp(r'\\\['), '')
        .replaceAll(RegExp(r'\\\]'), '');
  }
  
  /// Convert fractions: \frac{a}{b} -> a/b
  static String _convertFractions(String text) {
    // Pattern: \frac{numerator}{denominator}
    return text.replaceAllMapped(
      RegExp(r'\\frac\{([^}]+)\}\{([^}]+)\}'),
      (match) => '(${match.group(1)})/(${match.group(2)})',
    );
  }
  
  /// Convert Greek letters to Unicode equivalents
  static String _convertGreekLetters(String text) {
    final greekMap = {
      r'\alpha': 'α',
      r'\beta': 'β',
      r'\gamma': 'γ',
      r'\Gamma': 'Γ',
      r'\delta': 'δ',
      r'\Delta': 'Δ',
      r'\epsilon': 'ε',
      r'\zeta': 'ζ',
      r'\eta': 'η',
      r'\theta': 'θ',
      r'\Theta': 'Θ',
      r'\iota': 'ι',
      r'\kappa': 'κ',
      r'\lambda': 'λ',
      r'\Lambda': 'Λ',
      r'\mu': 'μ',
      r'\nu': 'ν',
      r'\xi': 'ξ',
      r'\Xi': 'Ξ',
      r'\pi': 'π',
      r'\Pi': 'Π',
      r'\rho': 'ρ',
      r'\sigma': 'σ',
      r'\Sigma': 'Σ',
      r'\tau': 'τ',
      r'\upsilon': 'υ',
      r'\Upsilon': 'Υ',
      r'\phi': 'φ',
      r'\Phi': 'Φ',
      r'\chi': 'χ',
      r'\psi': 'ψ',
      r'\Psi': 'Ψ',
      r'\omega': 'ω',
      r'\Omega': 'Ω',
    };
    
    String result = text;
    greekMap.forEach((latex, unicode) {
      result = result.replaceAll(latex, unicode);
    });
    
    return result;
  }
  
  /// Convert subscripts and superscripts to Unicode
  static String _convertScriptsToUnicode(String text) {
    String result = text;
    
    // Subscript map
    final subscriptMap = {
      '0': '₀', '1': '₁', '2': '₂', '3': '₃', '4': '₄',
      '5': '₅', '6': '₆', '7': '₇', '8': '₈', '9': '₉',
      '+': '₊', '-': '₋', '=': '₌', '(': '₍', ')': '₎',
      'a': 'ₐ', 'e': 'ₑ', 'i': 'ᵢ', 'o': 'ₒ', 'u': 'ᵤ',
      'x': 'ₓ', 'n': 'ₙ',
    };
    
    // Superscript map
    final superscriptMap = {
      '0': '⁰', '1': '¹', '2': '²', '3': '³', '4': '⁴',
      '5': '⁵', '6': '⁶', '7': '⁷', '8': '⁸', '9': '⁹',
      '+': '⁺', '-': '⁻', '=': '⁼', '(': '⁽', ')': '⁾',
      'n': 'ⁿ', 'i': 'ⁱ',
    };
    
    // Convert subscripts: _{...}
    result = result.replaceAllMapped(
      RegExp(r'_\{([^}]+)\}'),
      (match) {
        final content = match.group(1)!;
        return content.split('').map((char) => subscriptMap[char] ?? char).join();
      },
    );
    
    // Convert superscripts: ^{...}
    result = result.replaceAllMapped(
      RegExp(r'\^\{([^}]+)\}'),
      (match) {
        final content = match.group(1)!;
        return content.split('').map((char) => superscriptMap[char] ?? char).join();
      },
    );
    
    // Simple subscripts: _x -> x subscript
    result = result.replaceAllMapped(
      RegExp(r'_([a-zA-Z0-9])'),
      (match) {
        final char = match.group(1)!;
        return subscriptMap[char] ?? '_$char';
      },
    );
    
    // Simple superscripts: ^x -> x superscript
    result = result.replaceAllMapped(
      RegExp(r'\^([a-zA-Z0-9])'),
      (match) {
        final char = match.group(1)!;
        return superscriptMap[char] ?? '^$char';
      },
    );
    
    return result;
  }
  
  /// Convert chemistry notation: \mathrm{H}_{2}\mathrm{O} -> H₂O
  static String _convertChemistry(String text) {
    String result = text;
    
    // Remove \mathrm{} and keep content
    result = result.replaceAllMapped(
      RegExp(r'\\mathrm\{([^}]+)\}'),
      (match) => match.group(1)!,
    );
    
    // Convert ~ (non-breaking space in LaTeX) to regular space
    result = result.replaceAll('~', ' ');
    
    return result;
  }
  
  /// Convert common math operators
  static String _convertMathOperators(String text) {
    final operatorMap = {
      r'\times': '×',
      r'\div': '÷',
      r'\pm': '±',
      r'\mp': '∓',
      r'\cdot': '·',
      r'\neq': '≠',
      r'\leq': '≤',
      r'\geq': '≥',
      r'\ll': '≪',
      r'\gg': '≫',
      r'\approx': '≈',
      r'\equiv': '≡',
      r'\sim': '∼',
      r'\propto': '∝',
      r'\infty': '∞',
      r'\partial': '∂',
      r'\nabla': '∇',
      r'\sqrt': '√',
      r'\angle': '∠',
      r'\degree': '°',
      r'\circ': '°',
      r'\to': '→',
      r'\rightarrow': '→',
      r'\leftarrow': '←',
      r'\Rightarrow': '⇒',
      r'\Leftarrow': '⇐',
      r'\leftrightarrow': '↔',
      r'\in': '∈',
      r'\notin': '∉',
      r'\subset': '⊂',
      r'\supset': '⊃',
      r'\cup': '∪',
      r'\cap': '∩',
      r'\emptyset': '∅',
      r'\exists': '∃',
      r'\forall': '∀',
      r'\therefore': '∴',
      r'\because': '∵',
    };
    
    String result = text;
    operatorMap.forEach((latex, unicode) {
      result = result.replaceAll(latex, unicode);
    });
    
    return result;
  }
  
  /// Convert calculus notation
  static String _convertCalculus(String text) {
    String result = text;
    
    // Integral: \int -> ∫
    result = result.replaceAll(r'\int', '∫');
    
    // Summation: \sum -> Σ
    result = result.replaceAll(r'\sum', 'Σ');
    
    // Product: \prod -> Π
    result = result.replaceAll(r'\prod', 'Π');
    
    // Limit: \lim_{x \to a} -> lim(x→a)
    result = result.replaceAllMapped(
      RegExp(r'\\lim_\{([^}]+)\}'),
      (match) => 'lim(${match.group(1)})',
    );
    
    // Derivatives: \frac{dy}{dx} already handled by fraction converter
    
    return result;
  }
  
  /// Clean up remaining LaTeX commands
  static String _cleanupCommands(String text) {
    String result = text;
    
    // Remove common commands that don't need conversion
    result = result.replaceAll(r'\text', '');
    result = result.replaceAll(r'\mathrm', '');
    result = result.replaceAll(r'\mathbf', '');
    result = result.replaceAll(r'\mathit', '');
    result = result.replaceAll(r'\displaystyle', '');
    result = result.replaceAll(r'\textstyle', '');
    
    // Remove \left and \right
    result = result.replaceAll(r'\left', '');
    result = result.replaceAll(r'\right', '');
    
    // Remove \vec command but keep content: \vec{F} -> F⃗
    result = result.replaceAllMapped(
      RegExp(r'\\vec\{([^}]+)\}'),
      (match) => '${match.group(1)}⃗',
    );
    
    // Remove \bar command: \bar{x} -> x̄
    result = result.replaceAllMapped(
      RegExp(r'\\bar\{([^}]+)\}'),
      (match) => '${match.group(1)}̄',
    );
    
    // Remove \sqrt: \sqrt{x} -> √x or sqrt(x) for complex expressions
    result = result.replaceAllMapped(
      RegExp(r'\\sqrt\{([^}]+)\}'),
      (match) {
        final content = match.group(1)!;
        // If content is simple, use √ symbol
        if (content.length <= 3 && !content.contains(RegExp(r'[+\-*/]'))) {
          return '√$content';
        }
        // For complex expressions, use sqrt()
        return 'sqrt($content)';
      },
    );
    
    // Remove any remaining backslash commands: \command -> command
    result = result.replaceAll(RegExp(r'\\([a-zA-Z]+)'), r'$1');
    
    // Remove curly braces
    result = result.replaceAll('{', '');
    result = result.replaceAll('}', '');
    
    return result;
  }
  
  /// Final cleanup pass
  static String _finalCleanup(String text) {
    String result = text;
    
    // Remove multiple spaces
    result = result.replaceAll(RegExp(r'\s+'), ' ');
    
    // Clean up spacing around parentheses
    result = result.replaceAll(RegExp(r'\s*\(\s*'), '(');
    result = result.replaceAll(RegExp(r'\s*\)\s*'), ')');
    
    // Remove any remaining backslashes
    result = result.replaceAll(r'\', '');
    
    // Trim
    result = result.trim();
    
    return result;
  }
  
  /// Quick check if text contains LaTeX that needs conversion
  static bool containsLaTeX(String text) {
    return text.contains(RegExp(r'\\[a-zA-Z]+')) ||
           text.contains(RegExp(r'[\\_\^]')) ||
           text.contains(r'\(') ||
           text.contains(r'\)');
  }
}

