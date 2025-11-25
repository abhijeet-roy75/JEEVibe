#!/bin/bash

# JEEVibe GitHub Setup Script
# This script will initialize git and push to GitHub

echo "🚀 JEEVibe GitHub Setup"
echo "======================="
echo ""

# Check if git is initialized
if [ ! -d .git ]; then
    echo "📦 Initializing Git repository..."
    git init
    echo "✅ Git initialized"
else
    echo "✅ Git already initialized"
fi

# Add all files
echo ""
echo "📝 Adding files to git..."
git add .

# Create initial commit
echo ""
echo "💾 Creating initial commit..."
git commit -m "Initial commit: JEEVibe - AI-powered JEE exam prep app"

# Prompt for GitHub username
echo ""
read -p "Enter your GitHub username: " GITHUB_USERNAME

# Create repository using GitHub CLI or provide manual instructions
echo ""
echo "Choose setup method:"
echo "1) Automatic (using GitHub CLI - recommended)"
echo "2) Manual (I'll provide commands to run)"
read -p "Enter choice (1 or 2): " CHOICE

if [ "$CHOICE" = "1" ]; then
    # Check if gh is installed
    if command -v gh &> /dev/null; then
        echo ""
        echo "🔐 Logging into GitHub..."
        gh auth login
        
        echo ""
        echo "📦 Creating repository on GitHub..."
        gh repo create JEEVibe --public --source=. --remote=origin --push
        
        echo ""
        echo "✅ Repository created and code pushed!"
        echo "🌐 View your repository: https://github.com/$GITHUB_USERNAME/JEEVibe"
    else
        echo ""
        echo "❌ GitHub CLI not found. Installing..."
        echo "Run: brew install gh"
        echo "Then run this script again."
        exit 1
    fi
else
    echo ""
    echo "📋 Manual Setup Instructions:"
    echo "=============================="
    echo ""
    echo "1. Go to: https://github.com/new"
    echo "2. Repository name: JEEVibe"
    echo "3. Make it Public (or Private)"
    echo "4. DO NOT initialize with README, .gitignore, or license"
    echo "5. Click 'Create repository'"
    echo ""
    echo "6. Then run these commands:"
    echo ""
    echo "   git remote add origin https://github.com/$GITHUB_USERNAME/JEEVibe.git"
    echo "   git branch -M main"
    echo "   git push -u origin main"
    echo ""
fi

echo ""
echo "✨ Setup complete!"
