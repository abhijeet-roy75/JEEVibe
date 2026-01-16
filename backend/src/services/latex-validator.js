/**
 * JEEVibe - LaTeX Validation and Normalization Service
 * Ensures all mathematical and chemical content is properly formatted
 */

/**
 * Main validation and normalization function
 * @param {string} text - Text containing LaTeX markup
 * @returns {string} Normalized text with valid LaTeX
 */
function validateAndNormalizeLaTeX(text) {
  if (!text || typeof text !== 'string') {
    return text;
  }
  let normalized = text;

  // Auto-detect Devanagari (Hindi) characters. If present, use conservative
  // normalization to avoid aggressive LaTeX wrapping which often corrupts
  // mixed-language OCR outputs (Hindi + inline ascii math).
  const hasDevanagari = /[\u0900-\u097F]/.test(text);

  // Step 1: Fix common AI generation errors (safe to run for all languages)
  normalized = fixCommonErrors(normalized);

  // For Hindi / Devanagari text, avoid aggressive wrapping and delimiter
  // insertion. Instead run a conservative pipeline that fixes obvious issues
  // but preserves original spacing and non-latin tokens.
  if (hasDevanagari) {
    // Fix chemical formulas and unicode subscripts/superscripts
    normalized = fixChemicalFormulas(normalized);

    // Remove invalid/empty commands and do light balancing only
    normalized = removeInvalidCommands(normalized);
    normalized = balanceDelimiters(normalized);

    // Final cleanup and return early
    normalized = finalCleanup(normalized);
    return normalized;
  }

  // Non-Devanagari (default) -- full normalization pipeline
  // Step 2: Remove nested delimiters
  normalized = removeNestedDelimiters(normalized);

  // Step 3: Fix chemical formulas
  normalized = fixChemicalFormulas(normalized);

  // Step 4: Ensure all math expressions have delimiters
  normalized = ensureDelimiters(normalized);

  // Step 5: Remove invalid LaTeX commands
  normalized = removeInvalidCommands(normalized);

  // Step 6: Balance delimiters (close any open ones)
  normalized = balanceDelimiters(normalized);

  // Step 7: Final cleanup
  normalized = finalCleanup(normalized);

  return normalized;
}

/**
 * Fix common AI generation errors
 */
