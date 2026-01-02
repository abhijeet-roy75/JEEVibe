# Scalability Analysis - Daily Adaptive Quiz System

## Executive Summary

**Estimated User Capacity:**
- **Current Design:** 10,000 - 50,000 active users comfortably
- **With Optimizations:** 100,000+ active users
- **Theoretical Limit:** 500,000+ users (with architectural changes)

**Key Bottlenecks:**
1. Weekly snapshot job (processes all users sequentially)
2. Question stats aggregation (8000 questions × all responses)
3. Quiz generation queries (needs optimization for high concurrency)

---

## Firestore Limits & Constraints

### Document Limits
- **Max Document Size:** 1MB
- **Max Writes per Transaction:** 500
- **Max Batch Write:** 500 operations
- **Max Query Results:** 1,000,000 documents (pagination required)

### Query Limits
- **Collection Group Queries:** Efficient with proper indexes
- **Composite Indexes:** Required for multi-field queries
- **Query Performance:** < 100ms for indexed queries (typically)

### Rate Limits
- **Reads:** 50,000 per second per database (Blaze plan)
- **Writes:** 20,000 per second per database (Blaze plan)
- **Free Tier:** 50,000 reads/day, 20,000 writes/day

---

## Storage Analysis

### Per-User Storage

**User Document (`users/{userId}`):**
- Profile data: ~5KB
- Assessment data: ~10KB
- Theta tracking: ~50KB (assuming 50 chapters tested)
- Daily quiz state: ~5KB
- **Total: ~70KB per user** ✅ Well under 1MB limit

**Assessment Responses:**
- 30 responses × 1KB = ~30KB per user
- Stored in subcollection (scales per user)

**Daily Quiz Responses:**
- 10 responses per quiz × 1KB = ~10KB per quiz
- If user completes 365 quizzes/year = ~3.6MB per user
- Stored in subcollection (scales per user)

**Daily Quiz History:**
- 1 quiz document × 2KB = ~2KB per quiz
- 365 quizzes/year = ~730KB per user per year

**Practice Streaks:**
- ~5KB per user (single document)

**Weekly Snapshots:**
- 1 snapshot × 10KB = ~10KB per week
- 52 weeks/year = ~520KB per user per year

**Total Storage per Active User (1 year):**
- User document: 70KB
- Assessment responses: 30KB
- Daily quiz responses: 3.6MB
- Quiz history: 730KB
- Practice streaks: 5KB
- Weekly snapshots: 520KB
- **Total: ~5MB per user per year**

### Total Storage Estimates

| Users | Storage (1 year) | Storage (5 years) |
|-------|------------------|-------------------|
| 1,000 | 5 GB | 25 GB |
| 10,000 | 50 GB | 250 GB |
| 50,000 | 250 GB | 1.25 TB |
| 100,000 | 500 GB | 2.5 TB |

**Firestore Storage:** $0.18/GB/month
- 1,000 users: ~$1/month
- 10,000 users: ~$9/month
- 50,000 users: ~$45/month
- 100,000 users: ~$90/month

---

## Performance Analysis

### Quiz Generation (Critical Path)

**Current Implementation:**
1. Load user profile: 1 read (~50ms)
2. Query questions by subject+chapter: 1 query (~100ms with index)
3. Filter by difficulty, discrimination: In-memory (~10ms)
4. Select optimal questions: In-memory (~20ms)
5. Interleave questions: In-memory (~5ms)

**Total: ~185ms per quiz generation** ✅ Under 500ms target

**Scalability:**
- **Concurrent Requests:** Can handle 100+ concurrent quiz generations
- **Bottleneck:** Firestore query performance (improves with indexes)
- **Optimization:** Cache frequently accessed questions

### Quiz Completion (Write-Heavy)

**Current Implementation:**
1. Batch update theta (10 questions): 1 user document update (~50ms)
2. Save 10 responses: 10 writes to subcollection (~200ms)
3. Save quiz document: 1 write (~50ms)
4. Update streaks: 1 document update (~50ms)

**Total: ~350ms per quiz completion**

