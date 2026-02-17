#!/usr/bin/env node
/**
 * Chapter Mapping Analysis Script
 *
 * Analyzes the mismatch between initial assessment chapter names
 * and daily quiz chapter names to suggest proper mapping.
 */

require('dotenv').config();
const { db } = require('../src/config/firebase');

async function analyzeChapterMapping() {
  console.log('=' .repeat(70));
  console.log('📊 Chapter Mapping Analysis');
  console.log('=' .repeat(70));
  console.log();

  try {
    // Get assessment chapters
    const assessmentSnapshot = await db.collection('initial_assessment_questions').get();
    const assessmentChapters = new Map();

    assessmentSnapshot.forEach(doc => {
      const data = doc.data();
      const subject = data.subject || 'Unknown';
      const chapter = data.chapter || 'Unknown';
      const key = `${subject}|||${chapter}`;

      if (!assessmentChapters.has(key)) {
        assessmentChapters.set(key, { subject, chapter, count: 0, questionIds: [] });
      }
      assessmentChapters.get(key).count++;
      assessmentChapters.get(key).questionIds.push(doc.id);
    });

    // Get daily quiz chapters
    const questionsSnapshot = await db.collection('questions').get();
    const dailyChapters = new Map();

    questionsSnapshot.forEach(doc => {
      const data = doc.data();
      const subject = data.subject || 'Unknown';
      const chapter = data.chapter || 'Unknown';
      const chapterKey = data.chapter_key || `${subject.toLowerCase()}_${chapter.toLowerCase().replace(/[^a-z0-9]+/g, '_')}`;
      const key = `${subject}|||${chapter}`;

      if (!dailyChapters.has(key)) {
        dailyChapters.set(key, { subject, chapter, chapterKey, count: 0 });
      }
      dailyChapters.get(key).count++;
    });

    // Group daily chapters by subject
    const dailyBySubject = {
      Physics: [],
      Chemistry: [],
      Mathematics: []
    };

    dailyChapters.forEach((data, key) => {
      const subj = data.subject;
      if (dailyBySubject[subj]) {
        dailyBySubject[subj].push(data);
      }
    });

    // Sort by count
    Object.values(dailyBySubject).forEach(arr => arr.sort((a, b) => b.count - a.count));

    // Print assessment chapters
    console.log('📋 INITIAL ASSESSMENT CHAPTERS (what students are tested on):\n');

    const assessmentBySubject = { Physics: [], Chemistry: [], Mathematics: [] };
    assessmentChapters.forEach((data, key) => {
      if (assessmentBySubject[data.subject]) {
        assessmentBySubject[data.subject].push(data);
      }
    });

    for (const [subj, chapters] of Object.entries(assessmentBySubject)) {
      console.log(`   ${subj}:`);
      chapters.forEach(ch => {
        console.log(`     - "${ch.chapter}" (${ch.count} questions)`);
      });
    }
    console.log();

    // Print daily quiz chapters
    console.log('📋 DAILY QUIZ CHAPTERS (available for practice):\n');

    for (const [subj, chapters] of Object.entries(dailyBySubject)) {
      console.log(`   ${subj}: (${chapters.length} chapters)`);
      chapters.slice(0, 15).forEach(ch => {
        console.log(`     - "${ch.chapter}" → ${ch.chapterKey} (${ch.count} questions)`);
      });
      if (chapters.length > 15) {
        console.log(`     ... and ${chapters.length - 15} more chapters`);
      }
      console.log();
    }

    // Suggest mappings
    console.log('=' .repeat(70));
    console.log('📝 SUGGESTED CHAPTER MAPPINGS');
    console.log('=' .repeat(70));
    console.log();
    console.log('The assessment uses BROAD chapter names, daily quiz uses SPECIFIC names.');
    console.log('Here are the suggested mappings:\n');

    const suggestedMappings = {
      'Physics / Mechanics': [
        'physics_kinematics',
        'physics_laws_of_motion',
        'physics_work_energy_and_power',
        'physics_rotational_motion',
        'physics_gravitation',
        'physics_properties_of_solids_liquids'
      ],
      'Physics / Magnetism': [
        'physics_magnetic_effects_magnetism'
      ],
      'Physics / Modern Physics': [
        'physics_atoms_nuclei',
        'physics_dual_nature_of_radiation',
        'physics_electronic_devices'
      ],
      'Chemistry / Physical Chemistry': [
        'chemistry_thermodynamics',
        'chemistry_equilibrium',
        'chemistry_solutions',
        'chemistry_chemical_kinetics',
        'chemistry_atomic_structure',
        'chemistry_redox_electrochemistry'
      ],
      'Chemistry / Organic Chemistry': [
        'chemistry_general_organic_chemistry',
        'chemistry_hydrocarbons',
        'chemistry_aldehydes_ketones',
        'chemistry_alcohols_phenols_ethers',
        'chemistry_amines_diazonium_salts',
        'chemistry_carboxylic_acids_derivatives',
        'chemistry_haloalkanes_and_haloarenes',
        'chemistry_biomolecules'
      ],
      'Chemistry / Inorganic Chemistry': [
        'chemistry_p_block_elements',
        'chemistry_d_f_block_elements',
        'chemistry_coordination_compounds',
        'chemistry_classification_periodicity',
        'chemistry_chemical_bonding'
      ],
      'Mathematics / Algebra': [
        'mathematics_complex_numbers',
        'mathematics_matrices_determinants',
        'mathematics_permutations_and_combinations',
        'mathematics_binomial_theorem',
        'mathematics_sequences_and_series',
        'mathematics_sets_relations_functions'
      ],
      'Mathematics / Calculus': [
        'mathematics_limits_continuity_differentiability',
        'mathematics_differential_calculus_aod',
        'mathematics_integral_calculus_indefinite',
        'mathematics_integral_calculus_definite_area',
        'mathematics_differential_equations'
      ],
      'Mathematics / Coordinate Geometry': [
        'mathematics_straight_lines',
        'mathematics_circles',
        'mathematics_conic_sections_ellipse_hyperbola',
        'mathematics_3d_geometry'
      ]
    };

    for (const [broad, specifics] of Object.entries(suggestedMappings)) {
      console.log(`   ${broad}:`);
      specifics.forEach(s => {
        const match = dailyBySubject[broad.split(' / ')[0]]?.find(ch => ch.chapterKey === s);
        const count = match ? match.count : 0;
        const status = count > 0 ? '✅' : '❌';
        console.log(`     ${status} ${s} (${count} questions)`);
      });
      console.log();
    }

    // Code suggestion
    console.log('=' .repeat(70));
    console.log('💻 CODE CHANGE OPTIONS');
    console.log('=' .repeat(70));
    console.log();
    console.log('OPTION 1: Update thetaCalculationService.js CHAPTER_NAME_NORMALIZATIONS');
    console.log('         to map broad names to specific chapter_keys\n');

    console.log('OPTION 2: Update initial_assessment_questions in Firestore');
    console.log('         to use specific chapter names matching daily quiz\n');

    console.log('OPTION 3 (RECOMMENDED): Create a broad-to-specific mapping function');
    console.log('         that distributes assessment results across related chapters\n');

  } catch (error) {
    console.error('Error:', error.message);
    process.exit(1);
  }
}

analyzeChapterMapping()
  .then(() => process.exit(0))
  .catch(err => {
    console.error(err);
    process.exit(1);
  });
