/**
 * Theta Calculation Service
 * 
 * Implements IRT-based theta calculation functions for initial assessment.
 * Based on JEEVibe IIDP Algorithm Specification v4 CALIBRATED.
 */

// ============================================================================
// CONSTANTS
// ============================================================================

const THETA_MIN = -3.0;
const THETA_MAX = 3.0;
const SE_FLOOR = 0.15;
const SE_CEILING = 0.6;

// JEE Chapter Weights
// Based on analysis of JEE Main & JEE Advanced papers (2019-2024)
// Weight Scale: 1.0 = High Priority, 0.8 = Medium-High, 0.6 = Medium, 0.4 = Low-Medium, 0.3 = Low
// Source: docs/engine/jee_chapter_weightage.js
const DEFAULT_CHAPTER_WEIGHT = 0.5;

// Chapter name normalization mapping
// Maps common variations of chapter names to standardized keys
const CHAPTER_NAME_NORMALIZATIONS = {
  // Physics variations
  "mechanics": "laws_of_motion", // "Mechanics" maps to "laws_of_motion" (main mechanics topic)
  "newtons_laws": "laws_of_motion",
  "newton's_laws": "laws_of_motion",
  "newton_laws": "laws_of_motion",
  "work_energy": "work_energy_power",
  "work_&_energy": "work_energy_power",
  "work_energy_and_power": "work_energy_power", // Normalize "and" variant
  "rotational": "rotational_motion",
  "rotational_dynamics": "rotational_motion",
  "electrostatics": "electrostatics", // Already correct
  "current_electricity": "current_electricity", // Already correct
  "magnetism": "magnetic_effects_magnetism", // "Magnetism" maps to daily quiz chapter
  "magnetic_field": "magnetic_effects_magnetism",
  "emi": "electromagnetic_induction",
  "electromagnetic_induction": "electromagnetic_induction", // Already correct
  "optics": "optics", // Maps to physics_optics
  "modern_physics": "atoms_nuclei", // "Modern Physics" maps to atoms_nuclei

  // Chemistry variations
  "atomic_structure": "atomic_structure", // Already correct
  "chemical_bonding": "chemical_bonding", // Already correct
  "thermodynamics": "thermodynamics", // Already correct
  "equilibrium": "equilibrium", // Already correct
  "physical_chemistry": "thermodynamics", // "Physical Chemistry" maps to "thermodynamics"
  "organic_chemistry": "general_organic_chemistry", // "Organic Chemistry" maps to GOC
  "inorganic_chemistry": "p_block_elements", // "Inorganic Chemistry" maps to p_block

  // Mathematics variations
  "calculus": "limits_continuity_differentiability", // "Calculus" maps to limits
  "limits_and_differentiability": "limits_continuity_differentiability", // Missing "continuity" in name
  "limits_differentiability": "limits_continuity_differentiability", // Short form
  "limit_continuity_and_differentiability": "limits_continuity_differentiability", // JEE syllabus exact name (singular "Limit")
  "limits_continuity_and_differentiability": "limits_continuity_differentiability", // Plural variation with "and"
  "algebra": "complex_numbers", // "Algebra" maps to complex_numbers
  "coordinate_geometry": "straight_lines", // Maps to straight_lines (foundation)
  "geometry": "straight_lines", // Default if ambiguous

  // Database Variations (found in questions collection) - normalize to daily quiz chapter keys
  "magnetic_effects_magnetism": "magnetic_effects_magnetism",
  "limits_continuity_differentiability": "limits_continuity_differentiability",
  "conic_sections_ellipse_hyperbola": "conic_sections_ellipse_hyperbola",
  "differential_calculus_aod": "differential_calculus_aod",
  "integral_calculus_definite_area": "integral_calculus_definite_area",
  "integral_calculus_indefinite": "integral_calculus_indefinite",
  "vector_algebra": "vector_algebra",
  "purification_characterization": "purification_characterization",
  "general_organic_chemistry_goc": "general_organic_chemistry",
  "general_organic_chemistry": "general_organic_chemistry",
  "units_measurements": "units_measurements",
  "3d_geometry": "3d_geometry",
  "p_block_elements": "p_block_elements",
  "d_f_block_elements": "d_f_block_elements",
};

