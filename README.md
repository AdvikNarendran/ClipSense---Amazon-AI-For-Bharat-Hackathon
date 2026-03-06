# ClipSense — AI-Powered Video Intelligence & Viral Growth Platform

> AI-powered video intelligence platform that transforms long-form content into viral-ready short clips.

ClipSense automatically identifies high-impact, viral-worthy moments from long-form video or audio content using multi-modal AI analysis. The platform eliminates manual video scrubbing by detecting emotional peaks and semantically important segments, generating short clips with captions and marketing insights.

**Team Mindbenders**: Advik Narendran, Maddala Yagnasri Priya, Samrudhi Sudhir Kamble, and Sanjivani Prajapal Shendre.

---

## 🚀 Key Features

### 1. Multimodal AI Pipeline
*   **High-Fidelity Transcription**: Powered by **OpenAI Whisper** and **Amazon Transcribe**.
*   **Viral Discovery (AWS Bedrock & Gemini)**: Dual-model reasoning to identify high-engagement segments with professional analyst precision. This includes LLM-powered evaluation of content importance and topic extraction.
*   **Visual Intelligence (AWS Rekognition)**: Automated scene change detection and visual segment analysis, including optional movement and gesture tracking.
*   **Smart Formatting**:
    *   **Face-Track Crop**: AI-powered face detection ensures the subject remains centered in vertical (9:16) formats.
    *   **Letterbox Mode**: Intelligent fitting of any aspect ratio for stylistic consistency.
*   **Dynamic Subtitles**: High-quality, word-synced subtitles burned directly into the video.

### 2. Deep Emotional Analytics
*   **Emotional Timelines**: Precise tracking of 6 core emotions (Joy, Surprise, Anger, etc.) using audio and text-based emotion analysis.
*   **Attention Curves**: Visual peak-and-valley analysis using acoustic and text sentiment, combining emotion intensity, semantic importance, and optional visual engagement signals into a unified 0-100 scale timeline.
*   **Detailed Insights**: AI-generated "Engagement Intensity" scores and primary emotion labeling for every clip.

### 3. Automated Clip Creation
*   **Smart Segmentation**: Automatically identifies 5-20 viral-worthy clips per video (15-90 seconds each).
*   **Intelligent Ranking**: Clips ranked by virality potential using multi-signal scoring.
*   **Auto-Generated Captions**: Hook titles and captions optimized for social media.
*   **Multiple Formats**: Export clips in MP4, MOV, and other formats.

### 4. Marketing Intelligence
*   **Virality Prediction**: AI-powered scores (0-100) predicting social media performance based on emotion intensity (30%), semantic importance (30%), content novelty (20%), duration optimality (10%), and hook quality (10%).
*   **Engagement Analytics**: Emotion vs engagement graphs and attention heatmaps.
*   **Performance Dashboards**: Comprehensive analytics and insights.

### 5. Executive Dashboard (Admin)
*   **Platform Oversight**: High-level monitoring of system health and AI engine status.
*   **Creator Intelligence**: Analytics across all users and projects.
*   **Global Export**: One-click metadata export (JSON) for all clips and analytics.

---

## Target Users

-   **Creators**: Upload content and receive auto-generated clips with captions, manage their own projects, and view personal analytics.
-   **Marketers**: Analyze engagement predictions and performance insights.
-   **Admins**: Manage users, monitor system health, oversee AI pipelines, and have full platform visibility, including global project access and creator performance metrics.

---

## 🛠 Tech Stack

### AI & Cloud Infrastructure
*   **Reasoning**: AWS Bedrock (Claude 3 Haiku / Llama 3), Gemini API or GPT-4 for semantic analysis and caption generation.
*   **Computer Vision**: AWS Rekognition (Segment/Scene Detection), MediaPipe/OpenCV for vision analysis.
*   **Speech-to-Text**: AWS Transcribe & OpenAI Whisper.
*   **Storage**: Amazon S3 (Media) & DynamoDB (Metadata), PostgreSQL for structured data, MongoDB for semi-structured data.
*   **Hosting**: AWS App Runner (Backend) & AWS Amplify (Frontend).
*   **Containerization**: Docker.

### Backend (Python)
*   **Framework**: Flask (REST API) or FastAPI.
*   **Processing**: `MoviePy`, `MediaPipe`, `OpenCV`, `FFmpeg`.
*   **Analysis**: `Librosa`, `PyAudioAnalysis` for audio emotion detection, `NumPy`, Transformers (Hugging Face) for text sentiment analysis.
*   **Asynchronous Tasks**: Celery.
*   **Caching**: Redis for job status caching.

### Frontend (TypeScript)
*   **Framework**: Next.js 14 (App Router).
*   **Styling**: Tailwind CSS.
*   **Visuals**: Recharts/D3.js for analytics visualization.

---

## 📁 Repository Structure

```text
ClipSense/
├── backend/                           ← Python Backend (ClipSense Core)
│   ├── app.py                         ← Flask Application Entry Point
│   ├── server.py                      ← Backend Server & Route Handlers
│   ├── ai_engine.py                   ← AI Engine (Whisper & Gemini Integration)
│   ├── video_processor.py             ← Video Processing & Face Tracking
│   ├── emotion_analyzer.py            ← Emotional Analysis Logic
│   ├── attention_curve.py             ← Attention & Engagement Analytics
│   ├── db.py                          ← Database Connectors
│   ├── email_utils.py                 ← Notification & Email Utilities
│   ├── ffmpeg.exe                     ← Local FFmpeg Binary
│   └── requirements.txt               ← Backend dependencies
│
└── frontend/                          ← Next.js Frontend (ClipSense UX)
    ├── src/                           ← Application Source Code
    │   ├── app/                       ← Next.js App Router (Pages & API)
    │   ├── components/                ← UI Components & Data Visualizations
    │   ├── context/                   ← Global State Management
    │   └── lib/                       ← Utilities & API Clients
    ├── public/                        ← Static Assets
    ├── next.config.mjs                ← Next.js Configuration
    └── package.json                   ← Frontend dependencies & scripts
```

---

## ⚡ Quick Start

### 1. Backend Configuration
1. Navigate to `backend`.
2. Install dependencies: `pip install -r requirements.txt`.
3. Create a `.env` file from `.env.example`.
4. Add your `GEMINI_API_KEY` and `MONGO_URI`.
5. Start the server: `python server.py`.

### 2. Frontend Configuration
1. Navigate to `frontend`.
2. Install dependencies: `npm install`.
3. Ensure `.env.local` points to your backend: `NEXT_PUBLIC_API_URL=http://localhost:5000`.
4. Launch the application: `npm run dev`.

---

## 📜 Role-Based Access
*   **Creators**: Can upload videos, manage their own projects, and view personal analytics.
*   **Admins**: Full platform visibility, including system health, global project access, and creator performance metrics.

---

## ⚖️ License
Built with ❤️ during the **Amazon AI for Bharat Hackathon** — Finalized as **ClipSense**.
