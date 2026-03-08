# ClipSense Cloud Architecture

## System Overview

ClipSense uses a hybrid AWS architecture that combines serverless and compute services to deliver AI-powered video intelligence at scale. The architecture is designed for cost-efficiency, scalability, and reliability, leveraging AWS managed services to minimize operational overhead while maintaining high performance for video processing workloads.

## Complete Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              User Layer                                      │
│                                                                              │
│  ┌──────────────┐         ┌──────────────┐         ┌──────────────┐       │
│  │   Creator    │         │   Marketer   │         │    Admin     │       │
│  │   Browser    │         │   Browser    │         │   Browser    │       │
│  └──────┬───────┘         └──────┬───────┘         └──────┬───────┘       │
│         │                        │                        │                 │
│         └────────────────────────┼────────────────────────┘                │
│                                  │ HTTPS                                    │
└──────────────────────────────────┼──────────────────────────────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                          AWS Cloud (ap-south-1)                              │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────┐    │
│  │                      Presentation Layer                             │    │
│  │                                                                      │    │
│  │  ┌──────────────────────────────────────────────────────────┐     │    │
│  │  │              AWS Amplify Hosting                          │     │    │
│  │  │  • Next.js 14 Frontend (SSR + Static)                    │     │    │
│  │  │  • Automatic CI/CD from GitHub                           │     │    │
│  │  │  • Global CDN Distribution                               │     │    │
│  │  │  • HTTPS with AWS Certificate Manager                    │     │    │
│  │  └────────────────────────┬─────────────────────────────────┘     │    │
│  └───────────────────────────┼───────────────────────────────────────┘    │
│                              │ REST API Calls                               │
│                              ▼                                              │
│  ┌────────────────────────────────────────────────────────────────────┐    │
│  │                      API Layer                                      │    │
│  │                                                                      │    │
│  │  ┌──────────────────┐         ┌─────────────────────────────┐     │    │
│  │  │  API Gateway     │────────▶│   Lambda Function           │     │    │
│  │  │  (REST API)      │         │   clipsense-api             │     │    │
│  │  │  • HTTPS Only    │         │   • 3008MB Memory           │     │    │
│  │  │  • CORS Enabled  │         │   • 900s Timeout            │     │    │
│  │  │  • Rate Limiting │         │   • Flask API (Python)      │     │    │
│  │  │  • DDoS Guard    │         │   • JWT Authentication      │     │    │
│  │  └──────────────────┘         │   • Email Notifications     │     │    │
│  │                                │   • Presigned URL Gen       │     │    │
│  │                                └──────────┬──────────────────┘     │    │
│  └───────────────────────────────────────────┼────────────────────────┘    │
│                                              │                              │
│                    ┌─────────────────────────┼─────────────────────┐       │
│                    │                         │                     │       │
│                    ▼                         ▼                     ▼       │
│  ┌────────────────────────────────────────────────────────────────────┐    │
│  │                    Processing Layer                                 │    │
│  │                                                                      │    │
│  │  ┌──────────────────┐         ┌─────────────────────────────┐     │    │
│  │  │   SQS Queue      │────────▶│   EC2 Worker (t3.small)     │     │    │
│  │  │   Standard       │  Poll   │   • 2GB RAM + 2GB Swap      │     │    │
│  │  │   • FIFO Order   │  Every  │   • Docker Container        │     │    │
│  │  │   • 1hr Timeout  │  5 sec  │   • Auto-restart Policy     │     │    │
│  │  │   • DLQ Enabled  │         │   • Whisper Transcription   │     │    │
│  │  └──────────────────┘         │   • Emotion Analysis        │     │    │
│  │                                │   • Gemini AI Processing    │     │    │
│  │                                │   • MoviePy Rendering       │     │    │
│  │                                │   • FFmpeg Video Ops        │     │    │
│  │                                └──────────┬──────────────────┘     │    │
│  └───────────────────────────────────────────┼────────────────────────┘    │
│                                              │                              │
│                    ┌─────────────────────────┼─────────────────────┐       │
│                    │                         │                     │       │
│                    ▼                         ▼                     ▼       │
│  ┌────────────────────────────────────────────────────────────────────┐    │
│  │                      Data Layer                                     │    │
│  │                                                                      │    │
│  │  ┌──────────────┐    ┌──────────────┐    ┌──────────────────┐    │    │
│  │  │  Amazon S3   │    │  DynamoDB    │    │  External AI     │    │    │
│  │  │  Bucket      │    │  Tables      │    │  Services        │    │    │
│  │  │              │    │              │    │                  │    │    │
│  │  │  • Videos    │    │  • Users     │    │  • Gemini API    │    │    │
│  │  │  • Clips     │    │  • Projects  │    │  • AWS Bedrock   │    │    │
│  │  │  • Encrypted │    │  • Metadata  │    │  • Rekognition   │    │    │
│  │  │  • Versioned │    │  • 5 RCU/WCU │    │  • Transcribe    │    │    │
│  │  │  • Private   │    │  • Encrypted │    │                  │    │    │
│  │  └──────────────┘    └──────────────┘    └──────────────────┘    │    │
│  └────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────┐    │
│  │                    Notification Layer                               │    │
│  │                                                                      │    │
│  │  ┌──────────────────────────────────────────────────────────────┐  │    │
│  │  │              Amazon SES / Gmail SMTP                          │  │    │
│  │  │  • OTP Email Delivery                                        │  │    │
│  │  │  • Processing Completion Notifications                       │  │    │
│  │  │  • Error Alerts                                              │  │    │
│  │  └──────────────────────────────────────────────────────────────┘  │    │
│  └────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

## Component Justification & Design Decisions

### Why This Architecture Works

This hybrid architecture combines the best of serverless and traditional compute to deliver a cost-effective, scalable, and reliable video processing platform. Here's why each component was chosen:

#### 1. AWS Amplify (Frontend Hosting)
**Why Chosen:**
- Automatic CI/CD from GitHub eliminates manual deployment
- Global CDN distribution ensures fast load times worldwide
- Built-in HTTPS with AWS Certificate Manager (free SSL)
- Seamless integration with AWS services
- Pay-per-use pricing model (only pay for bandwidth)

