# DAU Infrastructure & Scaling Guide

## Overview

This document outlines JEEVibe's current infrastructure, DAU (Daily Active Users) capacity at each tier, and the roadmap for scaling.

---

## Current Infrastructure Stack

| Component | Service | Tier | Cost |
|-----------|---------|------|------|
| **Backend API** | Render.com | Free | $0/month |
| **Database** | Firebase Firestore | Blaze (Pay-as-you-go) | ~$0-20/month |
| **Authentication** | Firebase Phone Auth | Blaze | Included |
| **File Storage** | Firebase Storage | Blaze | ~$0-5/month |
| **Cron Jobs** | Render.com / cron-job.org | Free | $0/month |

### Backend (Render.com Free Tier)

**Current Limitations:**
- 750 free hours/month (sufficient for always-on single instance)
- Instance spins down after 15 min inactivity
- Cold start: ~30-60 seconds
- 512 MB RAM, shared CPU
- No persistent disk

**Resilience Features Implemented:**
- Circuit breaker pattern for AI services (Gemini, OpenAI)
- Automatic retry with exponential backoff
- Graceful degradation when services unavailable
- Request timeout handling (30s default)

### Database (Firebase Firestore)

**Current Usage:**
- Region: `asia-south1` (Mumbai) for India users
- Indexed queries for fast lookups
- Subcollections for per-user data isolation

**Free Tier Limits (exceeded, now on Blaze):**
- 50K reads/day
- 20K writes/day
- 1 GB storage

**Blaze Plan Pricing:**
- Reads: $0.06 per 100K
- Writes: $0.18 per 100K
- Storage: $0.18/GB/month

---

## User Subscription Tiers

| Feature | Free | Pro | Ultra |
|---------|------|-----|-------|
| Daily Snap Solves | 3/day | 15/day | Unlimited |
| Practice Questions | Limited | Full access | Full access |
| Snap History | 7 days | 30 days | Unlimited |
| AI Tutor | Basic | Enhanced | Premium |
| Image Cache | 10 MB | 100 MB | 500 MB |
| Offline Mode | No | Yes | Yes |
| Analytics | Basic | Detailed | Detailed |

---

## DAU Capacity by Phase

### Phase 1: Launch (0-10,000 DAU) ✅ CURRENT

**Status:** Production Ready

**Infrastructure:**
- Render.com free tier (single instance)
- Firebase Firestore (Blaze plan)
- No caching layer

**Performance:**
- Quiz generation: ~185ms
- Quiz completion: ~350ms
- Weekly snapshot job: ~37 minutes

**Monthly Costs:**
| Component | Cost |
|-----------|------|
| Render.com | $0 |
| Firestore (10K users) | ~$20-30 |
| Phone Auth | ~$10-15 |
| Storage | ~$5 |
| **Total** | **~$35-50/month** |

**Bottlenecks:** None at this scale

---

### Phase 2: Growth (10,000-50,000 DAU) ⚠️ NEEDS OPTIMIZATION

**Required Upgrades:**

1. **Upgrade Render.com to Starter ($7/month)**
   - Persistent instance (no cold starts)
   - Cron job support built-in
   - Better CPU allocation

2. **Implement Batch Processing**
   ```javascript
   // Process users in batches of 100 for weekly snapshots
   const batches = chunk(users, 100);
   for (const batch of batches) {
     await Promise.all(batch.map(user => createSnapshot(user.id)));
   }
   ```

3. **Add In-Memory Caching**
   - Cache user profiles (5 min TTL)
   - Cache question metadata
   - Reduce Firestore reads by ~40%

4. **Incremental Question Stats**
   - Only update questions answered this week
   - Reduces processing from 8000 to ~200 questions

**Monthly Costs:**
| Component | Cost |
|-----------|------|
| Render.com Starter | $7 |
| Firestore (50K users) | ~$80-100 |
| Phone Auth | ~$50 |
| Storage | ~$20 |
| **Total** | **~$160-180/month** |

**Timeline:** Implement when approaching 10K DAU

---

### Phase 3: Scale (50,000-100,000 DAU) ❌ ARCHITECTURE CHANGES

**Required Upgrades:**

1. **Upgrade Render.com to Standard ($25/month)**
   - 2 GB RAM
   - Dedicated CPU
   - Auto-scaling available

2. **Add Redis Caching Layer**
   - Render Redis ($10/month) or Upstash (free tier)
   - Session caching
   - Rate limiting
   - Distributed locks

3. **Background Job Queue**
   - Bull/BullMQ with Redis
   - Async processing of:
     - Weekly snapshots
     - Question stats aggregation
     - Analytics computation

4. **Database Optimizations**
   - Add composite indexes
   - Implement read replicas (if needed)
   - Shard by user ID ranges

**Infrastructure Diagram:**
```
                    ┌─────────────────┐
                    │   Load Balancer │
                    │   (Render.com)  │
                    └────────┬────────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
        ┌─────▼─────┐  ┌─────▼─────┐  ┌─────▼─────┐
        │  API #1   │  │  API #2   │  │  API #3   │
        └─────┬─────┘  └─────┬─────┘  └─────┬─────┘
              │              │              │
              └──────────────┼──────────────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
        ┌─────▼─────┐  ┌─────▼─────┐  ┌─────▼─────┐
        │   Redis   │  │ Firestore │  │  Worker   │
        │   Cache   │  │    DB     │  │   Queue   │
        └───────────┘  └───────────┘  └───────────┘
```

**Monthly Costs:**
| Component | Cost |
|-----------|------|
| Render.com Standard (x2) | $50 |
| Redis (Render) | $10 |
| Firestore (100K users) | ~$150-200 |
| Phone Auth | ~$100 |
| Storage | ~$40 |
| **Total** | **~$350-400/month** |