function fixCommonErrors(text) {
  let fixed = text;

  // Fix multiple backslashes before delimiters (common AI error)
  // Match 2+ backslashes followed by delimiter and replace with single backslash
  fixed = fixed.replace(/\\{2,}\(/g, '\\(');
  fixed = fixed.replace(/\\{2,}\)/g, '\\)');
  fixed = fixed.replace(/\\{2,}\[/g, '\\[');
  fixed = fixed.replace(/\\{2,}\]/g, '\\]');

  // Fix missing backslash before common commands
  fixed = fixed.replace(/(?<!\\)mathrm\{/g, '\\mathrm{');
  fixed = fixed.replace(/(?<!\\)frac\{/g, '\\frac{');
  fixed = fixed.replace(/(?<!\\)sqrt\{/g, '\\sqrt{');

  // Fix \text{} -> \mathrm{} (proper LaTeX but we prefer mathrm for chemistry)
  // Must run BEFORE ext{} fix to avoid partial match
  fixed = fixed.replace(/\\text\{/g, '\\mathrm{');

  // Fix tab+ext{ pattern (from \text{} where \t became a tab character)
  // Using explicit tab character match
  fixed = fixed.replace(/\u0009ext\{/g, '\\mathrm{');

  // Fix tab+imes pattern (from \times where \t became a tab character)
  fixed = fixed.replace(/\u0009imes/g, '\\times');

  // Fix ext{} -> \mathrm{} (common OCR error, missing backslash)
  fixed = fixed.replace(/(?<!\\)ext\{/g, '\\mathrm{');

  // Ensure spaces in chemical formulas use ~ (non-breaking space)
  fixed = fixed.replace(/\\mathrm\{([^}]*)\s+([^}]*)\}/g, '\\mathrm{$1~$2}');

  return fixed;
}

/**
 * Remove nested LaTeX delimiters that cause parser errors
 * AGGRESSIVE VERSION: Multiple passes with different strategies
 */
function removeNestedDelimiters(text) {
  let cleaned = text;
  const maxIterations = 10; // Increased for more aggressive cleaning

  // Strategy 1: Remove nested inline delimiters \( ... \( ... \) ... \)
  for (let i = 0; i < maxIterations; i++) {
    const before = cleaned;

    // Find content between outer delimiters
    cleaned = cleaned.replace(/\\\(([^]*?)\\\)/g, (match, content) => {
      // Remove any inner delimiters from the content
      const innerCleaned = content
        .replace(/\\\(/g, '')
        .replace(/\\\)/g, '')
        .replace(/\\\[/g, '')
        .replace(/\\\]/g, '');
      return '\\(' + innerCleaned + '\\)';
    });

    // If no changes were made, we're done
    if (before === cleaned) break;
  }

  // Strategy 2: Remove nested display delimiters \[ ... \[ ... \] ... \]
  for (let i = 0; i < maxIterations; i++) {
    const before = cleaned;

    cleaned = cleaned.replace(/\\\[([^]*?)\\\]/g, (match, content) => {
      // Remove any inner delimiters from the content
      const innerCleaned = content
        .replace(/\\\(/g, '')
        .replace(/\\\)/g, '')
        .replace(/\\\[/g, '')
        .replace(/\\\]/g, '');
      return '\\[' + innerCleaned + '\\]';
    });

    if (before === cleaned) break;
  }

  // Strategy 3: Aggressive pattern matching for common nested patterns
  // Pattern: \( text \( inner \) text \) -> \( text inner text \)
  for (let i = 0; i < maxIterations; i++) {
    const before = cleaned;

    // Match any sequence of delimiters and remove inner ones
    cleaned = cleaned.replace(/\\\(([^\\]*?)(\\\(|\\\[)([^]*?)(\\\)|\\\])([^\\]*?)\\\)/g,
      (match, before, openDelim, inner, closeDelim, after) => {
        return '\\(' + before + inner + after + '\\)';
      }
    );

    if (before === cleaned) break;
  }

  // Strategy 3.5: ULTRA-AGGRESSIVE - Remove ALL inner delimiters from any \(...\) block
  // This is a safety net for extremely nested cases
  for (let i = 0; i < 5; i++) {
    const before = cleaned;

    // Find all \(...\) blocks and strip inner delimiters
    cleaned = cleaned.replace(/\\\(([^\)]*)\\\)/g, (match, content) => {
      // Remove ALL delimiter patterns from content
      const innerCleaned = content
        .replace(/\\\(/g, '')
        .replace(/\\\)/g, '')
        .replace(/\\\[/g, '')
        .replace(/\\\]/g, '');
      return '\\(' + innerCleaned + '\\)';
    });

    if (before === cleaned) break;
  }

  // Strategy 4: Remove any stray delimiters that appear consecutively
  // \(\( -> \(, \)\) -> \), etc.
  cleaned = cleaned.replace(/\\\(\s*\\\(/g, '\\(');
  cleaned = cleaned.replace(/\\\)\s*\\\)/g, '\\)');
  cleaned = cleaned.replace(/\\\[\s*\\\[/g, '\\[');
  cleaned = cleaned.replace(/\\\]\s*\\\]/g, '\\]');

  // Strategy 5: Remove delimiters immediately followed by their closing pair
  // \(\) -> empty, but preserve meaningful content
  cleaned = cleaned.replace(/\\\(\s*\\\)/g, '');
  cleaned = cleaned.replace(/\\\[\s*\\\]/g, '');

  return cleaned;
}

/**
 * Fix chemical formulas to use proper LaTeX syntax
 */
function fixChemicalFormulas(text) {
  let fixed = text;

  // Convert Unicode subscripts to LaTeX (common in AI responses)
  const unicodeSubscripts = {
    '₀': '_{0}', '₁': '_{1}', '₂': '_{2}', '₃': '_{3}', '₄': '_{4}',
    '₅': '_{5}', '₆': '_{6}', '₇': '_{7}', '₈': '_{8}', '₉': '_{9}'
  };

  const unicodeSuperscripts = {
    '⁰': '^{0}', '¹': '^{1}', '²': '^{2}', '³': '^{3}', '⁴': '^{4}',
    '⁵': '^{5}', '⁶': '^{6}', '⁷': '^{7}', '⁸': '^{8}', '⁹': '^{9}',
    '⁺': '^{+}', '⁻': '^{-}'
  };

  // Replace Unicode subscripts
  Object.entries(unicodeSubscripts).forEach(([unicode, latex]) => {
    fixed = fixed.replace(new RegExp(unicode, 'g'), latex);
  });

  // Replace Unicode superscripts
  Object.entries(unicodeSuperscripts).forEach(([unicode, latex]) => {
    fixed = fixed.replace(new RegExp(unicode, 'g'), latex);
  });

  // Ensure chemical elements are wrapped in \mathrm{}
  // Match chemical formulas like H2O, CO2, NH4+ that aren't already in LaTeX
  // This is a simple heuristic - only apply outside of existing LaTeX delimiters

  // Split by LaTeX delimiters to avoid modifying content inside them
  const parts = [];
  let currentPos = 0;
  const delimiterPattern = /\\\(|\\\)|\\\[|\\\]/g;
  let match;
  let insideLaTeX = false;

  while ((match = delimiterPattern.exec(fixed)) !== null) {
    if (!insideLaTeX) {
      // Outside LaTeX - process this part
      const part = fixed.substring(currentPos, match.index);
      parts.push({ text: part, isLaTeX: false });
      insideLaTeX = true;
    } else {
      // Inside LaTeX - don't process
      const part = fixed.substring(currentPos, match.index);
      parts.push({ text: part, isLaTeX: true });
      insideLaTeX = false;
    }
    parts.push({ text: match[0], isDelimiter: true });
    currentPos = match.index + match[0].length;
  }

  // Add remaining text
  if (currentPos < fixed.length) {
    parts.push({ text: fixed.substring(currentPos), isLaTeX: insideLaTeX });
  }

  // Process non-LaTeX parts
  fixed = parts.map(part => {
    if (part.isDelimiter || part.isLaTeX) {
      return part.text;
    }

    // Convert simple chemical formulas like H2O -> \(\mathrm{H}_{2}\mathrm{O}\)
    // Only if not already in LaTeX
    let text = part.text;

    // Pattern: Capital letter optionally followed by lowercase, followed by digit(s)
    // This catches: H2, CO2, H2O, etc.
    text = text.replace(/\b([A-Z][a-z]?)(\d+)\b/g, (match, element, number) => {
      // Check if already in LaTeX context
      if (match.includes('\\mathrm')) return match;
      return `\\(\\mathrm{${element}}_{${number}}\\)`;
    });

    return text;
  }).join('');

  return fixed;
}

/**
 * Ensure all mathematical expressions have proper delimiters
 */
function ensureDelimiters(text) {
  let fixed = text;

  // Split text by existing delimiters to only process text outside of them
  const parts = _splitByDelimiters(fixed);

  fixed = parts.map(part => {
    if (part.isDelimited) {
      return part.text; // Already has delimiters, don't modify
    }

    let content = part.text;

    // Wrap standalone \mathrm{} expressions (chemistry formulas)
    // Pattern: \mathrm{...} with any number of subscripts/superscripts following
    // Example: \mathrm{sp}^{3} -> \(\mathrm{sp}^{3}\)
    content = content.replace(
      /\\mathrm\{[^}]+\}(?:[_^]\{[^}]+\})*/g,
      (match) => {
        // Don't double-wrap if already in delimiters
        return `\\(${match}\\)`;
      }
    );

    // Wrap standalone math commands
    const mathCommands = [
      'frac', 'int', 'sum', 'lim', 'sqrt', 'infty',
      'alpha', 'beta', 'gamma', 'theta', 'pi', 'Delta', 'omega', 'phi',
      'sin', 'cos', 'tan', 'cot', 'sec', 'csc', 'log', 'ln', 'exp'
    ];
    mathCommands.forEach(cmd => {
      // Improved regex: match \cmd only if not already preceded by \
      // And handle optional arguments like \sin^{2} or \tan(x)
      const pattern = new RegExp(`(?<!\\\\)\\\\${cmd}(?:[\\^_]\\{?[^}]*\\}?)?`, 'g');
      content = content.replace(pattern, (match) => `\\(${match}\\)`);

      // Also catch "naked" trig/log functions missing backslash (common in mixed language content)
      // Matches "sin" if not part of another word and followed by ^, _, (, or space
      const nakedPattern = new RegExp(`(?<![a-zA-Z\\\\])\\b(${cmd})\\b(?=[\\^_\\(\\s])`, 'g');
      content = content.replace(nakedPattern, (match, p1) => `\\(\\${p1}\\)`);
    });

    // Wrap standalone subscripts/superscripts patterns (for variables or chemical numbers)
    // Matches patterns like _{4}, ^{2}, _2, ^+, etc.
    content = content.replace(/(?<!\\)([_^]\{?[^}\s]+\}?)/g, (match) => `\\(${match}\\)`);

    // Handle single char subscript/superscript e.g. x^2, H_2 (common in chemistry/math)
    content = content.replace(/([a-zA-Z])([_^][0-9a-zA-Z])(?![a-zA-Z0-9])/g, (match) => `\\(${match}\\)`);

    // Wrap sequences of \mathrm that are separated by spaces or underscores
    // Example: "\mathrm{H}_{2}\mathrm{O}" -> "\(\mathrm{H}_{2}\mathrm{O}\)"
    content = content.replace(
      /\\mathrm\{[^}]+\}(?:[_^]\{[^}]+\}|\\mathrm\{[^}]+\})*/g,
      (match) => `\\(${match}\\)`
    );

    return content;
  }).join('');

  return fixed;
}