**Alternatives Considered:**
- Vercel: More expensive for high traffic
- S3 + CloudFront: Requires manual CI/CD setup
- EC2 + Nginx: High operational overhead

**Why It Works:**
Amplify provides enterprise-grade hosting with zero DevOps overhead, perfect for a Next.js application that needs fast global delivery.

#### 2. API Gateway + Lambda (API Layer)
**Why Chosen:**
- Serverless = zero server management
- Auto-scales from 0 to 1000s of concurrent requests
- Pay only for actual requests (no idle costs)
- Built-in DDoS protection and rate limiting
- 900s timeout sufficient for upload operations
- 3008MB memory handles large file uploads

**Alternatives Considered:**
- EC2 + Flask: Requires 24/7 running costs
- App Runner: More expensive than Lambda
- ECS Fargate: Overkill for simple API

**Why It Works:**
Lambda handles bursty traffic patterns perfectly. Most API calls (auth, status checks) complete in <1s, making Lambda extremely cost-effective. The API layer doesn't need to process videos—it just orchestrates.

#### 3. Amazon SQS (Job Queue)
**Why Chosen:**
- Decouples API from processing (async architecture)
- Guarantees message delivery (no lost jobs)
- 1-hour visibility timeout prevents duplicate processing
- Dead Letter Queue (DLQ) captures failed jobs
- Unlimited queue depth handles traffic spikes
- Free tier: 1M requests/month

**Alternatives Considered:**
- Redis Queue: Requires managing Redis server
- RabbitMQ: Complex setup and maintenance
- Direct Lambda → EC2: No retry mechanism

**Why It Works:**
SQS enables the API to respond instantly while processing happens asynchronously. If the worker crashes, the job automatically reappears in the queue for retry.

#### 4. EC2 t3.small (Video Processing Worker)
**Why Chosen:**
- Video processing requires sustained CPU + memory
- 2GB RAM + 2GB swap = 4GB effective memory
- Handles Whisper transcription + MoviePy rendering
- Docker container for easy deployment
- Auto-restart policy ensures reliability
- Cost: ~$15/month (predictable)

**Alternatives Considered:**
- Lambda: 15-minute timeout too short for long videos
- Fargate: 3x more expensive than EC2
- Batch: Overkill for single-worker setup
- t2.micro: Insufficient memory (crashes during rendering)

**Why It Works:**
Video processing is CPU/memory intensive and can take 5-30 minutes per video. EC2 provides the sustained compute needed at a predictable cost. The swap space prevents OOM crashes during peak memory usage.

#### 5. Amazon S3 (Media Storage)
**Why Chosen:**
- 99.999999999% durability (11 nines)
- Unlimited storage capacity
- Presigned URLs enable direct browser downloads
- Server-side encryption (AES-256) by default
- Versioning protects against accidental deletion
- Lifecycle policies for automatic cleanup

**Alternatives Considered:**
- EBS volumes: Limited capacity, single-AZ
- EFS: More expensive, unnecessary for object storage
- Third-party CDN: Adds complexity

**Why It Works:**
S3 is the industry standard for media storage. Presigned URLs eliminate the need to proxy large video files through Lambda, saving bandwidth costs and improving download speed.

#### 6. DynamoDB (Metadata Storage)
**Why Chosen:**
- Serverless NoSQL database (zero management)
- Single-digit millisecond latency
- Auto-scales read/write capacity
- Free tier: 25GB storage, 25 RCU/WCU
- Built-in encryption at rest
- Point-in-time recovery available

**Alternatives Considered:**
- RDS PostgreSQL: Requires instance management
- MongoDB Atlas: Additional vendor dependency
- S3 JSON files: No query capabilities

**Why It Works:**
DynamoDB's key-value model perfectly fits our access patterns (get project by ID, list user's projects). The free tier covers typical usage, and the serverless model eliminates database administration.

#### 7. External AI Services (Gemini, Bedrock, Rekognition, Transcribe)
**Why Chosen:**
- **Gemini API**: Cost-effective LLM for semantic analysis ($0.00015/1K tokens)
- **AWS Bedrock (Claude 3 Haiku)**: Backup LLM with AWS integration
- **AWS Rekognition**: Scene detection and visual analysis (pay-per-image)
- **AWS Transcribe**: High-quality speech-to-text (backup for Whisper)

**Alternatives Considered:**
- Self-hosted models: Requires GPU instances ($$$)
- OpenAI GPT-4: More expensive than Gemini
- Open-source Whisper only: No cloud backup

**Why It Works:**
Using managed AI services eliminates the need for expensive GPU infrastructure. Gemini provides excellent quality at low cost, while AWS services offer enterprise reliability and seamless integration.

#### 8. Email Notifications (Gmail SMTP)
**Why Chosen:**
- Free for low-volume sending
- Simple SMTP integration
- Reliable delivery
- No AWS SES verification delays

**Alternatives Considered:**
- AWS SES: Requires domain verification
- SendGrid: Additional vendor dependency
- SNS: SMS costs more than email

**Why It Works:**
Gmail SMTP provides instant setup for OTP delivery and processing notifications without the overhead of configuring AWS SES.

### Architecture Principles

#### 1. Separation of Concerns
- **API Layer**: Handles authentication, uploads, status checks
- **Processing Layer**: Handles compute-intensive video processing
- **Data Layer**: Handles persistent storage
- **Notification Layer**: Handles user communications

This separation allows each layer to scale independently and fail gracefully.

#### 2. Asynchronous Processing
The SQS queue decouples the API from processing, enabling:
- Instant API responses (no waiting for processing)
- Automatic retry on failures
- Traffic spike absorption
- Multiple workers (horizontal scaling)

#### 3. Cost Optimization
- Serverless components (Lambda, DynamoDB) scale to zero
- EC2 worker runs 24/7 but handles multiple jobs
- S3 lifecycle policies auto-delete old files
- Free tier maximization reduces costs

#### 4. Reliability & Fault Tolerance
- SQS guarantees message delivery
- EC2 auto-restart on crashes
- S3 multi-AZ replication
- DynamoDB automatic backups
- Dead Letter Queue captures failed jobs

