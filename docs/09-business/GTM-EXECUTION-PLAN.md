# JEEVibe GTM Execution Plan

> **Status**: Active Execution
>
> **Created**: 2026-01-23
>
> **Related**:
> - [BUSINESS-MODEL-REVIEW.md](./BUSINESS-MODEL-REVIEW.md) - Strategic pricing and tier analysis
> - [TRIAL-FIRST-IMPLEMENTATION.md](../03-features/TRIAL-FIRST-IMPLEMENTATION.md) - Trial system spec
> - [PROMO-REFERRAL-SYSTEM.md](../03-features/PROMO-REFERRAL-SYSTEM.md) - Promo/referral code implementation

## Current State

| Dimension | Status |
|-----------|--------|
| **Stage** | Pre-launch beta |
| **Beta Partners** | Local coaching classes in Pune, Mumbai |
| **Beta Offer** | Pro licenses (free) for feedback |
| **Target** | 50-100 beta students |

---

## Phase 1: Coaching Beta (Current - 2-4 weeks)

**Goal**: Product validation + testimonial collection

### Actions

| Action | Owner | Status | Success Metric |
|--------|-------|--------|----------------|
| Onboard 2-3 coaching classes in Pune | Business | In Progress | 50+ students |
| Onboard 1-2 coaching classes in Mumbai | Business | In Progress | 30+ students |
| Set up usage analytics tracking | Engineering | Pending | Dashboard live |
| Create in-app testimonial request (Day 7) | Product | Pending | Prompt designed |
| Run NPS survey at Day 14 | Product | Pending | NPS > 40 |
| Collect 20-50 video testimonials | Marketing | Pending | Videos recorded |

### Beta User Requirements

Each beta user should:
- Use the app for at least 7 days
- Try Snap & Solve at least 10 times
- Complete at least 2 Daily Quizzes
- Provide feedback (survey or video)

### Key Metrics to Track

| Metric | Target | Why |
|--------|--------|-----|
| **DAU/MAU** | >30% | Measures stickiness |
| **Snap & Solve usage** | >5/user/week | Validates hero feature |
| **Feature usage distribution** | Snap > Quiz > Practice | Validates value hierarchy |
| **NPS** | >40 | Product-market fit signal |
| **Bug reports** | <10 critical | Launch readiness |

### Testimonial Collection Strategy

**Day 7 in-app prompt:**
```
"You've solved 25 questions this week! Would you record a quick video about your experience?"

[Record Video]  [Maybe Later]
```

**Ask for:**
- 30-second video about favorite feature
- Permission to use on social media
- Star rating for App Store

---

## Phase 2: Controlled Launch (Weeks 4-8)

**Goal**: Validate conversion funnel before paid acquisition

### Channel Strategy

| Channel | Action | Budget | Expected CAC |
|---------|--------|--------|--------------|
| **Coaching referrals** | Each beta user invites 5 friends | ₹0 | ₹0 |
| **Teacher WhatsApp groups** | Teachers share in their student groups | ₹0 | ₹0 |
| **Micro-influencers** | 2-3 JEE YouTubers (10K-50K subs) | ₹30-50K | ₹50-100 |
| **Instagram Reels** | 5-10 organic "Snap & Solve" demo videos | ₹0 | ₹0 |
| **Google Ads (branded)** | "JEEVibe" keywords only | ₹10K | ₹100-150 |

### Referral Program (MVP)

Launch with minimal viable referral:

| Role | Reward |
|------|--------|
| **Referrer** | +5 bonus snaps for 7 days |
| **Referee** | +3 bonus snaps for 7 days + ₹50 off first purchase |
| **Streak bonus** | 3 successful referrals = 1 week Pro free |

**Tracking**: Start with Google Sheets if referral system not built. Manually track referral codes.

### Micro-Influencer Criteria

| Criterion | Requirement |
|-----------|-------------|
| **Audience** | JEE/NEET aspirants |
| **Subscribers** | 10K-50K (micro, not macro) |
| **Engagement** | >5% comment rate |
| **Content type** | Study tips, problem solving, motivation |
| **Cost** | ₹5-15K per video |

