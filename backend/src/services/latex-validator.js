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

  // Step 1: Fix common AI generation errors
  normalized = fixCommonErrors(normalized);

  // Step 2: Remove nested delimiters
  normalized = removeNestedDelimiters(normalized);

  // Step 3: Fix chemical formulas
  normalized = fixChemicalFormulas(normalized);

  // Step 4: Ensure all math expressions have delimiters
  normalized = ensureDelimiters(normalized);

  // Step 5: Remove invalid LaTeX commands
  normalized = removeInvalidCommands(normalized);

  // Step 6: Final cleanup
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

  // Fix ext{} -> \mathrm{} (common OCR error)
  fixed = fixed.replace(/(?<!\\)ext\{/g, '\\mathrm{');
  fixed = fixed.replace(/\\text\{/g, '\\mathrm{');

  // Ensure spaces in chemical formulas use ~ (non-breaking space)
  fixed = fixed.replace(/\\mathrm\{([^}]*)\s+([^}]*)\}/g, '\\mathrm{$1~$2}');

  return fixed;
}

/**
 * Remove nested LaTeX delimiters that cause parser errors
 */
function removeNestedDelimiters(text) {
  let cleaned = text;
  const maxIterations = 5;

  // Remove nested inline delimiters \( ... \( ... \) ... \)
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

  // Remove nested display delimiters \[ ... \[ ... \] ... \]
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

  // Look for common math patterns that might be missing delimiters
  // This is conservative - we only wrap obvious math expressions

  // Pattern: Standalone fractions, integrals, etc. without delimiters
  // Match \frac, \int, \sum, etc. that aren't already in delimiters
  const mathCommands = ['frac', 'int', 'sum', 'lim', 'sqrt', 'infty'];
  
  mathCommands.forEach(cmd => {
    // Match \command that's not preceded by \( or \[
    const pattern = new RegExp(`(?<!\\\\\\()(?<!\\\\\\[)\\\\${cmd}(?:\\{[^}]*\\})?`, 'g');
    
    fixed = fixed.replace(pattern, (match) => {
      // Check if this is already inside delimiters by looking at context
      // This is a simple heuristic
      return `\\(${match}\\)`;
    });
  });

  return fixed;
}

/**
 * Remove invalid or unsupported LaTeX commands
 */
function removeInvalidCommands(text) {
  let cleaned = text;

  // Remove control sequences that aren't valid LaTeX
  // Pattern: backslash followed by single letter that's not part of a command
  cleaned = cleaned.replace(/\\([ntrbfv])(?![a-zA-Z])/g, ' ');

  // Remove empty subscripts and superscripts
  cleaned = cleaned.replace(/_\{\}/g, '');
  cleaned = cleaned.replace(/\^\{\}/g, '');

  // Remove standalone backslashes that aren't part of commands
  cleaned = cleaned.replace(/\\(?![a-zA-Z()[\]])/g, '');

  return cleaned;
}

/**
 * Final cleanup pass
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

module.exports = {
  validateAndNormalizeLaTeX,
  validateDelimiters,
  fixCommonErrors,
  removeNestedDelimiters,
  fixChemicalFormulas,
  ensureDelimiters,
  removeInvalidCommands
};