**Scalability:**
- **Firestore Write Limit:** 20,000 writes/second
- **Per Quiz:** 12 writes (1 user + 10 responses + 1 quiz)
- **Theoretical Capacity:** 1,666 quizzes/second = 144M quizzes/day
- **Practical Capacity:** ~1,000 concurrent completions/second

### Weekly Snapshot Job (Bottleneck)

**Current Implementation:**
- Processes users sequentially
- For each user:
  - Read user document: ~50ms
  - Query responses: ~100ms
  - Calculate changes: ~20ms
  - Write snapshot: ~50ms
  - **Total: ~220ms per user**

**Scalability Analysis:**

| Users | Processing Time | Status |
|-------|----------------|--------|
| 1,000 | ~4 minutes | ✅ Good |
| 10,000 | ~37 minutes | ⚠️ Acceptable |
| 50,000 | ~3 hours | ❌ Too slow |
| 100,000 | ~6 hours | ❌ Unacceptable |

**Bottleneck:** Sequential processing

**Solutions:**
1. **Batch Processing:** Process 100 users in parallel
2. **Incremental Updates:** Only process users active this week
3. **Distributed Processing:** Split by user ID ranges

### Question Stats Aggregation (Weekly Job)

**Current Implementation:**
- Processes all 8000 questions
- For each question:
  - Query collection group: ~100ms
  - Aggregate stats: ~20ms
  - Update question: ~50ms
  - **Total: ~170ms per question**

**Scalability:**
- **8000 questions × 170ms = ~23 minutes**
- **With batching (100 at a time):** ~23 minutes (same, but more efficient)

**Optimization:** Only update questions answered this week (reduces to ~100-200 questions)

---

## Scalability by Component

### 1. User Profile Reads
- **Capacity:** 50,000 reads/second
- **Per User:** 1 read per quiz generation
- **Support:** 50,000 concurrent quiz generations ✅

### 2. Question Queries
- **Capacity:** Indexed queries are fast (< 100ms)
- **Bottleneck:** None with proper indexes ✅

### 3. Response Writes
- **Capacity:** 20,000 writes/second
- **Per Quiz:** 10 response writes
- **Support:** 2,000 quizzes/second = 172M quizzes/day ✅

### 4. Weekly Snapshots
- **Bottleneck:** Sequential processing
- **Current:** 10,000 users = ~37 minutes ⚠️
- **Optimized:** 100,000 users = ~1 hour ✅

### 5. Question Stats
- **Current:** 23 minutes for all questions
- **Optimized:** 2-3 minutes (only active questions) ✅

---

## Recommended User Capacity

### Phase 1: Initial Launch (0-10,000 users)
**Status:** ✅ Ready
- All components scale well
- Weekly job: ~37 minutes (acceptable)
- No optimizations needed

### Phase 2: Growth (10,000-50,000 users)
**Status:** ⚠️ Needs Optimization
- Weekly snapshot job: ~3 hours (too slow)
- **Required:** Batch processing for snapshots
- **Required:** Incremental question stats (only active questions)

### Phase 3: Scale (50,000-100,000 users)
**Status:** ❌ Needs Architecture Changes
- Weekly snapshot job: ~6 hours (unacceptable)
- **Required:** Distributed processing
- **Required:** Background job queue (e.g., Bull, BullMQ)
- **Required:** Caching layer (Redis)

### Phase 4: Enterprise (100,000+ users)
**Status:** ❌ Needs Major Refactoring
- **Required:** Microservices architecture
- **Required:** Separate read/write databases
- **Required:** Event-driven architecture
- **Required:** CDN for question content

---

## Optimization Roadmap

### Immediate (0-10,000 users)
- ✅ Current design is sufficient
- ✅ Monitor performance metrics

### Short-term (10,000-50,000 users)
1. **Optimize Weekly Snapshots:**
   ```javascript
   // Process users in batches of 100
   const batches = chunk(users, 100);
   await Promise.all(batches.map(batch => 
     Promise.all(batch.map(user => createSnapshot(user.id)))
   ));
   ```

2. **Incremental Question Stats:**
   ```javascript
   // Only update questions answered this week
   const questionsThisWeek = await getQuestionsAnsweredThisWeek();
   await batchUpdateQuestionStats(questionsThisWeek);
   ```