**Outreach script:**
```
Hi [Name], I'm [Your Name] from JEEVibe - we're building an AI-powered JEE prep app that solves doubts instantly via photo.

Would you be interested in trying it and sharing with your audience? We'd provide:
- Free Pro account for you
- ₹[X] for a dedicated video
- Exclusive discount code for your viewers

Let me know if you'd like to see a demo!
```

### Critical Milestone

**Before scaling to Phase 3:**
- Trial-to-paid conversion > 5%
- CAC < ₹200 on organic/referral channels
- NPS > 40
- <5% Day-30 churn

---

## Phase 3: Scale (Weeks 8-16)

**Goal**: Pour fuel on what works

### Scale Decision Matrix

| If This Works | Do More Of | Budget Allocation |
|---------------|------------|-------------------|
| Referrals converting >5% | Double referral rewards temporarily | 20% |
| Influencer CAC <₹100 | Sign 10 more micro-influencers | 40% |
| Coaching partnerships | Expand to Kota, Delhi, Hyderabad | 20% |
| Organic Reels getting traction | Hire part-time content creator | 10% |
| Google Ads CAC <₹150 | Expand to JEE keywords | 10% |

### Geographic Expansion Priority

| Priority | City | Why |
|----------|------|-----|
| **1** | Kota | JEE coaching capital |
| **2** | Delhi NCR | Large student population |
| **3** | Hyderabad | Strong coaching ecosystem |
| **4** | Bangalore | Tech-savvy parents |
| **5** | Chennai | Growing JEE aspirant base |

### Paid Acquisition Channels

| Channel | Monthly Budget | Expected CAC | Target Conversions |
|---------|----------------|--------------|-------------------|
| **Instagram Ads** | ₹50K | ₹100-150 | 350-500 |
| **YouTube Ads** | ₹30K | ₹150-200 | 150-200 |
| **Google Search** | ₹40K | ₹100-150 | 270-400 |
| **Influencers** | ₹50K | ₹50-100 | 500-1000 |
| **Total** | ₹1.7L | ~₹120 avg | 1,270-2,100 |

---

## Coaching Partnership Playbook

### Partnership Tiers

| Tier | Offer | Value to Coaching | Value to JEEVibe |
|------|-------|-------------------|------------------|
| **Beta Partner** | Free Pro for all students | "We provide AI doubt solving" | User acquisition + feedback |
| **Launch Partner** | 30% revenue share | Passive income stream | Aligned incentives |
| **Bulk License** | ₹99/student/month (50+ students) | Discount vs individual | Predictable B2B revenue |

### Coaching Acquisition Funnel

```
Teacher discovers JEEVibe
        ↓
Demo to coaching owner
        ↓
Free trial for 1 batch (30 days)
        ↓
Students love it → Teacher recommends
        ↓
Option A: Revenue share (individual purchases)
Option B: Bulk license (coaching pays)
```

### Partnership Agreement Terms

| Term | Value |
|------|-------|
| **Revenue share** | 20-30% of first 6 months |
| **Bulk discount** | ₹99/student/month (50+ students) |
| **Minimum commitment** | 3 months |
| **Reporting** | Monthly usage + conversion report |
| **Exclusivity** | Non-exclusive |

### Coaching Outreach Script

```
Subject: AI Doubt Solving for Your Students - Free Trial

Hi [Coaching Name],

I'm [Your Name] from JEEVibe. We've built an AI-powered app that solves JEE doubts instantly - students just snap a photo of any problem.

We're offering select coaching institutes in [City] a free 30-day Pro trial for all students. Here's what they get:
- Instant solutions via photo (15/day)
- Daily practice quizzes
- Full JEE syllabus coverage

No cost, no commitment. Would you be open to a 15-minute demo?

[Your Name]
[Phone]
```

---

## Seasonal Strategy

### JEE Calendar Alignment

| Period | Student Mindset | Strategy |
|--------|-----------------|----------|
| **Jan-April** | "Exam mode, need help NOW" | Peak conversion, maximize paid acquisition |
| **May-June** | "Results out, planning next year" | Target Class 11 → 12 transition |
| **July-Sept** | "Starting fresh, building habits" | Focus on engagement, habit formation |
| **Oct-Dec** | "Getting serious, mocks starting" | Push mock test feature, conversion focus |

### Monthly Tactical Calendar

