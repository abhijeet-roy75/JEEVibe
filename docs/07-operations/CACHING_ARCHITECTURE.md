# JEEVibe Caching Architecture

## Overview

This document outlines the caching strategy for JEEVibe to reduce Firestore reads, improve response times, and prepare for horizontal scaling.

- **Phase 1**: Enhanced `node-cache` (in-memory, single instance) - Current
- **Phase 2**: Redis/Upstash (distributed, multi-instance) - Future

---

## Phase 1: node-cache Implementation

### 1.1 Cache Module Design

**File**: `backend/src/utils/cache.js`

**Architecture**: Separate cache instances for different data types:

| Cache Type | Purpose | TTL Default | Check Period |
|------------|---------|-------------|--------------|
| `globalCache` | Questions, static data | 1 hour | 120 sec |
| `userCache` | Per-user data | 5 min | 60 sec |

**Cache Key Structure**:
```
Global:
  global:assessment_questions
  global:questions:{chapterKey}
  global:chapter_mapping

Per-User:
  user:{userId}:theta
  user:{userId}:recent_qs
  user:{userId}:streak
  user:{userId}:tier
```

---

### 1.2 Global Caches

#### A. Assessment Questions Cache

| Property | Value |
|----------|-------|
| Cache Key | `global:assessment_questions` |
| TTL | 24 hours |
| Size | ~60KB (30 questions) |
| Invalidation | Manual via admin endpoint |

**Caching Logic**:
1. Check cache for assessment questions
2. If cache hit → use cached questions
3. If cache miss → fetch from Firestore, cache result
4. Apply per-user randomization (deterministic via userId seed)

**Why userId randomization works with caching**:
- Same 30 questions cached globally
- Randomization uses `crypto.createHash('md5').update(userId)` as seed
- Same user always gets same order (resumability)
- Different users get different orders (anti-cheating)
- No need to store order per user

#### B. Question Bank Cache (by Chapter)

| Property | Value |
|----------|-------|
| Cache Key | `global:questions:{chapterKey}` |
| TTL | 1 hour |
| Size | ~100KB per chapter, ~3MB total |
| Invalidation | Manual via admin endpoint |

**Caching Logic**:
1. Check cache for chapter questions
2. If cache hit → use cached questions
3. If cache miss → fetch from Firestore, cache result
4. Apply filtering (exclude recent, difficulty match) in-memory
5. Score by Fisher Information and select in-memory

---

### 1.3 Per-User Caches

#### A. User Theta Profile

| Property | Value |
|----------|-------|
| Cache Key | `user:{userId}:theta` |
| TTL | 10 minutes |
| Size | ~3KB per user |
| Invalidation | On quiz completion |

**Cached Data**:
```javascript
{
  theta_by_chapter: { ... },
  theta_by_subject: { ... },
  overall_theta: number,
  completed_quiz_count: number,
  learning_phase: "exploration" | "exploitation"
}
```

#### B. Recent Question IDs

| Property | Value |
|----------|-------|
| Cache Key | `user:{userId}:recent_qs` |
| TTL | 1 hour |
| Size | ~2KB per user (Set of ~300 IDs) |
| Invalidation | Append on quiz completion |

**Note**: This cache is additive - on quiz completion, new question IDs are appended rather than invalidating the entire cache.

#### C. Streak Data

| Property | Value |
|----------|-------|
| Cache Key | `user:{userId}:streak` |
| TTL | 1 hour |
| Size | ~500B per user |
| Invalidation | On quiz completion |

#### D. Subscription Tier (Already Implemented)

| Property | Value |
|----------|-------|
| Cache Key | `user:{userId}:tier` |
| TTL | 60 seconds |
| Invalidation | On subscription change |

---

### 1.4 Cache Invalidation Rules

| Event | Caches to Invalidate |
|-------|---------------------|
| Quiz completed | `user:{userId}:theta`, `user:{userId}:streak` |
| Quiz completed | Append to `user:{userId}:recent_qs` |
| Questions updated (admin) | `global:assessment_questions`, `global:questions:*` |
| User subscription change | `user:{userId}:tier` |

---

### 1.5 Admin Endpoints

```
GET  /api/admin/cache/stats
POST /api/admin/cache/invalidate/questions?confirm=true
POST /api/admin/cache/invalidate/user/:userId?confirm=true
POST /api/admin/cache/warm
```

