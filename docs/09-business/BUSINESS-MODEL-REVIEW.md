# JEEVibe Business Model Review & GTM Recommendations

> **Status**: Strategic Reference Document
>
> **Created**: 2026-01-23
>
> **Related**:
> - [GTM-EXECUTION-PLAN.md](./GTM-EXECUTION-PLAN.md) - Detailed execution plan
> - [TIER-SYSTEM-ARCHITECTURE.md](../03-features/TIER-SYSTEM-ARCHITECTURE.md) - Technical tier implementation
> - [TRIAL-FIRST-IMPLEMENTATION.md](../03-features/TRIAL-FIRST-IMPLEMENTATION.md) - Trial system engineering spec
> - [PROMO-REFERRAL-SYSTEM.md](../03-features/PROMO-REFERRAL-SYSTEM.md) - Promo/referral code implementation
> - [ANTI-ABUSE-SESSION-MANAGEMENT.md](../03-features/ANTI-ABUSE-SESSION-MANAGEMENT.md) - Session management spec

## Context Summary

| Dimension | Value |
|-----------|-------|
| **Target Market** | JEE Main aspirants (15L+ students, price-sensitive) |
| **Stage** | Cold start, bootstrap (₹50L-1Cr Y1 target, 5-10K paid users) |
| **Launch Timeline** | 1-2 months |
| **Differentiation** | AI-first (Snap & Solve + AI Tutor) + Personalization + Convenience |
| **Content Strategy** | Human-curated + AI (quality advantage) |
| **Acquisition** | Hybrid (organic + paid + partnerships) |

---

## Current Tier Model Assessment

### PROS

| Strength | Why It Matters |
|----------|----------------|
| **Full solutions for all tiers** | Builds trust, drives word-of-mouth (competitors gate quality) |
| **Pricing undercuts market** | Pro ₹199-299/mo vs PW ₹500+, Unacademy ₹1000+ |
| **AI Tutor as ULTRA differentiator** | 5-10x cheaper than human tutoring, unique moat |
| **Clear value ladder** | FREE→PRO (usage), PRO→ULTRA (AI Tutor) - no confusion |
| **Firestore-driven config** | Instant A/B testing without deployment |
| **IST timezone handling** | Shows local market understanding |

### CONS

| Issue | Risk | Severity |
|-------|------|----------|
| **Free tier too generous** | 5 snaps/day may satisfy 80% of needs (mitigated by trial-first model) | LOW |
| **No referral program** | Critical for cold start - missing viral loop | HIGH |
| **No introductory pricing** | Unknown brand asking ₹299/month upfront | MEDIUM |
| **Annual plans won't sell** | No trust yet for ₹2,388 commitment | MEDIUM |
| **PRO vs ULTRA gap too narrow** | ₹150/mo difference may cannibalize | MEDIUM |
| **Offline mode feels like table stakes** | May create negative perception when gated | LOW |
| **No family/institutional pricing** | Missing B2B revenue stream | LOW |

### Recommended Tier Limits (Hard Caps)

Replace all "Unlimited" with hard caps. Market as "Unlimited" but enforce fair use limits.

| Feature | FREE | PRO | ULTRA |
|---------|------|-----|-------|
| **Snap & Solve** | 5/day | 15/day | 50/day |
| **Practice after Snap** | - | 3/snap | 3/snap |
| **Daily Quiz** | 1/day | 10/day | 25/day |
| **Chapter Practice** | 1/week/subject | 5/day | 15/day |
| **Mock Tests** | 1/month | 5/month | 15/month |
| **Solution History** | 7 days | 30 days | 365 days |
| **AI Tutor Messages** | - | - | 100/day |
| **Analytics** | Basic | Full | Full |
| **Offline Mode** | - | Yes | Yes |
| **Devices** | 1 | 2 | 2 |

> **Note**: Monitor usage via admin portal. If >5% of users hit 80% of daily limit, consider increasing.

---

## Trial-First Model (Adopted)

All new users automatically receive a **30-day Pro trial** upon signup. No credit card required.

### User Journey

```
SIGNUP → PRO TRIAL (30 days) → PAID or FREE
```

