# JEE Main 2025 Syllabus Integration

## Overview
The JEEVibe backend now includes comprehensive JEE Main 2025 syllabus reference to improve:
- Topic identification accuracy
- Syllabus-aligned question generation
- Proper difficulty assessment
- Better subject categorization

## Syllabus Structure

### Mathematics (14 Units)
1. Sets, Relations and Functions
2. Complex Numbers and Quadratic Equations
3. Matrices and Determinants
4. Permutations and Combinations
5. Binomial Theorem
6. Sequence and Series
7. Limit, Continuity and Differentiability
8. Integral Calculus
9. Differential Equations
10. Co-ordinate Geometry
11. Three Dimensional Geometry
12. Vector Algebra
13. Statistics and Probability
14. Trigonometry

### Physics (Multiple Units)
- Units and Measurements
- Kinematics
- Laws of Motion
- Work, Energy and Power
- Rotational Motion
- Gravitation
- Properties of Solids and Liquids
- Thermodynamics
- And more...

### Chemistry
- Physical Chemistry
- Organic Chemistry
- Inorganic Chemistry

## Implementation

### Files
- `backend/src/prompts/jee_syllabus_reference.js` - Complete syllabus structure and helper functions
- Updated prompts to reference JEE Main 2025 syllabus
- Topic alignment function ensures topics match syllabus structure

### Features
1. **Topic Alignment**: Automatically aligns identified topics with JEE syllabus units
2. **Topic Suggestions**: Provides syllabus-aligned topic suggestions based on question content
3. **Difficulty Standards**: Uses JEE Main difficulty benchmarks (Easy: 70%+, Medium: 40-70%, Hard: 20-40%)
4. **Question Generation**: Ensures follow-up questions align with syllabus structure

## Usage

The syllabus reference is automatically used when:
- Solving questions from images (topic identification)
- Generating follow-up practice questions (syllabus alignment)
- Determining difficulty levels (JEE Main standards)

## Benefits

1. **Accuracy**: Topics are properly categorized according to official syllabus
2. **Consistency**: All questions follow JEE Main structure
3. **Relevance**: Generated questions match actual JEE Main difficulty and format
4. **Better Learning**: Students get questions aligned with their exam preparation

## Future Enhancements

- Complete Chemistry syllabus mapping
- Sub-topic level granularity
- Topic-wise difficulty distribution
- Integration with question bank

