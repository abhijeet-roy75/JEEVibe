/**
 * JEE Chapter Weightage Configuration
 * 
 * Based on analysis of JEE Main & JEE Advanced papers (2019-2024)
 * 
 * Weight Scale:
 *   1.0  = High Priority   (8-12 marks in JEE Main, frequently tested)
 *   0.8  = Medium-High     (6-8 marks, regularly tested)
 *   0.6  = Medium Priority (4-6 marks, moderate frequency)
 *   0.4  = Low-Medium      (2-4 marks, occasionally tested)
 *   0.3  = Low Priority    (0-2 marks, rarely tested)
 * 
 * @version 1.0
 * @author Dr. Amara Chen
 * @lastUpdated December 2024
 */

// ============================================================================
// PHYSICS CHAPTERS (Total: ~21 chapters, 100 marks in JEE Main)
// ============================================================================

const PHYSICS_CHAPTERS = {
  // MECHANICS (35-40% of Physics = ~35-40 marks)
  "physics_kinematics": {
    weight: 1.0,
    jee_main_marks: "8-12",
    jee_advanced_frequency: "High",
    topics: ["Motion in 1D", "Motion in 2D", "Projectile Motion", "Relative Motion"],
    priority: "HIGH"
  },
  "physics_laws_of_motion": {
    weight: 1.0,
    jee_main_marks: "8-12",
    jee_advanced_frequency: "High",
    topics: ["Newton's Laws", "Friction", "Circular Motion", "Pseudo Forces"],
    priority: "HIGH"
  },
  "physics_work_energy_power": {
    weight: 1.0,
    jee_main_marks: "8-12",
    jee_advanced_frequency: "High",
    topics: ["Work-Energy Theorem", "Conservation of Energy", "Power", "Collisions"],
    priority: "HIGH"
  },
  "physics_rotational_motion": {
    weight: 1.0,
    jee_main_marks: "8-12",
    jee_advanced_frequency: "Very High",
    topics: ["Moment of Inertia", "Angular Momentum", "Rolling Motion", "Torque"],
    priority: "HIGH"
  },
  "physics_gravitation": {
    weight: 0.6,
    jee_main_marks: "4-8",
    jee_advanced_frequency: "Medium",
    topics: ["Newton's Law of Gravitation", "Orbital Motion", "Kepler's Laws", "Escape Velocity"],
    priority: "MEDIUM"
  },
  "physics_properties_of_matter": {
    weight: 0.6,
    jee_main_marks: "4-8",
    jee_advanced_frequency: "Medium",
    topics: ["Elasticity", "Fluid Mechanics", "Surface Tension", "Viscosity"],
    priority: "MEDIUM"
  },
  
  // THERMODYNAMICS & KINETIC THEORY (10-12% of Physics)
  "physics_thermodynamics": {
    weight: 0.8,
    jee_main_marks: "8-12",
    jee_advanced_frequency: "High",
    topics: ["Laws of Thermodynamics", "Heat Engines", "Entropy", "Thermodynamic Processes"],
    priority: "HIGH"
  },
  "physics_kinetic_theory": {
    weight: 0.6,
    jee_main_marks: "4-8",
    jee_advanced_frequency: "Medium",
    topics: ["Kinetic Theory of Gases", "Degrees of Freedom", "Mean Free Path"],
    priority: "MEDIUM"
  },
  
  // WAVES & OSCILLATIONS (8-10% of Physics)
  "physics_oscillations": {
    weight: 0.8,
    jee_main_marks: "4-8",
    jee_advanced_frequency: "High",
    topics: ["SHM", "Damped Oscillations", "Forced Oscillations", "Resonance"],
    priority: "MEDIUM-HIGH"
  },
  "physics_waves": {
    weight: 0.8,
    jee_main_marks: "4-8",
    jee_advanced_frequency: "High",
    topics: ["Wave Motion", "Superposition", "Standing Waves", "Doppler Effect"],
    priority: "MEDIUM-HIGH"
  },
  
  // ELECTROMAGNETISM (25-30% of Physics = ~25-30 marks)
  "physics_electrostatics": {
    weight: 1.0,
    jee_main_marks: "8-12",
    jee_advanced_frequency: "Very High",
    topics: ["Coulomb's Law", "Electric Field", "Gauss's Law", "Capacitors"],
    priority: "HIGH"
  },
  "physics_current_electricity": {
    weight: 1.0,
    jee_main_marks: "8-12",
    jee_advanced_frequency: "High",
    topics: ["Ohm's Law", "Kirchhoff's Laws", "RC Circuits", "Electrical Instruments"],
    priority: "HIGH"
  },
  "physics_magnetic_effects": {
    weight: 1.0,
    jee_main_marks: "8-12",
    jee_advanced_frequency: "High",
    topics: ["Biot-Savart Law", "Ampere's Law", "Lorentz Force", "Magnetic Materials"],
    priority: "HIGH"
  },
  "physics_electromagnetic_induction": {
    weight: 1.0,
    jee_main_marks: "8-12",
    jee_advanced_frequency: "High",
    topics: ["Faraday's Law", "Lenz's Law", "Self/Mutual Inductance", "LC Oscillations"],
    priority: "HIGH"
  },
  "physics_ac_circuits": {
    weight: 0.6,
    jee_main_marks: "4-8",
    jee_advanced_frequency: "Medium",
    topics: ["AC Fundamentals", "LCR Circuits", "Resonance", "Transformers"],
    priority: "MEDIUM"
  },
  "physics_electromagnetic_waves": {
    weight: 0.4,
    jee_main_marks: "2-4",
    jee_advanced_frequency: "Low",
    topics: ["EM Spectrum", "Properties of EM Waves"],
    priority: "LOW"
  },
  
  // OPTICS (8-10% of Physics)
  "physics_ray_optics": {
    weight: 0.8,
    jee_main_marks: "4-8",
    jee_advanced_frequency: "High",
    topics: ["Reflection", "Refraction", "Lenses", "Optical Instruments"],
    priority: "MEDIUM-HIGH"
  },
  "physics_wave_optics": {
    weight: 0.8,
    jee_main_marks: "4-8",
    jee_advanced_frequency: "High",
    topics: ["Interference", "Diffraction", "Polarization", "Young's Double Slit"],
    priority: "MEDIUM-HIGH"
  },
  
  // MODERN PHYSICS (10-12% of Physics)
  "physics_dual_nature": {
    weight: 0.6,
    jee_main_marks: "4-8",
    jee_advanced_frequency: "Medium",
    topics: ["Photoelectric Effect", "de Broglie Wavelength", "Electron Microscope"],
    priority: "MEDIUM"
  },
  "physics_atoms_nuclei": {
    weight: 0.6,
    jee_main_marks: "4-8",
    jee_advanced_frequency: "Medium",
    topics: ["Bohr Model", "Radioactivity", "Nuclear Reactions", "Mass-Energy"],
    priority: "MEDIUM"
  },
  "physics_semiconductors": {
    weight: 0.4,
    jee_main_marks: "4-8",
    jee_advanced_frequency: "Low",
    topics: ["PN Junction", "Diodes", "Transistors", "Logic Gates"],
    priority: "LOW-MEDIUM"
  }
};

