# Master Chapter List for JEEVibe

Use these exact chapter names when uploading questions to ensure consistency across the assessment and daily quiz systems.

## Chemistry (21 chapters)

| Chapter Name | Current Question Count |
|--------------|------------------------|
| Alcohols, Phenols & Ethers | 45 |
| Aldehydes & Ketones | 60 |
| Amines & Diazonium Salts | 40 |
| Atomic Structure | 35 |
| Basic Concepts | 25 |
| Biomolecules | 30 |
| Carboxylic Acids & Derivatives | 40 |
| Chemical Bonding | 50 |
| Chemical Kinetics | 35 |
| Classification & Periodicity | 35 |
| Coordination Compounds | 45 |
| d & f Block Elements | 45 |
| Equilibrium | 55 |
| General Organic Chemistry | 50 |
| Haloalkanes and Haloarenes | 40 |
| Hydrocarbons | 50 |
| p-Block Elements | 55 |
| Principles of Practical Chemistry | 20 |
| Purification & Characterization | 20 |
| Redox & Electrochemistry | 50 |
| Solutions | 40 |
| Thermodynamics | 107 |

**Total Chemistry: 922 questions**

---

## Mathematics (20 chapters)

| Chapter Name | Current Question Count |
|--------------|------------------------|
| 3D Geometry | 55 |
| Binomial Theorem | 25 |
| Circles | 35 |
| Complex Numbers | 50 |
| Conic Sections (Ellipse & Hyperbola) | 40 |
| Differential Calculus (AOD) | 40 |
| Differential Equations | 39 |
| Integral Calculus (Definite & Area) | 50 |
| Integral Calculus (Indefinite) | 50 |
| Inverse Trigonometry | 28 |
| Limits, Continuity & Differentiability | 50 |
| Matrices & Determinants | 50 |
| Permutations and Combinations | 35 |
| Probability | 51 |
| Sequences and Series | 25 |
| Sets, Relations & Functions | 28 |
| Statistics | 25 |
| Straight Lines | 35 |
| Trigonometry | 35 |
| Vector Algebra | 40 |

**Total Mathematics: 786 questions**

---

## Physics (23 chapters)

| Chapter Name | Current Question Count |
|--------------|------------------------|
| AC Circuits | 22 |
| Atoms & Nuclei | 40 |
| Current Electricity | 50 |
| Dual Nature of Radiation | 23 |
| Eddy Currents | 3 ⚠️ |
| Electromagnetic Induction | 21 |
| Electromagnetic Waves | 25 |
| Electronic Devices | 28 |
| Electrostatics | 55 |
| Experimental Skills | 20 |
| Gravitation | 35 |
| Kinematics | 61 |
| Kinetic Theory of Gases | 25 |
| Laws of Motion | 70 |
| Magnetic Effects & Magnetism | 49 |
| Optics | 50 |
| Oscillations & Waves | 40 |
| Properties of Solids & Liquids | 42 |
| Rotational Motion | 90 |
| Thermodynamics | 107 (shared with Chemistry) |
| Transformers | 4 ⚠️ |
| Units & Measurements | 30 |
| Work, Energy and Power | 35 |

**Total Physics: 868 questions**

---

## Chapters Needing More Questions

These chapters have critically low question counts:

| Chapter | Subject | Count | Priority |
|---------|---------|-------|----------|
| Eddy Currents | Physics | 3 | CRITICAL |
| Transformers | Physics | 4 | CRITICAL |
| Principles of Practical Chemistry | Chemistry | 20 | LOW |
| Purification & Characterization | Chemistry | 20 | LOW |
| Experimental Skills | Physics | 20 | LOW |

---

## Recommended Minimums

- **Initial Assessment**: 2-3 questions per chapter minimum
- **Daily Quiz Bank**: 20+ questions per chapter for good variety
- **Ideal Coverage**: 40-50 questions per chapter for adaptive difficulty

---

## Data Upload Format

When uploading questions, ensure each question has:

```json
{
  "question_id": "UNIQUE_ID",
  "subject": "Chemistry" | "Mathematics" | "Physics",
  "chapter": "Exact chapter name from this list",
  "difficulty": "easy" | "medium" | "hard",
  "question_text": "...",
  "options": [...],
  "correct_option": 0-3,
  "solution": "..."
}
```

**Important**: Use exact chapter names as listed above. Case and spelling must match exactly.
