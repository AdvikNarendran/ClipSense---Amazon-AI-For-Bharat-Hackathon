# Design Document: ClipSense

## Overview

ClipSense is an AI-powered video intelligence platform that transforms long-form content into viral-ready short clips through multi-modal analysis. The system employs a pipeline architecture where media flows through sequential processing stages: transcription, emotion analysis, semantic evaluation, attention curve generation, clip segmentation, and caption generation.

The design prioritizes modularity, scalability, and asynchronous processing to handle multiple concurrent users and large media files. Each AI component operates independently, allowing for parallel processing and easy replacement of individual models.

### Key Design Principles

1. **Asynchronous Processing**: All media processing occurs asynchronously with job status tracking
2. **Modular AI Components**: Each AI capability (ASR, emotion detection, LLM analysis) is a separate service
3. **Cloud-Native Architecture**: Leverages cloud storage (S3) and scalable compute resources
4. **API-First Design**: RESTful API layer separates frontend from backend processing
5. **Progressive Enhancement**: Vision analysis is optional and can be enabled per-user or per-media

## Architecture

### System Components

```
┌─────────────────────────────────────────────────────────────────┐
│                         Frontend Layer                           │
│                    (React/Next.js Web App)                       │
└────────────────────────────┬────────────────────────────────────┘
                             │ HTTPS/REST API
┌────────────────────────────┴────────────────────────────────────┐
│                         API Gateway                              │
│                  (FastAPI/Node.js Backend)                       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │   Auth       │  │   Media      │  │  Analytics   │         │
│  │   Service    │  │   Service    │  │   Service    │         │
│  └──────────────┘  └──────────────┘  └──────────────┘         │
└────────────────────────────┬────────────────────────────────────┘
                             │
┌────────────────────────────┴────────────────────────────────────┐
│                    AI Orchestration Layer                        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │ Transcription│  │   Emotion    │  │  Semantic    │         │
│  │   Pipeline   │  │   Analyzer   │  │  Analyzer    │         │
│  └──────────────┘  └──────────────┘  └──────────────┘         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │    Clip      │  │   Caption    │  │   Vision     │         │
│  │  Generator   │  │  Generator   │  │  Analyzer    │         │
│  └──────────────┘  └──────────────┘  └──────────────┘         │
└────────────────────────────┬────────────────────────────────────┘
                             │
        ┌────────────────────┴────────────────────┐
        │                                         │
┌───────┴────────┐                    ┌───────────┴──────────┐
│  Cloud Storage │                    │     Database         │
│   (AWS S3)     │                    │  (PostgreSQL/MongoDB)│
│                │                    │                      │
│ - Raw Media    │                    │ - User Data          │
│ - Clips        │                    │ - Transcripts        │
│ - Thumbnails   │                    │ - Emotion Scores     │
└────────────────┘                    │ - Clip Metadata      │
                                      │ - Analytics Data     │
                                      └──────────────────────┘
```

### Processing Pipeline Flow

```
Upload → Storage → Transcription → Emotion Analysis → Semantic Analysis
                                                              ↓
                                                    Attention Curve
                                                              ↓
                                                    Clip Segmentation
                                                              ↓
                                                      Clip Ranking
                                                              ↓
                                                  Caption Generation
                                                              ↓
                                                    Ready for Download
```

### Technology Stack

**Frontend:**
- React 18+ with Next.js 14 for SSR and routing
- TailwindCSS for styling
- Recharts or D3.js for analytics visualization
- Axios for API communication

**Backend:**
- Python FastAPI for REST API (preferred for AI integration)
- Pydantic for request/response validation
- Celery for asynchronous task queue
- Redis for job status caching

**AI/ML:**
- Whisper (OpenAI) for speech-to-text transcription
- Gemini API or GPT-4 for semantic analysis and caption generation
- Librosa or PyAudioAnalysis for audio emotion detection
- Transformers (Hugging Face) for text sentiment analysis
- Optional: MediaPipe or OpenCV for vision analysis