// ============================================================================
// CHEMISTRY CHAPTERS (Total: ~27 chapters, 100 marks in JEE Main)
// ============================================================================

const CHEMISTRY_CHAPTERS = {
  // PHYSICAL CHEMISTRY (35-40% of Chemistry)
  "chemistry_atomic_structure": {
    weight: 0.8,
    jee_main_marks: "4-8",
    jee_advanced_frequency: "High",
    topics: ["Quantum Numbers", "Electronic Configuration", "Periodic Properties"],
    priority: "MEDIUM-HIGH"
  },
  "chemistry_chemical_bonding": {
    weight: 1.0,
    jee_main_marks: "8-12",
    jee_advanced_frequency: "Very High",
    topics: ["VSEPR", "MOT", "Hybridization", "Hydrogen Bonding"],
    priority: "HIGH"
  },
  "chemistry_states_of_matter": {
    weight: 0.6,
    jee_main_marks: "4-8",
    jee_advanced_frequency: "Medium",
    topics: ["Gas Laws", "Kinetic Theory", "Liquefaction", "Critical Constants"],
    priority: "MEDIUM"
  },
  "chemistry_thermodynamics": {
    weight: 1.0,
    jee_main_marks: "8-12",
    jee_advanced_frequency: "High",
    topics: ["Enthalpy", "Entropy", "Gibbs Energy", "Thermochemistry"],
    priority: "HIGH"
  },
  "chemistry_equilibrium": {
    weight: 1.0,
    jee_main_marks: "8-12",
    jee_advanced_frequency: "Very High",
    topics: ["Chemical Equilibrium", "Ionic Equilibrium", "pH", "Buffer Solutions"],
    priority: "HIGH"
  },
  "chemistry_redox_reactions": {
    weight: 0.6,
    jee_main_marks: "4-8",
    jee_advanced_frequency: "Medium",
    topics: ["Oxidation States", "Balancing Redox", "Electrochemical Series"],
    priority: "MEDIUM"
  },
  "chemistry_solutions": {
    weight: 0.8,
    jee_main_marks: "4-8",
    jee_advanced_frequency: "High",
    topics: ["Concentration Terms", "Colligative Properties", "Raoult's Law"],
    priority: "MEDIUM-HIGH"
  },
  "chemistry_electrochemistry": {
    weight: 1.0,
    jee_main_marks: "8-12",
    jee_advanced_frequency: "High",
    topics: ["Nernst Equation", "Electrolysis", "Galvanic Cells", "Conductance"],
    priority: "HIGH"
  },
  "chemistry_chemical_kinetics": {
    weight: 1.0,
    jee_main_marks: "8-12",
    jee_advanced_frequency: "High",
    topics: ["Rate Laws", "Order of Reaction", "Arrhenius Equation", "Catalysis"],
    priority: "HIGH"
  },
  "chemistry_surface_chemistry": {
    weight: 0.4,
    jee_main_marks: "2-4",
    jee_advanced_frequency: "Low",
    topics: ["Adsorption", "Colloids", "Emulsions", "Catalysis"],
    priority: "LOW"
  },
  "chemistry_solid_state": {
    weight: 0.6,
    jee_main_marks: "4-8",
    jee_advanced_frequency: "Medium",
    topics: ["Crystal Structures", "Unit Cells", "Defects", "Electrical Properties"],
    priority: "MEDIUM"
  },
  
  // INORGANIC CHEMISTRY (25-30% of Chemistry)
  "chemistry_classification_elements": {
    weight: 0.6,
    jee_main_marks: "4-8",
    jee_advanced_frequency: "Medium",
    topics: ["Periodic Table", "Periodic Trends", "Ionization Energy", "Electronegativity"],
    priority: "MEDIUM"
  },
  "chemistry_hydrogen": {
    weight: 0.3,
    jee_main_marks: "0-4",
    jee_advanced_frequency: "Low",
    topics: ["Isotopes", "Preparation", "Compounds of Hydrogen"],
    priority: "LOW"
  },
  "chemistry_s_block": {
    weight: 0.6,
    jee_main_marks: "4-8",
    jee_advanced_frequency: "Medium",
    topics: ["Alkali Metals", "Alkaline Earth Metals", "Compounds"],
    priority: "MEDIUM"
  },
  "chemistry_p_block": {
    weight: 1.0,
    jee_main_marks: "8-16",
    jee_advanced_frequency: "Very High",
    topics: ["Group 13-18 Elements", "Compounds", "Reactions"],
    priority: "HIGH"
  },
  "chemistry_d_f_block": {
    weight: 0.8,
    jee_main_marks: "4-8",
    jee_advanced_frequency: "High",
    topics: ["Transition Elements", "Lanthanides", "Actinides", "Properties"],
    priority: "MEDIUM-HIGH"
  },
  "chemistry_coordination_compounds": {
    weight: 0.8,
    jee_main_marks: "4-8",
    jee_advanced_frequency: "High",
    topics: ["Werner's Theory", "Isomerism", "VBT", "CFT"],
    priority: "MEDIUM-HIGH"
  },
  
  // ORGANIC CHEMISTRY (30-35% of Chemistry)
  "chemistry_organic_basics": {
    weight: 0.8,
    jee_main_marks: "4-8",
    jee_advanced_frequency: "High",
    topics: ["IUPAC Nomenclature", "Isomerism", "Electronic Effects", "Reaction Mechanisms"],
    priority: "HIGH"
  },
  "chemistry_hydrocarbons": {
    weight: 0.8,
    jee_main_marks: "4-8",
    jee_advanced_frequency: "High",
    topics: ["Alkanes", "Alkenes", "Alkynes", "Aromatic Compounds"],
    priority: "MEDIUM-HIGH"
  },
  "chemistry_haloalkanes": {
    weight: 0.8,
    jee_main_marks: "4-8",
    jee_advanced_frequency: "High",
    topics: ["SN1/SN2", "Elimination", "Grignard Reagents", "Polyhalogen Compounds"],
    priority: "MEDIUM-HIGH"
  },
  "chemistry_alcohols_phenols": {
    weight: 0.8,
    jee_main_marks: "4-8",
    jee_advanced_frequency: "High",
    topics: ["Preparation", "Reactions", "Acidity", "Ethers"],
    priority: "MEDIUM-HIGH"
  },
  "chemistry_aldehydes_ketones": {
    weight: 1.0,
    jee_main_marks: "8-12",
    jee_advanced_frequency: "Very High",
    topics: ["Nucleophilic Addition", "Aldol Condensation", "Cannizzaro", "Named Reactions"],
    priority: "HIGH"
  },
  "chemistry_carboxylic_acids": {
    weight: 0.8,
    jee_main_marks: "4-8",
    jee_advanced_frequency: "High",
    topics: ["Acidity", "Derivatives", "Reactions", "Amides"],
    priority: "MEDIUM-HIGH"
  },
  "chemistry_amines": {
    weight: 0.8,
    jee_main_marks: "4-8",
    jee_advanced_frequency: "High",
    topics: ["Basicity", "Preparation", "Diazonium Salts", "Coupling Reactions"],
    priority: "MEDIUM-HIGH"
  },
  "chemistry_biomolecules": {
    weight: 0.4,
    jee_main_marks: "4-8",
    jee_advanced_frequency: "Low",
    topics: ["Carbohydrates", "Proteins", "Nucleic Acids", "Vitamins"],
    priority: "LOW-MEDIUM"
  },
  "chemistry_polymers": {
    weight: 0.4,
    jee_main_marks: "2-4",
    jee_advanced_frequency: "Low",
    topics: ["Types of Polymers", "Polymerization", "Commercial Polymers"],
    priority: "LOW"
  },
  "chemistry_environmental_chemistry": {
    weight: 0.3,
    jee_main_marks: "0-4",
    jee_advanced_frequency: "Very Low",
    topics: ["Pollution", "Greenhouse Effect", "Ozone Depletion"],
    priority: "LOW"
  }
};

