# ClipSense Cloud Architecture

## System Overview

ClipSense uses a hybrid AWS architecture optimized for the free tier, combining serverless and compute services to handle video processing at scale.

## Architecture Diagram

```
┌─────────────┐
│   Browser   │
└──────┬──────┘
       │ HTTPS
       ▼
┌─────────────────────────────────────────────────────────────┐
│                        AWS Cloud                             │
│                                                              │
│  ┌──────────────┐                                           │
│  │   Amplify    │  Next.js Frontend                         │
│  │   Hosting    │  (SSR + Static)                           │
│  └──────┬───────┘                                           │
│         │ API Calls                                          │
│         ▼                                                    │
│  ┌──────────────┐      ┌─────────────┐                     │
│  │ API Gateway  │─────▶│   Lambda    │  Flask API          │
│  │   (HTTPS)    │      │  (512MB)    │  Auth, Upload       │
│  └──────────────┘      └──────┬──────┘                     │
│                               │                              │
│                               │ Send Job                     │
│                               ▼                              │
│                        ┌──────────────┐                     │
│                        │  SQS Queue   │                     │
│                        └──────┬───────┘                     │
│                               │                              │
│                               │ Poll Jobs                    │
│                               ▼                              │
│                        ┌──────────────┐                     │
│                        │ EC2 t2.micro │  Video Worker       │
│                        │   (1GB RAM)  │  ML Processing      │
│                        └──────┬───────┘                     │
│                               │                              │
│         ┌─────────────────────┼─────────────────┐          │
│         ▼                     ▼                 ▼           │
│  ┌──────────┐          ┌──────────┐     ┌──────────┐      │
│  │    S3    │          │ DynamoDB │     │ Bedrock  │      │
│  │  Bucket  │          │  Tables  │     │Transcribe│      │
│  └──────────┘          └──────────┘     │Rekognition│     │
│                                          └──────────┘      │
└─────────────────────────────────────────────────────────────┘
```

## Data Flow

### Upload Flow

1. User uploads video via Amplify frontend
2. Frontend sends file to API Gateway → Lambda
3. Lambda saves video to S3 (`uploads/` prefix)
4. Lambda creates project record in DynamoDB
5. Lambda sends processing job to SQS queue
6. Lambda returns immediately (no waiting for processing)

### Processing Flow

1. EC2 worker polls SQS queue every 5 seconds
2. Worker receives processing job message
3. Worker downloads video from S3
4. Worker runs ML pipeline:
   - Transcription (AWS Transcribe or Whisper)
   - Emotion analysis (AI models)
   - Visual analysis (AWS Rekognition)
   - AI clip selection (AWS Bedrock)
   - Clip rendering (moviepy)
5. Worker uploads clips to S3 (`clips/` prefix)
6. Worker updates project status in DynamoDB
7. Worker deletes SQS message
8. Worker sends completion email to user

### Download Flow

1. User requests clip download via frontend
2. Frontend calls API Gateway → Lambda
3. Lambda generates presigned S3 URL (valid 1 hour)
4. Lambda returns presigned URL
5. Browser downloads directly from S3

## AWS Services Used

### Lambda (Free Tier: 1M requests/month)
- **Purpose**: API endpoints (auth, upload, status)
- **Configuration**: 512MB memory, 30s timeout
- **Cost**: FREE for typical usage
- **Scaling**: Automatic, handles 1000s of concurrent users

### EC2 t2.micro (Free Tier: 750 hours/month for 12 months)
- **Purpose**: Video processing worker
- **Configuration**: 1 vCPU, 1GB RAM, Amazon Linux 2023
- **Cost**: FREE for 12 months, then ~$8/month
- **Scaling**: Manual (add more instances if needed)

### SQS (Free Tier: 1M requests/month)
- **Purpose**: Job queue between Lambda and EC2
- **Configuration**: Standard queue, 1-hour visibility timeout
- **Cost**: FREE for typical usage

