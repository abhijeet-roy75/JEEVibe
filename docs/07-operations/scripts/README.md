# Scripts Operations Guide

This directory contains operational documentation for backend scripts and data management.

## Contents

- [UPDATE_SINGLE_QUESTION_GUIDE.md](UPDATE_SINGLE_QUESTION_GUIDE.md) - Guide for updating single questions in Firestore
- [SCRIPTS_README.md](SCRIPTS_README.md) - Overview of all available scripts

## Related Documentation

- [Backend Scripts](../../../backend/scripts/) - Actual script files
- [Collection Reference](../../02-architecture/COLLECTION_REFERENCE.md) - Firestore collection structure
- [Question Fixes](../../06-fixes/QUESTION_FIXES_NEEDED.md) - Questions requiring fixes

## Common Operations

### Update Single Question
```bash
node backend/scripts/update-single-question.js <question-id> <json-file-path>
```

See [UPDATE_SINGLE_QUESTION_GUIDE.md](UPDATE_SINGLE_QUESTION_GUIDE.md) for detailed instructions.