**Infrastructure:**
- AWS S3 for media storage
- PostgreSQL for structured data (users, metadata)
- MongoDB for semi-structured data (transcripts, analytics)
- AWS Lambda or EC2 for compute
- Docker for containerization

## Components and Interfaces

### 1. API Gateway

**Responsibilities:**
- Route HTTP requests to appropriate services
- Authenticate and authorize requests
- Rate limiting and request validation
- Response formatting and error handling

**Key Endpoints:**

```
POST   /api/v1/auth/login
POST   /api/v1/auth/register
GET    /api/v1/auth/me

POST   /api/v1/media/upload
GET    /api/v1/media/{media_id}
GET    /api/v1/media/list
DELETE /api/v1/media/{media_id}

GET    /api/v1/jobs/{job_id}/status
GET    /api/v1/jobs/{job_id}/progress

GET    /api/v1/clips/{media_id}
GET    /api/v1/clips/{clip_id}
GET    /api/v1/clips/{clip_id}/download

GET    /api/v1/analytics/{media_id}/attention-curve
GET    /api/v1/analytics/{media_id}/emotions
GET    /api/v1/analytics/{media_id}/summary

GET    /api/v1/admin/health
GET    /api/v1/admin/metrics
GET    /api/v1/admin/users
```

### 2. Media Service

**Responsibilities:**
- Handle media upload and validation
- Generate signed URLs for S3 access
- Manage media metadata
- Initiate processing pipeline

**Interface:**

```python
class MediaService:
    def upload_media(user_id: str, file: UploadFile) -> MediaUploadResponse:
        """
        Validates file, uploads to S3, creates DB record, initiates processing
        Returns: media_id, job_id, status
        """
        
    def get_media(media_id: str, user_id: str) -> MediaMetadata:
        """
        Retrieves media metadata with authorization check
        Returns: metadata including processing status
        """
        
    def list_media(user_id: str, filters: MediaFilters) -> List[MediaMetadata]:
        """
        Lists all media for a user with optional filtering
        Returns: paginated list of media metadata
        """
        
    def delete_media(media_id: str, user_id: str) -> bool:
        """
        Soft deletes media and associated data
        Returns: success status
        """
```

### 3. Transcription Pipeline

**Responsibilities:**
- Convert speech to text with word-level timestamps
- Handle multiple audio formats
- Retry logic for failures
- Store transcript in database

**Interface:**

```python
class TranscriptionPipeline:
    def transcribe(media_id: str, audio_path: str) -> Transcript:
        """
        Uses Whisper API to transcribe audio
        Returns: Transcript with word-level timestamps
        """
        
    def extract_audio(video_path: str) -> str:
        """
        Extracts audio track from video file
        Returns: path to audio file
        """
```

**Data Structure:**

```python
class Transcript:
    media_id: str
    segments: List[TranscriptSegment]
    language: str
    confidence: float

class TranscriptSegment:
    start_time: float  # seconds
    end_time: float
    text: str
    words: List[Word]
    
class Word:
    word: str
    start_time: float
    end_time: float
    confidence: float
```

### 4. Emotion Analyzer

**Responsibilities:**
- Analyze audio features for emotional content
- Perform text sentiment analysis on transcript
- Combine audio and text emotion signals
- Generate time-series emotion scores

**Interface:**

```python
class EmotionAnalyzer:
    def analyze_audio_emotion(audio_path: str) -> List[AudioEmotionScore]:
        """
        Analyzes pitch, tone, intensity for emotion detection
        Returns: time-series emotion scores from audio
        """
        
    def analyze_text_emotion(transcript: Transcript) -> List[TextEmotionScore]:
        """
        Uses sentiment analysis model on transcript segments
        Returns: emotion classifications per segment
        """
        
    def combine_emotions(audio_emotions: List[AudioEmotionScore], 
                        text_emotions: List[TextEmotionScore]) -> List[EmotionScore]:
        """
        Merges audio and text emotion signals
        Returns: unified emotion timeline
        """
```

