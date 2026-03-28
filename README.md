# ClipSense — AI-Powered Video Intelligence & Viral Growth Platform

> Transform long-form content into viral-ready short clips with multi-modal AI analysis

ClipSense automatically identifies high-impact, viral-worthy moments from long-form video or audio content using advanced AI. The platform eliminates manual video scrubbing by detecting emotional peaks, semantic importance, and visual engagement, generating short clips with captions and marketing insights.

**Live Demo**: [ClipSense Platform](https://main.d3ksgup2cfy60v.amplifyapp.com/)

**Team Mindbenders**: Advik Narendran, Maddala Yagnasri Priya, Samrudhi Sudhir Kamble, and Sanjivani Prajapal Shendre

---

## 🚀 Implemented Features

### 1. Intelligent Video Processing Pipeline
- **Multi-Model Transcription**: Hybrid approach using OpenAI Whisper (local) with AWS Transcribe fallback for high-fidelity speech-to-text
- **Dual-AI Reasoning**: AWS Bedrock (Claude 3 Haiku) with Gemini API fallback for viral moment detection and semantic analysis
- **Visual Intelligence**: AWS Rekognition for automated scene detection, shot boundaries, and visual segment analysis
- **Smart Clip Generation**: Automatically creates 3-5 viral-worthy clips (15-90 seconds) per video with intelligent ranking
- **Dynamic Subtitles**: Word-synced captions burned directly into video with customizable styling

### 2. Advanced Emotional Analytics
- **Real-Time Emotion Tracking**: Acoustic feature extraction analyzing 6 core emotions (Joy, Surprise, Anger, Sadness, Fear, Neutral)
- **Attention Curve Generation**: Visual peak-and-valley analysis combining emotion intensity, semantic importance, and engagement signals (0-100 scale)
- **Per-Clip Emotional Insights**: AI-generated engagement intensity scores and primary emotion labeling for every generated clip
- **Emotion Timeline Visualization**: Interactive charts showing emotional flow throughout the entire video

### 3. User Management & Authentication
- **Secure Authentication**: JWT-based auth with email verification via OTP
- **Role-Based Access Control**: Creator and Admin roles with granular permissions
- **Password Management**: Secure password reset flow with OTP verification
- **Google OAuth Integration**: One-click sign-in with Google accounts
- **Profile Management**: User profile updates and account settings

### 4. Project Management
- **Video Upload**: Direct upload with presigned S3 URLs for secure, scalable file transfer
- **Processing Status**: Real-time progress tracking with detailed status updates
- **Project Dashboard**: Comprehensive view of all user projects with filtering and search
- **Clip Management**: Download individual clips or all clips as a batch
- **Transcript Export**: Download full transcripts in plain text (.txt) format
- **Subtitle Export**: Download time-synced subtitles in SRT format

### 5. Analytics & Insights
- **Virality Prediction**: AI-powered scores (0-100) predicting social media performance
- **Engagement Metrics**: Emotion vs engagement graphs and attention heatmaps
- **Clip Performance**: Individual clip analytics with engagement intensity and primary emotions
- **Project Statistics**: Total clips generated, average engagement, processing time

### 6. Admin Dashboard
- **Platform Oversight**: System health monitoring and AI engine status
- **User Management**: View all users, manage roles, and monitor activity
- **Global Project Access**: View and manage all projects across all users
- **Analytics Export**: One-click JSON export of all platform data
- **Performance Metrics**: Platform-wide statistics and usage analytics

### 7. Notification System
- **Email Notifications**: Automated emails for registration, password reset, and processing completion
- **Processing Alerts**: Email notifications when video processing completes with clip count and engagement metrics
- **OTP Delivery**: Secure one-time password delivery for authentication flows

---

## ☁️ AWS Cloud Services Used

### Core Infrastructure
| Service | Purpose | Justification |
|---------|---------|---------------|
| **AWS Lambda** | Serverless API (Flask) | Handles auth, uploads, status checks without managing servers. Auto-scales to 1000s of concurrent requests. Cost-effective for API workloads. |
| **Amazon EC2** | Video processing worker | Provides dedicated compute for CPU/memory-intensive video processing. t3.small instance with 2GB RAM + 2GB swap handles transcription and rendering. |
| **Amazon S3** | Media storage | Highly durable (99.999999999%) object storage for videos and clips. Supports presigned URLs for secure direct uploads/downloads. |
| **Amazon DynamoDB** | NoSQL database | Serverless, auto-scaling database for user accounts and project metadata. Single-digit millisecond latency. |
| **Amazon SQS** | Job queue | Decouples API from worker, enabling asynchronous processing. Ensures no job loss with message persistence. |
| **AWS Amplify** | Frontend hosting | Managed CI/CD with automatic deployments from GitHub. Global CDN for fast content delivery. |
| **Amazon API Gateway** | HTTPS endpoint | Provides secure HTTPS endpoint for Lambda with built-in DDoS protection and request throttling. |

### AI & ML Services
| Service | Purpose | Justification |
|---------|---------|---------------|
| **AWS Bedrock** | LLM reasoning (Claude 3 Haiku) | Provides advanced language understanding for viral moment detection and semantic analysis. Pay-per-use pricing. |
| **AWS Transcribe** | Speech-to-text | Cloud-based transcription with high accuracy. Fallback when local Whisper is unavailable. |
| **AWS Rekognition** | Computer vision | Automated scene detection and visual analysis without managing ML infrastructure. |
| **Google Gemini API** | LLM fallback | Secondary AI model for viral analysis when Bedrock is unavailable. Provides model diversity. |
| **OpenAI Whisper** | Local transcription | Self-hosted on EC2 for cost-effective transcription. No per-minute charges. |

### Security & Monitoring
| Service | Purpose | Justification |
|---------|---------|---------------|
| **AWS IAM** | Access management | Fine-grained permissions for services. EC2 uses IAM roles to access S3/SQS/DynamoDB without hardcoded credentials. |
| **Amazon ECR** | Container registry | Stores Docker images for Lambda and EC2 worker. Integrated with AWS services. |
| **AWS CloudWatch** | Logging & monitoring | Centralized logs for Lambda and EC2. Enables debugging and performance monitoring. |

---

## 🏗️ Architecture Highlights

### Hybrid Serverless + Compute Architecture
- **Serverless API Layer**: Lambda handles all API requests with automatic scaling
- **Dedicated Processing Layer**: EC2 worker handles CPU-intensive video processing
- **Asynchronous Design**: SQS queue decouples API from processing for reliability
- **Direct S3 Access**: Presigned URLs enable direct browser-to-S3 uploads/downloads, reducing Lambda bandwidth costs

### Cost Optimization
- **Free Tier Maximization**: Architecture designed to stay within AWS free tier limits
- **Pay-Per-Use AI**: Bedrock and Transcribe only charged when used
- **Local Whisper**: Self-hosted transcription eliminates per-minute API costs
- **Efficient Storage**: S3 lifecycle policies can archive old videos to Glacier

### Scalability Strategy
- **Horizontal Scaling**: Add more EC2 workers to process multiple videos concurrently
- **Vertical Scaling**: Upgrade EC2 instance type for faster processing
- **Auto-Scaling Ready**: Architecture supports AWS Batch or ECS for automatic worker scaling

---

## 📁 Repository Structure

```text
ClipSense/
├── backend/                           # Python Backend (ClipSense Core)
│   ├── lambda_api.py                  # Lambda API (Auth, Upload, Status)
│   ├── worker.py                      # EC2 Worker (Video Processing)
│   ├── ai_engine.py                   # AI Engine (Whisper, Bedrock, Gemini)
│   ├── emotion_analyzer.py            # Emotional Analysis Logic
│   ├── attention_curve.py             # Attention & Engagement Analytics
│   ├── db.py                          # DynamoDB Connector
│   ├── aws_utils.py                   # S3, SQS, Rekognition Utilities
│   ├── email_utils.py                 # Email Notifications (Gmail SMTP)
│   ├── Dockerfile.lambda              # Lambda Container Image
│   ├── Dockerfile.worker              # EC2 Worker Container Image
│   ├── requirements-lambda.txt        # Lambda Dependencies
│   └── requirements.txt               # Worker Dependencies
│
├── frontend/                          # Next.js Frontend (ClipSense UX)
│   ├── src/
│   │   ├── app/                       # Next.js App Router (Pages)
│   │   ├── components/                # UI Components & Visualizations
│   │   ├── context/                   # Global State Management
│   │   └── lib/                       # API Client & Utilities
│   ├── public/                        # Static Assets
│   └── package.json                   # Frontend Dependencies
│
├── scripts/                           # Deployment & Utility Scripts
│   ├── setup-*.ps1                    # AWS Infrastructure Setup Scripts
│   ├── redeploy-*.ps1                 # Redeployment Scripts
│   └── *.sh                           # Bash Utility Scripts
│
├── docs/                              # Documentation & Guides
│   ├── DEPLOYMENT_*.md                # Deployment Guides
│   ├── *_GUIDE.md                     # Feature-Specific Guides
│   └── *_SUMMARY.md                   # Status Summaries
│
├── .github/workflows/                 # CI/CD Pipelines
│   ├── deploy-lambda.yml              # Lambda Auto-Deployment
│   └── deploy-worker.yml              # Worker Auto-Deployment
│
├── README.md                          # This File
├── ARCHITECTURE.md                    # Detailed Architecture Documentation
├── DEPLOYMENT.md                      # Deployment Instructions
└── amplify.yml                        # Amplify Build Configuration
```

---

## ⚡ Quick Start

### Prerequisites
- AWS Account with free tier access
- Docker installed locally
- Node.js 18+ and Python 3.11+
- AWS CLI configured with credentials

### 1. Backend Setup

```bash
cd backend

# Install dependencies
pip install -r requirements.txt

# Configure environment
cp .env.example .env
# Edit .env with your API keys:
# - GEMINI_API_KEY
# - SENDER_EMAIL / SENDER_PASSWORD (Gmail SMTP)
# - AWS credentials

# Run locally (optional)
python server.py
```

### 2. Frontend Setup

```bash
cd frontend

# Install dependencies
npm install

# Configure environment
cp .env.local.example .env.local
# Edit .env.local with your API URL

# Run development server
npm run dev
```

### 3. AWS Deployment

```bash
# Deploy infrastructure (run from project root)
cd backend

# 1. Setup S3 bucket
./setup-s3.ps1

# 2. Setup DynamoDB tables
./setup-dynamodb.ps1

# 3. Setup SQS queue
./setup-sqs.ps1

# 4. Setup ECR repositories
./setup-ecr.ps1

# 5. Deploy Lambda API
./setup-lambda.ps1

# 6. Setup API Gateway
./setup-api-gateway.ps1

# 7. Deploy EC2 worker
./setup-ec2.ps1

# 8. Deploy frontend to Amplify (via GitHub integration)
# Connect your GitHub repo in AWS Amplify Console
```

---

## 🔐 Security Features

- **JWT Authentication**: Secure token-based auth with 24-hour expiration
- **OTP Verification**: Email-based one-time passwords for registration and password reset
- **Role-Based Access**: Granular permissions for creators and admins
- **Presigned URLs**: Time-limited S3 access (1-hour expiration)
- **IAM Roles**: No hardcoded AWS credentials in code
- **Encryption**: S3 server-side encryption (AES-256), DynamoDB encryption at rest
- **HTTPS Only**: All traffic encrypted in transit
- **Input Validation**: Comprehensive validation on all API endpoints

---

## 📊 Performance Metrics

- **API Response Time**: < 200ms for most endpoints
- **Video Upload**: Direct to S3 with presigned URLs (no Lambda bandwidth limits)
- **Processing Time**: ~2-5 minutes for 10-minute video (depends on EC2 instance)
- **Concurrent Users**: Lambda auto-scales to handle 1000s of concurrent API requests
- **Storage**: Unlimited (S3 scales automatically)

---

## 🎯 Use Cases

### Content Creators
- Upload long-form videos (podcasts, interviews, webinars)
- Automatically generate viral-ready short clips
- Download clips with burned-in subtitles
- Analyze emotional engagement and attention curves

### Marketing Teams
- Identify high-engagement moments for social media
- Predict virality scores for content planning
- Export analytics for reporting
- Batch process multiple videos

### Platform Administrators
- Monitor system health and processing status
- Manage users and access control
- View platform-wide analytics
- Export global data for analysis

---

## 🚀 Future Enhancements

- **Auto-Scaling Workers**: AWS Batch or ECS for automatic worker scaling
- **Multi-Language Support**: Transcription and subtitles in multiple languages
- **Custom Branding**: User-configurable subtitle styles and watermarks
- **Social Media Integration**: Direct posting to YouTube, TikTok, Instagram
- **Advanced Analytics**: A/B testing, performance tracking, audience insights
- **Collaboration Features**: Team workspaces, shared projects, comments
- **API Access**: RESTful API for third-party integrations

---

## 📝 License

Built with ❤️ during the **Amazon AI for Bharat Hackathon** — Finalized as **ClipSense**.

---

## 🤝 Contributing

This project was developed as part of a hackathon. For questions or collaboration opportunities, please contact the team.

---

## 📧 Support

For issues or questions:
- Check the [DEPLOYMENT.md](DEPLOYMENT.md) guide
- Review the [ARCHITECTURE.md](ARCHITECTURE.md) documentation
- Contact: clipsense57@gmail.com