// ============================================================================
// MATHEMATICS CHAPTERS (Total: ~22 chapters, 100 marks in JEE Main)
// ============================================================================

const MATHEMATICS_CHAPTERS = {
  // ALGEBRA (30-35% of Mathematics)
  "mathematics_sets_relations": {
    weight: 0.6,
    jee_main_marks: "4-8",
    jee_advanced_frequency: "Medium",
    topics: ["Set Operations", "Relations", "Functions", "Equivalence Relations"],
    priority: "MEDIUM"
  },
  "mathematics_complex_numbers": {
    weight: 1.0,
    jee_main_marks: "8-12",
    jee_advanced_frequency: "Very High",
    topics: ["Argand Plane", "De Moivre's Theorem", "Roots of Unity", "Geometry with Complex Numbers"],
    priority: "HIGH"
  },
  "mathematics_quadratic_equations": {
    weight: 0.8,
    jee_main_marks: "4-8",
    jee_advanced_frequency: "High",
    topics: ["Nature of Roots", "Symmetric Functions", "Location of Roots", "Inequalities"],
    priority: "MEDIUM-HIGH"
  },
  "mathematics_permutations_combinations": {
    weight: 0.8,
    jee_main_marks: "4-8",
    jee_advanced_frequency: "High",
    topics: ["Counting Principles", "Arrangements", "Selections", "Distribution"],
    priority: "MEDIUM-HIGH"
  },
  "mathematics_binomial_theorem": {
    weight: 0.8,
    jee_main_marks: "4-8",
    jee_advanced_frequency: "High",
    topics: ["General Term", "Properties", "Multinomial Theorem", "Applications"],
    priority: "MEDIUM-HIGH"
  },
  "mathematics_sequences_series": {
    weight: 0.8,
    jee_main_marks: "4-8",
    jee_advanced_frequency: "High",
    topics: ["AP", "GP", "HP", "AGP", "Special Series", "Summation"],
    priority: "MEDIUM-HIGH"
  },
  "mathematics_matrices_determinants": {
    weight: 1.0,
    jee_main_marks: "8-12",
    jee_advanced_frequency: "Very High",
    topics: ["Matrix Operations", "Inverse", "System of Equations", "Properties of Determinants"],
    priority: "HIGH"
  },
  
  // CALCULUS (35-40% of Mathematics)
  "mathematics_limits_continuity": {
    weight: 1.0,
    jee_main_marks: "8-12",
    jee_advanced_frequency: "Very High",
    topics: ["Standard Limits", "L'Hopital's Rule", "Continuity", "Intermediate Value Theorem"],
    priority: "HIGH"
  },
  "mathematics_differentiation": {
    weight: 1.0,
    jee_main_marks: "8-12",
    jee_advanced_frequency: "Very High",
    topics: ["First Principles", "Chain Rule", "Implicit Differentiation", "Higher Order Derivatives"],
    priority: "HIGH"
  },
  "mathematics_applications_derivatives": {
    weight: 1.0,
    jee_main_marks: "8-12",
    jee_advanced_frequency: "Very High",
    topics: ["Tangent/Normal", "Maxima/Minima", "Monotonicity", "Mean Value Theorems"],
    priority: "HIGH"
  },
  "mathematics_integration": {
    weight: 1.0,
    jee_main_marks: "8-12",
    jee_advanced_frequency: "Very High",
    topics: ["Indefinite Integrals", "Definite Integrals", "Techniques", "Properties"],
    priority: "HIGH"
  },
  "mathematics_applications_integrals": {
    weight: 0.8,
    jee_main_marks: "4-8",
    jee_advanced_frequency: "High",
    topics: ["Area Under Curves", "Volume of Revolution", "Arc Length"],
    priority: "MEDIUM-HIGH"
  },
  "mathematics_differential_equations": {
    weight: 0.8,
    jee_main_marks: "4-8",
    jee_advanced_frequency: "High",
    topics: ["First Order", "Linear Equations", "Homogeneous", "Applications"],
    priority: "MEDIUM-HIGH"
  },
  
  // COORDINATE GEOMETRY (15-20% of Mathematics)
  "mathematics_straight_lines": {
    weight: 0.8,
    jee_main_marks: "4-8",
    jee_advanced_frequency: "High",
    topics: ["Forms of Lines", "Angle Between Lines", "Distance", "Family of Lines"],
    priority: "MEDIUM-HIGH"
  },
  "mathematics_circles": {
    weight: 1.0,
    jee_main_marks: "8-12",
    jee_advanced_frequency: "Very High",
    topics: ["Equations", "Tangent/Normal", "Family of Circles", "Radical Axis"],
    priority: "HIGH"
  },
  "mathematics_conic_sections": {
    weight: 1.0,
    jee_main_marks: "8-12",
    jee_advanced_frequency: "Very High",
    topics: ["Parabola", "Ellipse", "Hyperbola", "Tangent/Normal", "Chord of Contact"],
    priority: "HIGH"
  },
  
  // VECTORS & 3D (10-12% of Mathematics)
  "mathematics_vectors": {
    weight: 1.0,
    jee_main_marks: "8-12",
    jee_advanced_frequency: "High",
    topics: ["Vector Algebra", "Dot Product", "Cross Product", "Triple Products"],
    priority: "HIGH"
  },
  "mathematics_3d_geometry": {
    weight: 0.8,
    jee_main_marks: "4-8",
    jee_advanced_frequency: "High",
    topics: ["Direction Cosines", "Planes", "Lines in 3D", "Shortest Distance"],
    priority: "MEDIUM-HIGH"
  },
  
  // STATISTICS & PROBABILITY (8-10% of Mathematics)
  "mathematics_probability": {
    weight: 1.0,
    jee_main_marks: "8-12",
    jee_advanced_frequency: "Very High",
    topics: ["Conditional Probability", "Bayes' Theorem", "Random Variables", "Distributions"],
    priority: "HIGH"
  },
  "mathematics_statistics": {
    weight: 0.6,
    jee_main_marks: "4-8",
    jee_advanced_frequency: "Medium",
    topics: ["Mean", "Median", "Mode", "Standard Deviation", "Variance"],
    priority: "MEDIUM"
  },
  
  // TRIGONOMETRY (8-10% of Mathematics)
  "mathematics_trigonometry": {
    weight: 0.8,
    jee_main_marks: "4-8",
    jee_advanced_frequency: "High",
    topics: ["Identities", "Equations", "Inverse Trigonometry", "Properties of Triangles"],
    priority: "MEDIUM-HIGH"
  }
};