// ============================================================================
// BROAD-TO-SPECIFIC CHAPTER MAPPING
// ============================================================================
// Maps broad assessment chapter names to ALL related specific daily quiz chapters
// This allows theta from a broad category to be distributed across specific topics

const BROAD_TO_SPECIFIC_CHAPTER_MAP = {
  // Physics broad chapters
  "physics_mechanics": [
    "physics_kinematics",
    "physics_laws_of_motion",
    "physics_work_energy_and_power",
    "physics_rotational_motion",
    "physics_gravitation",
    "physics_properties_of_solids_liquids"
  ],
  "physics_magnetism": [
    "physics_magnetic_effects_magnetism"
  ],
  "physics_modern_physics": [
    "physics_atoms_nuclei",
    "physics_dual_nature_of_radiation",
    "physics_electronic_devices"
  ],

  // Chemistry broad chapters
  "chemistry_physical_chemistry": [
    "chemistry_thermodynamics",
    "chemistry_equilibrium",
    "chemistry_solutions",
    "chemistry_chemical_kinetics",
    "chemistry_atomic_structure",
    "chemistry_redox_electrochemistry"
  ],
  "chemistry_organic_chemistry": [
    "chemistry_general_organic_chemistry",
    "chemistry_hydrocarbons",
    "chemistry_aldehydes_ketones",
    "chemistry_alcohols_phenols_ethers",
    "chemistry_amines_diazonium_salts",
    "chemistry_carboxylic_acids_derivatives",
    "chemistry_haloalkanes_and_haloarenes",
    "chemistry_biomolecules"
  ],
  "chemistry_inorganic_chemistry": [
    "chemistry_p_block_elements",
    "chemistry_d_f_block_elements",
    "chemistry_coordination_compounds",
    "chemistry_classification_periodicity",
    "chemistry_chemical_bonding"
  ],

  // Mathematics broad chapters
  "mathematics_algebra": [
    "mathematics_complex_numbers",
    "mathematics_matrices_determinants",
    "mathematics_permutations_and_combinations",
    "mathematics_binomial_theorem",
    "mathematics_sequences_and_series",
    "mathematics_sets_relations_functions"
  ],
  "mathematics_calculus": [
    "mathematics_limits_continuity_differentiability",
    "mathematics_differential_calculus_aod",
    "mathematics_integral_calculus_indefinite",
    "mathematics_integral_calculus_definite_area",
    "mathematics_differential_equations"
  ],
  "mathematics_coordinate_geometry": [
    "mathematics_straight_lines",
    "mathematics_circles",
    "mathematics_conic_sections_ellipse_hyperbola",
    "mathematics_3d_geometry"
  ]
};

/**
 * Check if a chapter key is a broad category that maps to specific chapters
 *
 * @param {string} chapterKey - The chapter key to check
 * @returns {boolean} True if this is a broad category
 */
function isBroadChapter(chapterKey) {
  return BROAD_TO_SPECIFIC_CHAPTER_MAP.hasOwnProperty(chapterKey);
}

/**
 * Get specific chapters for a broad chapter category
 * Returns the original chapter if it's not a broad category
 *
 * @param {string} chapterKey - The chapter key (may be broad or specific)
 * @returns {string[]} Array of specific chapter keys
 */
function getSpecificChapters(chapterKey) {
  if (BROAD_TO_SPECIFIC_CHAPTER_MAP[chapterKey]) {
    return BROAD_TO_SPECIFIC_CHAPTER_MAP[chapterKey];
  }
  // If not a broad chapter, return as-is in an array
  return [chapterKey];
}