| Phase | Duration | Features | Goal |
|-------|----------|----------|------|
| **Trial** | Day 1-30 | Full Pro access (15 snaps, 10 quizzes, offline, etc.) | Hook the user |
| **Countdown** | Day 25-30 | Push notifications showing trial ending | Create urgency |
| **Decision** | Day 30 | Upgrade prompt | Convert to paid |
| **Post-trial** | Day 31+ | Free tier (5 snaps, 1 quiz) OR Paid | Retain or monetize |

### Why Trial-First Works

| Benefit | Explanation |
|---------|-------------|
| **Loss aversion** | Users feel the pain of losing 15 → 5 snaps |
| **Full value demo** | Users experience everything before deciding |
| **Built-in urgency** | Trial countdown creates natural conversion pressure |
| **Higher engagement** | Pro features = more usage = more habit formation |

### Trial Notifications

| Day | Notification |
|-----|--------------|
| 7 | "You've solved 42 questions this week! 23 days left in your trial." |
| 25 | "5 days left! Keep your Pro features for ₹199/month." |
| 28 | "2 days left! Don't lose your 30-day solution history." |
| 30 | "Trial ended. Upgrade to continue with Pro features." |

### Free Tier Post-Trial

Keep at **5 snaps/day** (not 3) because:
- 15 → 5 is already a 67% reduction (painful enough)
- 15 → 3 would feel punitive and cause bad reviews
- 5 snaps keeps users engaged for future conversion

---

## Recommended Tier Adjustments

### 1. Quarterly-First Pricing Strategy

Make quarterly the default/highlighted option. Lower monthly feels accessible, quarterly is the value play.

| Tier | Monthly | Quarterly (DEFAULT) | Annual |
|------|---------|---------------------|--------|
| **Pro** | ₹249 | ₹199/mo (₹597) | ₹149/mo (₹1,788) |
| **Ultra** | ₹449 | ₹349/mo (₹1,047) | ₹249/mo (₹2,988) |

**Rationale**:
- ₹597 for 3 months is easier to commit to than ₹2,388 for annual
- Monthly at ₹249 pushes users toward quarterly value
- Annual is for power users, not the default

### 2. Student ID Discount (Tier 2/3 Friendly)

```
Verify student ID → 20% off first purchase
Pro Quarterly: ₹597 → ₹477 (₹159/mo)
Ultra Quarterly: ₹1,047 → ₹837 (₹279/mo)
```

**Rationale**: Captures price-sensitive Tier 2/3 students without regional pricing complexity.

### 3. Add Referral Tier Benefits

```
New: Referral rewards
- Referrer: +5 bonus snaps for 7 days
- Referee: +3 bonus snaps for 7 days + ₹50 off first purchase
- Streak bonus: 3 successful referrals = 1 week Pro free
```

**Rationale**: CRITICAL for cold start. Zero-cost acquisition.

### 4. Consider "Student Verification" Unlock

```
New: Verify student ID → Unlock 2 extra snaps/day (free tier)
```

**Rationale**: Builds authentic user base, prevents abuse, creates engagement hook.

---

## GTM Strategy Recommendations

### Phase 1: Pre-Launch (Now - Launch)

| Action | Purpose |
|--------|---------|
| **Build referral system** | URGENT - Critical for cold start |
| **Create "Founding Members" waitlist** | Build launch list with urgency |
| **Partner with 2-3 micro-influencers** | JEE prep YouTubers with 10K-50K subs |
| **Prepare 50 beta testers** | Testimonials + bug fixes before launch |

### Phase 2: Launch Month

| Channel | Budget Allocation | Expected CAC |
|---------|-------------------|--------------|
| **Referral program** | ₹0 (organic) | ₹0 |
| **Instagram/YouTube influencers** | 40% of budget | ₹50-100 |
| **Google Ads (branded + JEE keywords)** | 30% of budget | ₹100-200 |
| **School/coaching partnerships** | 20% of budget | ₹30-50 |
| **Organic content (Reels, Shorts)** | 10% of budget | ₹0 |

### Phase 3: Months 2-6

- **Double down on what works** based on CAC data
- **Build case studies**: "I improved 50 percentile using JEEVibe"
- **Seasonal push**: Jan-April (JEE Main season)
- **Testimonial loop**: Ask every converter for video review

---

## Unit Economics Target

