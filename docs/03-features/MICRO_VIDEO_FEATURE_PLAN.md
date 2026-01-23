# Micro Video Feature for Chapter Practice

> **Status**: Planning
> **Created**: January 2026
> **Scope**: Add AI-generated educational micro videos to the chapter practice feature

---

## Executive Summary

This document outlines the implementation plan for adding **micro videos** (30-second AI-generated educational videos) to JEEVibe's chapter practice feature. Students will be able to watch concept explanations for topics they're practicing, with videos shown at multiple touchpoints throughout the practice flow.

### Key Highlights

| Aspect | Decision |
|--------|----------|
| **Video Hosting** | YouTube Unlisted (free bandwidth, excellent India CDN) |
| **Video Duration** | ~30 seconds per concept |
| **Generation** | AI-powered pipeline (Claude + Manim/Avatar + TTS) |
| **Access** | Premium-only (Pro/Ultra subscribers) |
| **Cost per Video** | ~$0.04-0.05 |

---

## Table of Contents

1. [Current State](#current-state)
2. [Architecture Decisions](#architecture-decisions)
3. [Database Schema](#database-schema)
4. [Backend Implementation](#backend-implementation)
5. [AI Video Generation Pipeline](#ai-video-generation-pipeline)
6. [Mobile App Implementation](#mobile-app-implementation)
7. [Integration Points](#integration-points)
8. [File Changes Summary](#file-changes-summary)
9. [Cost Analysis](#cost-analysis)
10. [Verification Plan](#verification-plan)

---

## Current State

### What Exists
- **Chapter Practice**: Robust practice system with chapter picker, question screens, session management, IRT-based adaptive difficulty
- **Data Models**: Questions have `subject`, `chapter`, `sub_topics` fields
- **Media Handling**: Firebase Storage for images with caching

### What's Missing
- No video player or streaming functionality
- No video URLs in any data models
- No video-related API endpoints

---

## Architecture Decisions

### 1. Video Storage: YouTube Unlisted + Firebase Metadata

**Why YouTube?**
- **Free bandwidth** - YouTube pays for streaming costs
- **India optimization** - Excellent CDN coverage for target audience
- **Auto quality switching** - Adapts to student's connection speed
- **No transcoding work** - Upload once, works everywhere

**Trade-offs:**
- Less control over player UI
- YouTube branding visible
- Platform dependency

### 2. Video Association: Chapter Level with Topic Tags

Videos are associated at the **chapter level** but tagged with specific topics for filtering:

```
physics_laws_of_motion → [
  { video_id: "lom_concept_1", topics: ["Newton's First Law"], type: "concept" },
  { video_id: "lom_concept_2", topics: ["Friction"], type: "concept" },
  { video_id: "lom_problem_1", topics: ["Pulley Systems"], type: "problem_solving" }
]
```

**Rationale:**
- Chapter-level provides good coverage (5-10 videos per chapter)
- Topic tags allow matching videos to specific questions
- Sub-topic level would require too many videos for full coverage

### 3. When to Show Videos

| Entry Point | Trigger | Content |
|-------------|---------|---------|
| **Pre-Practice** | Loading screen (opt-in) | Overview concept video |
| **After Wrong Answer** | In explanation widget | Video matching question's sub_topics |
| **End of Session** | Result screen | Videos for topics with low accuracy |
| **Chapter Browser** | Chapter picker screen | Full video list for chapter |

### 4. Subscription Gating

- **Premium-only** feature (Pro/Ultra subscribers)
- Use existing `SubscriptionService.gatekeepFeature()` pattern
- Show upgrade prompt for free users

---

## Database Schema

### Collection: `micro_videos`

```javascript
{
  video_id: string,                    // Unique identifier
  youtube_video_id: string,            // "dQw4w9WgXcQ"
  title: string,                       // "Newton's Third Law Explained"
  description: string,                 // Brief description
  duration_seconds: number,            // 30
  thumbnail_url: string,               // Firebase Storage URL

  // Classification
  subject: string,                     // "Physics"
  chapter: string,                     // "Laws of Motion"
  chapter_key: string,                 // "physics_laws_of_motion"
  topics: string[],                    // ["Newton's Laws"]
  sub_topics: string[],                // ["Action-Reaction Pairs"]

  // Metadata
  video_type: "concept" | "problem_solving" | "tips",
  difficulty: "easy" | "medium" | "hard",
  language: "en" | "hi" | "hinglish",
  is_active: boolean,

  // Timestamps
  created_at: timestamp,
  updated_at: timestamp
}
```

### Collection: `video_generation_jobs`

```javascript
{
  job_id: string,
  status: "pending" | "generating" | "completed" | "failed",

  input: {
    chapter_key: string,
    sub_topic: string,
    concept: string,
    language: "en" | "hi"
  },

  output: {
    youtube_video_id: string,
    micro_video_id: string,
    duration_seconds: number
  },

  pipeline_logs: [
    { step: "script", status: "completed", timestamp: timestamp },
    { step: "render", status: "completed", timestamp: timestamp },
    { step: "tts", status: "completed", timestamp: timestamp },
    { step: "compose", status: "completed", timestamp: timestamp },
    { step: "upload", status: "completed", timestamp: timestamp }
  ],

  error_message?: string,
  created_at: timestamp,
  completed_at?: timestamp
}
```

### Collection: `video_watch_events` (Analytics)

```javascript
{
  user_id: string,
  video_id: string,
  chapter_key: string,
  watch_duration_seconds: number,
  video_duration_seconds: number,
  completion_percentage: number,
  completed: boolean,
  context: "intro" | "wrong_answer" | "review" | "browse",
  question_id?: string,
  watched_at: timestamp
}
```

---

## Backend Implementation

### New API Endpoints

#### Video Fetching API (`/api/micro-videos`)

```javascript
// Get all videos for a chapter
GET /api/micro-videos/chapter/:chapterKey
Response: {
  videos: MicroVideo[],
  total_count: number
}

// Get videos matching specific topics
GET /api/micro-videos/topic?chapter_key=X&sub_topics=Y,Z
Response: {
  videos: MicroVideo[],
  matched_topics: string[]
}

// Record video watch event
POST /api/micro-videos/watch-event
Body: {
  video_id: string,
  watch_duration_seconds: number,
  completed: boolean,
  context: string,
  question_id?: string
}
```

#### Admin Video Generation API (`/api/admin/video-gen`)

```javascript
// Generate single video
POST /api/admin/video-gen/generate
Body: {
  chapter_key: string,
  sub_topic: string,
  concept: string,
  language: "en" | "hi"
}
Response: { job_id: string }

// Batch generate for chapter
POST /api/admin/video-gen/batch
Body: {
  chapter_key: string,
  generate_all_subtopics: boolean
}
Response: { job_ids: string[] }

// List generation jobs
GET /api/admin/video-gen/jobs
Response: { jobs: VideoGenerationJob[] }

// Get specific job status
GET /api/admin/video-gen/jobs/:jobId
Response: VideoGenerationJob
```

### New Backend Files

| File | Purpose |
|------|---------|
| `backend/src/routes/microVideos.js` | Public API for fetching videos |
| `backend/src/services/microVideoService.js` | Video business logic |
| `backend/src/routes/adminVideoGen.js` | Admin API for generation |
| `backend/src/config/videoGenConfig.js` | Pipeline configuration |

---

## AI Video Generation Pipeline

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│               Video Generation Pipeline                      │
├─────────────────────────────────────────────────────────────┤
│  Trigger: Admin request OR automated batch job               │
│                                                              │
│  Input: {                                                    │
│    chapter_key: "physics_laws_of_motion",                    │
│    sub_topic: "Newton's Third Law",                          │
│    concept: "Action-reaction pairs"                          │
│  }                                                           │
│                           ↓                                  │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ 1. SCRIPT GENERATION (Claude/GPT API)               │    │
│  │    - Generate 30s explanation script                │    │
│  │    - Generate Manim scene code OR avatar script     │    │
│  └─────────────────────────────────────────────────────┘    │
│                           ↓                                  │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ 2. VISUAL RENDERING                                 │    │
│  │    Option A: Manim (equations, diagrams, physics)   │    │
│  │    Option B: AI Avatar API (Synthesia/HeyGen)       │    │
│  └─────────────────────────────────────────────────────┘    │
│                           ↓                                  │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ 3. AUDIO GENERATION (ElevenLabs / Google TTS)       │    │
│  │    - Hindi or English narration                     │    │
│  │    - Sync with visuals                              │    │
│  └─────────────────────────────────────────────────────┘    │
│                           ↓                                  │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ 4. VIDEO COMPOSITION (FFmpeg)                       │    │
│  │    - Combine video + audio                          │    │
│  │    - Add intro/outro branding                       │    │
│  └─────────────────────────────────────────────────────┘    │
│                           ↓                                  │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ 5. UPLOAD & STORE                                   │    │
│  │    - Upload to YouTube (unlisted)                   │    │
│  │    - Store metadata in Firestore                    │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

### Pipeline Services

| Service | Purpose |
|---------|---------|
| `scriptGeneratorService.js` | Claude/GPT API to generate scripts + Manim code |
| `manimRendererService.js` | Execute Manim code, render video frames |
| `ttsService.js` | ElevenLabs/Google TTS for narration |
| `videoComposerService.js` | FFmpeg to combine video + audio |
| `youtubeUploadService.js` | YouTube Data API for upload |
| `pipelineOrchestrator.js` | Coordinates full pipeline |

### Pipeline Configuration

```javascript
// backend/src/config/videoGenConfig.js
module.exports = {
  // Script generation
  scriptModel: 'claude-3-5-sonnet',  // or 'gpt-4o'
  scriptMaxTokens: 500,

  // Visual rendering (pluggable)
  renderer: 'manim',  // or 'synthesia' or 'heygen'
  manimQuality: 'medium_quality',  // 720p

  // Audio
  ttsProvider: 'elevenlabs',  // or 'google'
  ttsVoice: 'hindi_female_1',

  // Output
  videoDuration: 30,  // seconds
  outputFormat: 'mp4',

  // Upload
  youtubePrivacy: 'unlisted',
  autoGenerateThumbnail: true
};
```

### Rendering Options

#### Option A: Manim (Recommended for JEE)

**Best for:** Mathematical equations, physics diagrams, graphs, step-by-step derivations

**Pros:**
- Perfect for JEE math/physics content
- Handles LaTeX equations correctly
- Fully automatable
- Very low cost (~$0.01/video for compute)

**Cons:**
- Requires Manim environment setup
- Limited to animation-style videos

#### Option B: AI Avatar (Synthesia/HeyGen)

**Best for:** Talking head explanations, tips, motivational content

**Pros:**
- Human-like presenter
- Easy to create
- No animation coding needed

**Cons:**
- Higher cost (~$0.50-1.00/video)
- Cannot show dynamic equations natively
- Would need overlay for math content

---

## Mobile App Implementation

### New Dependencies

```yaml
# pubspec.yaml
dependencies:
  youtube_player_flutter: ^8.1.2
```

### Data Models

```dart
// mobile/lib/models/micro_video_models.dart

class MicroVideo {
  final String videoId;
  final String youtubeVideoId;
  final String title;
  final String description;
  final int durationSeconds;
  final String? thumbnailUrl;
  final String subject;
  final String chapter;
  final String chapterKey;
  final List<String> topics;
  final List<String> subTopics;
  final String difficulty;
  final String videoType;
  final String language;

  // Computed properties
  String get formattedDuration {
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String get youtubeUrl =>
    'https://youtube.com/watch?v=$youtubeVideoId';
}

class VideoWatchProgress {
  final String videoId;
  final int watchedSeconds;
  final bool completed;
  final DateTime lastWatched;
}
```

### State Management

```dart
// mobile/lib/providers/micro_video_provider.dart

class MicroVideoProvider extends ChangeNotifier {
  List<MicroVideo>? _chapterVideos;
  Map<String, VideoWatchProgress> _watchProgress = {};
  bool _isLoading = false;
  String? _error;

  // Getters
  List<MicroVideo>? get chapterVideos => _chapterVideos;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Methods
  Future<void> loadVideosForChapter(String chapterKey, String authToken);

  List<MicroVideo> getVideosForTopics(List<String> subTopics) {
    if (_chapterVideos == null) return [];
    return _chapterVideos!.where((video) =>
      video.subTopics.any((t) => subTopics.contains(t))
    ).toList();
  }

  Future<void> recordWatchProgress(
    String videoId,
    int seconds,
    bool completed,
    String authToken,
  );

  MicroVideo? getIntroVideoForChapter(String chapterKey);

  List<MicroVideo> getRecommendedAfterWrongAnswer(PracticeQuestion question);
}
```

### UI Widgets

| Widget | Purpose |
|--------|---------|
| `video_thumbnail_card.dart` | Thumbnail image + play button + duration badge |
| `video_player_screen.dart` | Full-screen YouTube player with progress tracking |
| `video_suggestion_card.dart` | "Watch this video" prompt for explanations |
| `chapter_videos_sheet.dart` | Bottom sheet listing all chapter videos |

---

## Integration Points

### 1. Chapter Picker Screen

**File:** `mobile/lib/screens/chapter_practice/chapter_picker_screen.dart`

**Changes:**
- Add video icon badge on chapter cards that have videos
- Show video count: "5 videos available"
- Tap icon to open video list sheet

### 2. Practice Loading Screen

**File:** `mobile/lib/screens/chapter_practice/chapter_practice_loading_screen.dart`

**Changes:**
- Fetch videos for chapter during loading
- Show optional "Watch intro video?" card
- Store videos in provider for session access

### 3. Question Screen (After Wrong Answer)

**File:** `mobile/lib/screens/chapter_practice/chapter_practice_question_screen.dart`

**Changes:**
- In `_buildTeacherMessage` section after wrong answers
- Add video suggestion card when matching video exists
- "Priya Ma'am suggests watching: [Video Title]"

### 4. Detailed Explanation Widget

**File:** `mobile/lib/widgets/daily_quiz/detailed_explanation_widget.dart`

**Changes:**
- Add optional `relatedVideos` parameter
- Render video suggestion at bottom of explanation
- "Still confused? Watch this 2-min video"

### 5. Result Screen

**File:** `mobile/lib/screens/chapter_practice/chapter_practice_result_screen.dart`

**Changes:**
- Add "Review Concepts" section
- Show videos for topics where accuracy < 50%
- Horizontal scrollable list of video cards

---

## File Changes Summary

### Backend - New Files (10)

| File | Purpose |
|------|---------|
| `src/routes/microVideos.js` | Public API for fetching videos |
| `src/services/microVideoService.js` | Video business logic |
| `src/routes/adminVideoGen.js` | Admin API for generation |
| `src/config/videoGenConfig.js` | Pipeline configuration |
| `src/services/videoGeneration/scriptGeneratorService.js` | Script generation |
| `src/services/videoGeneration/manimRendererService.js` | Manim rendering |
| `src/services/videoGeneration/ttsService.js` | Text-to-speech |
| `src/services/videoGeneration/videoComposerService.js` | FFmpeg composition |
| `src/services/videoGeneration/youtubeUploadService.js` | YouTube upload |
| `src/services/videoGeneration/pipelineOrchestrator.js` | Pipeline coordinator |

### Backend - Modified Files (2)

| File | Changes |
|------|---------|
| `src/routes/index.js` | Register new routes |
| `package.json` | Add dependencies |

### Mobile - New Files (6)

| File | Purpose |
|------|---------|
| `lib/models/micro_video_models.dart` | Data models |
| `lib/providers/micro_video_provider.dart` | State management |
| `lib/widgets/video/video_thumbnail_card.dart` | Thumbnail widget |
| `lib/widgets/video/video_player_screen.dart` | Player screen |
| `lib/widgets/video/video_suggestion_card.dart` | Suggestion card |
| `lib/widgets/video/chapter_videos_sheet.dart` | Video list sheet |

### Mobile - Modified Files (7)

| File | Changes |
|------|---------|
| `pubspec.yaml` | Add youtube_player_flutter |
| `lib/services/api_service.dart` | Add video API methods |
| `lib/screens/chapter_practice/chapter_picker_screen.dart` | Video badge |
| `lib/screens/chapter_practice/chapter_practice_loading_screen.dart` | Intro video |
| `lib/screens/chapter_practice/chapter_practice_question_screen.dart` | Video suggestions |
| `lib/screens/chapter_practice/chapter_practice_result_screen.dart` | Review section |
| `lib/widgets/daily_quiz/detailed_explanation_widget.dart` | Video link |

---

## Cost Analysis

### Per-Video Generation Cost (Manim Approach)

| Component | Cost |
|-----------|------|
| Claude API (script generation) | ~$0.01 |
| ElevenLabs TTS (30s audio) | ~$0.02 |
| Manim render (compute) | ~$0.01 |
| YouTube upload | Free |
| **Total** | **~$0.04-0.05** |

### Alternative: AI Avatar Approach

| Component | Cost |
|-----------|------|
| Synthesia/HeyGen | ~$0.50-1.00 |
| YouTube upload | Free |
| **Total** | **~$0.50-1.00** |

### Initial Content Budget

| Scope | Videos | Cost (Manim) | Cost (Avatar) |
|-------|--------|--------------|---------------|
| MVP (15 chapters × 3 videos) | 45 | ~$2-3 | ~$25-45 |
| Full coverage (15 chapters × 10 videos) | 150 | ~$7-8 | ~$75-150 |

### Batch Generation Strategy

1. Extract unique `sub_topics` from questions collection
2. Group by chapter_key
3. Prioritize most common sub-topics
4. Generate 3-5 videos per chapter initially
5. Run overnight batch jobs to avoid API rate limits

---

## Verification Plan

### 1. Backend Testing

- [ ] Test `/api/micro-videos/chapter/:chapterKey` returns correct videos
- [ ] Test `/api/micro-videos/topic` filtering works
- [ ] Test watch event recording
- [ ] Test admin video generation endpoints
- [ ] Verify Firestore queries are efficient

### 2. Mobile Testing

- [ ] YouTube player loads and plays videos
- [ ] Video thumbnails load correctly
- [ ] Progress tracking works
- [ ] Subscription gating prevents free user access
- [ ] Offline state handled gracefully

### 3. Integration Testing

Full flow test:
1. Select chapter → See video badge
2. Start practice → See intro video option
3. Answer wrong → See video suggestion
4. Complete session → See review videos
5. Watch video → Progress recorded

### 4. Generation Pipeline Testing

- [ ] Script generation produces valid Manim code
- [ ] Manim renders without errors
- [ ] TTS generates clear audio
- [ ] FFmpeg composition works
- [ ] YouTube upload succeeds
- [ ] Metadata stored correctly in Firestore

---

## Appendix: External Resources

### AI Video Generation Tools

- [topic2manim](https://github.com/mateolafalce/topic2manim) - Multi-agent topic to video
- [VideoGen AI](https://github.com/ApilageAI/AI-Video-generator-Using-Google-Gemini-Manim) - Gemini + Manim + ElevenLabs
- [Code2Video](https://opencv.org/blog/code2video/) - Research framework for educational videos
- [Manim Community](https://github.com/3b1b/manim) - Animation engine

### AI Avatar Platforms

- [Synthesia](https://www.synthesia.io/pricing) - $18-64/mo, 230+ avatars
- [HeyGen](https://www.heygen.com/api-pricing) - $99/mo API, 175+ languages

### TTS Services

- [ElevenLabs](https://elevenlabs.io/) - High quality, Hindi support
- [Google Cloud TTS](https://cloud.google.com/text-to-speech) - Cost-effective, many languages

---

*Document generated: January 2026*