3. **Cache Frequently Accessed Data:**
   - Cache user profiles (5min TTL)
   - Cache question metadata
   - Use Redis or in-memory cache

### Medium-term (50,000-100,000 users)
1. **Background Job Queue:**
   - Use Bull/BullMQ for async processing
   - Process snapshots in background
   - Retry failed jobs

2. **Database Sharding:**
   - Shard by user ID ranges
   - Distribute load across multiple databases

3. **Read Replicas:**
   - Separate read/write operations
   - Use read replicas for analytics

### Long-term (100,000+ users)
1. **Microservices:**
   - Separate quiz generation service
   - Separate analytics service
   - Separate user service

2. **Event-Driven Architecture:**
   - Publish events for quiz completion
   - Async processing of snapshots
   - Event sourcing for audit trail

---

## Cost Analysis

### Firestore Costs (Blaze Plan)

**Storage:**
- 10,000 users × 5MB/year = 50GB
- Cost: 50GB × $0.18/GB/month = **$9/month**

**Reads:**
- Quiz generation: 2 reads per quiz
- Progress queries: 10 reads per query
- Estimated: 1M reads/day for 10,000 active users
- Cost: 30M reads/month × $0.06/100K = **$18/month**

**Writes:**
- Quiz completion: 12 writes per quiz
- Estimated: 100K quizzes/day = 1.2M writes/day
- Cost: 36M writes/month × $0.18/100K = **$65/month**

**Total for 10,000 users: ~$92/month**

### Render.com Costs
- **Free Tier:** 750 hours/month (sufficient for < 1,000 users)
- **Starter Plan:** $7/month (for cron jobs)
- **Standard Plan:** $25/month (recommended for production)

**Total Infrastructure Cost: ~$120/month for 10,000 users**

---

## Bottleneck Summary

| Component | Current Capacity | Bottleneck | Solution |
|-----------|------------------|------------|----------|
| Quiz Generation | 50,000 concurrent | None | ✅ Ready |
| Quiz Completion | 2,000/sec | None | ✅ Ready |
| Weekly Snapshots | 10,000 users | Sequential processing | Batch processing |
| Question Stats | 8000 questions | All questions | Incremental updates |
| Storage | Unlimited | Cost | Monitor and optimize |

---

## Recommendations

### For Launch (0-10,000 users)
✅ **Current design is production-ready**
- No changes needed
- Monitor performance
- Set up alerts

### For Growth (10,000-50,000 users)
⚠️ **Implement optimizations:**
1. Batch processing for weekly snapshots
2. Incremental question stats updates
3. Caching layer (Redis or in-memory)
4. Background job queue

### For Scale (50,000+ users)
❌ **Architectural changes required:**
1. Distributed processing
2. Microservices architecture
3. Event-driven design
4. Read replicas

---

## Monitoring & Alerts

### Key Metrics to Monitor

1. **Quiz Generation Time:**
   - Target: < 500ms
   - Alert: > 1 second

2. **Weekly Job Duration:**
   - Target: < 1 hour
   - Alert: > 2 hours

3. **Firestore Read/Write Rates:**
   - Monitor: Approaching limits
   - Alert: > 80% of quota

4. **Error Rates:**
   - Target: < 0.1%
   - Alert: > 1%

5. **Storage Growth:**
   - Monitor: Per-user storage
   - Alert: > 10MB per user

---

## Conclusion

**Current Design Capacity:**
- **Comfortable:** 10,000 active users
- **Acceptable:** 50,000 active users (with optimizations)
- **Theoretical:** 100,000+ users (with architectural changes)

**Key Strengths:**
- ✅ Efficient per-user subcollections
- ✅ Indexed queries for fast quiz generation
- ✅ Atomic updates for data consistency
- ✅ Scalable storage model

**Key Weaknesses:**
- ⚠️ Weekly snapshot job (sequential processing)
- ⚠️ Question stats (processes all questions)
- ⚠️ No caching layer (yet)

**Recommendation:**
Start with current design, implement optimizations as you approach 10,000 users.