/**
 * Expand theta estimates from broad chapters to specific chapters
 * Used after initial assessment to distribute theta across all related topics
 *
 * @param {Object} thetaByChapter - Original theta estimates (may include broad chapters)
 * @returns {Object} Expanded theta estimates with specific chapters
 */
function expandBroadChaptersToSpecific(thetaByChapter) {
  const expandedTheta = {};

  for (const [chapterKey, thetaData] of Object.entries(thetaByChapter)) {
    if (isBroadChapter(chapterKey)) {
      // This is a broad chapter - distribute theta to all specific chapters
      const specificChapters = getSpecificChapters(chapterKey);

      for (const specificChapter of specificChapters) {
        // Don't overwrite if specific chapter already has data
        if (!expandedTheta[specificChapter]) {
          expandedTheta[specificChapter] = {
            ...thetaData,
            source_chapter: chapterKey, // Track where this theta came from
            is_derived: true, // Mark as derived from broad category
            derived_at: new Date().toISOString()
          };
        }
      }

      // Also keep the broad chapter for reference
      expandedTheta[chapterKey] = {
        ...thetaData,
        is_broad_category: true,
        expanded_to: specificChapters
      };
    } else {
      // Specific chapter - keep as-is
      expandedTheta[chapterKey] = thetaData;
    }
  }

  return expandedTheta;
}