/**
 * Helper function to split text by LaTeX delimiters
 */
function _splitByDelimiters(text) {
  const parts = [];
  let currentPos = 0;
  let insideDelimiters = false;

  // Find all \( \) and \[ \] delimiters
  const delimiterRegex = /\\\(|\\\)|\\\[|\\\]/g;
  let match;

  while ((match = delimiterRegex.exec(text)) !== null) {
    if (!insideDelimiters) {
      // We found an opening delimiter
      if (currentPos < match.index) {
        parts.push({ text: text.substring(currentPos, match.index), isDelimited: false });
      }
      currentPos = match.index;
      insideDelimiters = true;
    } else {
      // We found a closing delimiter
      parts.push({ text: text.substring(currentPos, match.index + match[0].length), isDelimited: true });
      currentPos = match.index + match[0].length;
      insideDelimiters = false;
    }
  }

  // Add remaining text
  if (currentPos < text.length) {
    parts.push({ text: text.substring(currentPos), isDelimited: insideDelimiters });
  }

  return parts;
}

/**
 * Remove invalid or unsupported LaTeX commands
 */
function removeInvalidCommands(text) {
  let cleaned = text;

  // CRITICAL: Removed aggressive backslash-character replacements that mangle \tan, \theta, etc.

  // Remove empty subscripts and superscripts
  cleaned = cleaned.replace(/_\{\}/g, '');
  cleaned = cleaned.replace(/\^\{\}/g, '');

  // Remove standalone backslashes that aren't part of commands
  cleaned = cleaned.replace(/\\(?![a-zA-Z()[\]])/g, '');

  return cleaned;
}