// ============================================================================
// COMBINED CHAPTER WEIGHTS (Flat object for algorithm use)
// ============================================================================

const JEE_CHAPTER_WEIGHTS = {};

// Add Physics chapters
for (const [key, value] of Object.entries(PHYSICS_CHAPTERS)) {
  JEE_CHAPTER_WEIGHTS[key] = value.weight;
}

// Add Chemistry chapters
for (const [key, value] of Object.entries(CHEMISTRY_CHAPTERS)) {
  JEE_CHAPTER_WEIGHTS[key] = value.weight;
}

// Add Mathematics chapters
for (const [key, value] of Object.entries(MATHEMATICS_CHAPTERS)) {
  JEE_CHAPTER_WEIGHTS[key] = value.weight;
}

// Default weight for chapters not in the list
const DEFAULT_CHAPTER_WEIGHT = 0.5;

// ============================================================================
// SUMMARY STATISTICS
// ============================================================================

const WEIGHTAGE_SUMMARY = {
  physics: {
    total_chapters: Object.keys(PHYSICS_CHAPTERS).length,
    high_priority: Object.values(PHYSICS_CHAPTERS).filter(c => c.weight >= 1.0).length,
    medium_priority: Object.values(PHYSICS_CHAPTERS).filter(c => c.weight >= 0.6 && c.weight < 1.0).length,
    low_priority: Object.values(PHYSICS_CHAPTERS).filter(c => c.weight < 0.6).length,
    avg_weight: (Object.values(PHYSICS_CHAPTERS).reduce((sum, c) => sum + c.weight, 0) / Object.keys(PHYSICS_CHAPTERS).length).toFixed(2)
  },
  chemistry: {
    total_chapters: Object.keys(CHEMISTRY_CHAPTERS).length,
    high_priority: Object.values(CHEMISTRY_CHAPTERS).filter(c => c.weight >= 1.0).length,
    medium_priority: Object.values(CHEMISTRY_CHAPTERS).filter(c => c.weight >= 0.6 && c.weight < 1.0).length,
    low_priority: Object.values(CHEMISTRY_CHAPTERS).filter(c => c.weight < 0.6).length,
    avg_weight: (Object.values(CHEMISTRY_CHAPTERS).reduce((sum, c) => sum + c.weight, 0) / Object.keys(CHEMISTRY_CHAPTERS).length).toFixed(2)
  },
  mathematics: {
    total_chapters: Object.keys(MATHEMATICS_CHAPTERS).length,
    high_priority: Object.values(MATHEMATICS_CHAPTERS).filter(c => c.weight >= 1.0).length,
    medium_priority: Object.values(MATHEMATICS_CHAPTERS).filter(c => c.weight >= 0.6 && c.weight < 1.0).length,
    low_priority: Object.values(MATHEMATICS_CHAPTERS).filter(c => c.weight < 0.6).length,
    avg_weight: (Object.values(MATHEMATICS_CHAPTERS).reduce((sum, c) => sum + c.weight, 0) / Object.keys(MATHEMATICS_CHAPTERS).length).toFixed(2)
  },
  total: {
    total_chapters: Object.keys(JEE_CHAPTER_WEIGHTS).length,
    high_priority_total: Object.values(JEE_CHAPTER_WEIGHTS).filter(w => w >= 1.0).length,
    medium_priority_total: Object.values(JEE_CHAPTER_WEIGHTS).filter(w => w >= 0.6 && w < 1.0).length,
    low_priority_total: Object.values(JEE_CHAPTER_WEIGHTS).filter(w => w < 0.6).length
  }
};

// ============================================================================
// EXPORTS
// ============================================================================

module.exports = {
  // Detailed chapter data
  PHYSICS_CHAPTERS,
  CHEMISTRY_CHAPTERS,
  MATHEMATICS_CHAPTERS,
  
  // Flat weight map (for algorithm use)
  JEE_CHAPTER_WEIGHTS,
  DEFAULT_CHAPTER_WEIGHT,
  
  // Summary
  WEIGHTAGE_SUMMARY
};