const JEE_CHAPTER_WEIGHTS = {
  // Physics (~21 chapters) - Original format
  "physics_kinematics": 1.0,
  "physics_laws_of_motion": 1.0,
  "physics_work_energy_power": 1.0,
  "physics_rotational_motion": 1.0,
  "physics_gravitation": 0.6,
  "physics_properties_of_matter": 0.6,
  "physics_thermodynamics": 0.8,
  "physics_kinetic_theory": 0.6,
  "physics_oscillations": 0.8,
  "physics_waves": 0.8,
  "physics_electrostatics": 1.0,
  "physics_current_electricity": 1.0,
  "physics_magnetic_effects": 1.0,
  "physics_electromagnetic_induction": 1.0,
  "physics_ac_circuits": 0.6,
  "physics_electromagnetic_waves": 0.4,
  "physics_ray_optics": 0.8,
  "physics_wave_optics": 0.8,
  "physics_dual_nature": 0.6,
  "physics_atoms_nuclei": 0.6,
  "physics_semiconductors": 0.4,
  // Physics - Daily quiz chapter name variants
  "physics_magnetic_effects_magnetism": 1.0,  // Variant of magnetic_effects
  "physics_atoms_nuclei": 0.6,
  "physics_work_energy_and_power": 1.0,       // Variant with "and"
  "physics_units_measurements": 0.6,          // Units and Measurements
  "physics_units_and_measurements": 0.6,      // With "and"
  "physics_properties_of_solids_liquids": 0.6, // Variant name
  "physics_dual_nature_of_radiation": 0.6,    // Full chapter name
  "physics_electronic_devices": 0.4,          // Variant of semiconductors
  "physics_optics": 0.8,                      // Combined optics
  "physics_kinetic_theory_of_gases": 0.6,     // Full name variant of kinetic_theory
  "physics_oscillations_waves": 0.8,          // Combined oscillations and waves
  "physics_transformers": 0.4,                // Transformers (low-medium priority)
  "physics_eddy_currents": 0.4,               // Eddy currents (low-medium priority)
  "physics_experimental_skills": 0.4,         // Experimental skills and measurements

  // Chemistry (~27 chapters) - Original format
  "chemistry_atomic_structure": 0.8,
  "chemistry_classification_elements": 0.6,
  "chemistry_chemical_bonding": 1.0,
  "chemistry_states_of_matter": 0.6,
  "chemistry_thermodynamics": 1.0,
  "chemistry_equilibrium": 1.0,
  "chemistry_redox_reactions": 0.6,
  "chemistry_hydrogen": 0.3,
  "chemistry_s_block": 0.6,
  "chemistry_p_block": 1.0,
  "chemistry_organic_basics": 0.8,
  "chemistry_hydrocarbons": 0.8,
  "chemistry_haloalkanes": 0.8,
  "chemistry_alcohols_phenols": 0.8,
  "chemistry_aldehydes_ketones": 1.0,
  "chemistry_carboxylic_acids": 0.8,
  "chemistry_amines": 0.8,
  "chemistry_biomolecules": 0.4,
  "chemistry_polymers": 0.4,
  "chemistry_environmental_chemistry": 0.3,
  "chemistry_solid_state": 0.6,
  "chemistry_solutions": 0.8,
  "chemistry_electrochemistry": 1.0,
  "chemistry_chemical_kinetics": 1.0,
  "chemistry_surface_chemistry": 0.4,
  "chemistry_coordination_compounds": 0.8,
  "chemistry_d_f_block": 0.8,
  // Chemistry - Daily quiz chapter name variants
  "chemistry_general_organic_chemistry": 0.8,  // Variant of organic_basics/GOC
  "chemistry_p_block_elements": 1.0,           // Variant of p_block
  "chemistry_pblock_elements": 1.0,            // Another variant of p_block
  "chemistry_d_f_block_elements": 0.8,         // Variant of d_f_block
  "chemistry_redox_electrochemistry": 1.0,     // Redox and electrochemistry combined
  "chemistry_alcohols_phenols_ethers": 0.8,    // Full chapter name
  "chemistry_amines_diazonium_salts": 0.8,     // Full chapter name
  "chemistry_carboxylic_acids_derivatives": 0.8, // Full chapter name
  "chemistry_haloalkanes_and_haloarenes": 0.8, // With "and"
  "chemistry_classification_periodicity": 0.6, // Full chapter name
  "chemistry_classification_and_periodicity": 0.6, // With "and" variant
  "chemistry_purification_characterization": 0.6, // Purification chapter
  "chemistry_basic_concepts": 0.8,             // Mole concept, stoichiometry (important foundation)
  "chemistry_principles_of_practical_chemistry": 0.4, // Practical chemistry, significant figures

  // Mathematics (~22 chapters) - Original format
  "mathematics_sets_relations": 0.6,
  "mathematics_complex_numbers": 1.0,
  "mathematics_quadratic_equations": 0.8,
  "mathematics_permutations_combinations": 0.8,
  "mathematics_binomial_theorem": 0.8,
  "mathematics_sequences_series": 0.8,
  "mathematics_matrices_determinants": 1.0,
  "mathematics_limits_continuity": 1.0,
  "mathematics_differentiation": 1.0,
  "mathematics_applications_derivatives": 1.0,
  "mathematics_integration": 1.0,
  "mathematics_applications_integrals": 0.8,
  "mathematics_differential_equations": 0.8,
  "mathematics_coordinate_geometry": 1.0,
  "mathematics_straight_lines": 0.8,
  "mathematics_circles": 1.0,
  "mathematics_conic_sections": 1.0,
  "mathematics_3d_geometry": 0.8,
  "mathematics_vectors": 1.0,
  "mathematics_probability": 1.0,
  "mathematics_statistics": 0.6,
  "mathematics_trigonometry": 0.8,
  // Mathematics - Daily quiz chapter name variants
  "mathematics_limits_continuity_differentiability": 1.0, // Variant of limits_continuity
  "mathematics_permutations_and_combinations": 0.8,       // With "and"
  "mathematics_sequences_and_series": 0.8,                // With "and"
  "mathematics_sets_relations_functions": 0.6,            // Full chapter name
  "mathematics_differential_calculus_aod": 1.0,           // AOD = Application of Derivatives
  "mathematics_integral_calculus_indefinite": 1.0,        // Indefinite integrals
  "mathematics_integral_calculus_definite_area": 0.8,     // Definite integrals + area
  "mathematics_conic_sections_ellipse_hyperbola": 1.0,    // Full chapter name
  "mathematics_conic_sections_parabola": 1.0,             // Parabola-specific conic sections
  "mathematics_parabola": 1.0,                            // Parabola standalone
  "mathematics_vector_algebra": 1.0,                      // Variant of vectors
  "mathematics_threedimensional_geometry": 0.8,           // Full name variant of 3d_geometry
  "mathematics_inverse_trigonometry": 0.6                 // Inverse trigonometric functions
};

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