/**
 * Step 6: Balance delimiters
 * Appends missing closing delimiters if counts don't match
 */
function balanceDelimiters(text) {
  let fixed = text;

  // Count inline delimiters
  const openInline = (fixed.match(/\\\(/g) || []).length;
  const closeInline = (fixed.match(/\\\)/g) || []).length;

  if (openInline > closeInline) {
    fixed += '\\)'.repeat(openInline - closeInline);
  }

  // Count display delimiters
  const openDisplay = (fixed.match(/\\\[/g) || []).length;
  const closeDisplay = (fixed.match(/\\\]/g) || []).length;

  if (openDisplay > closeDisplay) {
    fixed += '\\]'.repeat(openDisplay - closeDisplay);
  }

  // Count \left and \right
  const openLeft = (fixed.match(/\\left/g) || []).length;
  const closeRight = (fixed.match(/\\right/g) || []).length;

  if (openLeft > closeRight) {
    // Try to be smart about what we're closing
    // Most common is \left( and \left[
    const openLeftParen = (fixed.match(/\\left\(/g) || []).length;
    const closeRightParen = (fixed.match(/\\right\)/g) || []).length;
    if (openLeftParen > closeRightParen) {
      fixed += '\\right)'.repeat(openLeftParen - closeRightParen);
    } else {
      // Fallback: just add \right. (null delimiter) or guess )
      fixed += '\\right)'.repeat(openLeft - closeRight);
    }
  }

  return fixed;
}