| Metric | Target | Rationale |
|--------|--------|-----------|
| **Trial-to-Paid Conversion** | 5-10% | Higher than freemium due to trial-first model |
| **Monthly Churn** | <10% | Healthy for bootstrap stage |
| **LTV** | ₹1,500-2,000 | Assumes 5-7 month average retention |
| **CAC** | <₹300 | 5x LTV/CAC ratio minimum |
| **Payback Period** | <2 months | Critical for bootstrap cash flow |

---

## Pricing Comparison (Market Context)

| Competitor | Monthly Price | What You Get |
|------------|---------------|--------------|
| **Physics Wallah** | ₹499-999 | Video lectures + tests |
| **Unacademy** | ₹1,000-2,500 | Live classes + recordings |
| **Vedantu** | ₹800-1,500 | Live tutoring sessions |
| **Allen Digital** | ₹1,500+ | Full course + tests |
| **JEEVibe Pro** | ₹199-249 | AI doubt solving + practice + 30-day free trial |
| **JEEVibe Ultra** | ₹499 | + Unlimited AI tutoring |

**Your positioning**: "Instant doubt solving + AI tutoring at 1/3rd the price"

---

## Feature Value Hierarchy (Marketing Priority)

### Perceived Value Ranking

| Rank | Feature | Perceived Value | Marketing Priority |
|------|---------|-----------------|-------------------|
| **#1** | **Snap & Solve** | HIGHEST | Lead with this - "hero feature" |
| **#2** | **Mock Exams** | HIGH | Strong conversion driver |
| **#3** | **Chapter Practice** | MEDIUM-HIGH | Systematic prep appeal |
| **#4** | **Daily Quiz** | MEDIUM | Engagement/habit driver |
| **#5** | **Adaptive Learning** | LOW (initially) | Background feature - don't lead with |

### Why This Ranking

| Feature | Student Mindset | Conversion Power |
|---------|-----------------|------------------|
| **Snap & Solve** | "I'm stuck at 11pm, need help NOW" | Highest - immediate gratification |
| **Mock Exams** | "Am I ready for JEE? How do I compare?" | High - 1/month limit frustrates serious students |
| **Chapter Practice** | "I need to cover the syllabus" | Medium - feels like "work" |
| **Daily Quiz** | "Keep me sharp" | Low - 1/day feels sufficient |
| **Adaptive Learning** | "I don't see how this helps me" | None - invisible algorithm |

### Marketing Implications

**Lead messaging:**
```
"Stuck on a JEE problem? Snap a photo, get the solution in seconds."
```

**Conversion messaging (trial expiry):**
```
"Your trial ends in 3 days. Don't lose access to unlimited mock tests."
```

**Reposition adaptive learning as:**
```
"Questions that adapt to YOUR level" (embedded benefit, not standalone feature)
```

### Feature Gating Conversion Power

| Feature | Free Limit | Student Feeling | Conversion Power |
|---------|------------|-----------------|------------------|
| **Mock Exams** | 1/month | "I NEED more!" | **Highest** |
| **Snap & Solve** | 5/day | "I want more" | High |
| **Chapter Practice** | 1/week/subject | "Frustrating" | Medium |
| **Daily Quiz** | 1/day | "Fine for now" | Low |

> **Key insight**: Mock Exams at 1/month is your strongest conversion lever. Students hit this wall quickly during exam season (Jan-April).

---

## Critical Launch Checklist

### Must-Have Before Launch (HIGH PRIORITY)

- [ ] **Single active session enforcement** (new login = old devices kicked)
- [ ] **30-day Pro trial for all new signups** (auto-downgrade to Free after)
- [ ] **Referral program implemented** (even basic version)
- [ ] **Quarterly-first pricing UI** (₹199/mo Pro, ₹349/mo Ultra)
- [ ] **20-50 testimonials from beta testers**
- [ ] **App store optimization** (ASO) completed
- [ ] **Landing page with social proof**

### Should-Have Week 1 (MEDIUM PRIORITY)

- [ ] Influencer content scheduled
- [ ] Google Ads campaigns ready
- [ ] School partnership outreach started
- [ ] Support response SLA defined (<2 hours)

### Nice-to-Have Month 1 (LOW PRIORITY)

- [ ] Push notification strategy
- [ ] Email drip campaigns
- [ ] Community Discord/Telegram
- [ ] Student ambassador program

---

## Anti-Abuse Strategy