/**
 * Standard normal CDF approximation (Abramowitz and Stegun)
 * Returns P(Z <= z) where Z ~ N(0, 1)
 */
function normalCDF(z) {
  const t = 1 / (1 + 0.2316419 * Math.abs(z));
  const d = 0.3989423 * Math.exp(-z * z / 2);
  const p = d * t * (0.3193815 + t * (-0.3565638 + t * (1.781478 + t * (-1.821256 + t * 1.330274))));

  if (z > 0) {
    return 1 - p;
  } else {
    return p;
  }
}

/**
 * Inverse normal CDF (percentile point function)
 * Returns z such that P(Z <= z) = p
 */
function normalInverseCDF(p) {
  // Clamp p to [0.0001, 0.9999] to avoid edge cases
  p = Math.max(0.0001, Math.min(0.9999, p));

  // Approximation using Beasley-Springer-Moro algorithm
  const a = [0, -3.969683028665376e+01, 2.209460984245205e+02, -2.759285104469687e+02, 1.383577518672690e+02, -3.066479806614716e+01, 2.506628277459239e+00];
  const b = [0, -5.447609879822406e+01, 1.615858368580409e+02, -1.556989798598866e+02, 6.680131188771972e+01, -1.328068155288572e+01];
  const c = [0, -7.784894002430293e-03, -3.223964580411365e-01, -2.400758277161838e+00, -2.549732539343734e+00, 4.374664141464968e+00, 2.938163982698783e+00];
  const d = [0, 7.784695709041462e-03, 3.224671290700398e-01, 2.445134137142996e+00, 3.754408661907416e+00];

  let q = p - 0.5;
  let r, z;

  if (Math.abs(q) < 0.425) {
    r = 0.180625 - q * q;
    z = q * (((((a[1] * r + a[2]) * r + a[3]) * r + a[4]) * r + a[5]) * r + a[6]) /
      (((((b[1] * r + b[2]) * r + b[3]) * r + b[4]) * r + b[5]) * r + 1);
  } else {
    r = q > 0 ? 1 - p : p;
    r = Math.sqrt(-Math.log(r));
    z = (((((c[1] * r + c[2]) * r + c[3]) * r + c[4]) * r + c[5]) * r + c[6]) /
      ((((d[1] * r + d[2]) * r + d[3]) * r + d[4]) * r + 1);
    if (q < 0) z = -z;
  }

  return z;
}

// ============================================================================
// CORE THETA FUNCTIONS
// ============================================================================

/**
 * Enforce hard bounds on theta [-3.0, +3.0]
 */
function boundTheta(theta) {
  return Math.max(THETA_MIN, Math.min(THETA_MAX, theta));
}

/**
 * Convert theta to percentile using standard normal CDF
 * θ ~ N(0, 1) approximately
 * 
 * @param {number} theta - Ability estimate [-3, +3]
 * @returns {number} Percentile [0, 100]
 */
function thetaToPercentile(theta) {
  const percentile = normalCDF(theta) * 100;
  return Math.round(Math.max(0, Math.min(100, percentile)) * 100) / 100; // 2 decimal places
}

/**
 * Convert percentile to theta (inverse of thetaToPercentile)
 * 
 * @param {number} percentile - Percentile [0, 100]
 * @returns {number} Theta estimate [-3, +3]
 */
function percentileToTheta(percentile) {
  const p = percentile / 100;
  const theta = normalInverseCDF(p);
  return boundTheta(theta);
}