/**
 * Step 7: Final cleanup
 */
function finalCleanup(text) {
  let cleaned = text;

  // Normalize whitespace (but preserve intentional spaces in LaTeX)
  // Remove multiple spaces outside of LaTeX delimiters
  cleaned = cleaned.replace(/([^\\\s])\s{2,}([^\\\s])/g, '$1 $2');

  // Trim whitespace at start and end
  cleaned = cleaned.trim();

  return cleaned;
}

/**
 * Validate LaTeX delimiters are balanced
 * @param {string} text - Text to validate
 * @returns {Object} Validation result with balanced status and error messages
 */
function validateDelimiters(text) {
  if (!text || typeof text !== 'string') {
    return { balanced: true, errors: [] };
  }

  const errors = [];

  // Count inline delimiters
  const openInline = (text.match(/\\\(/g) || []).length;
  const closeInline = (text.match(/\\\)/g) || []).length;

  if (openInline !== closeInline) {
    errors.push(`Unbalanced inline delimiters: ${openInline} open \\(, ${closeInline} close \\)`);
  }

  // Count display delimiters
  const openDisplay = (text.match(/\\\[/g) || []).length;
  const closeDisplay = (text.match(/\\\]/g) || []).length;

  if (openDisplay !== closeDisplay) {
    errors.push(`Unbalanced display delimiters: ${openDisplay} open \\[, ${closeDisplay} close \\]`);
  }

  // Check for special characters outside delimiters
  const outsideDelimiters = text.replace(/\\\(.*?\\\)/g, '').replace(/\\\[.*?\\\]/g, '');
  const hasUnescapedSpecial = /[_^{}]/.test(outsideDelimiters);

  if (hasUnescapedSpecial) {
    errors.push('Special characters (_^{}) found outside LaTeX delimiters');
  }

  return {
    balanced: errors.length === 0,
    errors: errors
  };
}

/**
 * Validate LaTeX and reject if critically malformed
 * Returns { valid: boolean, errors: string[], normalized: string }
 */
