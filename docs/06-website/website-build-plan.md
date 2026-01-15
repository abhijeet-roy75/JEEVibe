# JEEVibe Marketing Website - Build Plan

**Version:** 1.0
**Date:** January 2026
**Status:** Planning Complete

---

## Overview

Build a static marketing website at **jeevibe.com** with landing page, Our Approach page, Terms & Conditions, and Privacy Policy.

| Attribute | Value |
|-----------|-------|
| **Tech Stack** | HTML + Tailwind CSS |
| **Hosting** | Firebase Hosting |
| **Domain** | jeevibe.com (GoDaddy → Firebase DNS) |
| **Location** | `/website` folder in main repo |

---

## Project Structure

```
/website/
├── index.html              # Landing page
├── approach.html           # Our Approach (differentiators)
├── terms.html              # Terms & Conditions
├── privacy.html            # Privacy Policy
├── package.json            # Tailwind build tooling
├── tailwind.config.js      # Tailwind config with JEEVibe colors
├── src/
│   └── input.css           # Tailwind source
├── assets/
│   ├── css/
│   │   └── output.css      # Compiled Tailwind
│   ├── images/
│   │   ├── logo.svg
│   │   ├── hero-mockup.png
│   │   ├── priya-maam-avatar.png
│   │   ├── theta-curve.svg
│   │   └── features/
│   └── js/
│       └── main.js         # Mobile menu toggle
└── README.md
```

---

## Design System

Matching the mobile app's design language from `mobile/lib/theme/app_colors.dart`:

| Token | Value | Usage |
|-------|-------|-------|
| Primary | `#9333EA` | Buttons, links, accents |
| Secondary | `#EC4899` | Highlights, gradients |
| Success | `#10B981` | Positive states |
| Background | `#FAF5FF` | Page background |
| Surface | `#FFFFFF` | Cards, containers |
| Text | `#1F2937` | Body text |
| Muted | `#6B7280` | Secondary text |

**Typography:** Inter (Google Fonts)
**Border Radius:** 12px (medium), 16px (large)

---

## Page 1: Landing Page (index.html)

### Section Structure

1. **Navigation**
   - Logo (left)
   - Nav links: Features, Our Approach, Download
   - CTA button: "Download App"

2. **Hero Section**
   ```
   Headline: "Crack JEE with AI-Powered Learning"
   Subheadline: "Snap a question, get instant step-by-step solutions from Priya Ma'am"
   CTA: [Download on App Store] [Get it on Google Play]
   Visual: App mockup showing Snap & Solve feature
   ```

3. **Features Grid** (4 cards)
   | Feature | Icon | Description |
   |---------|------|-------------|
   | Snap & Solve | Camera | Photo any question, get AI solutions instantly |
   | Daily Quiz | Quiz | Personalized 10-question daily practice |
   | Smart Analytics | Chart | Track progress across Physics, Chemistry, Math |
   | Priya Ma'am | Avatar | Your warm, encouraging AI tutor |

4. **Why JEEVibe?** (4 cards linking to /approach)
   | Differentiator | Headline | One-liner |
   |----------------|----------|-----------|
   | Adaptive Learning | "Questions that adapt to YOU" | IRT-powered quizzes that match your exact level |
   | Initial Assessment | "Personalized from Day 1" | Know your strengths and weaknesses instantly |
   | AI-Native | "Real AI, not question banks" | Fresh questions generated in real-time |
   | Priya Ma'am | "Your AI tutor who cares" | Warm guidance—not a robotic chatbot |

5. **How It Works** (3 steps)
   1. Download & Sign Up (Phone OTP)
   2. Take Initial Assessment (10 minutes)
   3. Start Learning (Daily quizzes + Snap & Solve)

6. **Download CTA**
   - App Store badge
   - Play Store badge
   - "Free to start. No credit card required."

7. **Footer**
   - Logo
   - Links: Our Approach, Terms, Privacy, Contact
   - Social links (if applicable)
   - Copyright: © 2026 JEEVibe