**Unlimited Ultra tier creates account sharing risk.** Without controls, 10 students sharing 1 Ultra account = ₹30/month each (vs ₹299 Pro).

### Current Protections

| Measure | Status |
|---------|--------|
| Phone # validation via SMS | Done |
| Screenshot blocking | Done |
| API authentication | Done |

### Required Before Launch

| Measure | Priority | Impact |
|---------|----------|--------|
| **Single active session** | CRITICAL | New login kicks out all other devices |
| **Device limit (2 max)** | HIGH | Prevents spreading to 10+ devices |
| **Hard limits on all tiers** | MEDIUM | Prevents bot abuse, enables monitoring |

### Recommended Hard Limits (All Tiers)

Replace "unlimited" (-1) with generous daily caps. Monitor via admin portal and adjust based on real usage.

| Feature | FREE | PRO | ULTRA | Rationale |
|---------|------|-----|-------|-----------|
| **Snap & Solve** | 5/day | 15/day | 50/day | Top 1% student might do 30/day during exams |
| **Daily Quiz** | 1/day | 10/day | 25/day | 25 quizzes = 5+ hours of practice |
| **AI Tutor Messages** | 0 | 0 | 100/day | 100 messages = ~2 hours of tutoring |
| **Chapter Practice Sessions** | 1/week/subject | 5/day | 15/day | 15 sessions = full day of practice |
| **Mock Tests** | 1/month | 5/month | 15/month | 15/month = every other day, plenty for serious prep |
| **Solution History** | 7 days | 30 days | 365 days | 1 year is effectively "unlimited" |
| **Devices** | 1 | 2 | 2 | Same for Pro/Ultra |

**Marketing**: Continue to say "Unlimited" - no legitimate student hits these caps. Add fair use policy in Terms of Service.

**Monitoring**: Track users hitting >80% of daily limits in admin portal. If many legitimate users hit caps, increase limits.

**Full technical spec**: [ANTI-ABUSE-SESSION-MANAGEMENT.md](../03-features/ANTI-ABUSE-SESSION-MANAGEMENT.md)

---

## Risks to Monitor

| Risk | Mitigation |
|------|------------|
| **Account sharing (Ultra)** | Single session + device limits (see Anti-Abuse section) |
| **PW launches similar AI feature** | Move fast, build brand loyalty |
| **Low conversions (<1%)** | Tighten free tier, improve paywall UX |
| **High churn (>15%)** | Add engagement hooks (streaks, gamification) |
| **AI quality issues** | Human review queue for flagged solutions |
| **Seasonal revenue dip** | Push annual plans after trust is built |

---

## Summary

**The tier model is fundamentally sound** - pricing is competitive, value ladder is clear, and AI Tutor differentiation is unique in the budget segment.

**Critical gaps to address before launch:**

1. **CRITICAL** - Single active session to prevent account sharing
2. **CRITICAL** - Implement 30-day Pro trial for all new signups
3. **HIGH** - Build referral program (non-negotiable for cold start)
4. **HIGH** - Quarterly-first pricing with student discount
5. **MEDIUM** - Trial expiry notifications (Day 7, 25, 28, 30)

**Your positioning**: "The AI-powered JEE prep that solves doubts instantly at ₹299/month" - targets convenience-seeking, price-sensitive JEE Main aspirants who don't want to watch 2-hour lectures for a 5-minute doubt.

---

## Action Items

| Priority | Item | Owner | Status |
|----------|------|-------|--------|
| CRITICAL | Implement single active session | Engineering | Pending |
| CRITICAL | Implement 30-day Pro trial for new signups | Engineering | Pending |
| HIGH | Update Firestore tier_config with hard limits | Engineering | Pending |
| HIGH | Design referral program | Product | Pending |
| HIGH | Implement quarterly-first pricing UI | Design | Pending |
| HIGH | Add device limits (1 free, 2 paid) | Engineering | Pending |
| MEDIUM | Trial expiry push notifications (Day 7, 25, 28, 30) | Engineering | Pending |
| MEDIUM | Student ID verification for discount | Engineering | Pending |
| MEDIUM | Update paywall UI with trial countdown | Design | Pending |
| MEDIUM | Add admin portal alert for users hitting 80% limits | Engineering | Pending |
| LOW | Create institutional pricing | Business | Backlog |