#### 5. Security by Default
- All traffic over HTTPS
- S3 bucket blocks public access
- IAM roles (no hardcoded credentials)
- JWT authentication
- Encryption at rest (S3, DynamoDB)

## Data Flow

### Upload Flow (Step-by-Step)

```
User Browser → Amplify Frontend → API Gateway → Lambda → S3 + DynamoDB + SQS
```

1. **User uploads video** via Amplify frontend (Next.js)
2. **Frontend sends multipart form data** to API Gateway endpoint: `POST /api/upload`
3. **API Gateway invokes Lambda** function with request payload
4. **Lambda authenticates user** via JWT token validation
5. **Lambda generates unique project ID** (UUID)
6. **Lambda saves video to S3** at `uploads/{project_id}/{filename}`
7. **Lambda creates project record** in DynamoDB with status: "queued"
8. **Lambda sends processing job** to SQS queue with project metadata
9. **Lambda returns immediately** with project ID (no waiting for processing)
10. **Frontend redirects** to project dashboard showing "Processing..." status

**Key Design Decision:** Lambda returns immediately after queuing the job, providing instant user feedback. Processing happens asynchronously in the background.

### Processing Flow (Step-by-Step)

```
SQS Queue → EC2 Worker → S3 (download) → AI Processing → S3 (upload) → DynamoDB → Email
```

1. **EC2 worker polls SQS** every 5 seconds for new jobs
2. **Worker receives message** with project ID and video metadata
3. **Worker updates DynamoDB** status to "processing" (progress: 0%)
4. **Worker downloads video** from S3 to local `/tmp` directory
5. **Worker runs transcription** (Whisper or AWS Transcribe)
   - Updates progress: 20%
   - Saves transcript to DynamoDB
6. **Worker runs emotion analysis** (audio + text sentiment)
   - Extracts acoustic features from audio
   - Analyzes text sentiment from transcript
   - Generates emotion timeline (6 emotions: Joy, Surprise, Anger, Sadness, Fear, Neutral)
   - Updates progress: 50%
   - Saves emotion data to DynamoDB
7. **Worker runs visual analysis** (AWS Rekognition - optional)
   - Detects scene changes
   - Identifies faces and objects
   - Updates progress: 60%
8. **Worker runs AI clip selection** (Gemini/Bedrock)
   - Analyzes transcript + emotions + visual data
   - Identifies 5-20 viral-worthy segments
   - Generates hook titles and captions
   - Calculates virality scores
   - Updates progress: 70%
9. **Worker renders clips** (MoviePy + FFmpeg)
   - Extracts video segments
   - Burns subtitles into video
   - Applies face-tracking crop (9:16 format)
   - Exports MP4 files
   - Updates progress: 90% (incremental per clip)
10. **Worker uploads clips** to S3 at `clips/{project_id}/clip_{n}.mp4`
11. **Worker updates DynamoDB** with clip metadata and status: "completed" (progress: 100%)
12. **Worker sends completion email** to user with project link
13. **Worker deletes SQS message** (job complete)
14. **Worker deletes local files** to free disk space

**Key Design Decision:** The worker updates progress incrementally, allowing the frontend to show real-time processing status. If the worker crashes, the SQS message reappears after 1 hour for automatic retry.

### Download Flow (Step-by-Step)

```
User Browser → Amplify Frontend → API Gateway → Lambda → S3 Presigned URL → Direct Download
```

1. **User clicks "Download Clip"** in frontend
2. **Frontend calls API**: `GET /api/projects/{project_id}/clips/{clip_id}/download`
3. **API Gateway invokes Lambda** function
4. **Lambda authenticates user** and verifies project ownership
5. **Lambda generates presigned S3 URL** (valid for 1 hour)
6. **Lambda returns presigned URL** to frontend
7. **Frontend redirects browser** to presigned URL
8. **Browser downloads directly from S3** (no Lambda proxy)

**Key Design Decision:** Presigned URLs enable direct S3 downloads, eliminating the need to proxy large video files through Lambda. This saves bandwidth costs and improves download speed.

### Transcript & Emotion Data Retrieval

```
User Browser → Amplify Frontend → API Gateway → Lambda → DynamoDB → JSON Response
```

**Transcript Endpoint:** `GET /api/projects/{project_id}/transcript`
- Returns plain text transcript for download

**Subtitle Endpoint:** `GET /api/projects/{project_id}/subtitles`
- Returns SRT format subtitles with timestamps

**Emotion Endpoint:** `GET /api/projects/{project_id}/emotions`
- Returns emotion timeline array with timestamps and emotion scores

**Key Design Decision:** Separate endpoints for different data formats allow frontend flexibility and enable future integrations (e.g., third-party subtitle editors).

### Email Notification Flow

```
Lambda/Worker → Gmail SMTP → User Email
```

**OTP Email (Lambda):**
1. User requests OTP for authentication
2. Lambda generates 6-digit OTP
3. Lambda sends email via Gmail SMTP
4. User receives OTP within seconds

**Processing Complete Email (Worker):**
1. Worker completes video processing
2. Worker sends completion email with project link
3. User receives notification to view clips

**Key Design Decision:** Email notifications keep users informed without requiring them to poll the API for status updates.

## AWS Services Used (Complete Reference)