/**
 * Convert raw accuracy to initial theta estimate
 * Based on empirical IRT calibration curves
 * 
 * @param {number} accuracy - Proportion correct [0, 1]
 * @param {number} numQuestions - Number of questions (affects confidence in extreme scores)
 * @returns {number} Initial theta estimate [-3, +3]
 */
function accuracyToThetaMapping(accuracy, numQuestions = 1) {
  // Handle extreme cases
  if (accuracy === 1.0) {
    return numQuestions >= 5 ? 2.0 : 1.5;
  } else if (accuracy === 0.0) {
    return numQuestions >= 5 ? -2.0 : -1.5;
  }

  // Standard mapping based on accuracy ranges
  if (accuracy < 0.20) {
    return -2.5;  // Very weak foundation
  } else if (accuracy < 0.40) {
    return -1.5;  // Below average, major gaps
  } else if (accuracy < 0.60) {
    return -0.5;  // Slightly below average
  } else if (accuracy < 0.75) {
    return 0.5;   // Above average
  } else if (accuracy < 0.90) {
    return 1.5;   // Strong performance
  } else {
    return 2.5;  // Excellent (90%+ accuracy)
  }
}

/**
 * Calculate standard error (confidence interval) for theta estimate
 * More questions + accuracy near 0.5 = more informative = lower SE
 * 
 * @param {number} numQuestions - Number of questions answered in topic
 * @param {number} accuracy - Proportion correct [0, 1]
 * @returns {number} Standard error [0.15, 0.6]
 */
function calculateInitialSE(numQuestions, accuracy) {
  if (numQuestions <= 0) {
    return SE_CEILING; // Maximum uncertainty
  }

  // Maximum likelihood estimation variance formula (simplified)
  // SE decreases with sqrt(n)
  const baseSE = 1.0 / Math.sqrt(numQuestions);

  // Adjust for informativeness: accuracy near 50% is most informative
  // (provides most information about ability level)
  const informationPenalty = 1 + Math.abs(accuracy - 0.5);

  let SE = baseSE * informationPenalty;

  // Clamp to typical range: [0.15, 0.6] and round to 3 decimal places
  return Math.round(Math.max(SE_FLOOR, Math.min(SE_CEILING, SE)) * 1000) / 1000;
}

/**
 * Calculate WEIGHTED overall theta by JEE chapter importance
 * 
 * @param {Object} thetaByChapter - Dict of {chapter_key: {theta, ...}}
 * @returns {number} Weighted overall theta
 */
function calculateWeightedOverallTheta(thetaByChapter) {
  if (Object.keys(thetaByChapter).length === 0) {
    return 0.0;
  }

  let weightedSum = 0;
  let totalWeight = 0;

  for (const [chapterKey, data] of Object.entries(thetaByChapter)) {
    const weight = JEE_CHAPTER_WEIGHTS[chapterKey] || DEFAULT_CHAPTER_WEIGHT;
    weightedSum += data.theta * weight;
    totalWeight += weight;
  }

  if (totalWeight === 0) {
    console.warn(
      'Total weight is 0 for weighted overall theta calculation. ' +
      'All chapters may have weight 0 or no chapters provided.'
    );
    return 0.0;
  }

  return boundTheta(weightedSum / totalWeight);
}

/**
 * Calculate overall theta as simple average (equal weights for all chapters)
 * DEPRECATED: Use calculateWeightedOverallTheta instead
 * Kept for backward compatibility
 * 
 * @param {Object} thetaEstimates - Dict of {chapter_key: {theta, ...}}
 * @returns {number} Overall theta (average)
 */
function calculateOverallTheta(thetaEstimates) {
  // For backward compatibility, delegate to weighted version
  // This maintains the same interface but uses weights
  return calculateWeightedOverallTheta(thetaEstimates);
}