**Data Structure:**

```python
class EmotionScore:
    timestamp: float
    joy: float  # 0-1
    sadness: float
    anger: float
    surprise: float
    neutral: float
    intensity: float  # overall emotional intensity
```

### 5. Semantic Analyzer

**Responsibilities:**
- Evaluate semantic importance of transcript segments
- Extract key topics and entities
- Identify content novelty and relevance
- Generate importance scores

**Interface:**

```python
class SemanticAnalyzer:
    def analyze_importance(transcript: Transcript) -> List[ImportanceScore]:
        """
        Uses LLM to evaluate semantic importance of segments
        Returns: importance scores and extracted concepts
        """
        
    def extract_topics(segment: TranscriptSegment) -> List[Topic]:
        """
        Identifies key topics and entities in segment
        Returns: list of topics with relevance scores
        """
```

**Data Structure:**

```python
class ImportanceScore:
    start_time: float
    end_time: float
    score: float  # 0-100
    topics: List[str]
    entities: List[str]
    novelty_score: float
```

### 6. Attention Curve Generator

**Responsibilities:**
- Combine emotion and semantic signals
- Generate normalized attention curve
- Identify peaks for clip candidates
- Store curve data for visualization

**Interface:**

```python
class AttentionCurveGenerator:
    def generate_curve(emotion_scores: List[EmotionScore],
                      importance_scores: List[ImportanceScore],
                      vision_scores: Optional[List[VisionScore]] = None) -> AttentionCurve:
        """
        Combines multiple signals into unified attention curve
        Returns: normalized time-series attention data
        """
        
    def find_peaks(curve: AttentionCurve, min_distance: float = 30.0) -> List[Peak]:
        """
        Identifies local maxima in attention curve
        Returns: peak locations and intensities
        """
```

**Algorithm:**

```
attention_score(t) = w1 * emotion_intensity(t) + 
                     w2 * semantic_importance(t) + 
                     w3 * vision_engagement(t)

where:
  w1 = 0.4 (emotion weight)
  w2 = 0.5 (semantic weight)
  w3 = 0.1 (vision weight, if enabled)
  
normalize to 0-100 scale
```

### 7. Clip Generator

**Responsibilities:**
- Segment content based on attention peaks
- Determine optimal clip boundaries
- Rank clips by engagement potential
- Generate clip metadata

**Interface:**

```python
class ClipGenerator:
    def generate_clips(attention_curve: AttentionCurve,
                      transcript: Transcript,
                      min_duration: float = 15.0,
                      max_duration: float = 90.0) -> List[ClipCandidate]:
        """
        Creates clip candidates from attention peaks
        Returns: list of ranked clip candidates
        """
        
    def rank_clips(clips: List[ClipCandidate]) -> List[RankedClip]:
        """
        Ranks clips by virality potential
        Returns: sorted list of clips
        """
```

**Clip Segmentation Algorithm:**

```
1. Identify peaks in attention curve (local maxima)
2. For each peak:
   a. Set peak as clip center
   b. Expand window to min_duration (15s)
   c. Continue expanding while attention > threshold
   d. Stop at max_duration (90s) or attention drop
   e. Adjust boundaries to sentence/phrase boundaries
3. Remove overlapping clips (keep higher-ranked)
4. Ensure minimum 5 clips, maximum 20 clips
```

**Data Structure:**

```python
class ClipCandidate:
    clip_id: str
    media_id: str
    start_time: float
    end_time: float
    duration: float
    peak_attention: float
    avg_attention: float
    transcript_text: str
    emotion_profile: Dict[str, float]
    
class RankedClip(ClipCandidate):
    rank: int
    virality_score: float
    hook_title: str
    caption: str
```

### 8. Caption Generator

