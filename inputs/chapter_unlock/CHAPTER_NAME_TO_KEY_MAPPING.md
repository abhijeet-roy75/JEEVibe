# Chapter Name to Database Key Mapping

## How to Use This File

1. Find the chapter name from your JSON (e.g., "Units & Measurements")
2. Replace `{"name": "Units & Measurements"}` with the database key string
3. Final format should be: `"physics_units_measurements"` (just the string, no object)

---

## PHYSICS CHAPTERS

### 11th Grade Physics

| Chapter Name in JSON | Database Key (use this) |
|---------------------|-------------------------|
| Units & Measurements | `physics_units_measurements` |
| Kinematics | `physics_kinematics` |
| Laws of Motion | `physics_laws_of_motion` |
| Work, Energy & Power | `physics_work_energy_and_power` |
| Rotational Motion | `physics_rotational_motion` |
| Gravitation | `physics_gravitation` |
| Properties of Solids & Liquids | `physics_properties_of_solids_liquids` |
| Thermodynamics | `physics_thermodynamics` |
| Kinetic Theory of Gases | `physics_kinetic_theory_of_gases` |
| Oscillations & Waves | `physics_oscillations_waves` |

### 12th Grade Physics

| Chapter Name in JSON | Database Key (use this) |
|---------------------|-------------------------|
| Electrostatics | `physics_electrostatics` |
| Current Electricity | `physics_current_electricity` |
| Magnetic Effects & Magnetism | `physics_magnetic_effects_magnetism` |
| EMI & AC Circuits | `physics_electromagnetic_induction` |
| EM Waves | `physics_electromagnetic_waves` |
| Optics | `physics_optics` |
| Dual Nature of Radiation | `physics_dual_nature_of_radiation` |
| Atoms & Nuclei | `physics_atoms_nuclei` |
| Electronic Devices | `physics_electronic_devices` |

**Note**: "EMI & AC Circuits" maps to `physics_electromagnetic_induction`. AC Circuits has a separate key `physics_ac_circuits` if needed.

---

## CHEMISTRY CHAPTERS

### 11th Grade Chemistry

| Chapter Name in JSON | Database Key (use this) |
|---------------------|-------------------------|
| Basic Concepts | `chemistry_basic_concepts` |
| Atomic Structure | `chemistry_atomic_structure` |
| Chemical Bonding | `chemistry_chemical_bonding` |
| Classification & Periodicity | `chemistry_classification_and_periodicity` |
| Equilibrium | `chemistry_equilibrium` |
| Thermodynamics | `chemistry_thermodynamics` |
| Redox & Electrochemistry | `chemistry_redox_electrochemistry` |
| p-Block Elements | `chemistry_p_block_elements` |
| Basic Principles (GOC) | `chemistry_general_organic_chemistry` |
| Hydrocarbons | `chemistry_hydrocarbons` |

### 12th Grade Chemistry

| Chapter Name in JSON | Database Key (use this) |
|---------------------|-------------------------|
| Solutions | `chemistry_solutions` |
| Redox & Electrochemistry | `chemistry_redox_electrochemistry` |
| Chemical Kinetics | `chemistry_chemical_kinetics` |
| d & f Block Elements | `chemistry_d_f_block_elements` |
| Coordination Compounds | `chemistry_coordination_compounds` |
| p-Block Elements | `chemistry_p_block_elements` |
| Haloalkanes & Haloarenes | `chemistry_haloalkanes_and_haloarenes` |
| Alcohols, Phenols & Ethers | `chemistry_alcohols_phenols_ethers` |
| Aldehydes & Ketones | `chemistry_aldehydes_ketones` |
| Carboxylic Acids & Derivatives | `chemistry_carboxylic_acids_derivatives` |
| Amines & Diazonium Salts | `chemistry_amines_diazonium_salts` |
| Biomolecules | `chemistry_biomolecules` |

---

## MATHEMATICS CHAPTERS

### 11th Grade Mathematics