| Month | Primary Action | Secondary Action |
|-------|----------------|------------------|
| **Feb** | Beta feedback collection | Testimonial recording |
| **Mar** | Controlled launch | Influencer outreach |
| **Apr** | Scale referrals | Coaching expansion |
| **May** | Class 11 targeting | Content creation ramp |
| **June** | Class 11 onboarding | Summer engagement |
| **July** | Habit building campaigns | Feature improvements |
| **Aug** | Back-to-school push | Coaching partnerships |
| **Sept** | Mock test promotion | Conversion optimization |
| **Oct** | Pre-season ramp | Paid acquisition scale |
| **Nov** | Full scale acquisition | Retention focus |
| **Dec** | Peak conversion | Annual plan push |

---

## Content Strategy

### Organic Content Pillars

| Pillar | Content Type | Frequency | Platform |
|--------|--------------|-----------|----------|
| **Snap & Solve demos** | Screen recordings | 3x/week | Instagram Reels, YouTube Shorts |
| **JEE tips** | Quick tips, tricks | 2x/week | Instagram, Twitter |
| **Student success** | Testimonials | 1x/week | All platforms |
| **Behind the scenes** | Team, product | 1x/week | Instagram Stories |

### Sample Content Calendar (Week 1)

| Day | Content | Platform |
|-----|---------|----------|
| Mon | Snap & Solve demo (Physics) | Reels |
| Tue | "5 common JEE mistakes" | Twitter thread |
| Wed | Student testimonial video | YouTube Shorts |
| Thu | Snap & Solve demo (Math) | Reels |
| Fri | "Weekend study plan" tip | Instagram Story |
| Sat | Behind the scenes | Instagram Story |
| Sun | Week's best solutions compilation | Reels |

---

## Metrics & Reporting

### Weekly Dashboard

| Metric | Target | Tracking |
|--------|--------|----------|
| New signups | 100+/week (beta) | Firebase Analytics |
| DAU | 50% of signups | Firebase Analytics |
| Snap & Solve usage | 5+/user/week | Custom event |
| Referrals sent | 10+/week | Referral system |
| Testimonials collected | 5+/week | Manual tracking |

### Monthly Review

| Metric | Month 1 Target | Month 2 Target | Month 3 Target |
|--------|----------------|----------------|----------------|
| **Total users** | 500 | 2,000 | 5,000 |
| **Trial starts** | 500 | 2,000 | 5,000 |
| **Trial-to-paid** | 3% | 5% | 7% |
| **Paid users** | 15 | 100 | 350 |
| **MRR** | ₹3,000 | ₹20,000 | ₹70,000 |
| **CAC** | ₹0 (organic) | ₹100 | ₹150 |

---

## Risk Mitigation

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| **Low trial conversion (<3%)** | Medium | High | Tighten free tier, improve paywall UX |
| **Coaching partners don't promote** | Medium | Medium | Revenue share incentive, co-branded reports |
| **Influencer content flops** | Low | Low | Start with 2-3, iterate on messaging |
| **Competitor launches similar** | Medium | High | Move fast, build brand loyalty |
| **Beta feedback is negative** | Low | High | Iterate quickly, delay launch if needed |

---

## Immediate Action Items

| Priority | Action | Owner | Deadline |
|----------|--------|-------|----------|
| **1** | Finalize coaching partnerships in Pune | Business | This week |
| **2** | Set up Firebase analytics events | Engineering | This week |
| **3** | Create testimonial request flow | Product | Week 2 |
| **4** | Draft referral program spec | Product | Week 2 |
| **5** | Identify 5 micro-influencers | Marketing | Week 2 |
| **6** | Create first 3 Reels scripts | Marketing | Week 2 |
| **7** | Design NPS survey | Product | Week 2 |
| **8** | Coaching partnership agreement template | Business | Week 3 |

---

## Success Criteria for Launch

**Green light for public launch when:**

- [ ] 50+ beta users active for 14+ days
- [ ] NPS > 40
- [ ] 20+ video testimonials collected
- [ ] Trial-to-paid conversion > 5% (simulated with survey intent)
- [ ] <5 critical bugs reported
- [ ] Referral system functional (even MVP)
- [ ] 2+ coaching partners committed to promote

**Red flags requiring delay:**

- NPS < 20
- >50% drop-off within 3 days
- Major feature broken (Snap & Solve, payments)
- Negative feedback pattern (same issue from 5+ users)