| Service | Purpose | Configuration | Cost | Justification |
|---------|---------|---------------|------|---------------|
| **AWS Amplify** | Frontend hosting with CI/CD | Next.js 14, Auto-deploy from GitHub | ~$1-5/month | Zero-config deployment, global CDN, automatic HTTPS |
| **API Gateway** | HTTPS endpoint for Lambda | REST API, CORS enabled, rate limiting | FREE (1M req/month for 12mo), then $1/M req | Managed API layer with DDoS protection |
| **Lambda** | Serverless API (auth, upload, status) | 3008MB memory, 900s timeout, Python 3.11 | FREE (1M req/month), then $0.20/M req | Auto-scaling, pay-per-request, zero server management |
| **EC2 t3.small** | Video processing worker | 2 vCPU, 2GB RAM + 2GB swap, Docker | ~$15/month | Sustained compute for video processing, predictable cost |
| **SQS** | Job queue (Lambda → EC2) | Standard queue, 1hr visibility timeout, DLQ | FREE (1M req/month), then $0.40/M req | Decouples API from processing, guarantees delivery |
| **S3** | Video and clip storage | Private bucket, AES-256 encryption, versioning | FREE (5GB), then $0.023/GB/month | Industry-standard object storage, presigned URLs |
| **DynamoDB** | User and project metadata | 2 tables (Users, Projects), 5 RCU/WCU each | FREE (25GB, 25 RCU/WCU), then $0.25/GB/month | Serverless NoSQL, single-digit ms latency |
| **ECR** | Docker image registry | 2 repos (lambda-api, worker) | FREE (500MB/month), then $0.10/GB/month | Managed container registry for Lambda + EC2 |
| **IAM** | Access control and permissions | Roles for Lambda, EC2, and services | FREE | Secure credential management, no hardcoded keys |
| **CloudWatch** | Logs and monitoring | Lambda logs, EC2 metrics | FREE (5GB logs/month), then $0.50/GB | Centralized logging and alerting |
| **Gemini API** | LLM for semantic analysis | gemini-1.5-flash model | $0.00015/1K tokens | Cost-effective AI reasoning for clip selection |
| **AWS Bedrock** | Backup LLM (Claude 3 Haiku) | On-demand pricing | $0.00025/1K input tokens | Enterprise AI with AWS integration |
| **AWS Rekognition** | Visual analysis (scene detection) | Pay-per-image pricing | $0.001/image | Managed computer vision, no GPU needed |
| **AWS Transcribe** | Speech-to-text (backup) | Pay-per-minute pricing | $0.024/minute | Cloud backup for Whisper transcription |
| **Gmail SMTP** | Email notifications (OTP, alerts) | SMTP relay | FREE (low volume) | Instant setup, reliable delivery |

### Service Integration Map

```
┌─────────────────────────────────────────────────────────────────┐
│                     Service Dependencies                         │
│                                                                  │
│  Amplify ──────────────────────────────────────────────────────┐│
│     │                                                           ││
│     └──▶ API Gateway ──▶ Lambda ──┬──▶ S3                     ││
│                                    ├──▶ DynamoDB               ││
│                                    ├──▶ SQS                    ││
│                                    ├──▶ IAM (roles)            ││
│                                    └──▶ Gmail SMTP             ││
│                                                                 ││
│  SQS ──▶ EC2 Worker ──────────────┬──▶ S3                     ││
│                                    ├──▶ DynamoDB               ││
│                                    ├──▶ Gemini API             ││
│                                    ├──▶ AWS Bedrock            ││
│                                    ├──▶ AWS Rekognition        ││
│                                    ├──▶ AWS Transcribe         ││
│                                    ├──▶ IAM (roles)            ││
│                                    └──▶ Gmail SMTP             ││
│                                                                 ││
│  CloudWatch ◀────────────────────────── All Services           ││
│                                                                 ││
│  ECR ──────────────────────────────┬──▶ Lambda (image)        ││
│                                    └──▶ EC2 (image)            ││
└─────────────────────────────────────────────────────────────────┘
```

## Security Model

### Authentication & Authorization

#### JWT-Based Authentication
- **Token Generation**: Lambda generates JWT tokens on successful login
- **Token Storage**: Stored in browser localStorage (HttpOnly cookies for production)
- **Token Expiration**: 24-hour validity, requires re-authentication after expiry
- **Token Validation**: Every API request validates JWT signature and expiration

#### Role-Based Access Control (RBAC)
- **Creator Role**: Can upload videos, manage own projects, view personal analytics
- **Admin Role**: Full platform access, system health monitoring, global project visibility
- **Authorization Check**: Lambda validates user role before granting access to resources

#### OTP Email Verification
- **Purpose**: Passwordless authentication or 2FA
- **Flow**: User requests OTP → Lambda generates 6-digit code → Email sent via SMTP → User enters code
- **Expiration**: OTP valid for 10 minutes
- **Rate Limiting**: Max 3 OTP requests per email per hour

### Network Security

#### HTTPS Everywhere
- **Amplify**: Automatic HTTPS with AWS Certificate Manager (ACM)
- **API Gateway**: HTTPS-only endpoints, TLS 1.2+ required
- **S3 Presigned URLs**: HTTPS-only, 1-hour expiration

#### DDoS Protection
- **API Gateway**: Built-in AWS Shield Standard (free DDoS protection)
- **Rate Limiting**: API Gateway throttling (10,000 req/sec burst, 5,000 req/sec steady)
- **CloudFront**: Amplify uses CloudFront CDN with DDoS mitigation

#### Security Groups & Network ACLs
- **EC2 Security Group**: 
  - Inbound: SSH (port 22) from AWS Session Manager only
  - Outbound: HTTPS (443) for AWS API calls, SMTP (587) for email
- **VPC**: Default VPC with private subnets (future: move EC2 to private subnet)

### Data Security

#### Encryption at Rest
- **S3**: Server-side encryption (SSE-S3) with AES-256, enabled by default
- **DynamoDB**: Encryption at rest using AWS-managed keys (KMS)
- **EBS Volumes**: EC2 root volume encrypted with AWS-managed keys
- **Lambda Environment Variables**: Encrypted at rest with AWS KMS

#### Encryption in Transit
- **All AWS API Calls**: TLS 1.2+ encryption
- **S3 Uploads/Downloads**: HTTPS-only, enforced by bucket policy
- **Database Connections**: DynamoDB uses HTTPS for all requests

#### Data Access Control
- **S3 Bucket Policy**: Blocks all public access, requires IAM authentication
- **DynamoDB**: IAM-based access control, no public endpoints
- **Presigned URLs**: Time-limited (1 hour), scoped to specific objects

### Secrets Management

#### IAM Roles (No Hardcoded Credentials)
- **Lambda Execution Role**: Grants access to S3, DynamoDB, SQS, Bedrock, Rekognition
- **EC2 Instance Role**: Grants access to S3, DynamoDB, SQS, ECR
- **Principle of Least Privilege**: Each role has minimal required permissions

#### Environment Variables
- **Lambda**: Stored in AWS Lambda configuration, encrypted with KMS
  - `GEMINI_API_KEY`, `JWT_SECRET_KEY`, `SENDER_EMAIL`, `SENDER_PASSWORD`