| Chapter Name in JSON | Database Key (use this) |
|---------------------|-------------------------|
| Sets, Relations & Functions | `mathematics_sets_relations_functions` |
| Trigonometry | `mathematics_trigonometry` |
| Complex Numbers | `mathematics_complex_numbers` |
| Permutations & Combinations | `mathematics_permutations_and_combinations` |
| Binomial Theorem | `mathematics_binomial_theorem` |
| Sequences & Series | `mathematics_sequences_and_series` |
| Straight Lines | `mathematics_straight_lines` |
| Conic Sections (Parabola) | `mathematics_conic_sections_parabola` |
| Conic Sections (Ellipse & Hyperbola) | `mathematics_conic_sections_ellipse_hyperbola` |
| 3D Geometry | `mathematics_three_dimensional_geometry` |
| Limits, Continuity & Differentiability | `mathematics_limits_continuity_differentiability` |
| Statistics | `mathematics_statistics` |
| Probability | `mathematics_probability` |

### 12th Grade Mathematics

| Chapter Name in JSON | Database Key (use this) |
|---------------------|-------------------------|
| Inverse Trigonometry | `mathematics_inverse_trigonometry` |
| Matrices & Determinants | `mathematics_matrices_determinants` |
| Limits, Continuity & Differentiability | `mathematics_limits_continuity_differentiability` |
| Differential Calculus (AOD) | `mathematics_differential_calculus_aod` |
| Integral Calculus (Indefinite) | `mathematics_integral_calculus_indefinite` |
| Integral Calculus (Definite & Area) | `mathematics_integral_calculus_definite_area` |
| Differential Equations | `mathematics_differential_equations` |
| Vector Algebra | `mathematics_vector_algebra` |
| 3D Geometry | `mathematics_three_dimensional_geometry` |
| Probability | `mathematics_probability` |

---

## EXAMPLE BEFORE & AFTER

### ❌ BEFORE (Current format with objects):

```json
"month_1": {
  "physics": [
    { "name": "Units & Measurements" },
    { "name": "Kinematics" }
  ],
  "chemistry": [
    { "name": "Basic Concepts" },
    { "name": "Atomic Structure" }
  ],
  "mathematics": [
    { "name": "Sets, Relations & Functions" }
  ]
}
```

### ✅ AFTER (Correct format with database keys):

```json
"month_1": {
  "physics": [
    "physics_units_measurements",
    "physics_kinematics"
  ],
  "chemistry": [
    "chemistry_basic_concepts",
    "chemistry_atomic_structure"
  ],
  "mathematics": [
    "mathematics_sets_relations_functions"
  ]
}
```

---

## SPECIAL NOTES

### Duplicate Chapter Names

Some chapters appear in both 11th and 12th but use the **SAME database key**:

1. **Thermodynamics**:
   - 11th Grade Chemistry → `chemistry_thermodynamics`
   - (No separate 12th version)

2. **Limits, Continuity & Differentiability**:
   - Both 11th and 12th Math → `mathematics_limits_continuity_differentiability`

3. **Probability**:
   - Both 11th and 12th Math → `mathematics_probability`

4. **3D Geometry**:
   - Both 11th and 12th Math → `mathematics_three_dimensional_geometry`

5. **Redox & Electrochemistry**:
   - 11th Grade Chemistry → `chemistry_redox_electrochemistry`
   - 12th Grade Chemistry → `chemistry_redox_electrochemistry` (same key)

### Missing from Database