**Responsibilities:**
- Generate attention-grabbing hook titles
- Create concise captions summarizing clip content
- Optimize for social media platforms
- Ensure character limits

**Interface:**

```python
class CaptionGenerator:
    def generate_hook(clip: ClipCandidate) -> str:
        """
        Uses LLM to create engaging hook title
        Returns: hook title (max 100 chars)
        """
        
    def generate_caption(clip: ClipCandidate) -> str:
        """
        Creates descriptive caption for clip
        Returns: caption (max 300 chars)
        """
```

**LLM Prompt Template:**

```
Generate a viral hook title for this video clip:

Transcript: {clip.transcript_text}
Emotion: {dominant_emotion}
Topics: {topics}

Requirements:
- Maximum 100 characters
- Attention-grabbing and curiosity-inducing
- Suitable for TikTok, Instagram Reels, YouTube Shorts
- No clickbait or misleading content

Hook Title:
```

### 9. Analytics Engine

**Responsibilities:**
- Calculate virality prediction scores
- Generate engagement metrics
- Create visualization data
- Track performance over time

**Interface:**

```python
class AnalyticsEngine:
    def calculate_virality_score(clip: ClipCandidate) -> float:
        """
        Predicts viral potential (0-100)
        Returns: virality score
        """
        
    def generate_attention_heatmap(media_id: str) -> HeatmapData:
        """
        Creates visualization data for attention over time
        Returns: heatmap data structure
        """
        
    def get_emotion_timeline(media_id: str) -> EmotionTimeline:
        """
        Retrieves emotion data for graphing
        Returns: time-series emotion data
        """
```

**Virality Score Algorithm:**

```
virality_score = (
    0.3 * emotion_intensity_score +
    0.3 * semantic_importance_score +
    0.2 * novelty_score +
    0.1 * duration_optimality_score +
    0.1 * hook_quality_score
) * 100

where each component is normalized to 0-1
```

### 10. Vision Analyzer (Optional)

**Responsibilities:**
- Detect movement and gestures
- Identify scene changes
- Track visual engagement signals
- Contribute to attention curve

**Interface:**

```python
class VisionAnalyzer:
    def analyze_movement(video_path: str) -> List[MovementScore]:
        """
        Detects motion intensity over time
        Returns: movement scores per frame
        """
        
    def detect_scene_changes(video_path: str) -> List[float]:
        """
        Identifies scene transitions
        Returns: timestamps of scene changes
        """
        
    def track_gestures(video_path: str) -> List[GestureEvent]:
        """
        Detects hand gestures and body language
        Returns: gesture events with timestamps
        """
```

## Data Models

### User Model

```python
class User:
    user_id: str  # UUID
    email: str
    password_hash: str
    role: UserRole  # CREATOR, MARKETER, ADMIN
    created_at: datetime
    last_login: datetime
    subscription_tier: str
    settings: UserSettings

class UserSettings:
    enable_vision_analysis: bool
    default_clip_duration: int
    notification_preferences: Dict[str, bool]
```

### Media Model

```python
class Media:
    media_id: str  # UUID
    user_id: str
    filename: str
    file_size: int  # bytes
    duration: float  # seconds
    format: str  # mp4, mov, mp3, etc.
    s3_key: str
    upload_timestamp: datetime
    processing_status: ProcessingStatus
    transcript_id: Optional[str]
    
class ProcessingStatus:
    status: str  # queued, processing, completed, failed
    current_stage: str  # transcription, emotion_analysis, etc.
    progress_percent: int
    error_message: Optional[str]
    started_at: datetime
    completed_at: Optional[datetime]
```

### Transcript Model

```python
class TranscriptDocument:
    transcript_id: str
    media_id: str
    language: str
    segments: List[TranscriptSegment]
    word_count: int
    created_at: datetime
```

### Emotion Data Model

```python
class EmotionData:
    media_id: str
    emotion_timeline: List[EmotionScore]
    dominant_emotion: str
    avg_intensity: float
    created_at: datetime
```