- **EC2**: Stored in `/etc/clipsense/.env` file with `chmod 600` (owner-only read)
  - Same variables as Lambda for consistency

#### API Key Rotation
- **Gemini API Key**: Rotated when leaked or compromised
- **JWT Secret**: Rotated periodically (invalidates all existing tokens)
- **Email Password**: App-specific password, rotated on security events

### Input Validation & Sanitization

#### File Upload Validation
- **File Type**: Only video formats allowed (MP4, MOV, AVI, MKV)
- **File Size**: Max 500MB per upload (configurable)
- **Virus Scanning**: Future enhancement (AWS Macie or ClamAV)

#### API Input Validation
- **SQL Injection**: Not applicable (DynamoDB is NoSQL)
- **XSS Prevention**: Frontend sanitizes user input before rendering
- **CSRF Protection**: JWT tokens prevent cross-site request forgery

### Audit & Compliance

#### Logging
- **CloudWatch Logs**: All Lambda invocations logged with request/response
- **EC2 Worker Logs**: Docker container logs streamed to CloudWatch
- **S3 Access Logs**: Optional (can enable for compliance)
- **DynamoDB Streams**: Optional (can enable for audit trail)

#### Monitoring & Alerts
- **CloudWatch Alarms**: Alert on Lambda errors, EC2 CPU/memory spikes
- **SQS Dead Letter Queue**: Captures failed jobs for investigation
- **Email Alerts**: Admin notified on critical failures

### Security Best Practices Implemented

✅ **Principle of Least Privilege**: IAM roles grant minimal required permissions  
✅ **Defense in Depth**: Multiple security layers (network, application, data)  
✅ **Encryption Everywhere**: Data encrypted at rest and in transit  
✅ **No Hardcoded Secrets**: All credentials in environment variables or IAM roles  
✅ **Regular Updates**: Docker images rebuilt with latest security patches  
✅ **Audit Logging**: All API calls and processing jobs logged  
✅ **Rate Limiting**: API Gateway throttling prevents abuse  
✅ **Time-Limited Access**: Presigned URLs and JWT tokens expire automatically

## Scalability & Performance

### Current Capacity

| Component | Current Capacity | Bottleneck | Scaling Strategy |
|-----------|------------------|------------|------------------|
| **API (Lambda)** | 1000s of concurrent requests | None (auto-scales) | Automatic (AWS managed) |
| **Frontend (Amplify)** | Global CDN, unlimited users | None (auto-scales) | Automatic (AWS managed) |
| **Worker (EC2)** | 1 video at a time | Single instance | Horizontal (add workers) |
| **Queue (SQS)** | Unlimited queue depth | None | N/A (managed service) |
| **Storage (S3)** | Unlimited | None | N/A (managed service) |
| **Database (DynamoDB)** | 5 RCU/WCU per table | Low throughput | Increase RCU/WCU or auto-scaling |

### Performance Metrics

#### API Response Times
- **Authentication**: <100ms (JWT validation)
- **Upload Initiation**: <500ms (S3 presigned URL generation)
- **Status Check**: <50ms (DynamoDB query)
- **Clip Download**: <200ms (presigned URL generation)

#### Processing Times (per video)
- **Transcription**: 1-5 minutes (depends on video length)
- **Emotion Analysis**: 30-60 seconds
- **Visual Analysis**: 1-2 minutes (optional)
- **AI Clip Selection**: 30-60 seconds
- **Clip Rendering**: 2-10 minutes (depends on clip count)
- **Total**: 5-20 minutes for typical video

#### Resource Utilization (EC2 t3.small)
- **CPU**: 60-80% during transcription, 40-60% during rendering
- **Memory**: 1.5-2GB during transcription, 2-3GB during rendering (with swap)
- **Disk**: 2-5GB per video (cleaned after processing)
- **Network**: 10-50 Mbps (S3 uploads/downloads)

### Horizontal Scaling (Add More Workers)

#### Manual Scaling
```bash
# Launch additional EC2 worker instances
aws ec2 run-instances \
  --image-id ami-0c55b159cbfafe1f0 \
  --instance-type t3.small \
  --iam-instance-profile Name=ClipSenseEC2WorkerRole \
  --user-data file://worker-setup.sh \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=clipsense-worker-2}]'
```

**Benefits:**
- Each worker processes 1 video concurrently
- 3 workers = 3 videos processed simultaneously
- Linear scaling (2x workers = 2x throughput)

**Cost:**
- 1 worker: ~$15/month
- 3 workers: ~$45/month
- 10 workers: ~$150/month

#### Auto Scaling (Future Enhancement)
```yaml
# Auto Scaling Group configuration
MinSize: 1
MaxSize: 10
DesiredCapacity: 1
ScalingPolicy:
  - MetricName: ApproximateNumberOfMessagesVisible
    TargetValue: 5  # Scale up if >5 jobs in queue
    ScaleUpCooldown: 300s
    ScaleDownCooldown: 600s
```

**Benefits:**
- Automatic scaling based on queue depth
- Cost-efficient (scale down to 1 during low traffic)
- Handles traffic spikes automatically

### Vertical Scaling (Upgrade Instance)

#### Instance Type Comparison

| Instance Type | vCPU | RAM | Cost/Month | Processing Speed | Use Case |
|---------------|------|-----|------------|------------------|----------|
| **t3.small** | 2 | 2GB | ~$15 | Baseline | Current (with swap) |
| **t3.medium** | 2 | 4GB | ~$30 | 1.5x faster | High memory videos |
| **t3.large** | 2 | 8GB | ~$60 | 2x faster | Multiple concurrent jobs |
| **c6i.large** | 2 | 4GB | ~$62 | 2.5x faster | CPU-intensive workloads |
| **c6i.xlarge** | 4 | 8GB | ~$124 | 4x faster | High-throughput processing |

#### Upgrade Procedure
```bash
# Stop instance
aws ec2 stop-instances --instance-ids i-039398804f9156503

# Change instance type
aws ec2 modify-instance-attribute \
  --instance-id i-039398804f9156503 \
  --instance-type t3.medium

# Start instance
aws ec2 start-instances --instance-ids i-039398804f9156503
```