These chapters are NOT found in your database (67 total, your JSON has some that don't exist):

- ❌ "EMI & AC Circuits" as combined - use `physics_electromagnetic_induction` instead
- ⚠️ Verify if `physics_ac_circuits` should be added separately if you want AC Circuits distinct

---

## COMPLETE MONTH-BY-MONTH MAPPING

Based on your current JSON structure:

### Month 1
```json
"physics": [
  "physics_units_measurements",
  "physics_kinematics"
],
"chemistry": [
  "chemistry_basic_concepts",
  "chemistry_atomic_structure"
],
"mathematics": [
  "mathematics_sets_relations_functions"
]
```

### Month 2
```json
"physics": [],
"chemistry": [
  "chemistry_chemical_bonding"
],
"mathematics": [
  "mathematics_trigonometry"
]
```

### Month 3
```json
"physics": [
  "physics_laws_of_motion",
  "physics_work_energy_and_power"
],
"chemistry": [
  "chemistry_classification_and_periodicity"
],
"mathematics": [
  "mathematics_complex_numbers",
  "mathematics_permutations_and_combinations"
]
```

### Month 4
```json
"physics": [
  "physics_rotational_motion"
],
"chemistry": [
  "chemistry_equilibrium"
],
"mathematics": [
  "mathematics_binomial_theorem",
  "mathematics_sequences_and_series"
]
```

### Month 5
```json
"physics": [
  "physics_gravitation"
],
"chemistry": [
  "chemistry_thermodynamics"
],
"mathematics": [
  "mathematics_straight_lines"
]
```

### Month 6
```json
"physics": [
  "physics_properties_of_solids_liquids",
  "physics_thermodynamics"
],
"chemistry": [
  "chemistry_redox_electrochemistry",
  "chemistry_p_block_elements"
],
"mathematics": [
  "mathematics_conic_sections_parabola"
]
```

### Month 7
```json
"physics": [
  "physics_kinetic_theory_of_gases",
  "physics_oscillations_waves"
],
"chemistry": [
  "chemistry_general_organic_chemistry"
],
"mathematics": [
  "mathematics_conic_sections_ellipse_hyperbola",
  "mathematics_three_dimensional_geometry"
]
```

### Month 8
```json
"physics": [],
"chemistry": [
  "chemistry_hydrocarbons"
],
"mathematics": [
  "mathematics_limits_continuity_differentiability",
  "mathematics_statistics"
]
```

### Month 9
```json
"physics": [],
"chemistry": [],
"mathematics": [
  "mathematics_probability"
]
```

### Month 10 (Revision)
```json
"physics": [],
"chemistry": [],
"mathematics": []
```

### Month 11
```json
"physics": [
  "physics_electrostatics"
],
"chemistry": [
  "chemistry_solutions"
],
"mathematics": [
  "mathematics_inverse_trigonometry"
]
```

### Month 12
```json
"physics": [
  "physics_current_electricity"
],
"chemistry": [
  "chemistry_redox_electrochemistry",
  "chemistry_chemical_kinetics"
],
"mathematics": [
  "mathematics_matrices_determinants"
]
```

### Month 13
```json
"physics": [
  "physics_magnetic_effects_magnetism"
],
"chemistry": [
  "chemistry_d_f_block_elements",
  "chemistry_coordination_compounds"
],
"mathematics": [
  "mathematics_limits_continuity_differentiability",
  "mathematics_differential_calculus_aod"
]
```

### Month 14
```json
"physics": [
  "physics_electromagnetic_induction"
],
"chemistry": [
  "chemistry_p_block_elements"
],
"mathematics": [
  "mathematics_integral_calculus_indefinite"
]
```

### Month 15
```json
"physics": [
  "physics_electromagnetic_waves",
  "physics_optics"
],
"chemistry": [
  "chemistry_haloalkanes_and_haloarenes"
],
"mathematics": [
  "mathematics_integral_calculus_definite_area"
]
```

### Month 16
```json
"physics": [],
"chemistry": [
  "chemistry_alcohols_phenols_ethers"
],
"mathematics": [
  "mathematics_differential_equations"
]
```

### Month 17
```json
"physics": [
  "physics_dual_nature_of_radiation",
  "physics_atoms_nuclei"
],
"chemistry": [
  "chemistry_aldehydes_ketones"
],
"mathematics": [
  "mathematics_vector_algebra",
  "mathematics_three_dimensional_geometry"
]
```

### Month 18
```json
"physics": [
  "physics_electronic_devices"
],
"chemistry": [
  "chemistry_carboxylic_acids_derivatives",
  "chemistry_amines_diazonium_salts"
],
"mathematics": [
  "mathematics_probability"
]
```

### Month 19
```json
"physics": [],
"chemistry": [
  "chemistry_biomolecules"
],
"mathematics": []
```

### Months 20-24 (Revision)
```json
"physics": [],
"chemistry": [],
"mathematics": []
```

---

## ✅ VALIDATION CHECKLIST

After updating your JSON:

- [ ] All `{"name": "..."}` objects replaced with plain strings
- [ ] All strings use exact database keys (copy-paste from tables above)
- [ ] Month keys are lowercase: `month_1` not `Month_1` ✓ (already done)
- [ ] Empty arrays `[]` for revision months ✓ (already done for months 10, 20-24)
- [ ] No trailing commas in JSON
- [ ] File is valid JSON (use JSONLint.com to validate)

---

## 🎯 Quick Find & Replace Guide

If using VS Code or text editor with regex find/replace:

**Step 1**: Remove all `{"name": "` prefixes
- Find: `\{\s*"name":\s*"`
- Replace: `"`

**Step 2**: Remove all `"}` suffixes from chapter objects
- Find: `"\s*\}`
- Replace: `"`

**Step 3**: Manually replace chapter names with database keys using tables above

OR just copy-paste the complete month-by-month mapping from this document!