### Clip Model

```python
class Clip:
    clip_id: str  # UUID
    media_id: str
    start_time: float
    end_time: float
    duration: float
    rank: int
    virality_score: float
    hook_title: str
    caption: str
    s3_key: str  # path to generated clip file
    thumbnail_s3_key: str
    transcript_text: str
    emotion_profile: Dict[str, float]
    topics: List[str]
    created_at: datetime
    download_count: int
```

### Analytics Model

```python
class MediaAnalytics:
    media_id: str
    attention_curve: List[AttentionPoint]
    peak_moments: List[Peak]
    avg_attention: float
    emotion_distribution: Dict[str, float]
    top_topics: List[str]
    clip_count: int
    created_at: datetime

class AttentionPoint:
    timestamp: float
    score: float  # 0-100
```

## Error Handling

### Error Categories

1. **Validation Errors (400)**
   - Invalid file format
   - File size exceeds limit
   - Missing required fields
   - Invalid parameters

2. **Authentication Errors (401)**
   - Invalid credentials
   - Expired token
   - Missing authentication

3. **Authorization Errors (403)**
   - Insufficient permissions
   - Access to another user's resources

4. **Not Found Errors (404)**
   - Media not found
   - Clip not found
   - User not found

5. **Processing Errors (500)**
   - Transcription failure
   - AI model errors
   - Storage errors
   - Database errors

### Error Response Format

```json
{
  "error": {
    "code": "TRANSCRIPTION_FAILED",
    "message": "Failed to transcribe audio after 3 attempts",
    "details": {
      "media_id": "abc-123",
      "stage": "transcription",
      "attempt": 3
    },
    "timestamp": "2024-01-15T10:30:00Z"
  }
}
```

### Retry Strategy

- **Transcription failures**: Retry 3 times with exponential backoff (1s, 2s, 4s)
- **LLM API failures**: Retry 2 times with 2s delay
- **Storage operations**: Retry 3 times immediately
- **Database operations**: Retry 2 times with 1s delay

### Graceful Degradation

- If vision analysis fails, continue with audio/text only
- If caption generation fails, use transcript excerpt as fallback
- If emotion analysis fails, use semantic importance only
- If clip generation produces <5 clips, lower threshold and retry

## Testing Strategy

ClipSense requires both unit testing and property-based testing to ensure correctness across the complex AI pipeline.

### Unit Testing Approach

Unit tests will focus on:
- API endpoint behavior with specific inputs
- Authentication and authorization logic
- Data validation and error handling
- Database operations and queries
- File upload and storage operations
- Specific edge cases (empty files, malformed data)

### Property-Based Testing Approach

Property tests will verify universal correctness properties across randomized inputs using a property-based testing library (Hypothesis for Python, fast-check for TypeScript).

**Configuration:**
- Minimum 100 iterations per property test
- Each test tagged with: `Feature: clipsense, Property {N}: {property_text}`
- Tests reference design document properties

**Test Organization:**
- Property tests in separate files: `test_properties_*.py`
- Unit tests in: `test_unit_*.py`
- Integration tests in: `test_integration_*.py`

### Testing Tools

- **Python Backend**: pytest, Hypothesis (property-based testing), pytest-asyncio
- **Frontend**: Jest, React Testing Library, fast-check (property-based testing)
- **API Testing**: pytest with httpx, Postman collections
- **Load Testing**: Locust or k6

### CI/CD Integration

- All tests run on every pull request
- Property tests run with 100 iterations in CI
- Integration tests run against test database
- Load tests run nightly on staging environment


## Correctness Properties

A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.

### Property 1: Media Upload Persistence

*For any* valid media file (video or audio in supported format), when uploaded by a Creator, the System should store the file in cloud storage, return a unique media identifier, and create a database record containing all required metadata fields (filename, size, duration, upload timestamp, creator ID).

**Validates: Requirements 1.1, 1.4**

### Property 2: File Format Validation