/**
 * Format chapter key from subject and chapter name
 * Example: "Physics", "Laws of Motion" -> "physics_laws_of_motion"
 *
 * @param {string} subject - Subject name
 * @param {string} chapter - Chapter name
 * @returns {string} Chapter key
 */
function formatChapterKey(subject, chapter) {
  let subjectLower = subject.toLowerCase().trim();

  // Defensive check: if subject looks like an already-formed key (contains underscores followed by more text),
  // extract just the subject portion. This handles cases where a chapter key is mistakenly passed as subject.
  // Valid subjects are: physics, chemistry, mathematics, maths, math
  const validSubjects = ['physics', 'chemistry', 'mathematics', 'maths', 'math'];
  if (subjectLower.includes('_')) {
    const possibleSubject = subjectLower.split('_')[0];
    if (validSubjects.includes(possibleSubject)) {
      console.warn(
        `formatChapterKey received what looks like a chapter key as subject: "${subject}". ` +
        `Extracting subject: "${possibleSubject}"`
      );
      subjectLower = possibleSubject;
    }
  }

  // Normalize subject name variations
  if (subjectLower === 'math' || subjectLower === 'maths') {
    subjectLower = 'mathematics';
  }

  let chapterLower = chapter.toLowerCase().trim()
    .replace(/[^a-z0-9\s]/g, '')  // Remove special characters
    .replace(/\s+/g, '_');         // Replace spaces with underscores

  // Apply normalization if chapter name matches a known variation
  const normalizedChapter = CHAPTER_NAME_NORMALIZATIONS[chapterLower];
  if (normalizedChapter) {
    chapterLower = normalizedChapter;
  }

  const chapterKey = `${subjectLower}_${chapterLower}`;

  // Log warning if chapter key doesn't exist in weights (for debugging)
  if (!JEE_CHAPTER_WEIGHTS[chapterKey] && !chapterKey.includes('unknown')) {
    console.warn(
      `Chapter key "${chapterKey}" (from "${subject}" / "${chapter}") not found in JEE_CHAPTER_WEIGHTS. ` +
      `Using default weight ${DEFAULT_CHAPTER_WEIGHT}.`
    );
  }

  return chapterKey;
}

/**
 * Get subject from chapter key
 * Example: "physics_laws_of_motion" -> "physics"
 * 
 * @param {string} chapterKey - Chapter key identifier
 * @returns {string} Subject name
 */
function getSubjectFromChapter(chapterKey) {
  if (chapterKey.startsWith('physics_')) return 'physics';
  if (chapterKey.startsWith('chemistry_')) return 'chemistry';
  if (chapterKey.startsWith('mathematics_') || chapterKey.startsWith('maths_')) return 'mathematics';
  return 'unknown';
}

/**
 * Calculate subject balance (distribution of questions across Physics, Chemistry, Math)
 * 
 * @param {Object} thetaEstimates - Dict of {chapter_key: {attempts, ...}}
 * @returns {Object} Dict of {subject: proportion}
 */
/**
 * Calculate subject-level theta from chapter thetas
 * 
 * @param {Object} thetaByChapter - Dict of {chapter_key: {theta, attempts, ...}}
 * @param {string} subject - Subject name ('physics', 'chemistry', 'mathematics')
 * @returns {Object} Subject theta data
 */