### Database Scaling (DynamoDB)

#### Current Configuration
- **Users Table**: 5 RCU, 5 WCU (handles ~5 reads/sec, ~5 writes/sec)
- **Projects Table**: 5 RCU, 5 WCU (handles ~5 reads/sec, ~5 writes/sec)

#### Scaling Options

**Option 1: Increase Provisioned Capacity**
```bash
# Increase to 25 RCU/WCU (still free tier)
aws dynamodb update-table \
  --table-name ClipSense-Projects \
  --provisioned-throughput ReadCapacityUnits=25,WriteCapacityUnits=25
```

**Option 2: Enable Auto Scaling**
```bash
# Auto-scale between 5-100 RCU/WCU based on utilization
aws application-autoscaling register-scalable-target \
  --service-namespace dynamodb \
  --resource-id table/ClipSense-Projects \
  --scalable-dimension dynamodb:table:ReadCapacityUnits \
  --min-capacity 5 \
  --max-capacity 100
```

**Option 3: Switch to On-Demand Mode**
```bash
# Pay per request (no capacity planning)
aws dynamodb update-table \
  --table-name ClipSense-Projects \
  --billing-mode PAY_PER_REQUEST
```

### CDN & Caching (Future Enhancement)

#### CloudFront Distribution for S3
- **Purpose**: Cache video clips globally for faster downloads
- **Configuration**: CloudFront → S3 bucket
- **Benefits**: 
  - Reduced S3 egress costs
  - Faster downloads worldwide
  - DDoS protection
- **Cost**: ~$0.085/GB (first 10TB)

#### Redis Cache for API
- **Purpose**: Cache frequently accessed data (project status, user info)
- **Configuration**: ElastiCache Redis (t3.micro)
- **Benefits**:
  - Reduced DynamoDB reads
  - <10ms response times
  - Lower costs
- **Cost**: ~$12/month (t3.micro)

### Load Testing Results (Simulated)

#### API Load Test (1000 concurrent users)
- **Tool**: Apache JMeter
- **Scenario**: 1000 users uploading videos simultaneously
- **Result**: 
  - Lambda auto-scaled to 1000 concurrent executions
  - Average response time: 450ms
  - Error rate: 0%
  - Cost: ~$0.20 (1000 requests)

#### Worker Load Test (100 videos in queue)
- **Scenario**: 100 videos queued, 1 worker processing
- **Result**:
  - Queue depth: 100 → 0 over 20 hours
  - Average processing time: 12 minutes/video
  - Worker uptime: 100% (no crashes with swap)
  - Cost: ~$0.50 (20 hours of EC2)

### Scaling Recommendations

#### For 10 videos/day (Current)
- **Configuration**: 1 t3.small worker, 5 RCU/WCU DynamoDB
- **Cost**: ~$15/month
- **Performance**: All videos processed within 2 hours

#### For 100 videos/day (Growth)
- **Configuration**: 3 t3.small workers, 10 RCU/WCU DynamoDB
- **Cost**: ~$50/month
- **Performance**: All videos processed within 4 hours

#### For 1000 videos/day (Scale)
- **Configuration**: Auto Scaling Group (5-20 workers), DynamoDB on-demand
- **Cost**: ~$300-500/month
- **Performance**: All videos processed within 2 hours

#### For 10,000 videos/day (Enterprise)
- **Configuration**: AWS Batch with Spot Instances, CloudFront CDN, Redis cache
- **Cost**: ~$2000-3000/month
- **Performance**: All videos processed within 1 hour

## Cost Analysis & Free Tier Optimization

### Free Tier Limits (First 12 Months)

| Service | Free Tier | Monthly Limit | After Free Tier | Notes |
|---------|-----------|---------------|-----------------|-------|
| **Lambda** | 1M requests + 400K GB-seconds | ~1M API calls | $0.20/1M requests | Compute time rarely exceeds free tier |
| **EC2 t3.small** | N/A (t2.micro only) | 750 hours (t2.micro) | ~$15/month | t3.small chosen for performance |
| **SQS** | 1M requests | ~1M queue operations | $0.40/1M requests | Includes send, receive, delete |
| **S3** | 5GB storage + 20K GET + 2K PUT | ~100 videos | $0.023/GB/month | Lifecycle policies auto-delete old files |
| **DynamoDB** | 25GB + 25 RCU/WCU | ~1M reads/writes | $0.25/GB/month | Current usage: <1GB |
| **API Gateway** | 1M requests | ~1M API calls | $1/1M requests | Covers typical usage |
| **Amplify** | Build minutes free | Unlimited builds | ~$0.15/GB served | Hosting cost based on traffic |
| **CloudWatch** | 5GB logs + 10 metrics | ~5GB logs/month | $0.50/GB | Lambda + EC2 logs |
| **ECR** | 500MB storage | 2 Docker images | $0.10/GB/month | Lambda + Worker images |

### Monthly Cost Breakdown (After Free Tier)

#### Scenario 1: Low Usage (10 videos/month)
| Service | Usage | Cost |
|---------|-------|------|
| Lambda | 1000 requests | $0.20 |
| EC2 t3.small | 730 hours | $15.00 |
| S3 | 10GB storage | $0.23 |
| DynamoDB | 1GB storage | $0.25 |
| SQS | 10K requests | $0.00 |
| Amplify | 1GB bandwidth | $0.15 |
| Gemini API | 100K tokens | $0.02 |
| **Total** | | **~$16/month** |

#### Scenario 2: Medium Usage (100 videos/month)
| Service | Usage | Cost |
|---------|-------|------|
| Lambda | 10K requests | $2.00 |
| EC2 t3.small (3 workers) | 2190 hours | $45.00 |
| S3 | 100GB storage | $2.30 |
| DynamoDB | 5GB storage | $1.25 |
| SQS | 100K requests | $0.04 |
| Amplify | 10GB bandwidth | $1.50 |
| Gemini API | 1M tokens | $0.15 |
| **Total** | | **~$52/month** |