**Timeline:** Plan when approaching 50K DAU

---

### Phase 4: Enterprise (100,000+ DAU) ❌ MAJOR REFACTORING

**Required Upgrades:**

1. **Microservices Architecture**
   - Quiz Generation Service
   - User Service
   - Analytics Service
   - AI Tutor Service

2. **Event-Driven Architecture**
   - Pub/Sub for quiz completion events
   - Async processing pipelines
   - Event sourcing for audit trail

3. **CDN for Static Content**
   - Question images
   - Solution diagrams
   - Reduces bandwidth costs

4. **Consider Cloud Migration**
   - Google Cloud Run (auto-scaling)
   - Cloud Functions for background jobs
   - Cloud Pub/Sub for messaging

**Infrastructure Options:**

| Option | Pros | Cons |
|--------|------|------|
| Stay on Render | Simple, familiar | Limited auto-scaling |
| Google Cloud | Native Firebase integration | Higher complexity |
| AWS | Most scalable | Steeper learning curve |

**Monthly Costs:**
| Component | Cost |
|-----------|------|
| Compute (GCR/ECS) | ~$200-300 |
| Redis/Memcached | ~$50 |
| Firestore/DynamoDB | ~$300-400 |
| CDN | ~$50 |
| Monitoring | ~$50 |
| **Total** | **~$650-850/month** |

---

## Current Resilience Features

### Circuit Breaker Pattern

Implemented for external AI services:

```javascript
// Circuit breaker states: CLOSED → OPEN → HALF_OPEN
const circuitBreaker = {
  failureThreshold: 5,      // Open after 5 failures
  recoveryTimeout: 30000,   // Try again after 30s
  successThreshold: 2       // Close after 2 successes
};
```

**Protected Services:**
- Gemini AI (snap-solve)
- OpenAI (AI tutor)
- External APIs

### Timeout Handling

| Operation | Timeout | Fallback |
|-----------|---------|----------|
| AI Generation | 30s | Return error with retry option |
| Database Query | 10s | Return cached data if available |
| Image Processing | 20s | Queue for background processing |

### Rate Limiting

| Endpoint | Free Tier | Pro Tier | Ultra Tier |
|----------|-----------|----------|------------|
| Snap Solve | 3/day | 15/day | Unlimited |
| AI Tutor | 10/day | 50/day | Unlimited |
| Practice | 30/day | Unlimited | Unlimited |

---

## Monitoring & Alerts

### Key Metrics to Track

1. **Response Time**
   - Target: < 500ms (p95)
   - Alert: > 1s (p95)

2. **Error Rate**
   - Target: < 0.1%
   - Alert: > 1%

3. **Weekly Job Duration**
   - Target: < 1 hour
   - Alert: > 2 hours

4. **Firestore Usage**
   - Monitor: Daily reads/writes
   - Alert: > 80% of estimated budget

### Recommended Tools

| Tool | Purpose | Cost |
|------|---------|------|
| Render Logs | Application logs | Free |
| Firebase Console | Database metrics | Free |
| Better Uptime | Uptime monitoring | Free tier |
| Sentry | Error tracking | Free tier |

---

## Scaling Triggers

| Metric | Current | Action Trigger | Action |
|--------|---------|----------------|--------|
| DAU | <10K | 8K DAU | Plan Phase 2 upgrades |
| Response Time | <500ms | >800ms (p95) | Add caching |
| Weekly Job | <1 hr | >2 hrs | Implement batching |
| Error Rate | <0.1% | >0.5% | Investigate & fix |
| Monthly Cost | ~$50 | >$100 | Review optimizations |

---

## Quick Reference: Upgrade Checklist

### When approaching 10K DAU:
- [ ] Upgrade Render to Starter plan ($7/month)
- [ ] Implement in-memory caching for user profiles
- [ ] Add batch processing for weekly snapshots
- [ ] Set up proper monitoring (Sentry, Better Uptime)

### When approaching 50K DAU:
- [ ] Upgrade Render to Standard plan ($25/month)
- [ ] Add Redis caching layer
- [ ] Implement background job queue (Bull)
- [ ] Consider horizontal scaling (2+ instances)
- [ ] Add CDN for static assets

### When approaching 100K DAU:
- [ ] Evaluate cloud migration (GCP/AWS)
- [ ] Design microservices architecture
- [ ] Implement event-driven processing
- [ ] Add comprehensive monitoring (Datadog/New Relic)

---

## Cost Optimization Tips

1. **Firestore Reads**
   - Use `.select()` to fetch only needed fields
   - Implement client-side caching
   - Batch queries where possible

2. **Firestore Writes**
   - Use batch writes (up to 500 ops)
   - Debounce frequent updates
   - Use increment operations vs read-modify-write

3. **Compute**
   - Optimize cold starts with keep-alive pings
   - Use efficient algorithms for quiz generation
   - Compress API responses

4. **Storage**
   - Compress images before upload
   - Set lifecycle rules for old data
   - Use tiered storage for archives

---

## Summary

| Phase | DAU | Monthly Cost | Status |
|-------|-----|--------------|--------|
| 1 | 0-10K | ~$35-50 | ✅ Current |
| 2 | 10K-50K | ~$160-180 | ⚠️ Plan at 8K DAU |
| 3 | 50K-100K | ~$350-400 | ❌ Plan at 40K DAU |
| 4 | 100K+ | ~$650-850 | ❌ Plan at 80K DAU |

**Current Capacity:** 10,000 DAU comfortably, 50,000 with optimizations

**Next Milestone:** Implement Phase 2 optimizations when approaching 8-10K DAU
