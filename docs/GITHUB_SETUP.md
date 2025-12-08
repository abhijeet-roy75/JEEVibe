# GitHub Setup Guide for JEEVibe

This guide will help you set up your JEEVibe repository on GitHub.

## Step 1: Move Documentation Files

Move all .md files from root to docs folder (except README.md which should stay in root):

```bash
# Navigate to project root
cd /Users/abhijeetroy/Documents/JEEVibe

# Move walkthrough.md to docs
mv walkthrough.md docs/

# Verify the move
ls -la docs/
```

## Step 2: Create .gitignore

Create a `.gitignore` file to exclude sensitive and unnecessary files:

```bash
cat > .gitignore << 'EOF'
# Dependencies
node_modules/
.pnp
.pnp.js

# Testing
coverage/

# Production
build/
dist/

# Environment variables
.env
.env.local
.env.development.local
.env.test.local
.env.production.local

# Logs
npm-debug.log*
yarn-debug.log*
yarn-error.log*
lerna-debug.log*
*.log

# OS
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db

# IDE
.vscode/
.idea/
*.swp
*.swo
*~

# Flutter/Dart
.dart_tool/
.flutter-plugins
.flutter-plugins-dependencies
.packages
.pub-cache/
.pub/
build/
*.g.dart
*.freezed.dart

# iOS
mobile/ios/Pods/
mobile/ios/.symlinks/
mobile/ios/Flutter/Flutter.framework
mobile/ios/Flutter/Flutter.podspec
mobile/ios/.generated/
mobile/ios/Runner.xcworkspace/xcuserdata/
mobile/ios/Runner.xcodeproj/xcuserdata/
mobile/ios/Runner.xcodeproj/project.xcworkspace/xcuserdata/

# Android
mobile/android/.gradle/
mobile/android/captures/
mobile/android/local.properties
mobile/android/app/debug
mobile/android/app/profile
mobile/android/app/release

# Docs (exclude from GitHub)
docs/

# Temporary files
*.tmp
*.temp
.cache/
EOF
```

## Step 3: Initialize Git Repository

```bash
# Initialize git (if not already initialized)
git init

# Add all files
git add .

# Create initial commit
git commit -m "Initial commit: JEEVibe - AI-powered JEE exam prep app"
```

## Step 4: Create GitHub Repository

### Option A: Using GitHub CLI (Recommended)

```bash
# Install GitHub CLI if not already installed
# On macOS:
brew install gh

# Login to GitHub
gh auth login

# Create repository
gh repo create JEEVibe --public --source=. --remote=origin --push

# This will:
# - Create a new public repository named "JEEVibe"
# - Add it as remote "origin"
# - Push your code
```

### Option B: Using GitHub Website

1. **Create Repository on GitHub**
   - Go to https://github.com/new
   - Repository name: `JEEVibe`
   - Description: "AI-powered JEE exam preparation app with instant solutions and practice quizzes"
   - Visibility: Public (or Private)
   - **DO NOT** initialize with README, .gitignore, or license
   - Click "Create repository"

2. **Connect Local Repository**
   ```bash
   # Add GitHub as remote (replace YOUR_USERNAME)
   git remote add origin https://github.com/YOUR_USERNAME/JEEVibe.git
   
   # Verify remote
   git remote -v
   
   # Push to GitHub
   git branch -M main
   git push -u origin main
   ```

## Step 5: Verify Upload

```bash
# Check status
git status

# View commit history
git log --oneline

# Open repository in browser
gh repo view --web
# OR manually go to: https://github.com/YOUR_USERNAME/JEEVibe
```

## Step 6: Create README.md (if needed)

If you want to update the README with project information:

```bash
cat > README.md << 'EOF'
# JEEVibe 🎓

AI-powered JEE exam preparation app that provides instant solutions and practice quizzes.

## Features

- 📸 **Snap & Solve**: Take a photo of any JEE question and get instant solutions
- 🤖 **AI-Powered**: Powered by OpenAI's GPT-4 Vision for accurate OCR and solutions
- 📚 **Step-by-Step Solutions**: Detailed explanations from "Priya Ma'am"
- 🎯 **Practice Quizzes**: Follow-up questions to reinforce learning
- 🎨 **Beautiful UI**: Modern purple/pink gradient theme
- ⚡ **Fast**: Optimized for quick responses

## Tech Stack

### Backend
- Node.js + Express
- OpenAI GPT-4 Vision API
- RESTful API architecture

### Mobile (iOS)
- Flutter/Dart
- Camera integration
- LaTeX rendering for mathematical formulas
- Image cropping and compression

## Getting Started

### Prerequisites
- Node.js 18+
- Flutter 3.0+
- OpenAI API key

### Backend Setup

```bash
cd backend
npm install
cp .env.example .env
# Add your OPENAI_API_KEY to .env
npm run dev
```

### Mobile Setup

```bash
cd mobile
flutter pub get
flutter run
```

## Deployment

- **Backend**: Deployed on Render.com
- **iOS**: Distributed via TestFlight

See [DEPLOYMENT_GUIDE.md](docs/DEPLOYMENT_GUIDE.md) for detailed instructions.

## License

MIT License - see LICENSE file for details

## Contact

For questions or support, please open an issue.
EOF

# Commit the updated README
git add README.md
git commit -m "Update README with project information"
git push
```

## Step 7: Set Up Branch Protection (Optional)

Protect your main branch from accidental force pushes:

```bash
# Using GitHub CLI
gh api repos/:owner/:repo/branches/main/protection \
  -X PUT \
  -F required_status_checks=null \
  -F enforce_admins=false \
  -F required_pull_request_reviews=null \
  -F restrictions=null
```

Or do it manually:
1. Go to repository Settings → Branches
2. Add rule for `main` branch
3. Enable "Require pull request reviews before merging"

## Common Git Commands

### Daily Workflow

```bash
# Check status
git status

# Add changes
git add .

# Commit changes
git commit -m "Your commit message"

# Push to GitHub
git push

# Pull latest changes
git pull
```

### Branching

```bash
# Create new branch
git checkout -b feature/new-feature

# Switch branches
git checkout main

# Merge branch
git merge feature/new-feature

# Delete branch
git branch -d feature/new-feature
```

### Undoing Changes

```bash
# Discard changes in working directory
git checkout -- filename

# Unstage file
git reset HEAD filename

# Undo last commit (keep changes)
git reset --soft HEAD~1

# Undo last commit (discard changes)
git reset --hard HEAD~1
```

## Troubleshooting

### Issue: "Permission denied (publickey)"
**Solution**: Set up SSH keys or use HTTPS with personal access token

```bash
# Use HTTPS instead
git remote set-url origin https://github.com/YOUR_USERNAME/JEEVibe.git
```

### Issue: "Repository not found"
**Solution**: Verify repository name and your access

```bash
git remote -v
# Update if needed
git remote set-url origin https://github.com/YOUR_USERNAME/JEEVibe.git
```

### Issue: "Docs folder is being tracked"
**Solution**: Remove from git tracking

```bash
git rm -r --cached docs/
git commit -m "Remove docs folder from tracking"
git push
```

## Next Steps

1. ✅ Set up GitHub repository
2. ✅ Configure .gitignore
3. ✅ Push initial code
4. 🔄 Set up CI/CD (optional)
5. 🔄 Add collaborators (if team project)
6. 🔄 Create issues for bug tracking
7. 🔄 Set up project board for task management

---

**Happy coding! 🚀**
EOF
