/**
 * Chapter Key Formatter Utility
 *
 * Centralized chapter name normalization and formatting logic.
 * This utility ensures consistent chapter key generation across all services.
 *
 * Created: 2026-02-13
 * Reason: Eliminate code duplication across 6+ services
 *
 * Usage:
 *   const { formatChapterKey, chapterKeyToDisplayName } = require('../utils/chapterKeyFormatter');
 *   const key = formatChapterKey('Physics', 'Laws of Motion');
 *   // Returns: "physics_laws_of_motion"
 */

const logger = require('./logger');

// Chapter name normalizations (consolidate similar chapter names)
const CHAPTER_NAME_NORMALIZATIONS = {
  // Physics
  'law_of_motion': 'laws_of_motion',
  'newton_law': 'laws_of_motion',
  'newtons_laws': 'laws_of_motion',
  'work_energy_power': 'work_power_energy',
  'work_and_energy': 'work_power_energy',
  'center_of_mass': 'system_of_particles',
  'rotational_motion': 'rotation',
  'simple_harmonic_motion': 'shm',
  'wave_motion': 'waves',
  'heat_transfer': 'thermal_properties',
  'thermodynamic': 'thermodynamics',
  'kinetic_theory_of_gases': 'kinetic_theory',
  'electric_field': 'electrostatics',
  'electric_potential': 'electrostatics',
  'magnetic_field': 'magnetism',
  'electromagnetic_wave': 'electromagnetic_waves',
  'ray_optic': 'ray_optics',
  'wave_optic': 'wave_optics',
  'dual_nature': 'dual_nature_of_radiation',
  'atom': 'atoms',
  'nucleus': 'nuclei',
  'semiconductor': 'semiconductors',

  // Chemistry
  'atomic_structure': 'structure_of_atom',
  'periodic_table': 'periodic_properties',
  'chemical_bond': 'chemical_bonding',
  'states_of_matter': 'gaseous_state',
  'thermochemistry': 'thermodynamics',
  'chemical_equilibria': 'equilibrium',
  'ionic_equilibrium': 'equilibrium',
  'redox_reaction': 'redox_reactions',
  'electrochemistry': 'electrochemistry',
  'surface_chemistry': 'surface_chemistry',
  's_block': 's_block_elements',
  'p_block': 'p_block_elements',
  'd_block': 'd_and_f_block_elements',
  'f_block': 'd_and_f_block_elements',
  'coordination_compound': 'coordination_compounds',
  'organic_chemistry_basic': 'basic_principles_organic',
  'hydrocarbon': 'hydrocarbons',
  'halogen_derivative': 'haloalkanes_haloarenes',
  'alcohol_phenol_ether': 'alcohols_phenols_ethers',
  'aldehyde_ketone': 'aldehydes_ketones_carboxylic_acids',
  'carboxylic_acid': 'aldehydes_ketones_carboxylic_acids',
  'organic_nitrogen': 'nitrogen_compounds',
  'amine': 'nitrogen_compounds',
  'biomolecule': 'biomolecules',
  'polymer': 'polymers',
  'chemistry_in_everyday_life': 'chemistry_everyday_life',

  // Mathematics
  'set_relation_function': 'sets_relations_functions',
  'complex_number': 'complex_numbers',
  'quadratic_equation': 'quadratic_equations',
  'sequence_series': 'sequences_and_series',
  'permutation_combination': 'permutations_combinations',
  'binomial_theorem': 'binomial_theorem',
  'straight_line': 'straight_lines',
  'conic_section': 'conic_sections',
  'circle': 'circles',
  '3d_geometry': 'three_d_geometry',
  'vector_algebra': 'vectors',
  'trigonometry': 'trigonometric_functions',
  'inverse_trigonometric_function': 'inverse_trigonometric_functions',
  'limit_continuity': 'limits_and_continuity',
  'differentiation': 'derivatives',
  'application_of_derivative': 'applications_of_derivatives',
  'indefinite_integral': 'integrals',
  'definite_integral': 'definite_integrals',
  'application_of_integral': 'applications_of_integrals',
  'differential_equation': 'differential_equations',
  'probability': 'probability',
  'statistics': 'statistics',
  'mathematical_reasoning': 'mathematical_reasoning',
  'linear_programming': 'linear_programming'
};