*For any* file with a random format extension, the System should accept only files with supported formats (MP4, MOV, AVI, MP3, WAV, M4A) and reject all other formats with an appropriate error message.

**Validates: Requirements 1.3**

### Property 3: User Media Isolation

*For any* Creator and their uploaded media, when that Creator requests their media list, all returned media records should belong exclusively to that Creator's user ID, and no other Creator's media should be included.

**Validates: Requirements 1.5**

### Property 4: Transcription Initiation

*For any* uploaded media file, the System should automatically initiate transcription processing and create a job record with "queued" or "processing" status.

**Validates: Requirements 2.1, 11.1**

### Property 5: Transcript Structure Completeness

*For any* completed transcription, the stored transcript should contain word-level timestamps where each word has a start time, end time, and the text content.

**Validates: Requirements 2.2**

### Property 6: Transcript Round-Trip Consistency

*For any* media file with a completed transcript, retrieving the transcript by media ID should return data equivalent to what was stored, preserving all timestamps and text content.

**Validates: Requirements 2.4**

### Property 7: Emotion Classification Validity

*For any* transcript or audio file processed for emotion analysis, the resulting emotion scores should contain only valid emotion categories (joy, sadness, anger, surprise, neutral) with scores in the range 0-1.

**Validates: Requirements 3.1, 3.2**

### Property 8: Emotion Data Temporal Granularity

*For any* media file with emotion analysis, the time intervals between consecutive emotion score timestamps should be at most 5 seconds, ensuring sufficient temporal resolution.

**Validates: Requirements 3.5**

### Property 9: Emotion Data Round-Trip Consistency

*For any* media file with completed emotion analysis, retrieving the emotion data by media ID should return time-series scores equivalent to what was stored.

**Validates: Requirements 3.4**

### Property 10: Importance Score Range Validity

*For any* transcript segment processed for semantic importance, the assigned importance score should be in the range 0-100.

**Validates: Requirements 4.2**

### Property 11: Topic Extraction Completeness

*For any* content-rich transcript segment (more than 50 words), semantic analysis should extract at least one topic, entity, or concept.

**Validates: Requirements 4.3**

### Property 12: Segment Duration Constraints

*For any* transcript segment processed by the Semantic Analyzer, the segment duration should be between 30 and 60 seconds.

**Validates: Requirements 4.5**

### Property 13: Attention Curve Normalization

*For any* generated attention curve, all attention score values should be in the range 0-100.

**Validates: Requirements 5.2**

### Property 14: Attention Curve Round-Trip Consistency

*For any* media file with a generated attention curve, retrieving the curve data by media ID should return time-series values equivalent to what was stored.

**Validates: Requirements 5.4**

### Property 15: Peak Detection Completeness

*For any* attention curve with local maxima, the Analytics Engine should identify at least one peak as a potential clip candidate.

**Validates: Requirements 5.5**

### Property 16: Clip Duration Constraints

*For any* generated clip candidate, the clip duration (end_time - start_time) should be between 15 and 90 seconds.

**Validates: Requirements 6.2**

### Property 17: Clip Count Constraints

*For any* long-form content with sufficient attention peaks, the Clip Generator should produce between 5 and 20 clip candidates.

**Validates: Requirements 6.4**

### Property 18: Clip Ranking Consistency

*For any* set of generated clips for a media file, when clips are ranked by virality score, the clips should be ordered in descending order by their rank scores.

**Validates: Requirements 6.3**

### Property 19: Clip Metadata Completeness

*For any* generated clip, the stored clip record should contain all required metadata fields: clip_id, media_id, start_time, end_time, duration, rank, virality_score, hook_title, caption, and transcript_text.

**Validates: Requirements 6.5**

### Property 20: Generated Text Character Limits

*For any* generated clip, the hook title should not exceed 100 characters and the caption should not exceed 300 characters.

**Validates: Requirements 7.1, 7.2**

### Property 21: Caption Data Persistence