function validateAndReject(text, fieldName = 'text') {
  if (!text || typeof text !== 'string') {
    return { valid: true, errors: [], normalized: text };
  }

  const errors = [];
  let normalized = text;

  try {
    // Attempt normalization
    normalized = validateAndNormalizeLaTeX(text);

    // Check for severely nested delimiters (more than 2 levels)
    const nestedInlinePattern = /\\\([^\\]*\\\([^\\]*\\\([^\\]*\\\)/;
    if (nestedInlinePattern.test(normalized)) {
      errors.push(`${fieldName}: Severely nested inline delimiters detected (3+ levels)`);
    }

    // Check delimiter balance
    const delimiterCheck = validateDelimiters(normalized);
    if (!delimiterCheck.balanced) {
      errors.push(`${fieldName}: Unbalanced delimiters - ${delimiterCheck.errors.join(', ')}`);
    }

    // Check for common AI errors that shouldn't exist after normalization
    if (normalized.includes('\\(\\(') || normalized.includes('\\)\\)')) {
      errors.push(`${fieldName}: Consecutive delimiters found after normalization`);
    }

    // Check for \text{} which should have been converted to \mathrm{}
    if (normalized.includes('\\text{')) {
      console.warn(`${fieldName}: Found \\text{} command, should use \\mathrm{} for chemistry`);
    }

    // Log validation result
    if (errors.length > 0) {
      console.error(`LaTeX validation errors in ${fieldName}:`, errors);
      console.error(`Original text: ${text.substring(0, 200)}...`);
      console.error(`Normalized text: ${normalized.substring(0, 200)}...`);
    }

    return {
      valid: errors.length === 0,
      errors: errors,
      normalized: normalized
    };
  } catch (error) {
    errors.push(`${fieldName}: Validation exception - ${error.message}`);
    console.error(`LaTeX validation exception in ${fieldName}:`, error);
    return {
      valid: false,
      errors: errors,
      normalized: text // Return original on exception
    };
  }
}

/**
 * Comprehensive LaTeX validation for all text fields
 * Returns { valid: boolean, errors: string[], data: object }
 */
function validateSolutionResponse(solutionData) {
  const allErrors = [];
  const validated = {};

  // Validate recognizedQuestion
  const questionCheck = validateAndReject(solutionData.recognizedQuestion, 'recognizedQuestion');
  validated.recognizedQuestion = questionCheck.normalized;
  if (!questionCheck.valid) {
    allErrors.push(...questionCheck.errors);
  }

  // Validate solution fields
  if (solutionData.solution) {
    const approachCheck = validateAndReject(solutionData.solution.approach, 'solution.approach');
    validated.approach = approachCheck.normalized;
    if (!approachCheck.valid) allErrors.push(...approachCheck.errors);

    const finalAnswerCheck = validateAndReject(solutionData.solution.finalAnswer, 'solution.finalAnswer');
    validated.finalAnswer = finalAnswerCheck.normalized;
    if (!finalAnswerCheck.valid) allErrors.push(...finalAnswerCheck.errors);

    const tipCheck = validateAndReject(solutionData.solution.priyaMaamTip, 'solution.priyaMaamTip');
    validated.priyaMaamTip = tipCheck.normalized;
    if (!tipCheck.valid) allErrors.push(...tipCheck.errors);

    // Validate steps
    validated.steps = [];
    if (Array.isArray(solutionData.solution.steps)) {
      solutionData.solution.steps.forEach((step, index) => {
        const stepCheck = validateAndReject(step, `solution.steps[${index}]`);
        validated.steps.push(stepCheck.normalized);
        if (!stepCheck.valid) allErrors.push(...stepCheck.errors);
      });
    }
  }

  return {
    valid: allErrors.length === 0,
    errors: allErrors,
    validatedData: validated
  };
}

module.exports = {
  validateAndNormalizeLaTeX,
  validateDelimiters,
  validateAndReject,
  validateSolutionResponse,
  fixCommonErrors,
  removeNestedDelimiters,
  fixChemicalFormulas,
  ensureDelimiters,
  removeInvalidCommands,
  balanceDelimiters
};

