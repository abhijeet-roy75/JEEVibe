# Formation-Stage Playbook: U.S. HoldCo + India OpCo

> **Status**: Strategic Reference Document
>
> **Created**: 2026-01-23
>
> **Last Updated**: 2026-01-23

**Context**
- Founders: U.S. citizens
- Product: Mobile app for JEE (Joint Entrance Examination) preparation
- Users & revenue: India
- Current stage: Pre-incorporation / formation

This document consolidates guidance on **entity setup, founder compensation, cross-border money flows, arm's-length economics, and advisor engagement**, tailored to your current formation stage.

---

## 1. Recommended Target Structure

**Best-practice structure (future-proof):**

```
Founders (US citizens)
        ↓
Delaware C-Corp (HoldCo)
  - Owns IP
  - Cap table & fundraising
  - Founder employment & payroll
        ↓ 100%
Indian Private Limited (OpCo)
  - Employees & educators
  - JEE content & marketing
  - Student contracts & INR revenue
  - Data & regulatory compliance
```

**Rationale**
- Simplifies founder equity and compensation
- Maximizes VC fundraising optionality
- Aligns with Indian regulatory and data requirements
- Avoids future restructuring

---

## 2. What to Do at the Formation Stage

### Do Now
- Finalize target structure (U.S. HoldCo + India OpCo)
- Engage:
  - One **U.S. startup attorney** (incorporation + IP)
  - One **India CA** for a *fixed-scope advisory consult*

### Do NOT Do Yet
- Do not retain full-time CAs/CPAs
- Do not incorporate IndiaCo before activity starts
- Do not optimize taxes before revenue exists
- Do not sign detailed intercompany agreements yet

---

## 3. Recommended Formation Sequence

### Step 1 — Incorporate U.S. HoldCo
- Delaware C-Corp
- Founder stock issuance + vesting
- IP assignment from founders to HoldCo
- Basic bylaws and cap table

### Step 2 — India Advisory Validation
- Confirm:
  - 100% foreign-owned Pvt Ltd feasibility
  - Director requirements (at least 1 resident Indian director)
  - Expected timelines and costs
  - GST and data compliance flags

### Step 3 — MVP / Market Testing
- No IndiaCo yet
- No Indian hiring
- No INR revenue collection

### Step 4 — Incorporate IndiaCo **When Any Trigger Occurs**
- Collect revenue from Indian users
- Hire India-based employees or contractors
- Store Indian user data at scale
- Sign Indian vendors or educators

### Step 5 — ODI Compliance (When IndiaCo Incorporated)

When US HoldCo invests capital in IndiaCo:

| Requirement | Timeline | Authority |
|-------------|----------|-----------|
| **ODI Form** (Overseas Direct Investment) | Within 30 days of remittance | RBI via AD Bank |
| **Annual Performance Report (APR)** | By Dec 31 each year | RBI |
| **FLA Return** | By July 15 each year | RBI |

**Note**: Your US bank (AD Bank) files ODI on your behalf. Ensure they have experience with India investments.

---

## 4. How Founders Get Paid (Once Live)

**Core rule:** Founders are paid by the **U.S. HoldCo**, not directly from India.

### Approved Money Flows (India → U.S.)
1. **Intercompany services fees** (most common early)
2. **IP royalties** (later-stage)
3. **Dividends** (rare, only when profitable)

Flow example:
```
Indian customers → India OpCo
India OpCo → (services fee / royalty) → U.S. HoldCo
U.S. HoldCo → (salary) → Founders
```

### Tax Implications on Each Flow

| Payment Type | India Withholding Tax | GST (Reverse Charge) | US-India DTAA Rate |
|--------------|----------------------|---------------------|-------------------|
| **Services fees** | 10% (if no PE) | 18% | 10-15% |
| **Royalties** | 10% | 18% | 10-15% |
| **Dividends** | 0% (post-2020) | N/A | 15-25% |

**Important**:
- US HoldCo can claim **Foreign Tax Credit** on US returns for Indian withholding tax paid
- GST on imported services adds 18% to effective cost — factor into pricing

---

## 5. Arm's-Length Economics (Key Concept)

**Definition:**
Intercompany pricing must mirror what **independent, unrelated companies** would agree to under similar conditions.

**Authorities evaluate:**
1. Functions – who does the work
2. Assets – who owns IP and data
3. Risks – who bears market and regulatory risk
4. Comparables – what similar companies pay

**Practical guardrails (typical, not hard limits):**

| Payment Type | Typical Range | Calculation Basis |
|--------------|---------------|-------------------|
| **Services fees** | Cost + 8–15% markup | Markup on actual costs incurred by HoldCo |
| **Royalties** | 3–8% of revenue | Percentage of IndiaCo gross revenue |

