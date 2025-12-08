# JEE Exam Format Analysis

Based on review of JEE 2nd April Shift 2 exam paper.

## Key Findings

### 1. Question Types
- **Multiple Choice Questions (MCQs)**: Options labeled (A), (B), (C), (D)
- **Numerical Answer Type (NAT)**: Direct numerical answers (Q21-Q25, Q46-Q50, Q71-Q75)
- **Match the Following**: List-I and List-II matching (Q11)
- **Statement-based**: "Statement (I)" and "Statement (II)" with options (Q3, Q7)

### 2. Subject Distribution
- **Chemistry**: Q1-Q11 (Organic, Inorganic, Physical Chemistry)
- **Physics**: Mixed throughout
- **Mathematics**: Q12 onwards, with complex problems (Q70-Q75)

### 3. Text Formatting Patterns

#### Chemical Formulas
- Use LaTeX with `\mathrm{}`: `$\mathrm{Co}(\mathrm{en})_{3}$`, `$\mathrm{Na}_{4}\left[\mathrm{Fe}(\mathrm{CN})_{5} \mathrm{NOS}\right]$`
- Subscripts: `$\mathrm{H}_{2} \mathrm{O}$`, `$\mathrm{sp}^{3}$`
- Superscripts: `$^{3+}$`, `$^{2+}$`, `$^{3-}$`
- Complex compounds: `$\mathrm{Na}_{4}\left[\mathrm{Fe}(\mathrm{CN})_{5} \mathrm{NOS}\right]$`

#### Electronic Configurations
- Format: `$1 \mathrm{~s}^{2} 2 \mathrm{~s}^{2} 2 \mathrm{p}^{3}$`
- Uses `\mathrm{}` for orbital labels

#### Hybridization
- Examples: `$\mathrm{sp}^{3}$`, `$\mathrm{d}^{2} \mathrm{sp}^{3}$`, `$\mathrm{sp}^{3} \mathrm{~d}^{2}$`

#### Orbital Notation
- Examples: `$t_{2 g}^{6} e_{g}^{0}$`, `$t_{2 g}^{6} e_{g}^{4}$`

#### Mathematical Expressions
- Fractions: `$\frac{\mathrm{dy}}{\mathrm{dx}}$`
- Greek letters: `$\alpha$`, `$\beta$`, `$\gamma$`
- Matrices: `$A^{2}(A-2 I)$`
- Series: `$\frac{4.1}{1+4.1^{4}}$`
- Differential equations: `$\frac{\mathrm{dy}}{\mathrm{dx}}+2 \mathrm{ysec}^{2} \mathrm{x}$`

### 4. Common Patterns

#### Question Structure
- Questions often reference diagrams: "[Diagram]" or "[image]" placeholders
- Options can contain complex formulas
- Questions mix text and mathematical notation

#### LaTeX Usage
- **ALL** mathematical and chemical notation uses LaTeX
- Chemical formulas use `\mathrm{}` wrapper
- Subscripts/superscripts are part of LaTeX, not Unicode
- Inline math: `\(...\)`
- Display math: `\[...\]`

## Changes Made

### 1. Updated Prompts (`backend/src/prompts/priya_maam_base.js`)
- Added explicit examples of chemical formulas with `\mathrm{}`
- Added JEE exam format patterns
- Clarified that chemical formulas should use LaTeX, not Unicode
- Added examples of electronic configurations, hybridization, orbital notation

### 2. Updated Vision API Prompt (`backend/src/services/openai.js`)
- Clarified that chemical formulas should use LaTeX with `\mathrm{}`
- Added examples: `\(\mathrm{H}_{2}\mathrm{SO}_{4}\)`, `\(\mathrm{CO}_{2}\)`

### 3. Updated Follow-up Prompt (`backend/src/prompts/snap_solve.js`)
- Added comprehensive JEE format examples
- Included examples for chemistry, math, Greek letters, fractions

### 4. Improved LaTeX Validation (`mobile/lib/widgets/latex_widget.dart`)
- Better detection of LaTeX patterns including `\mathrm{}`
- Recognition of common LaTeX commands (`\frac`, `\sqrt`, `\int`, etc.)
- Improved handling of short formulas (like `H_2`, `sp^3`, `^{3+}`)

## Impact

These changes should:
1. **Reduce parsing errors** by ensuring AI generates proper LaTeX format
2. **Improve chemical formula rendering** by using `\mathrm{}` consistently
3. **Better handle JEE-specific notation** like orbital configurations and hybridization
4. **Match actual exam format** for better student familiarity

## Testing Recommendations

Test with:
- Chemistry questions with complex formulas
- Questions with electronic configurations
- Questions with orbital notation
- Questions with Greek letters and mathematical expressions
- Questions with diagrams (should show placeholder correctly)

