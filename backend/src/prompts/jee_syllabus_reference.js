/**
 * JEE Main 2025 Syllabus Reference
 * Structured topic mapping for Mathematics, Physics, and Chemistry
 * Used to improve topic identification and question generation
 */

const JEE_SYLLABUS = {
  mathematics: {
    unit1: {
      name: "Sets, Relations and Functions",
      topics: [
        "Sets and their representation",
        "Union, intersection and complement of sets",
        "Power set",
        "Relations and types of relations",
        "Equivalence relations",
        "Functions: one-one, into and onto",
        "Composition of functions"
      ]
    },
    unit2: {
      name: "Complex Numbers and Quadratic Equations",
      topics: [
        "Complex numbers as ordered pairs",
        "Representation in form a+ib",
        "Argand diagram",
        "Algebra of complex numbers",
        "Modulus and argument",
        "Quadratic equations in real and complex systems",
        "Relations between roots and coefficients",
        "Nature of roots",
        "Formation of quadratic equations"
      ]
    },
    unit3: {
      name: "Matrices and Determinants",
      topics: [
        "Algebra of matrices",
        "Types of matrices",
        "Determinants of order two and three",
        "Evaluation of determinants",
        "Area of triangles using determinants",
        "Adjoint and inverse of square matrix",
        "Solution of simultaneous linear equations"
      ]
    },
    unit4: {
      name: "Permutations and Combinations",
      topics: [
        "Fundamental principle of counting",
        "Permutations and combinations",
        "P(n, r) and C(n, r)",
        "Simple applications"
      ]
    },
    unit5: {
      name: "Binomial Theorem",
      topics: [
        "Binomial theorem for positive integral index",
        "General term and middle term",
        "Simple applications"
      ]
    },
    unit6: {
      name: "Sequence and Series",
      topics: [
        "Arithmetic and Geometric progressions",
        "Insertion of arithmetic and geometric means",
        "Relation between A.M and G.M"
      ]
    },
    unit7: {
      name: "Limit, Continuity and Differentiability",
      topics: [
        "Real-valued functions",
        "Algebra of functions",
        "Polynomial, rational, trigonometric, logarithmic, exponential functions",
        "Inverse functions",
        "Graphs of simple functions",
        "Limits, continuity and differentiability",
        "Differentiation rules (sum, difference, product, quotient)",
        "Differentiation of trigonometric, inverse trigonometric, logarithmic, exponential functions",
        "Composite and implicit functions",
        "Derivatives of order up to two",
        "Applications: Rate of change, monotonic functions, Maxima and minima"
      ]
    },
    unit8: {
      name: "Integral Calculus",
      topics: [
        "Integral as anti-derivative",
        "Fundamental integrals (algebraic, trigonometric, exponential, logarithmic)",
        "Integration by substitution, by parts, by partial fractions",
        "Integration using trigonometric identities",
        "Standard integrals: ∫dx/(x²+a²), ∫dx/√(x²±a²), ∫dx/(a²-x²), ∫dx/√(a²-x²)",
        "Integrals of type: ∫dx/(ax²+bx+c), ∫dx/√(ax²+bx+c), ∫(px+q)dx/(ax²+bx+c)",
        "Integrals: ∫√(a²±x²)dx, ∫√(x²-a²)dx",
        "Fundamental theorem of calculus",
        "Properties of definite integrals",
        "Evaluation of definite integrals",
        "Areas of regions bounded by curves"
      ]
    },
    unit9: {
      name: "Differential Equations",
      topics: [
        "Ordinary differential equations",
        "Order and degree",
        "Solution by separation of variables",
        "Homogeneous differential equations",
        "Linear differential equations: dy/dx + p(x)y = q(x)"
      ]
    },
    unit10: {
      name: "Co-ordinate Geometry",
      topics: [
        "Cartesian system of rectangular coordinates",
        "Distance formula, section formula",
        "Locus and its equation",
        "Slope of a line",
        "Parallel and perpendicular lines",
        "Intercepts of a line",
        "Equations of a line (various forms)",
        "Intersection of lines",
        "Angles between two lines",
        "Concurrence of three lines",
        "Distance of a point from a line",
        "Centroid, orthocentre, circumcentre of a triangle",
        "Circle: standard and general forms",
        "Equation of circle when endpoints of diameter are given",
        "Points of intersection of line and circle",
        "Conic sections: Parabola, Ellipse, Hyperbola (standard forms)"
      ]
    },
    unit11: {
      name: "Three Dimensional Geometry",
      topics: [
        "Coordinates of a point in space",
        "Distance between two points",
        "Section formula",
        "Direction ratios and direction cosines",
        "Angle between two intersecting lines",
        "Equation of a line",
        "Skew lines",
        "Shortest distance between skew lines"
      ]
    },
    unit12: {
      name: "Vector Algebra",
      topics: [
        "Vectors and scalars",
        "Addition of vectors",
        "Components of a vector in 2D and 3D",
        "Scalar and vector products"
      ]
    },
    unit13: {
      name: "Statistics and Probability",
      topics: [
        "Measures of dispersion",
        "Mean, median, mode (grouped and ungrouped data)",
        "Standard deviation, variance, mean deviation",
        "Probability of an event",
        "Addition and multiplication theorems of probability",
        "Bayes' theorem",
        "Probability distribution of a random variable"
      ]
    },
    unit14: {
      name: "Trigonometry",
      topics: [
        "Trigonometrical identities",
        "Trigonometrical functions",
        "Inverse trigonometrical functions and their properties"
      ]
    }
  },
  physics: {
    unit1: { name: "Units and Measurements", topics: ["SI Units", "Dimensions", "Errors in measurements", "Dimensional analysis", "Least count", "Significant figures"] },
    unit2: { name: "Kinematics", topics: ["Motion in straight line", "Position-time graph", "Velocity-time graph", "Projectile motion", "Uniform circular motion", "Relative velocity", "Vectors"] },
    unit3: { name: "Laws of Motion", topics: ["Newton's laws", "Momentum", "Conservation of linear momentum", "Friction", "Circular motion dynamics", "Inertia", "Impulse"] },
    unit4: { name: "Work, Energy and Power", topics: ["Work-energy theorem", "Potential energy", "Conservation of mechanical energy", "Collisions", "Power", "Spring potential energy"] },
    unit5: { name: "Rotational Motion", topics: ["Centre of mass", "Moment of inertia", "Angular momentum", "Torque", "Rigid body rotation", "Radius of gyration", "Rolling motion"] },
    unit6: { name: "Gravitation", topics: ["Universal law of gravitation", "Kepler's laws", "Gravitational potential", "Escape velocity", "Satellite motion", "Acceleration due to gravity"] },
    unit7: { name: "Properties of Solids and Liquids", topics: ["Elasticity", "Stress-strain", "Hooke's law", "Young's modulus", "Fluid pressure", "Viscosity", "Surface tension", "Heat transfer", "Bernoulli's theorem", "Thermal expansion"] },
    unit8: { name: "Thermodynamics", topics: ["Laws of thermodynamics", "Heat, work, internal energy", "Isothermal and adiabatic processes", "Carnot engine", "Reversible and irreversible processes"] },
    unit9: { name: "Kinetic Theory of Gases", topics: ["Equation of state of a perfect gas", "Work done on compressing a gas", "Kinetic theory of gases", "Degrees of freedom", "Law of equipartition of energy", "Mean free path"] },
    unit10: { name: "Oscillations and Waves", topics: ["Periodic motion", "Simple harmonic motion", "Oscillations of a spring", "Simple pendulum", "Wave motion", "Longitudinal and transverse waves", "Speed of sound", "Doppler effect"] },
    unit11: { name: "Electrostatics", topics: ["Electric charges", "Coulomb's law", "Electric field", "Electric flux", "Gauss's law", "Electric potential", "Capacitors and capacitance", "Dielectrics"] },
    unit12: { name: "Current Electricity", topics: ["Electric current", "Ohm's law", "Electrical resistance", "V-I characteristics", "Kirchhoff's laws", "Wheatstone bridge", "Potentiometer"] },
    unit13: { name: "Magnetic Effects of Current and Magnetism", topics: ["Biot-Savart law", "Ampere's law", "Force on a moving charge", "Cyclotron", "Magnetic dipole", "Earth's magnetic field", "Moving coil galvanometer"] },
    unit14: { name: "Electromagnetic Induction and Alternating Currents", topics: ["Faraday's law", "Lenz's law", "Eddy currents", "Self and mutual inductance", "Alternating currents", "LC oscillations", "LCR series circuit", "Resonance", "Power in AC circuits", "Wattless current", "AC generator", "Transformer"] },
    unit15: { name: "Electromagnetic Waves", topics: ["Displacement current", "Electromagnetic waves and their characteristics", "Electromagnetic spectrum"] },
    unit16: { name: "Optics", topics: ["Reflection and refraction of light", "Total internal reflection", "Lenses", "Lens maker's formula", "Magnification", "Power of a lens", "Dispersion", "Scattering of light", "Optical instruments", "Wave optics", "Interference", "Diffraction", "Polarisation"] },
    unit17: { name: "Dual Nature of Matter and Radiation", topics: ["Photoelectric effect", "Hertz and Lenard's observations", "Einstein's photoelectric equation", "Particle nature of light", "Matter waves", "de Broglie relation"] },
    unit18: { name: "Atoms and Nuclei", topics: ["Alpha-particle scattering experiment", "Rutherford's model of atom", "Bohr model", "Energy levels", "Hydrogen spectrum", "Composition and size of nucleus", "Radioactivity", "Mass-energy relation", "Mass defect", "Nuclear fission and fusion"] },
    unit19: { name: "Electronic Devices", topics: ["Semiconductors", "Semiconductor diode", "I-V characteristics in forward and reverse bias", "Diode as a rectifier", "I-V characteristics of LED, photodiode, solar cell, and Zener diode", "Zener diode as a voltage regulator", "Logic gates"] },
    unit20: { name: "Experimental Skills", topics: ["Vernier callipers", "Screw gauge", "Simple pendulum", "Metre Scale", "Young's modulus", "Surface tension", "Coefficient of viscosity", "Speed of sound", "Specific heat capacity", "Resistivity", "Potentiometer", "Focal length of mirrors and lenses", "Plotting a graph", "Diode characteristics"] },
  },
  unit1: { name: "Some Basic Concepts of Chemistry", topics: ["Matter and its nature", "Dalton's atomic theory", "Concept of atom, molecule, element and compound", "Laws of chemical combination", "Atomic and molecular masses", "Mole concept", "Molar mass", "Percentage composition", "Empirical and molecular formulas", "Chemical equations and stoichiometry"] },
  unit2: { name: "Atomic Structure", topics: ["Discovery of sub-atomic particles", "Thomson and Rutherford atomic models", "Bohr's model", "Quantum mechanical model of atom", "Quantum numbers", "Shapes of s, p, and d orbitals", "Rules for filling electrons in orbitals", "Electronic configuration of atoms", "Stability of half-filled and completely filled orbitals"] },
  unit3: { name: "Chemical Bonding and Molecular Structure", topics: ["Kossel-Lewis approach", "Ionic bond", "Covalent bond", "Bond parameters", "Lewis structure", "Polar character of covalent bond", "Valence Bond Theory", "Resonance", "Geometry of covalent molecules", "VSEPR theory", "Hybridization", "Molecular Orbital Theory", "Hydrogen bonding"] },
  unit4: { name: "Chemical Thermodynamics", topics: ["Fundamentals of thermodynamics", "First law of thermodynamics", "Internal energy and enthalpy", "Heat capacity", "Specific heat", "Measurement of U and H", "Hess's law", "Enthalpy of bond dissociation, combustion, formation, atomization, sublimation, phase transition, ionization, solution and dilution", "Second law of thermodynamics", "Entropy", "Gibbs energy change", "Spontaneity"] },
  unit5: { name: "Solutions", topics: ["Types of solutions", "Expression of concentration", "Solubility", "Vapour pressure", "Raoult's law", "Colligative properties", "Abnormal molecular mass", "Van't Hoff factor"] },
  unit6: { name: "Equilibrium", topics: ["Meaning of equilibrium", "Equilibria in physical processes", "Equilibria in chemical processes", "Law of chemical equilibrium", "Equilibrium constant", "Factors affecting equilibrium", "Le Chatelier's principle", "Ionic equilibrium", "Ionization of acids and bases", "pH scale", "Buffer solutions", "Solubility product", "Common ion effect"] },
  unit7: { name: "Redox Reactions and Electrochemistry", topics: ["Concept of oxidation and reduction", "Redox reactions", "Oxidation number", "Balancing redox reactions", "Conductance in electrolytic solutions", "Specific and molar conductivity", "Kohlrausch's law", "Electrolysis", "Galvanic cells", "Nernst equation", "Gibbs energy change and EMF", "Fuel cells", "Corrosion"] },
  unit8: { name: "Chemical Kinetics", topics: ["Rate of a reaction", "Factors affecting rate of reaction", "Order and molecularity", "Rate law and specific rate constant", "Integrated rate equations", "Half-life", "Concept of collision theory", "Activation energy", "Arrhenius equation"] },
  unit9: { name: "Classification of Elements and Periodicity in Properties", topics: ["Modern periodic law", "Long form of periodic table", "Periodic trends in properties of elements", "Atomic and ionic radii", "Ionization enthalpy", "Electron gain enthalpy", "Electronegativity", "Valence"] },
  unit10: { name: "p-Block Elements", topics: ["Group 13 to Group 18 elements", "General introduction", "Electronic configuration", "Occurrence", "Trends in physical and chemical properties", "Uses"] },
  unit11: { name: "d- and f- Block Elements", topics: ["General introduction", "Electronic configuration", "Occurrence", "Characteristics of transition metals", "Trends in properties", "Lanthanoids", "Actinoids"] },
  unit12: { name: "Coordination Compounds", topics: ["Introduction", "Ligands", "Coordination number", "Color", "Magnetic properties", "Shapes", "IUPAC nomenclature", "Bonding", "Werner's theory", "VBT", "CFT", "Isomerism", "Importance of coordination compounds"] },
  unit13: { name: "Purification and Characterisation of Organic Compounds", topics: ["Purification methods", "Qualitative analysis", "Quantitative analysis", "Calculations of empirical and molecular formulae"] },
  unit14: { name: "Some Basic Principles of Organic Chemistry", topics: ["Tetravalency of carbon", "Shapes of organic compounds", "Structural representations", "Nomenclature", "Isomerism", "Fundamental concepts in organic reaction mechanism", "Electronic displacements", "Types of organic reactions"] },
  unit15: { name: "Hydrocarbons", topics: ["Alkanes", "Alkenes", "Alkynes", "Aromatic hydrocarbons", "Benzene", "Toxicity and carcinogenicity"] },
  unit16: { name: "Organic Compounds Containing Halogens", topics: ["Haloalkanes", "Haloarenes", "Nature of C-X bond", "Physical and chemical properties", "Mechanism of substitution reactions", "Optical rotation", "Environmental effects"] },
  unit17: { name: "Organic Compounds Containing Oxygen", topics: ["Alcohols", "Phenols", "Ethers", "Aldehydes", "Ketones", "Carboxylic acids", "Structure", "Nomenclature", "Methods of preparation", "Physical and chemical properties", "Uses"] },
  unit18: { name: "Organic Compounds Containing Nitrogen", topics: ["Amines", "Diazonium salts", "Structure", "Nomenclature", "Methods of preparation", "Physical and chemical properties", "Uses"] },
  unit19: { name: "Biomolecules", topics: ["Carbohydrates", "Proteins", "Vitamins", "Nucleic acids", "Biological functions"] },
  unit20: { name: "Principles Related to Practical Chemistry", topics: ["Detection of extra elements", "Detection of functional groups", "Chemistry involved in preparation of inorganic compounds", "Chemistry involved in titrimetric exercises", "Chemical principles involved in qualitative salt analysis"] },
};