**Key constraint**: IndiaCo should retain **5-10% operating margin minimum**. If IndiaCo is consistently loss-making while sending large sums upstream → **not arm's length** → audit risk.

### Transfer Pricing Documentation Timing

| Stage | Action |
|-------|--------|
| **IndiaCo incorporation** | Sign basic 1-page intercompany services agreement |
| **First ₹50L revenue** | Get simple TP documentation from CA |
| **First ₹1Cr revenue** | Full transfer pricing study |
| **₹5Cr+ revenue** | Annual TP report and benchmarking |

**Note**: Indian tax authorities can challenge retroactively. Having a basic agreement from day 1 protects you.

---

## 6. Limits on Sending Money from India to the U.S.

- **No fixed dollar cap** under RBI/FEMA
- Effective limits are:
  - Arm's-length pricing
  - Transfer pricing documentation
  - IndiaCo profitability and substance

Large remittances are normal if properly structured and documented.

### Remittance Process

Each remittance requires:

| Document | Purpose | Who Provides |
|----------|---------|--------------|
| **Form 15CA** | Declaration of payment details | Filed online by IndiaCo |
| **Form 15CB** | CA certificate for tax compliance | Your India CA |
| **Invoice** | Services/royalty description | US HoldCo |
| **Intercompany agreement** | Legal basis for payment | Both parties |

**Timeline**: Allow 3-5 business days for 15CB certificate + bank processing.

---

## 7. Permanent Establishment Risk

If US founders spend significant time in India directing operations, US HoldCo could be deemed to have a **Permanent Establishment (PE)** in India — triggering Indian taxation on HoldCo profits.

### PE Risk Factors

| Risk Factor | Mitigation |
|-------------|------------|
| Founders in India >182 days/year | Track travel days carefully |
| Founders signing Indian contracts | IndiaCo employees sign all local contracts |
| Founders directing daily operations from India | Document that strategic decisions made from US |
| Fixed place of business in India | All Indian office space in IndiaCo's name |

### Safe Practices

- Keep founder India visits to **<90 days per year** per founder
- Maintain documentation showing strategic decisions made in US
- IndiaCo management should have autonomy for local operations
- Use video calls for oversight rather than physical presence

---

## 8. Data Localization Requirements

As an edtech handling student data, you must comply with Indian data regulations.

### RBI Data Localization (Payment Data)

| Requirement | Details |
|-------------|---------|
| **What** | All payment system data must be stored in India |
| **Scope** | Transaction data, card details, UPI data |
| **Solution** | Use Indian payment gateways (Razorpay, PayU) that handle compliance |

### Digital Personal Data Protection Act 2023 (DPDP)

| Requirement | Details |
|-------------|---------|
| **Consent** | Clear consent for data collection |
| **Purpose limitation** | Use data only for stated purposes |
| **Data principal rights** | Users can request access/deletion |
| **Children's data** | Parental consent for users <18 (most JEE students) |
| **Cross-border transfer** | Permitted to non-restricted countries (US is allowed) |

### Practical Implementation

| Data Type | Where to Store | Notes |
|-----------|----------------|-------|
| **Payment data** | India (via Razorpay/PayU) | Mandatory |
| **User profiles** | India preferred | Reduces latency, simplifies compliance |
| **Analytics/logs** | India or US | Anonymized OK anywhere |
| **AI model training data** | US OK if anonymized | Check consent language |

**Recommendation**: Store all user PII in India-region Firebase/GCP. Simpler compliance, better latency for users.

---

## 9. Employee Stock Options (ESOP)

For India-based employees, you have options:

| Approach | Complexity | Tax Efficiency | FEMA Approval |
|----------|------------|----------------|---------------|
| **US HoldCo grants to India employees** | High | Good | Required |
| **India ESOP pool** | Medium | Moderate | Not required |
| **Phantom stock / SAR** | Low | Moderate | Not required |

### Recommended Approach (Early Stage)

**Start with Phantom Stock / Stock Appreciation Rights (SARs)**:
- Cash-settled bonus tied to company valuation
- No FEMA approval needed
- No actual equity transfer complexity
- Convert to real equity at Series A when you have legal bandwidth

### If Using US HoldCo Equity for India Employees

| Step | Requirement |
|------|-------------|
| 1 | FEMA approval via AD Bank (Form ODI) |
| 2 | Employee files LRS declaration (up to $250K/year) |
| 3 | Taxed as perquisite at exercise (India) |
| 4 | Capital gains on sale (India + potentially US) |

**Timing**: Don't set up complex ESOP until you have 5+ India employees and legal budget.

---

## 10. Advisor Engagement Strategy

### India

| Role | When | Scope | Typical Cost |
|------|------|-------|--------------|
| **CA (one-time consult)** | Pre-IndiaCo | Structure validation | ₹15-25K |
| **CA (retainer)** | IndiaCo active | GST, TDS, compliance | ₹15-30K/month |
| **CS (Company Secretary)** | IndiaCo active | ROC filings, board minutes | ₹5-10K/month |
| **TP specialist** | Post ₹1Cr revenue | Transfer pricing study | ₹50-100K one-time |

