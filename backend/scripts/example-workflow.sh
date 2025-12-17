#!/bin/bash

# Example Workflow: Replace Old Questions with New Ones
# This is a reference script - review and modify before running!

set -e  # Exit on error

echo "=================================================="
echo "Question Bank Management Workflow"
echo "=================================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Navigate to backend directory
cd "$(dirname "$0")/.."

echo -e "${YELLOW}Step 1: List current questions in database${NC}"
echo "---"
node scripts/cleanup-questions.js --list
echo ""

echo -e "${YELLOW}Step 2: Preview what will be deleted${NC}"
echo "---"
echo "Example: Preview all Math questions"
echo "Command: node scripts/cleanup-questions.js --subject Math --preview"
echo ""
read -p "Press Enter to continue or Ctrl+C to exit..."
echo ""

echo -e "${YELLOW}Step 3: Backup and delete old questions${NC}"
echo "---"
echo "Example: Delete all Math questions with backup"
echo "Command: node scripts/cleanup-questions.js --subject Math --backup"
echo ""
echo -e "${RED}WARNING: This will delete questions! Only proceed if you're sure.${NC}"
read -p "Do you want to delete Math questions? (yes/no): " confirm_math
echo ""

if [ "$confirm_math" = "yes" ]; then
    echo "Deleting Math questions with backup..."
    node scripts/cleanup-questions.js --subject Math --backup
    echo ""
else
    echo "Skipping Math deletion."
    echo ""
fi

read -p "Do you want to delete Chemistry questions? (yes/no): " confirm_chem
echo ""

if [ "$confirm_chem" = "yes" ]; then
    echo "Deleting Chemistry questions with backup..."
    node scripts/cleanup-questions.js --subject Chemistry --backup
    echo ""
else
    echo "Skipping Chemistry deletion."
    echo ""
fi

echo -e "${YELLOW}Step 4: Place new question files${NC}"
echo "---"
echo "Copy your new JSON files to: inputs/question_bank/"
echo "Copy any SVG images to the same folder"
echo ""
echo "Example commands:"
echo "  cp ~/Downloads/questions_math_*.json ../inputs/question_bank/"
echo "  cp ~/Downloads/questions_chem_*.json ../inputs/question_bank/"
echo "  cp ~/Downloads/*.svg ../inputs/question_bank/"
echo ""
read -p "Press Enter after you've placed the new files (or Ctrl+C to exit)..."
echo ""

echo -e "${YELLOW}Step 5: Import new questions${NC}"
echo "---"
echo "Importing questions from inputs/question_bank/..."
node scripts/import-question-bank.js
echo ""

echo -e "${YELLOW}Step 6: Verify results${NC}"
echo "---"
echo "Listing all questions to verify import..."
node scripts/cleanup-questions.js --list
echo ""

echo -e "${GREEN}=================================================="
echo "Workflow Complete!"
echo "==================================================${NC}"
echo ""
echo "Summary of what happened:"
echo "1. Listed current questions"
echo "2. Previewed deletions"
echo "3. Backed up and deleted old questions"
echo "4. Imported new questions"
echo "5. Verified results"
echo ""
echo "Backups are stored in: backups/questions/"
echo "Processed files are in: inputs/question_bank/processed/"
echo ""
echo "Have a great day! 🎓"