*For any* clip with generated captions, retrieving the clip details by clip ID should return the hook title and caption that were stored.

**Validates: Requirements 7.5**

### Property 22: Virality Score Range Validity

*For any* generated clip, the calculated virality score should be in the range 0-100.

**Validates: Requirements 8.1**

### Property 23: Clip Ranking Sort Order

*For any* Marketer request for clip rankings, the returned clips should be sorted by virality score in descending order (highest score first).

**Validates: Requirements 8.4**

### Property 24: Analytics Data Structure Completeness

*For any* media file with completed processing, analytics requests should return data containing all required components: emotion timeline, attention heatmap data, virality scores, and aggregate statistics.

**Validates: Requirements 9.1, 9.2, 9.3, 9.4**

### Property 25: Analytics Response Format Validity

*For any* analytics data response, the data should be valid JSON containing time-series arrays with timestamp and value pairs suitable for visualization.

**Validates: Requirements 9.5**

### Property 26: Authentication Token Issuance

*For any* successful user authentication with valid credentials, the System should issue a JWT token containing the user's role information.

**Validates: Requirements 10.2**

### Property 27: Cross-User Access Denial

*For any* two distinct Creators A and B, when Creator A attempts to access Creator B's media, the System should deny access and return an authorization error.

**Validates: Requirements 10.3**

### Property 28: Role-Based Access Control

*For any* user attempting to access role-restricted endpoints (Marketer analytics, Admin management), the System should verify the user has the required role before granting access.

**Validates: Requirements 10.4, 10.5**

### Property 29: Job Status Progression

*For any* media processing job, the job status should progress through valid states (queued → processing → completed or failed) and never regress to earlier states.

**Validates: Requirements 11.3, 11.5**

### Property 30: Job Status Query Completeness

*For any* processing job, when a Creator polls for job status, the response should contain the current processing stage and a completion percentage between 0 and 100.

**Validates: Requirements 11.4**

### Property 31: Vision Analysis Conditional Processing

*For any* video file, when vision analysis is enabled in user settings, the System should perform movement detection and incorporate visual signals into the attention curve; when disabled, processing should complete using only audio and text analysis.

**Validates: Requirements 12.1, 12.2, 12.4**

### Property 32: Scene Change Detection

*For any* video file with vision analysis enabled, the System should detect and store scene changes with timestamps.

**Validates: Requirements 12.3**

### Property 33: Health Metrics Completeness

*For any* Admin request for system health metrics, the response should contain processing queue length, active job count, and error rate statistics.

**Validates: Requirements 13.1**

### Property 34: Pipeline Failure Logging

*For any* pipeline processing failure, the System should create a log entry containing error details, the failed stage, and a timestamp.

**Validates: Requirements 13.2**

### Property 35: Processing Time Metrics Accuracy

*For any* set of completed processing jobs, the calculated average processing time should equal the sum of individual processing times divided by the job count.

**Validates: Requirements 13.4**

### Property 36: Signed URL Generation

*For any* Creator request to download a clip, the System should generate a temporary signed URL with an expiration time of 24 hours from generation.

**Validates: Requirements 14.1, 14.5**

### Property 37: Multi-Format Clip Availability

*For any* generated clip, the System should provide the clip in multiple formats (at minimum MP4 and MOV).

**Validates: Requirements 14.2**

### Property 38: Metadata Export Completeness

*For any* clip metadata export request, the returned JSON should contain all clip metadata including hook titles, captions, timestamps, and virality scores.

**Validates: Requirements 14.3**

### Property 39: Batch Download Archive Completeness

*For any* batch download request for N clips, the generated ZIP archive should contain exactly N clip files.

**Validates: Requirements 14.4**

### Property 40: Rate Limiting Enforcement

*For any* user making requests, when the request count exceeds 100 requests per minute, subsequent requests should be rejected with a rate limit error until the time window resets.

**Validates: Requirements 15.5**