/**
 * Format a chapter key from subject and chapter name
 *
 * Rules:
 * 1. Convert to lowercase
 * 2. Remove special characters
 * 3. Replace spaces with underscores
 * 4. Apply normalization for known variations
 * 5. Ensure format: {subject}_{chapter}
 *
 * @param {string} subject - Subject name (Physics, Chemistry, Mathematics)
 * @param {string} chapter - Chapter name (Laws of Motion, Kinematics, etc.)
 * @returns {string} Formatted chapter key (physics_laws_of_motion)
 */
function formatChapterKey(subject, chapter) {
  let subjectLower = subject.toLowerCase().trim();

  // Defensive check: if subject looks like an already-formed key
  const validSubjects = ['physics', 'chemistry', 'mathematics', 'maths', 'math'];
  if (subjectLower.includes('_')) {
    const possibleSubject = subjectLower.split('_')[0];
    if (validSubjects.includes(possibleSubject)) {
      logger.warn('formatChapterKey: Subject looks like chapter key', {
        input_subject: subject,
        extracted_subject: possibleSubject
      });
      subjectLower = possibleSubject;
    }
  }

  // Normalize subject name variations
  if (subjectLower === 'math' || subjectLower === 'maths') {
    subjectLower = 'mathematics';
  }

  // Normalize chapter name
  let chapterLower = chapter.toLowerCase().trim()
    .replace(/[^a-z0-9\s]/g, '')  // Remove special characters
    .replace(/\s+/g, '_');         // Replace spaces with underscores

  // Apply normalization if chapter name matches a known variation
  const normalizedChapter = CHAPTER_NAME_NORMALIZATIONS[chapterLower];
  if (normalizedChapter) {
    chapterLower = normalizedChapter;
  }

  const chapterKey = `${subjectLower}_${chapterLower}`;

  return chapterKey;
}

/**
 * Convert chapter key to display name
 *
 * Example: physics_laws_of_motion → Laws Of Motion
 *
 * @param {string} chapterKey - Chapter key (physics_laws_of_motion)
 * @returns {string} Display name (Laws Of Motion)
 */
function chapterKeyToDisplayName(chapterKey) {
  return chapterKey
    .replace(/^(physics|chemistry|maths|mathematics)_/, '') // Remove subject prefix
    .split('_')
    .map(word => word.charAt(0).toUpperCase() + word.slice(1))
    .join(' ');
}

/**
 * Extract subject from chapter key
 *
 * Example: physics_laws_of_motion → physics
 *
 * @param {string} chapterKey - Chapter key (physics_laws_of_motion)
 * @returns {string} Subject (physics)
 */
function extractSubjectFromChapterKey(chapterKey) {
  const subject = chapterKey.split('_')[0];
  if (['physics', 'chemistry', 'mathematics'].includes(subject)) {
    return subject;
  }
  logger.warn('extractSubjectFromChapterKey: Invalid subject in key', { chapterKey });
  return 'unknown';
}

/**
 * Normalize subject name
 *
 * Handles variations like: Math → Mathematics, Maths → Mathematics
 *
 * @param {string} subject - Subject name
 * @returns {string} Normalized subject name
 */
function normalizeSubjectName(subject) {
  const lower = subject.toLowerCase().trim();
  if (lower === 'math' || lower === 'maths') {
    return 'mathematics';
  }
  if (['physics', 'chemistry', 'mathematics'].includes(lower)) {
    return lower;
  }
  logger.warn('normalizeSubjectName: Unknown subject', { subject });
  return subject;
}

/**
 * Validate chapter key format
 *
 * Valid format: {subject}_{chapter} where subject is physics|chemistry|mathematics
 *
 * @param {string} chapterKey - Chapter key to validate
 * @returns {boolean} True if valid, false otherwise
 */
function isValidChapterKey(chapterKey) {
  if (!chapterKey || typeof chapterKey !== 'string') {
    return false;
  }

  const parts = chapterKey.split('_');
  if (parts.length < 2) {
    return false;
  }

  const subject = parts[0];
  return ['physics', 'chemistry', 'mathematics'].includes(subject);
}

module.exports = {
  formatChapterKey,
  chapterKeyToDisplayName,
  extractSubjectFromChapterKey,
  normalizeSubjectName,
  isValidChapterKey,
  CHAPTER_NAME_NORMALIZATIONS
};