---

## Page 2: Our Approach (approach.html)

### Hero
```
Headline: "The Science Behind Your Score Improvement"
Subheadline: "How JEEVibe uses AI and adaptive learning to help you crack JEE"
```

### Section 1: The Problem We Solve

**Pain Points:**
- 500+ hours of video lectures = overwhelming
- Generic practice = wasted time on topics you already know
- Expensive coaching (₹1L+) = not accessible to everyone
- Studying alone = hard to stay motivated

**Visual:** Problem/solution comparison graphic

### Section 2: Our Solution - Adaptive Learning

**IRT-Based Question Selection**
- Item Response Theory (IRT) explained simply
- "Each question has a difficulty level. As you answer, we calculate YOUR ability score (theta)."
- "We serve questions at YOUR level—challenging enough to learn, easy enough not to frustrate"
- **Visual:** Theta curve diagram showing adaptive difficulty

**Initial Assessment**
- "Before you start, we assess your current knowledge"
- "10-minute assessment identifies your strengths and weak topics"
- "Your daily practice is personalized from day one"

### Section 3: AI-Native Architecture

**Not a Static Question Bank**
- "Traditional apps have 10,000 pre-written questions"
- "JEEVibe generates questions in real-time using AI"
- "Every question is fresh, relevant, and at your level"

**Snap & Solve + Follow-Up**
- "Snap any JEE question → Get step-by-step solution"
- "Then practice 3 similar questions to reinforce learning"
- "This is the '3-question follow-up method' that makes concepts stick"
- **Visual:** Screenshot of Snap & Solve flow

### Section 4: Meet Priya Ma'am

**Your AI Tutor**
- "Priya Ma'am is a 28-year-old IIT Bombay CSE graduate"
- "She explains concepts warmly, like a caring older sister"
- "Not a robotic chatbot—she remembers your progress and encourages you"
- **Visual:** Priya Ma'am avatar with example dialogue

**Teaching Philosophy**
- Step-by-step explanations
- Encouragement after mistakes ("Great try! Let's look at this together")
- Personalized feedback based on your weak areas

### Section 5: Built for Score Improvement

**The Goal: 30-50 Percentile Point Jump**
- "We're not here to be another study app"
- "Our mission: Help you improve your JEE rank meaningfully"
- "Adaptive practice → Focus on weak topics → Faster improvement"

**How We Measure Success**
- Track your theta score over time
- Weekly progress reports
- Mock test comparisons (before vs after)

### CTA Section
```
Ready to improve your JEE score?
[Download Free] [Back to Home]
```

---

## Page 3: Terms & Conditions (terms.html)

### Sections
1. **Introduction** - Agreement to terms
2. **Service Description** - What JEEVibe provides
3. **User Accounts**
   - Eligibility (13+ with parental consent for minors)
   - Account security responsibilities
4. **Subscription Terms**
   - Free tier: 5 daily snaps, 1 daily quiz, 7-day history
   - Pro tier: Unlimited snaps, unlimited quizzes, offline access
   - Ultra tier: All Pro features + enhanced benefits
5. **Acceptable Use Policy**
   - Prohibited activities
   - Content guidelines
6. **Intellectual Property**
   - JEEVibe owns all content and technology
   - User-generated content license
7. **Limitation of Liability**
   - Educational content disclaimer
   - No guarantee of exam results
8. **Termination**
   - User-initiated account deletion
   - JEEVibe-initiated termination rights
9. **Governing Law**
   - Jurisdiction: India
   - Dispute resolution

---

## Page 4: Privacy Policy (privacy.html)

### Sections
1. **Introduction**
   - Commitment to privacy
   - DPDP Act compliance statement

2. **Information We Collect**
   - Phone number (authentication)
   - Usage data (questions attempted, scores)
   - Images (Snap & Solve photos - processed, not stored long-term)
   - Device information

3. **How We Use Data**
   - Provide personalized learning
   - Improve our algorithms
   - Send progress reports
   - Customer support