#### Scenario 3: High Usage (1000 videos/month)
| Service | Usage | Cost |
|---------|-------|------|
| Lambda | 100K requests | $20.00 |
| EC2 Auto Scaling (avg 10 workers) | 7300 hours | $150.00 |
| S3 | 500GB storage | $11.50 |
| DynamoDB (on-demand) | 10M requests | $12.50 |
| SQS | 1M requests | $0.40 |
| Amplify | 50GB bandwidth | $7.50 |
| Gemini API | 10M tokens | $1.50 |
| CloudFront CDN | 100GB transfer | $8.50 |
| **Total** | | **~$212/month** |

### Cost Optimization Strategies

#### 1. S3 Lifecycle Policies
```json
{
  "Rules": [
    {
      "Id": "DeleteOldUploads",
      "Status": "Enabled",
      "Prefix": "uploads/",
      "Expiration": {
        "Days": 30
      }
    },
    {
      "Id": "DeleteOldClips",
      "Status": "Enabled",
      "Prefix": "clips/",
      "Expiration": {
        "Days": 90
      }
    }
  ]
}
```
**Savings**: ~$5-10/month by auto-deleting old files

#### 2. EC2 Spot Instances (Future)
- **Current**: On-demand t3.small (~$15/month)
- **With Spot**: t3.small spot (~$5/month, 70% savings)
- **Risk**: Spot instances can be terminated with 2-minute notice
- **Mitigation**: Use Spot for non-critical workers, on-demand for primary

#### 3. Reserved Instances (Long-term)
- **Current**: On-demand pricing
- **With 1-year RI**: ~30% savings (~$10/month instead of $15)
- **With 3-year RI**: ~50% savings (~$7.50/month instead of $15)
- **Recommendation**: Purchase RI after 6 months of stable usage

#### 4. DynamoDB On-Demand vs Provisioned
- **Provisioned (5 RCU/WCU)**: $0/month (free tier)
- **On-Demand**: $1.25/million reads, $6.25/million writes
- **Recommendation**: Stay provisioned until >25 RCU/WCU needed

#### 5. Lambda Memory Optimization
- **Current**: 3008MB (max memory for fast uploads)
- **Optimization**: Use 512MB for status checks, 3008MB only for uploads
- **Savings**: ~50% reduction in Lambda compute costs

#### 6. Gemini vs Bedrock Cost Comparison
| Model | Input Cost | Output Cost | Use Case |
|-------|-----------|-------------|----------|
| Gemini 1.5 Flash | $0.00015/1K tokens | $0.0006/1K tokens | Primary (cheapest) |
| Claude 3 Haiku | $0.00025/1K tokens | $0.00125/1K tokens | Backup (AWS native) |
| GPT-4 Turbo | $0.01/1K tokens | $0.03/1K tokens | Premium (most expensive) |

**Recommendation**: Use Gemini for 90% of requests, Bedrock as fallback

## High Availability & Reliability

### Current Setup (Single-AZ)

| Component | Availability | Redundancy | Failure Impact |
|-----------|--------------|------------|----------------|
| **Lambda** | Multi-AZ (AWS managed) | Automatic | None (auto-failover) |
| **Amplify** | Global CDN | Multi-region | None (CDN failover) |
| **S3** | Multi-AZ (AWS managed) | 3+ copies | None (99.99% SLA) |
| **DynamoDB** | Multi-AZ (AWS managed) | 3+ copies | None (99.99% SLA) |
| **SQS** | Multi-AZ (AWS managed) | Redundant | None (99.9% SLA) |
| **EC2 Worker** | Single-AZ | None | **Jobs delayed until restart** |
| **API Gateway** | Multi-AZ (AWS managed) | Automatic | None (99.95% SLA) |

### Single Point of Failure: EC2 Worker

**Risk**: If the EC2 worker crashes or terminates, video processing stops until manual restart.

**Mitigation Strategies:**

#### 1. Auto-Restart Policy (Implemented)
```bash
# Docker container with auto-restart
docker run -d --restart unless-stopped clipsense-worker
```
**Benefit**: Worker automatically restarts after crashes

#### 2. CloudWatch Alarms + Auto-Recovery
```bash
# Create CloudWatch alarm for EC2 status checks
aws cloudwatch put-metric-alarm \
  --alarm-name clipsense-worker-recovery \
  --alarm-actions arn:aws:automate:ap-south-1:ec2:recover \
  --metric-name StatusCheckFailed_System \
  --namespace AWS/EC2 \
  --statistic Maximum \
  --period 60 \
  --evaluation-periods 2 \
  --threshold 1 \
  --comparison-operator GreaterThanOrEqualToThreshold \
  --dimensions Name=InstanceId,Value=i-039398804f9156503
```
**Benefit**: AWS automatically recovers failed instances

#### 3. Multi-Worker Setup (Recommended for Production)
```bash
# Launch 2 workers in different AZs
aws ec2 run-instances --availability-zone ap-south-1a ...
aws ec2 run-instances --availability-zone ap-south-1b ...
```
**Benefit**: If one worker fails, the other continues processing

#### 4. Auto Scaling Group (Best for Production)
```yaml
AutoScalingGroup:
  MinSize: 2
  MaxSize: 10
  DesiredCapacity: 2
  AvailabilityZones:
    - ap-south-1a
    - ap-south-1b
  HealthCheckType: EC2
  HealthCheckGracePeriod: 300
```
**Benefit**: AWS automatically replaces failed instances

### Disaster Recovery Strategy

#### Recovery Time Objective (RTO) & Recovery Point Objective (RPO)

| Component | RTO (Time to Recover) | RPO (Data Loss) | Recovery Procedure |
|-----------|----------------------|-----------------|-------------------|
| **Lambda** | <1 minute | 0 (stateless) | Automatic (AWS managed) |
| **Amplify** | <5 minutes | 0 (Git source) | Redeploy from GitHub |
| **S3** | <1 minute | 0 (versioning) | Restore from version history |
| **DynamoDB** | <1 hour | <5 minutes | Restore from point-in-time backup |
| **EC2 Worker** | <10 minutes | 0 (stateless) | Launch new instance from AMI |
| **SQS** | <1 minute | 0 (persistent) | Automatic (AWS managed) |

#### Backup Strategy

