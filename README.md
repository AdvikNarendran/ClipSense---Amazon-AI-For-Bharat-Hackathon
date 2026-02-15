# ClipSense

> AI-powered video intelligence platform that transforms long-form content into viral-ready short clips

ClipSense automatically identifies high-impact, viral-worthy moments from long-form video or audio content using multi-modal AI analysis. The platform eliminates manual video scrubbing by detecting emotional peaks and semantically important segments, generating short clips with captions and marketing insights.

Done by Team Mindbenders having Advik Narendran, Maddala Yagnasri Priya, Samrudhi Sudhir Kamble and Sanjivani Prajapal Shendre as the team members.

## Problem Statement

Content creators, educators, podcasters, streamers, and digital marketers spend excessive time manually reviewing long videos to extract short clips for social media. This process is inefficient, subjective, and not scalable.

## Key Features

### Intelligent Content Analysis
- **Speech-to-Text Transcription**: Automatic transcription with word-level timestamps using Whisper ASR
- **Emotion Detection**: Audio and text-based emotion analysis to identify engaging moments
- **Semantic Analysis**: LLM-powered evaluation of content importance and topic extraction
- **Attention Curve Generation**: Visual representation of engagement potential over time

### Automated Clip Creation
- **Smart Segmentation**: Automatically identifies 5-20 viral-worthy clips per video (15-90 seconds each)
- **Intelligent Ranking**: Clips ranked by virality potential using multi-signal scoring
- **Auto-Generated Captions**: Hook titles and captions optimized for social media
- **Multiple Formats**: Export clips in MP4, MOV, and other formats

### Marketing Intelligence
- **Virality Prediction**: AI-powered scores (0-100) predicting social media performance
- **Engagement Analytics**: Emotion vs engagement graphs and attention heatmaps
- **Performance Dashboards**: Comprehensive analytics and insights
- **Optional Vision Analysis**: Movement and gesture tracking for enhanced analysis

## Target Users

- **Creators**: Upload content and receive auto-generated clips with captions
- **Marketers**: Analyze engagement predictions and performance insights
- **Admins**: Manage users, monitor system health, and oversee AI pipelines

## Technology Stack

### Frontend
- React 18+ with Next.js 14
- TailwindCSS for styling
- Recharts/D3.js for analytics visualization

### Backend
- Python FastAPI for REST API
- Celery for asynchronous task processing
- Redis for job status caching

### AI/ML Components
- Whisper (OpenAI) for speech-to-text
- Gemini API or GPT-4 for semantic analysis and caption generation
- Librosa/PyAudioAnalysis for audio emotion detection
- Transformers (Hugging Face) for text sentiment analysis
- Optional: MediaPipe/OpenCV for vision analysis

### Infrastructure
- AWS S3 for media storage
- PostgreSQL for structured data
- MongoDB for semi-structured data
- Docker for containerization



## Key Capabilities

### Emotion Detection
Analyzes both audio features (pitch, tone, intensity) and text sentiment to identify emotionally engaging moments across five categories: joy, sadness, anger, surprise, and neutral.

### Semantic Importance
Uses LLMs to evaluate content significance, extract key topics and entities, and identify novel or relevant information worth highlighting.

### Attention Curve
Combines emotion intensity, semantic importance, and optional visual engagement signals into a unified 0-100 scale timeline showing engagement potential.

### Virality Prediction
Calculates virality scores based on:
- Emotion intensity (30%)
- Semantic importance (30%)
- Content novelty (20%)
- Duration optimality (10%)
- Hook quality (10%)

