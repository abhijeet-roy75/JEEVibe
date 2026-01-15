# JEEVibe Account Setup Plan
## Business Accounts (India)

**Version:** 1.1
**Date:** January 2026
**Status:** Planning
**Business Jurisdiction:** India

---

## Overview

Set up all third-party service accounts under business accounts for an India-registered company, before product launch.

### Current State
- **Product Status:** Not live yet (no production traffic)
- **Accounts:** Using personal accounts for POC/development
- **Business:** To be registered in India

### Why Set Up Business Accounts Now?
- **Simpler:** No migration needed - just set up fresh before launch
- **Professionalism:** Business accounts for investor/partner communications
- **Team Access:** Multiple team members can have appropriate access
- **Tax Compliance:** Proper GST invoicing from day one
- **Legal:** Clean separation of personal and business

### Advantage: Not Live Yet
Since you're not live, you can:
- Set up fresh accounts (no data migration)
- Take your time with verification processes
- No downtime concerns
- No user disruption

---

## India Business Registration Prerequisites

Before setting up any business accounts, complete these steps:

### 1. Business Entity Registration

| Requirement | Details | Timeline |
|-------------|---------|----------|
| **Company Type** | Private Limited (Pvt Ltd) recommended for startups | 2-3 weeks |
| **PAN Card** | Company PAN (not personal) | Comes with registration |
| **TAN** | Tax Deduction Account Number (for TDS) | 1-2 weeks |
| **GST Registration** | Required for SaaS business | 1-2 weeks after PAN |
| **Bank Account** | Current account in company name | 1-2 weeks |

**Recommended Registration Service:** Cleartax, Razorpay Rize, or local CA

### 2. Documents You'll Need

For most service registrations:
- [ ] Certificate of Incorporation
- [ ] Company PAN Card
- [ ] GST Certificate
- [ ] Director's Aadhaar/PAN
- [ ] Company Address Proof
- [ ] Board Resolution (for authorized signatories)
- [ ] Bank Account Statement/Cancelled Cheque

### 3. D-U-N-S Number (for Apple)

| Step | Details | Timeline |
|------|---------|----------|
| Apply | https://developer.apple.com/enroll/duns-lookup/ | Free |
| Verification | D&B India verifies business | 1-2 weeks |
| Receive | 9-digit D-U-N-S number | Via email |

**Important:** Apply with exact legal name as on Certificate of Incorporation

---

## Pre-Setup Checklist

### 1. Set Up Business Email
Before setting up any accounts, establish business email:

| Option | Provider | Cost | Recommendation |
|--------|----------|------|----------------|
| Google Workspace | Google | ~$6/user/month | Recommended - integrates with Firebase |
| Microsoft 365 | Microsoft | ~$6/user/month | Alternative |
| Zoho Mail | Zoho | Free-$3/user/month | Budget option |

**Recommended emails to create:**
- `admin@jeevibe.com` - Primary account owner
- `tech@jeevibe.com` - Technical services
- `support@jeevibe.com` - User support
- `privacy@jeevibe.com` - Privacy/legal inquiries

### 2. Document Current POC State
Before switching to business accounts:
- [ ] Export any test data you want to preserve
- [ ] Document current API configurations
- [ ] Note any custom settings in Firebase/Render
- [ ] Backup environment variable values
- [ ] List API keys that need to be regenerated

---

## Services to Set Up

Since you're not live yet, these are **fresh setups**, not migrations.

| # | Service | Priority | Complexity | India Notes |
|---|---------|----------|------------|-------------|
| 1 | Google Play Developer | High | Medium | GST invoice needed |
| 2 | Apple Developer | High | Medium | D-U-N-S required |
| 3 | Firebase / Google Cloud | High | Low | Fresh project or transfer |
| 4 | Render.com | High | Low | USD payment (forex) |
| 5 | OpenAI API | High | Low | USD payment (forex) |
| 6 | GitHub | Medium | Low | Organization setup |
| 7 | Domain | Medium | Low | Keep or transfer |
| 8 | Codecov | Low | Low | Follows GitHub |

---

## 1. Google Play Developer Account

### Current State
- Personal Google account (POC/development)
- App not published to production yet

### Target State
- Business Google account (`admin@jeevibe.com`)
- Google Play Developer account under Indian business

### Setup Approach (Fresh - Recommended for Pre-Launch)

Since you're not live, **create fresh business account** and publish there:

1. Create new Google Play Developer account with business email
2. Complete identity verification
3. Publish app to new account
4. No transfer needed (nothing to transfer yet)

### Setup Steps (India)

#### Phase 1: Account Creation
- [ ] Create Google account for `admin@jeevibe.com`
- [ ] Go to play.google.com/console
- [ ] Click "Create Developer Account"
- [ ] Select "Organization" account type
- [ ] Enter company details:
  - Legal company name (as on CoI)
  - D-U-N-S number (if available) or company registration
  - GST number
  - Business address

#### Phase 2: Identity Verification
Google now requires identity verification for new accounts:
- [ ] Submit government ID (Director's PAN/Aadhaar)
- [ ] Company verification documents
- [ ] Wait for verification (2-7 days)

#### Phase 3: Payment Setup
- [ ] Add payment method (Indian credit card or bank)
- [ ] Pay $25 registration fee (~₹2,100)
- [ ] **Note:** Google provides GST invoice for Indian businesses
- [ ] Set up merchant account for receiving payments (if selling)

#### Phase 4: App Setup
- [ ] Create new app listing
- [ ] Upload APK/AAB from your build
- [ ] Complete store listing
- [ ] Submit for review

### India-Specific Requirements

| Requirement | Details |
|-------------|---------|
| **Account Type** | Organization (not Individual) |
| **GST** | Required for business accounts |
| **Payments** | Google pays to Indian bank account in INR |
| **Tax** | Google deducts TDS on developer payouts |

### Timeline
- Account creation: 1 day
- Verification: 2-7 days
- Total: ~1-2 weeks

### Cost
- Registration: $25 (~₹2,100) one-time
- GST invoice provided

---

## 2. Apple Developer Account

### Current State
- Personal Apple ID (POC/development)
- App not published to App Store yet

### Target State
- Apple Developer Organization account
- Registered under Indian company with D-U-N-S

### Setup Approach (Fresh - Recommended for Pre-Launch)

Since you're not live, **create fresh Organization account**:

1. Get D-U-N-S number for Indian company
2. Enroll as Organization (not Individual)
3. Publish app to new account
4. No transfer needed

### Setup Steps (India)

#### Phase 1: Get D-U-N-S Number (START THIS FIRST!)
D-U-N-S takes 1-2 weeks - start immediately after company registration.

- [ ] Go to https://developer.apple.com/enroll/duns-lookup/
- [ ] Search for your company (won't exist yet)
- [ ] Click to request new D-U-N-S
- [ ] Enter company details:
  - **Legal Name:** Exact name on Certificate of Incorporation
  - **Address:** Registered office address
  - **Director Info:** Name, designation, contact
- [ ] D&B India will contact for verification
- [ ] Receive D-U-N-S via email (9-digit number)

#### Phase 2: Apple Developer Enrollment
- [ ] Go to developer.apple.com/enroll
- [ ] Sign in with business Apple ID (create if needed)
- [ ] Select "Organization" enrollment
- [ ] Enter:
  - D-U-N-S number
  - Legal entity name (must match D-U-N-S exactly)
  - Company website
  - Account holder details (Director/Authorized signatory)

#### Phase 3: Documentation for India
Apple may request additional verification:
- [ ] Certificate of Incorporation
- [ ] GST Registration Certificate
- [ ] Authorization letter on company letterhead
- [ ] Director's government ID

#### Phase 4: Payment & Activation
- [ ] Pay $99/year (~₹8,300)
- [ ] Payment via international card (Visa/Mastercard)
- [ ] Apple provides invoice (no GST - foreign service)
- [ ] Account activates within 48 hours

#### Phase 5: App Setup
- [ ] Generate new certificates and provisioning profiles
- [ ] Update Xcode with new team
- [ ] Create app in App Store Connect
- [ ] Submit for review

### India-Specific Requirements

| Requirement | Details |
|-------------|---------|
| **D-U-N-S** | Mandatory for Organization accounts |
| **Legal Entity** | Must be registered company (Pvt Ltd, LLP, etc.) |
| **Account Holder** | Must have legal authority (Director, Partner) |
| **Payment** | International card required (USD) |
| **Tax** | No GST (foreign service), but count as forex outflow |

### Timeline
- D-U-N-S registration: **1-2 weeks** (start first!)
- Apple enrollment: 2-5 days
- Total: 2-3 weeks

### Cost
- $99/year (~₹8,300)
- D-U-N-S: Free

### Important Notes
- D-U-N-S name must **exactly match** legal company name
- Account holder must be able to legally bind the company
- Keep personal account for testing until business account is active

---

## 3. Firebase / Google Cloud

### Current State
- Firebase Project: `jeevibe` (POC/development)
- Services used: Auth, Firestore, Storage, Analytics
- Billing: Blaze plan (pay-as-you-go)
- Minimal data (test users only)

### Target State
- Firebase project owned by business Google account
- Google Cloud billing under business

### Setup Options

**Option A: Transfer Project Ownership (Recommended)**
- Add business account as Owner
- Remove personal account
- Keep existing project and test data
- No app config changes needed

**Option B: Create Fresh Project**
- Only if you want completely clean slate
- Requires updating `firebase_options.dart` in app
- More work, usually unnecessary

### Migration Steps (Option A)

#### Phase 1: Preparation
- [ ] Create Google account for `admin@jeevibe.com` (if not done)
- [ ] Set up Google Cloud billing account for business
  - Add business payment method
  - Business address and tax info

#### Phase 2: Add Business Account
- [ ] Go to Firebase Console → Project Settings → Users and permissions
- [ ] Click "Add member"
- [ ] Add `admin@jeevibe.com` with role "Owner"
- [ ] Accept invitation from business email

#### Phase 3: Transfer Billing
- [ ] Go to Google Cloud Console → Billing
- [ ] Create new billing account under business email
- [ ] Link Firebase project to new billing account
- [ ] Verify billing is active

#### Phase 4: Remove Personal Account
- [ ] Verify business account has full access
- [ ] Test all Firebase services work
- [ ] Remove personal account from project (or downgrade to Viewer)

#### Phase 5: Update Service Accounts
- [ ] Review service account keys
- [ ] Rotate any keys stored in personal locations
- [ ] Update backend environment variables if needed

### Timeline
- Preparation: 1 day
- Transfer: 1 day
- Verification: 1 day
- Total: 3-5 days

### Cost
- No additional cost (same Blaze plan)

### Risk Mitigation
- Keep personal account as backup Owner for 30 days
- Test all auth flows after transfer
- Monitor for any billing issues

---

## 4. Render.com

### Current State
- Personal account
- Backend service deployed
- URL: `https://jeevibe.onrender.com`

### Target State
- Team/Business account
- Proper team access management

### Migration Steps

#### Phase 1: Create Team Account
- [ ] Sign up for Render with business email
- [ ] Create a Team (Render Teams feature)
- [ ] Set up billing under business

#### Phase 2: Transfer Service
**Option A: Redeploy (Simple)**
- [ ] Connect new account to GitHub repo
- [ ] Create new Web Service with same settings
- [ ] Copy environment variables
- [ ] Update DNS/domain if using custom domain
- [ ] Update mobile app API URL (if URL changes)

**Option B: Transfer Ownership (if Render supports)**
- [ ] Contact Render support to transfer service
- [ ] May require enterprise plan

#### Phase 3: Cleanup
- [ ] Delete service from personal account
- [ ] Update documentation with new URLs
- [ ] Verify backend connectivity

### Timeline
- 1-2 days

### Cost
- Same as current plan
- Teams feature may have additional cost depending on plan

### Important Notes
- If URL changes (`jeevibe.onrender.com`), need to:
  - Update mobile app's API base URL
  - Release new app version
  - OR use custom domain (recommended)

---

## 5. OpenAI API

### Current State
- Personal OpenAI account
- API key in use for Snap & Solve

### Target State
- OpenAI account under business email
- Organization-level API access

### Migration Steps

#### Phase 1: Create Business Account
- [ ] Sign up at platform.openai.com with business email
- [ ] Complete account verification
- [ ] Add payment method
- [ ] Set usage limits

#### Phase 2: Generate New API Key
- [ ] Create new API key in business account
- [ ] Note the key (shown only once)

#### Phase 3: Update Backend
- [ ] Update Render.com environment variable `OPENAI_API_KEY`
- [ ] Verify API calls work
- [ ] Monitor for any errors

#### Phase 4: Cleanup
- [ ] Delete API key from personal account
- [ ] Optionally close personal account or keep separate

### Timeline
- 1-2 hours

### Cost
- Pay-as-you-go (same pricing)
- May need to add credits to new account

### Important Notes
- Coordinate timing to minimize API downtime
- Can run both keys briefly during transition
- Monitor usage in both accounts during transition

---

## 6. GitHub

### Current State
- Personal GitHub account
- Repository: (private repo for JEEVibe)
- GitHub Actions for CI/CD

### Target State
- GitHub Organization
- Team-based access control

### Migration Options

**Option A: Create Organization & Transfer Repo (Recommended)**
- Create org under business
- Transfer repo to org
- Personal account becomes org member

**Option B: Keep Personal, Add Collaborators**
- Simpler but less professional
- Limited access control

### Migration Steps (Option A)

#### Phase 1: Create Organization
- [ ] Go to GitHub → Settings → Organizations → New organization
- [ ] Choose plan (Free is usually sufficient)
- [ ] Name: `jeevibe` or `jeevibe-app`
- [ ] Add business email

#### Phase 2: Transfer Repository
- [ ] Go to repo → Settings → Danger Zone → Transfer
- [ ] Select organization as new owner
- [ ] Confirm transfer

#### Phase 3: Set Up Team Access
- [ ] Create teams (e.g., "Engineering", "Admin")
- [ ] Add team members with appropriate permissions
- [ ] Update branch protection rules if needed

#### Phase 4: Update CI/CD
- [ ] Verify GitHub Actions still work
- [ ] Update any secrets if needed
- [ ] Check webhook integrations (Render, etc.)

### Timeline
- 1-2 hours

### Cost
- Free tier usually sufficient
- Team plan if need advanced features

---

## 7. GoDaddy (Domain)

### Current State
- Domain: jeevibe.com
- Personal GoDaddy account

### Target State
- Domain under business account
- OR transfer to Google Domains (integrates with Firebase)

### Migration Options

**Option A: Keep at GoDaddy, Update Account**
- Create business GoDaddy account
- Transfer domain between accounts

**Option B: Transfer to Google Domains (Recommended)**
- Better integration with Firebase Hosting
- Simpler DNS management

### Migration Steps (Option B - Google Domains)

#### Phase 1: Preparation
- [ ] Ensure domain is unlocked at GoDaddy
- [ ] Disable domain privacy temporarily
- [ ] Get authorization code from GoDaddy

#### Phase 2: Transfer
- [ ] Go to Google Domains (domains.google.com)
- [ ] Sign in with business Google account
- [ ] Click "Transfer" → Enter `jeevibe.com`
- [ ] Enter authorization code
- [ ] Pay transfer fee (~$12)
- [ ] Confirm via email

#### Phase 3: Post-Transfer
- [ ] Wait for transfer to complete (5-7 days)
- [ ] Verify DNS records transferred correctly
- [ ] Update Firebase Hosting DNS if needed

### Timeline
- 5-7 days (domain transfer waiting period)

### Cost
- ~$12 transfer fee
- Extends registration by 1 year

---

## 8. Codecov (CI/CD Coverage)

### Current State
- Connected to GitHub repo
- Personal account

### Target State
- Connected to GitHub Organization
- Team access

### Migration Steps
- [ ] Codecov will automatically follow GitHub org
- [ ] Verify coverage reports still work
- [ ] Update any Codecov tokens if needed

### Timeline
- Automatic with GitHub migration

---

## Setup Schedule (India)

### Recommended Order

**Note:** Start D-U-N-S application immediately after company registration - it takes the longest!

| Week | Service | Reason |
|------|---------|--------|
| 0 | Company Registration | Pvt Ltd / LLP with CA |
| 0 | D-U-N-S Application | Start immediately! Takes 1-2 weeks |
| 1 | Business Email (Google Workspace) | Foundation for all accounts |
| 1 | Business Bank Account | Needed for payments |
| 1 | Firebase Transfer | Add business account as owner |
| 1 | GitHub Organization | Quick setup |
| 2 | OpenAI API | New account with business email |
| 2 | Render.com | New team account |
| 2 | Google Play Developer | After GST registration |
| 3 | Apple Developer | After D-U-N-S received |
| 3 | Domain (optional) | Transfer to Google Domains |

### Pre-Setup Checklist
- [ ] Company registered (CoI received)
- [ ] Company PAN obtained
- [ ] GST registration complete
- [ ] Business bank account opened
- [ ] International payment card available (for USD services)
- [ ] D-U-N-S application submitted
- [ ] Business email set up

### Post-Setup Checklist
- [ ] All services accessible from business accounts
- [ ] Personal accounts removed or downgraded
- [ ] Team members have appropriate access
- [ ] Billing verified on all services
- [ ] Documentation updated
- [ ] API keys rotated and old ones deleted

---

## Credentials Management

### Recommended: Use a Password Manager
- **1Password Teams** or **Bitwarden Business**
- Shared vaults for team credentials
- Secure API key storage

### Credentials to Migrate
| Service | Credential Type | Storage |
|---------|-----------------|---------|
| Google Play | Account login | Password manager |
| Apple Developer | Account login + 2FA | Password manager |
| Firebase | Service account JSON | Secure vault |
| Render.com | Account login + API key | Password manager |
| OpenAI | API key | Environment variable + vault |
| GitHub | Account login + tokens | Password manager |
| GoDaddy | Account login | Password manager |

---

## Cost Summary (India - INR)

*Exchange rate assumed: 1 USD = ₹83*

| Service | One-Time | Annual | Currency | GST Input Credit |
|---------|----------|--------|----------|------------------|
| Company Registration | ₹15,000-25,000 | - | INR | Yes |
| Google Workspace | - | ₹6,000/year | INR | Yes |
| Google Play | ₹2,100 | - | USD | Yes (GST invoice) |
| Apple Developer | - | ₹8,300/year | USD | No (foreign) |
| Firebase | - | Pay-as-you-go | USD | No (foreign) |
| Render.com | - | ₹7,000-21,000/year | USD | No (foreign) |
| OpenAI | - | Pay-as-you-go | USD | No (foreign) |
| GitHub | - | Free | - | - |
| Domain Transfer | ₹1,000 | ₹1,000/year | USD | No (foreign) |
| Password Manager | - | ₹4,000/year | INR/USD | Varies |

### Cost Breakdown

**One-Time Costs:**
- Company registration: ₹15,000-25,000
- Google Play registration: ₹2,100
- Domain transfer: ₹1,000
- **Total one-time:** ~₹20,000-30,000

**Annual Recurring:**
- Apple Developer: ₹8,300
- Google Workspace: ₹6,000
- Domain renewal: ₹1,000
- **Total annual (base):** ~₹15,000-20,000

**Variable (Usage-Based):**
- Firebase, OpenAI, Render: Depends on usage
- Budget ₹5,000-20,000/month initially

---

## Forex & Payment Considerations (India)

### USD Payments from India

Most services (Apple, OpenAI, Render, Firebase) charge in USD. Options:

| Method | Pros | Cons |
|--------|------|------|
| **International Credit Card** | Easy, instant | Forex markup (1.5-3.5%) |
| **Forex Card** | Better rates | Need to load in advance |
| **Business Credit Card** | Expense tracking, rewards | May have lower limits |

### Recommended Setup
1. Get a business credit card with good forex rates (HDFC Infinia, Axis Magnus)
2. Or use a forex card (Niyo, BookMyForex)
3. Enable international transactions on card
4. Set up transaction alerts

### Tax Implications

| Service | GST Status | TDS Applicable |
|---------|------------|----------------|
| Google Play (India payments in) | Google deducts | Yes (TDS by Google) |
| Apple (India payments in) | Apple deducts | Yes (TDS by Apple) |
| Firebase/GCP | Foreign service | No GST, count as import |
| OpenAI | Foreign service | No GST, count as import |
| Render | Foreign service | No GST, count as import |

**Note:** Consult your CA for proper accounting of foreign service expenses.

---

## Risk Register

Since you're **not live yet**, risks are much lower:

| Risk | Impact | Mitigation |
|------|--------|------------|
| D-U-N-S delay | Medium | Apply immediately after company registration |
| Account verification delay | Low | Have all documents ready |
| Card declined for USD | Low | Have backup payment method |
| Lost access to POC accounts | Low | Document credentials before setup |
| Firebase config mismatch | Low | Test thoroughly before launch |

---

## Support Contacts

| Service | Support URL | Notes |
|---------|-------------|-------|
| Google Play | play.google.com/console/contact | Developer support |
| Apple Developer | developer.apple.com/contact | Account issues |
| Firebase | firebase.google.com/support | Technical support |
| Render.com | render.com/support | Support tickets |
| OpenAI | help.openai.com | API support |
| GitHub | support.github.com | Account issues |
| GoDaddy | godaddy.com/help | Domain support |