### United States

| Role | When | Scope | Typical Cost |
|------|------|-------|--------------|
| **Startup attorney** | Now | Incorporation, IP assignment | $2-5K one-time |
| **CPA (light)** | Post-revenue | Tax filings, payroll | $300-500/month |
| **CPA (full)** | Series A | Audit-ready financials | $1-2K/month |

**Critical:** India CA and U.S. CPA must coordinate on:
- Withholding tax credits
- Transfer pricing consistency
- Intercompany agreement terms

---

## 11. Compliance Calendar (Once IndiaCo Active)

### Monthly

| Filing | Due Date | Authority |
|--------|----------|-----------|
| GST returns (GSTR-1, GSTR-3B) | 11th & 20th | GST Portal |
| TDS deposit | 7th of next month | Income Tax |
| PF/ESI deposit | 15th of next month | EPFO/ESIC |

### Quarterly

| Filing | Due Date | Authority |
|--------|----------|-----------|
| TDS returns (Form 24Q, 26Q) | End of month after quarter | Income Tax |
| Advance tax (if applicable) | 15th of Jun/Sep/Dec/Mar | Income Tax |

### Annual

| Filing | Due Date | Authority |
|--------|----------|-----------|
| Income tax return | Oct 31 (audit cases) | Income Tax |
| Transfer pricing report | Nov 30 | Income Tax |
| ROC annual return | Within 60 days of AGM | MCA |
| Statutory audit | Before AGM | CA |
| APR (ODI compliance) | Dec 31 | RBI |

### Per Remittance

| Filing | When | Authority |
|--------|------|-----------|
| Form 15CA | Before each payment | Income Tax portal |
| Form 15CB | Before each payment | CA certification |

---

## 12. Cost Discipline at Formation Stage

| Area | Spend Now | Defer | Typical Cost |
|------|-----------|-------|--------------|
| U.S. legal incorporation | Yes | — | $2-5K |
| India CA advisory (one-time) | Yes | — | ₹15-25K |
| India CA retainer | No | Until IndiaCo active | ₹15-30K/mo |
| India CS retainer | No | Until IndiaCo active | ₹5-10K/mo |
| U.S. CPA retainer | No | Until revenue | $300-500/mo |
| Transfer pricing study | No | Post ₹1Cr revenue | ₹50-100K |
| ESOP setup | No | Post Series A | $5-10K legal |

**Total pre-revenue spend**: ~$3-6K + ₹15-25K

---

## 13. Red Flags to Avoid

| Don't Do This | Why | Risk |
|---------------|-----|------|
| Pay founders directly from IndiaCo | Creates tax mess, breaks structure | High |
| Send >90% of revenue upstream | IndiaCo looks like a shell, not arm's length | High |
| Skip 15CA/15CB for remittances | Bank will block transfer | Medium |
| Ignore GST on services imports | 18% liability accrues silently | Medium |
| Store payment data outside India | RBI violation | High |
| Founders in India >182 days | PE risk for HoldCo | High |
| No intercompany agreement | TP challenge, no legal basis for payments | Medium |
| Grant US equity to India employees without FEMA | Violation, employee liability | High |

---

## 14. Bottom Line

- Design the structure **now**
- Execute incorporation **only when activity begins**
- Use U.S. HoldCo for ownership, IP, fundraising, and founder pay
- Use India OpCo for operations, users, revenue, and compliance
- Keep founders' India presence under 90 days/year
- Store user data and payments in India
- Have basic intercompany agreement from day 1

This approach minimizes cost and risk while preserving maximum flexibility as you scale.

---

## 15. Quick Reference: Formation Checklist

### Pre-Launch (Now)
- [ ] Finalize US HoldCo + India OpCo structure
- [ ] Engage US startup attorney
- [ ] Incorporate Delaware C-Corp
- [ ] Issue founder stock with vesting
- [ ] Assign IP to HoldCo
- [ ] Get India CA advisory consult

### At Launch (When Triggers Hit)
- [ ] Incorporate India Pvt Ltd (100% owned by US HoldCo)
- [ ] File ODI with RBI via AD Bank
- [ ] Appoint resident Indian director
- [ ] Sign basic intercompany services agreement
- [ ] Set up Indian payment gateway (Razorpay/PayU)
- [ ] Engage India CA on retainer
- [ ] Set up GST registration

### Post-Revenue
- [ ] Monthly GST and TDS compliance
- [ ] Quarterly TDS returns
- [ ] First remittance with 15CA/15CB
- [ ] Transfer pricing documentation (at ₹50L)
- [ ] Full TP study (at ₹1Cr)
