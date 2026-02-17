# Backend Scripts

117 utility scripts organized into 6 folders by purpose.

## Folders

| Folder | Scripts | Purpose |
|--------|---------|---------|
| [`cognitive-mastery/`](cognitive-mastery/) | 2 | Cognitive Mastery — upload data, tag questions |
| [`data-upload/`](data-upload/) | 10 | Import question banks, mock tests, content enrichment |
| [`migrations/`](migrations/) | 26 | One-time schema changes, field fixes, data backfills |
| [`user-management/`](user-management/) | 20 | Tier/trial management, user setup, teacher onboarding |
| [`diagnostics/`](diagnostics/) | 52 | Check, verify, audit, debug, analyze (read-only safe) |
| [`notifications/`](notifications/) | 7 | FCM tokens, MPA email reports |

---

## cognitive-mastery/

For Cognitive Mastery feature data. Run in this order for each new chapter drop from the product team:

```bash
# 1. Upload all content (atlas nodes, capsules, pools, questions, skill maps)
node scripts/cognitive-mastery/upload-cognitive-mastery.js --dry-run   # preview first
node scripts/cognitive-mastery/upload-cognitive-mastery.js             # upload data1 (default)
node scripts/cognitive-mastery/upload-cognitive-mastery.js --dir inputs/cognitive_mastery/data2

# 2. Tag existing chapter practice questions with micro_skill_ids
node scripts/cognitive-mastery/tag-questions-micro-skills.js --dry-run
node scripts/cognitive-mastery/tag-questions-micro-skills.js
node scripts/cognitive-mastery/tag-questions-micro-skills.js --chapter physics_electrostatics
```

---

## data-upload/

```bash
node scripts/data-upload/import-question-bank.js              # Import daily quiz questions
node scripts/data-upload/import-question-bank.js --file inputs/question_bank/questions_math.json
node scripts/data-upload/populate-assessment-questions.js     # Populate assessment questions
node scripts/data-upload/createMockTestTemplates.js           # Generate mock test templates
node scripts/data-upload/enrich-questions-why-wrong.js        # Add distractor_analysis via Claude AI
node scripts/data-upload/seed-countdown-schedule.js           # Seed 24-month unlock schedule
node scripts/data-upload/migrate-distractor-analysis.js       # Backfill distractor_analysis from JSON
```

---

## user-management/

```bash
node scripts/user-management/manage-tier.js pro +91XXXXXXXXXX      # Grant Pro tier
node scripts/user-management/manage-tier.js free +91XXXXXXXXXX     # Revoke to Free
node scripts/user-management/add-trial-to-user.js <userId>         # Add trial manually
node scripts/user-management/adjust-trial-by-phone.js +91XXXXXXXXXX 30  # Adjust trial days
node scripts/user-management/setup-user-for-phone.js +91XXXXXXXXXX # Fresh user setup
node scripts/user-management/cleanup-user.js <userId>              # Delete all user data
node scripts/user-management/create-weekly-snapshots.js            # Theta snapshots for all users
```

---

## diagnostics/

Safe to run — read-only by default. Use for debugging and verification.

```bash
node scripts/diagnostics/check_theta_tracking.js +91XXXXXXXXXX     # User theta state
node scripts/diagnostics/check-trial-status.js +91XXXXXXXXXX       # Trial status for phone
node scripts/diagnostics/count-questions.js                         # Question bank stats
node scripts/diagnostics/diagnose-collections.js <userId>           # Full user data state
node scripts/diagnostics/verify-question-bank-coverage.js           # Coverage by chapter
node scripts/diagnostics/debug-daily-quiz-generation.js <userId>    # Debug quiz gen
node scripts/diagnostics/list-all-chapter-keys.js                   # All chapter_key values
node scripts/diagnostics/audit-solution-steps.js                    # Check solution step completeness
```

---

## migrations/

**One-time scripts.** Most should only be run once — check the script header before running.

⚠️ `wipe-collection.js` is destructive — requires explicit confirmation.

---

## notifications/

```bash
node scripts/notifications/test-fcm-notification.js <userId>   # Test push notification
node scripts/notifications/send-test-mpa-email.js              # Test MPA email report
node scripts/notifications/check-fcm-tokens.js                 # Check FCM token state
```

---

## Common Workflows

### New chapter drop from product team (Cognitive Mastery)
```bash
cp -r ~/Downloads/laws_of_motion/ inputs/cognitive_mastery/data3/
node scripts/cognitive-mastery/upload-cognitive-mastery.js --dir inputs/cognitive_mastery/data3
node scripts/cognitive-mastery/tag-questions-micro-skills.js --chapter physics_laws_of_motion
```

### Import new question bank
```bash
cp ~/Downloads/questions_chemistry.json inputs/question_bank/
node scripts/data-upload/import-question-bank.js --file inputs/question_bank/questions_chemistry.json
node scripts/diagnostics/count-questions.js
```

### Debug a user issue
```bash
node scripts/diagnostics/check_theta_tracking.js +91XXXXXXXXXX
node scripts/diagnostics/diagnose-collections.js <userId>
node scripts/diagnostics/debug-daily-quiz-generation.js <userId>
```

### Adjust user tier for testing
```bash
node scripts/user-management/manage-tier.js pro +91XXXXXXXXXX
# ... test ...
node scripts/user-management/manage-tier.js free +91XXXXXXXXXX
```

---

See [QUESTION_BANK_MANAGEMENT.md](QUESTION_BANK_MANAGEMENT.md) for detailed question import documentation.