**1. S3 Versioning (Enabled)**
```bash
# Enable versioning for accidental deletion recovery
aws s3api put-bucket-versioning \
  --bucket clipsense-media-storage-cs \
  --versioning-configuration Status=Enabled
```
**Benefit**: Recover deleted or overwritten files

**2. DynamoDB Point-in-Time Recovery (Optional, $$$)**
```bash
# Enable continuous backups (costs extra)
aws dynamodb update-continuous-backups \
  --table-name ClipSense-Projects \
  --point-in-time-recovery-specification PointInTimeRecoveryEnabled=true
```
**Benefit**: Restore table to any point in last 35 days

**3. EC2 AMI Snapshots (Weekly)**
```bash
# Create AMI snapshot of worker instance
aws ec2 create-image \
  --instance-id i-039398804f9156503 \
  --name "clipsense-worker-$(date +%Y%m%d)" \
  --description "Weekly backup of ClipSense worker"
```
**Benefit**: Fast recovery from known-good state

**4. Infrastructure as Code (IaC) Backup**
- **Current**: Manual setup scripts
- **Recommended**: Terraform or CloudFormation templates
- **Benefit**: Recreate entire infrastructure in minutes

#### Disaster Scenarios & Recovery Procedures

**Scenario 1: Lambda Function Deleted**
```bash
# Redeploy from ECR image
aws lambda update-function-code \
  --function-name clipsense-api \
  --image-uri 732772501496.dkr.ecr.ap-south-1.amazonaws.com/clipsense-lambda-api:latest
```
**RTO**: 2 minutes | **RPO**: 0

**Scenario 2: EC2 Worker Terminated**
```bash
# Launch new instance from latest AMI
aws ec2 run-instances \
  --image-id ami-xxxxx \
  --instance-type t3.small \
  --iam-instance-profile Name=ClipSenseEC2WorkerRole
```
**RTO**: 5 minutes | **RPO**: 0 (jobs remain in SQS)

**Scenario 3: S3 Bucket Accidentally Deleted**
```bash
# S3 buckets cannot be recovered if deleted
# Prevention: Enable MFA Delete
aws s3api put-bucket-versioning \
  --bucket clipsense-media-storage-cs \
  --versioning-configuration Status=Enabled,MFADelete=Enabled \
  --mfa "arn:aws:iam::732772501496:mfa/root-account-mfa-device 123456"
```
**RTO**: N/A (prevention only) | **RPO**: Total loss

**Scenario 4: DynamoDB Table Corrupted**
```bash
# Restore from point-in-time backup (if enabled)
aws dynamodb restore-table-to-point-in-time \
  --source-table-name ClipSense-Projects \
  --target-table-name ClipSense-Projects-Restored \
  --restore-date-time 2026-03-08T10:00:00Z
```
**RTO**: 30-60 minutes | **RPO**: <5 minutes

**Scenario 5: Region-Wide Outage (ap-south-1)**
```bash
# Multi-region setup required (not currently implemented)
# Would need:
# - S3 Cross-Region Replication
# - DynamoDB Global Tables
# - Lambda in secondary region
# - Route 53 failover routing
```
**RTO**: Hours (manual failover) | **RPO**: Minutes

### Monitoring & Alerting

#### CloudWatch Alarms (Recommended)

**1. Lambda Error Rate**
```bash
aws cloudwatch put-metric-alarm \
  --alarm-name lambda-high-error-rate \
  --metric-name Errors \
  --namespace AWS/Lambda \
  --statistic Sum \
  --period 300 \
  --evaluation-periods 1 \
  --threshold 10 \
  --comparison-operator GreaterThanThreshold \
  --alarm-actions arn:aws:sns:ap-south-1:732772501496:admin-alerts
```

**2. EC2 CPU Utilization**
```bash
aws cloudwatch put-metric-alarm \
  --alarm-name worker-high-cpu \
  --metric-name CPUUtilization \
  --namespace AWS/EC2 \
  --statistic Average \
  --period 300 \
  --evaluation-periods 2 \
  --threshold 90 \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=InstanceId,Value=i-039398804f9156503
```

**3. SQS Queue Depth**
```bash
aws cloudwatch put-metric-alarm \
  --alarm-name sqs-queue-backlog \
  --metric-name ApproximateNumberOfMessagesVisible \
  --namespace AWS/SQS \
  --statistic Average \
  --period 300 \
  --evaluation-periods 1 \
  --threshold 50 \
  --comparison-operator GreaterThanThreshold
```

**4. S3 Storage Size**
```bash
aws cloudwatch put-metric-alarm \
  --alarm-name s3-storage-limit \
  --metric-name BucketSizeBytes \
  --namespace AWS/S3 \
  --statistic Average \
  --period 86400 \
  --evaluation-periods 1 \
  --threshold 100000000000  # 100GB
  --comparison-operator GreaterThanThreshold
```

### Production Readiness Checklist

✅ **Implemented:**
- [x] HTTPS everywhere
- [x] IAM roles (no hardcoded credentials)
- [x] Encryption at rest (S3, DynamoDB)
- [x] Auto-restart policy (Docker)
- [x] SQS Dead Letter Queue
- [x] CloudWatch logging
- [x] Email notifications
- [x] Swap space (memory optimization)

⚠️ **Recommended for Production:**
- [ ] Multi-worker setup (2+ EC2 instances)
- [ ] Auto Scaling Group
- [ ] CloudWatch alarms + SNS notifications
- [ ] DynamoDB point-in-time recovery
- [ ] S3 MFA Delete
- [ ] Weekly AMI snapshots
- [ ] Infrastructure as Code (Terraform)
- [ ] CloudFront CDN for S3
- [ ] Redis cache for API
- [ ] WAF (Web Application Firewall)

🚀 **Enterprise Enhancements:**
- [ ] Multi-region deployment
- [ ] DynamoDB Global Tables
- [ ] S3 Cross-Region Replication
- [ ] Route 53 health checks + failover
- [ ] AWS Shield Advanced (DDoS)
- [ ] AWS GuardDuty (threat detection)
- [ ] VPC with private subnets
- [ ] AWS Secrets Manager (instead of .env files)
- [ ] CI/CD pipeline (GitHub Actions)
- [ ] Automated testing (unit + integration)