4. **Third-Party Services**
   - Firebase (authentication, database, analytics)
   - OpenAI (question processing - data not retained)
   - Render.com (backend hosting)

5. **Data Retention**
   - Account data: Until deletion requested
   - Usage analytics: Anonymized after 12 months
   - Snap images: Processed and deleted within 24 hours

6. **Your Rights**
   - Access your data
   - Request deletion
   - Withdraw consent
   - Data portability

7. **Parental Consent**
   - Required for users under 18
   - SMS-based verification process
   - Parent can withdraw consent anytime

8. **Security Measures**
   - Encryption in transit and at rest
   - Firebase security rules
   - Regular security audits

9. **Contact Information**
   - Email: privacy@jeevibe.com
   - Address: [Company address]

10. **Updates to Policy**
    - Notification via app/email
    - Last updated date

---

## Implementation Steps

### Step 1: Project Setup
- [ ] Create `/website` directory
- [ ] Initialize npm: `npm init -y`
- [ ] Install Tailwind: `npm install -D tailwindcss`
- [ ] Initialize Tailwind: `npx tailwindcss init`
- [ ] Configure `tailwind.config.js` with JEEVibe colors
- [ ] Create `src/input.css` with Tailwind directives
- [ ] Add build script to `package.json`

### Step 2: Landing Page
- [ ] Create `index.html` structure
- [ ] Build navigation component
- [ ] Build hero section with mockup
- [ ] Build features grid
- [ ] Build "Why JEEVibe?" section
- [ ] Build how-it-works section
- [ ] Build download CTA
- [ ] Build footer
- [ ] Add responsive styles (mobile-first)

### Step 3: Our Approach Page
- [ ] Create `approach.html` structure
- [ ] Build hero section
- [ ] Build "Problem We Solve" section
- [ ] Build "Adaptive Learning" section with IRT visual
- [ ] Build "AI-Native" section
- [ ] Build "Meet Priya Ma'am" section
- [ ] Build "Score Improvement" section
- [ ] Add CTA and footer

### Step 4: Legal Pages
- [ ] Create `terms.html` with all sections
- [ ] Create `privacy.html` with all sections
- [ ] Style consistently with other pages

### Step 5: Assets
- [ ] Export/create logo.svg
- [ ] Create hero mockup image
- [ ] Add Priya Ma'am avatar
- [ ] Create theta curve SVG diagram
- [ ] Add feature icons
- [ ] Download App Store / Play Store badges

### Step 6: Firebase Hosting Setup
- [ ] Update `firebase.json` for website hosting
- [ ] Test locally: `firebase emulators:start`
- [ ] Deploy: `firebase deploy --only hosting`

### Step 7: Domain Configuration (GoDaddy)
- [ ] Add custom domain in Firebase Console
- [ ] Update DNS A records at GoDaddy
- [ ] Add CNAME for www subdomain
- [ ] Verify SSL certificate provisioning

---

## Deployment

### Firebase Hosting Config

```json
{
  "hosting": {
    "public": "website",
    "ignore": [
      "firebase.json",
      "**/.*",
      "**/node_modules/**",
      "**/src/**",
      "package.json",
      "tailwind.config.js"
    ]
  }
}
```

### DNS Configuration (GoDaddy)

| Type | Name | Value | TTL |
|------|------|-------|-----|
| A | @ | (Firebase IP 1) | 1 hour |
| A | @ | (Firebase IP 2) | 1 hour |
| CNAME | www | jeevibe.web.app | 1 hour |

*Note: Firebase will provide exact IP addresses when adding custom domain.*

---

## Verification Checklist

- [ ] All pages render correctly
- [ ] Responsive design works (mobile, tablet, desktop)
- [ ] All links functional
- [ ] Images load properly
- [ ] Lighthouse score > 90 (Performance, Accessibility)
- [ ] SSL certificate active
- [ ] Custom domain resolves correctly