function calculateSubjectTheta(thetaByChapter, subject) {
  const subjectChapters = Object.entries(thetaByChapter)
    .filter(([key, _]) => key.startsWith(`${subject}_`));

  if (subjectChapters.length === 0) {
    return {
      theta: null,
      percentile: null,
      status: 'not_tested',
      message: 'No questions answered in this subject during assessment',
      chapters_tested: 0,
      total_attempts: 0,
      weak_chapters: [],
      strong_chapters: []
    };
  }

  // Calculate weighted average
  let weightedSum = 0;
  let totalWeight = 0;
  let totalAttempts = 0;

  for (const [chapterKey, data] of subjectChapters) {
    // Validate data structure and theta value
    if (!data || typeof data !== 'object') {
      console.warn(`Chapter ${chapterKey} has invalid data structure, skipping`);
      continue;
    }

    if (typeof data.theta !== 'number' || isNaN(data.theta) || !isFinite(data.theta)) {
      console.warn(
        `Chapter ${chapterKey} has invalid theta: ${data.theta}, skipping. ` +
        `Expected a finite number.`
      );
      continue;
    }

    const weight = JEE_CHAPTER_WEIGHTS[chapterKey] || DEFAULT_CHAPTER_WEIGHT;
    weightedSum += data.theta * weight;
    totalWeight += weight;
    totalAttempts += (data.attempts || 0);
  }

  // Validate we have at least one valid chapter
  if (totalWeight === 0) {
    console.warn(
      `Subject ${subject} has no valid chapters with theta values. ` +
      `All chapters may have invalid data.`
    );
  }

  const subjectTheta = totalWeight > 0 ? weightedSum / totalWeight : 0.0;

  // Identify weak and strong chapters
  const sortedChapters = subjectChapters.sort((a, b) => a[1].theta - b[1].theta);
  const weakChapters = sortedChapters
    .filter(([_, data]) => data.theta < 0)
    .slice(0, 3)
    .map(([key, _]) => key);
  const strongChapters = sortedChapters
    .filter(([_, data]) => data.theta > 0.5)
    .slice(-3)
    .map(([key, _]) => key);

  return {
    theta: boundTheta(subjectTheta),
    percentile: thetaToPercentile(subjectTheta),
    status: 'tested',
    chapters_tested: subjectChapters.length,
    total_attempts: totalAttempts,
    weak_chapters: weakChapters,
    strong_chapters: strongChapters.reverse()
  };
}

/**
 * Calculate subject balance (distribution of attempts across subjects)
 * 
 * @param {Object} thetaEstimates - Dict of {chapter_key: {attempts, ...}}
 * @returns {Object} Dict of {subject: proportion}
 */
function calculateSubjectBalance(thetaEstimates) {
  const subjectCounts = { physics: 0, chemistry: 0, mathematics: 0 };

  for (const [chapterKey, data] of Object.entries(thetaEstimates)) {
    const subject = getSubjectFromChapter(chapterKey);
    if (subject in subjectCounts) {
      subjectCounts[subject] += data.attempts || 0;
    }
  }

  const total = subjectCounts.physics + subjectCounts.chemistry + subjectCounts.mathematics;

  if (total === 0) {
    return { physics: 1 / 3, chemistry: 1 / 3, mathematics: 1 / 3 };
  }

  return {
    physics: Math.round((subjectCounts.physics / total) * 1000) / 1000,
    chemistry: Math.round((subjectCounts.chemistry / total) * 1000) / 1000,
    mathematics: Math.round((subjectCounts.mathematics / total) * 1000) / 1000
  };
}

// ============================================================================
// EXPORTS
// ============================================================================

module.exports = {
  // Core functions
  boundTheta,
  thetaToPercentile,
  percentileToTheta,
  accuracyToThetaMapping,
  calculateInitialSE,
  calculateOverallTheta, // Backward compatibility
  calculateWeightedOverallTheta,
  calculateSubjectTheta,

  // Helper functions
  formatChapterKey,
  getSubjectFromChapter,
  calculateSubjectBalance,

  // Broad-to-specific chapter mapping functions
  isBroadChapter,
  getSpecificChapters,
  expandBroadChaptersToSpecific,

  // Constants
  THETA_MIN,
  THETA_MAX,
  SE_FLOOR,
  SE_CEILING,
  JEE_CHAPTER_WEIGHTS,
  DEFAULT_CHAPTER_WEIGHT,
  CHAPTER_NAME_NORMALIZATIONS,
  BROAD_TO_SPECIFIC_CHAPTER_MAP
};