### S3 (Free Tier: 5GB storage, 20K GET, 2K PUT)
- **Purpose**: Video and clip storage
- **Configuration**: Private bucket, AES-256 encryption
- **Cost**: FREE for low usage, ~$0.023/GB/month after

### DynamoDB (Free Tier: 25GB, 25 RCU/WCU)
- **Purpose**: User and project metadata
- **Configuration**: 5 RCU/WCU per table
- **Cost**: FREE for typical usage

### API Gateway (Free Tier: 1M requests/month for 12 months)
- **Purpose**: HTTPS endpoint for Lambda
- **Cost**: FREE for 12 months, then ~$1/million requests

### Amplify (Build minutes free, hosting ~$0.15/GB)
- **Purpose**: Frontend hosting with CI/CD
- **Cost**: ~$1-5/month for low traffic

### Bedrock, Transcribe, Rekognition (Pay per use)
- **Purpose**: AI services for video analysis
- **Cost**: Variable based on usage

## Security Model

### Authentication
- JWT tokens for API authentication
- Tokens stored in browser localStorage
- 24-hour token expiration

### Authorization
- Role-based access control (creator, admin)
- User can only access their own projects
- Admin can access all projects

### Network Security
- All traffic over HTTPS
- S3 bucket blocks public access
- EC2 security group allows only SSH (port 22)
- API Gateway provides DDoS protection

### Secrets Management
- Lambda: Environment variables (encrypted at rest)
- EC2: `/etc/clipsense/.env` file (chmod 600)
- IAM roles for AWS service access (no hardcoded credentials)

### Data Security
- S3 server-side encryption (AES-256)
- DynamoDB encryption at rest (default)
- Presigned URLs expire after 1 hour

## Scalability

### Current Capacity
- Lambda: Handles 1000s of concurrent API requests
- EC2: Processes 1 video at a time
- SQS: Unlimited queue depth

### Scaling Strategy

**Horizontal Scaling** (add more workers):
```bash
# Launch additional EC2 instances
./setup-ec2.sh  # Creates another worker
```

**Vertical Scaling** (upgrade instance):
```bash
# Stop current instance
aws ec2 stop-instances --instance-ids <instance-id>

# Change instance type
aws ec2 modify-instance-attribute \
  --instance-id <instance-id> \
  --instance-type t2.small

# Start instance
aws ec2 start-instances --instance-ids <instance-id>
```

**Auto Scaling** (future enhancement):
- Use AWS Batch for automatic worker scaling
- Use CloudWatch metrics to trigger scaling
- Use ECS/Fargate for containerized workers

## Free Tier Limits

| Service | Free Tier | After Free Tier |
|---------|-----------|-----------------|
| Lambda | 1M requests/month | $0.20/1M requests |
| EC2 t2.micro | 750 hours/month (12 months) | ~$8/month |
| SQS | 1M requests/month | $0.40/1M requests |
| S3 | 5GB storage, 20K GET, 2K PUT | $0.023/GB/month |
| DynamoDB | 25GB, 25 RCU/WCU | $0.25/GB/month |
| API Gateway | 1M requests/month (12 months) | $1/1M requests |
| Amplify | Build minutes free | ~$0.15/GB served |

**Estimated monthly cost after free tier**: $10-20 for moderate usage

## High Availability

### Current Setup
- Lambda: Multi-AZ by default
- DynamoDB: Multi-AZ by default
- S3: 99.999999999% durability
- EC2: Single instance (single point of failure)

### Improvements for Production
- Deploy multiple EC2 workers across AZs
- Use Auto Scaling Group for workers
- Enable DynamoDB point-in-time recovery
- Enable S3 versioning for critical data
- Add CloudWatch alarms for failures
- Implement dead-letter queue for failed jobs

## Disaster Recovery

### Backup Strategy
- S3: Enable versioning for video/clip recovery
- DynamoDB: Enable point-in-time recovery (costs extra)
- EC2: Create AMI snapshots periodically

### Recovery Procedures
- Lambda: Redeploy from ECR image
- EC2: Launch new instance from AMI or user data script
- Data: Restore from S3 versions or DynamoDB backups