| Endpoint | Purpose | Auth | Params |
|----------|---------|------|--------|
| `GET /stats` | Return hit/miss rates, key counts | Admin | - |
| `POST /invalidate/questions` | Clear all question caches | Admin | `?confirm=true` required |
| `POST /invalidate/user/:userId` | Clear user's caches | Admin | `?confirm=true` required |
| `POST /warm` | Pre-load assessment questions | Admin | - |

**Confirmation Requirement**: Invalidation endpoints require `?confirm=true` to prevent accidental cache clears. Returns 400 if missing.

---

### 1.6 Server Startup Cache Warming

**Behavior**: Mandatory - server warms assessment questions cache on startup before accepting requests.

**Startup Sequence**:
1. Initialize Express app
2. Connect to Firestore
3. **Warm assessment questions cache**
4. Start listening on port

---

## Phase 2: Redis/Upstash Migration (Future)

### 2.1 When to Migrate

Migrate when **ANY** of these occur:
- Multiple server instances needed (horizontal scaling)
- DAU exceeds 5,000
- Cache hit rates drop due to frequent instance restarts
- Need shared rate limiting across instances

### 2.2 Provider Recommendation

**Upstash** (serverless Redis):
- Free tier: 10k commands/day, 256MB
- Pro tier: $10/month, 10k commands/sec
- No connection management needed
- Pay-per-request pricing

### 2.3 Migration Strategy

1. Add `@upstash/redis` dependency
2. Create Redis client wrapper matching node-cache API
3. Update `cache.js` to use Redis
4. **No changes to service files** (same interface)

**Redis Key Structure**:
```
jeevibe:{env}:global:assessment_questions
jeevibe:{env}:global:questions:{chapterKey}
jeevibe:{env}:user:{userId}:theta
jeevibe:{env}:user:{userId}:recent_qs
```

### 2.4 Additional Redis Benefits
- Distributed rate limiting
- Session storage (if needed)
- Pub/sub for cache invalidation across instances
- Persistent cache across deployments

---

## Expected Impact

| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| Assessment start | 1 Firestore read | 0 reads | 100% |
| Quiz generation | 8-12 reads | 0-2 reads | 80-100% |
| Quiz generation latency | 500-1000ms | 50-100ms | 90% |
| Monthly Firestore cost (10k users) | ~$15-30 | ~$2-5 | 80-90% |
| Server memory | Baseline | +4-5MB | Negligible |

---

## Memory Usage Estimates

### Global Cache
| Data | Size |
|------|------|
| Assessment questions | ~60KB |
| Question bank (30 chapters) | ~3MB |
| **Total global** | **~3MB** |

### Per-User Cache (at scale)
| Active Users | Memory |
|--------------|--------|
| 100 | ~500KB |
| 1,000 | ~5MB |
| 10,000 | ~50MB |

**Total at 1k DAU**: ~8-10MB (well within Render's limits)

---

## Monitoring

### Cache Statistics Endpoint

`GET /api/admin/cache/stats` returns:
```json
{
  "global": {
    "keys": 32,
    "hits": 1500,
    "misses": 45,
    "hitRate": "97.1%"
  },
  "user": {
    "keys": 150,
    "hits": 3200,
    "misses": 120,
    "hitRate": "96.4%"
  }
}
```

### Key Metrics to Monitor
- Cache hit rate (target: >90%)
- Firestore read count (via Firebase console)
- Quiz generation latency (via logging)

---

## Rollback Plan

If caching causes issues:

1. **Quick disable**: Set `CACHE_ENABLED=false` env var
2. **Conditional check**: Cache module bypasses cache when disabled
3. **Fallback**: All Firestore queries remain in place

```javascript
// In cache.js
const CACHE_ENABLED = process.env.CACHE_ENABLED !== 'false';

const global = {
  get: (key) => CACHE_ENABLED ? globalCache.get(key) : undefined,
  // ...
};
```

---

## Files Modified

| File | Changes |
|------|---------|
| `backend/src/utils/cache.js` | Enhanced with global/user separation |
| `backend/src/services/stratifiedRandomizationService.js` | Assessment questions caching |
| `backend/src/services/questionSelectionService.js` | Chapter questions + recent IDs caching |
| `backend/src/services/dailyQuizService.js` | User theta caching, invalidation |
| `backend/src/routes/admin.js` | Cache management endpoints |
| `backend/src/index.js` | Cache warming on startup |

---

## Implementation Checklist

- [ ] Enhanced cache module with global/user caches
- [ ] Assessment questions caching
- [ ] Question bank caching by chapter
- [ ] User theta profile caching
- [ ] Recent question IDs caching
- [ ] Admin cache endpoints
- [ ] Server startup cache warming
- [ ] Operational guide documentation