/**
 * Get topic suggestions based on keywords in question text
 */
function getTopicSuggestions(questionText, subject) {
  const subjectSyllabus = JEE_SYLLABUS[subject.toLowerCase()];
  if (!subjectSyllabus) return null;

  const suggestions = [];
  const lowerText = questionText.toLowerCase();

  // Search through all units and topics
  Object.values(subjectSyllabus).forEach(unit => {
    unit.topics?.forEach(topic => {
      const topicKeywords = topic.toLowerCase().split(/\s+/);
      const matches = topicKeywords.filter(keyword =>
        keyword.length > 3 && lowerText.includes(keyword)
      );
      if (matches.length > 0) {
        suggestions.push({
          unit: unit.name,
          topic: topic,
          relevance: matches.length
        });
      }
    });
  });

  // Sort by relevance and return top matches
  return suggestions
    .sort((a, b) => b.relevance - a.relevance)
    .slice(0, 3)
    .map(s => `${s.unit} - ${s.topic}`);
}

/**
 * Get syllabus-aligned topic name
 */
function getSyllabusAlignedTopic(identifiedTopic, subject) {
  const subjectSyllabus = JEE_SYLLABUS[subject.toLowerCase()];
  if (!subjectSyllabus) return identifiedTopic;

  // Try to match identified topic with syllabus structure
  const lowerIdentified = identifiedTopic.toLowerCase();

  for (const unit of Object.values(subjectSyllabus)) {
    if (unit.name.toLowerCase().includes(lowerIdentified) ||
      lowerIdentified.includes(unit.name.toLowerCase())) {
      return unit.name;
    }

    // Check topics within unit
    if (unit.topics) {
      for (const topic of unit.topics) {
        if (topic.toLowerCase().includes(lowerIdentified) ||
          lowerIdentified.includes(topic.toLowerCase())) {
          return `${unit.name} - ${topic}`;
        }
      }
    }
  }

  return identifiedTopic; // Return as-is if no match
}

module.exports = {
  JEE_SYLLABUS,
  getTopicSuggestions,
  getSyllabusAlignedTopic
};

