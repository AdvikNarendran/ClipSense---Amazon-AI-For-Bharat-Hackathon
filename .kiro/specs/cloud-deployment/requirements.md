# Requirements Document

## Introduction

ClipSense is a full-stack video processing application that analyzes videos to generate clips based on attention curves, emotions, and AI-driven insights. The application consists of a Flask API backend, a video processing worker with heavy ML dependencies (torch, whisper, mediapipe, moviepy), and a Next.js frontend. This feature enables complete cloud deployment using a hybrid architecture: Lambda for API endpoints (scalable), EC2 for video processing (no timeout limits), and Amplify for frontend hosting. The backend already integrates with AWS services (S3, DynamoDB, Bedrock, Transcribe, Rekognition).

## Glossary

- **Backend_API**: The Lambda function running Flask API endpoints (auth, upload, status)
- **Video_Worker**: The EC2 t2.micro instance that processes videos from SQS queue
- **Frontend_Service**: The Next.js web application hosted on AWS Amplify
- **SQS_Queue**: AWS Simple Queue Service queue for video processing jobs
- **Container_Registry**: AWS Elastic Container Registry (ECR) for storing Lambda Docker image
- **API_Gateway**: AWS API Gateway providing HTTPS endpoint for Lambda function
- **Storage_Service**: AWS S3 bucket for storing uploaded videos and generated clips (already configured)
- **Database_Service**: AWS DynamoDB tables for users and projects (already configured)
- **Environment_Configuration**: Environment variables and secrets for Lambda and EC2
- **Deployment_Pipeline**: GitHub Actions workflows for deploying Lambda, EC2 worker, and frontend
- **Health_Endpoint**: API endpoint that reports service health status
- **Processing_Job**: SQS message containing video processing instructions

## Requirements

### Requirement 1: Backend Lambda API Deployment

**User Story:** As a DevOps engineer, I want to deploy the Flask API as a Lambda function, so that the application can handle unlimited concurrent users without managing servers

#### Acceptance Criteria

1. THE Backend_API SHALL run as an AWS Lambda function with container image
2. THE Backend_API SHALL use Lambda Web Adapter to run Flask application
3. THE Backend_API SHALL handle authentication, upload, project management, and status endpoints
4. THE Backend_API SHALL NOT include video processing logic or ML dependencies
5. WHEN a user uploads a video, THE Backend_API SHALL save to S3 and send a message to SQS_Queue
6. THE Backend_API SHALL have 512MB memory and 30-second timeout
7. THE Backend_API SHALL be accessible via API Gateway HTTPS endpoint
8. THE Backend_API SHALL scale automatically to handle concurrent requests

### Requirement 2: Frontend Amplify Deployment

**User Story:** As a DevOps engineer, I want to deploy the Next.js frontend on AWS Amplify, so that users can access the web interface with automatic CI/CD

#### Acceptance Criteria

1. THE Frontend_Service SHALL be deployed on AWS Amplify with automatic git integration
2. THE Frontend_Service SHALL be built using "npm run build" on each git push
3. THE Frontend_Service SHALL be served over HTTPS via Amplify's CDN
4. WHEN a user requests the root URL, THE Frontend_Service SHALL return the application within 2 seconds
5. THE Frontend_Service SHALL configure NEXT_PUBLIC_API_URL to point to the API_Gateway endpoint
6. THE Frontend_Service SHALL support client-side routing for Next.js pages
7. THE Frontend_Service SHALL cache static assets with appropriate cache headers

### Requirement 3: Video Processing Worker Deployment

**User Story:** As a DevOps engineer, I want to deploy a dedicated EC2 worker for video processing, so that long-running jobs don't timeout and can process videos of any length

#### Acceptance Criteria

1. THE Video_Worker SHALL run on an EC2 t2.micro instance
2. THE Video_Worker SHALL poll SQS_Queue for processing jobs every 5 seconds
3. WHEN a Processing_Job is received, THE Video_Worker SHALL download the video from S3
4. THE Video_Worker SHALL run transcription, AI analysis, and clip rendering
5. THE Video_Worker SHALL upload generated clips to S3
6. THE Video_Worker SHALL update project status in DynamoDB throughout processing
7. WHEN processing completes, THE Video_Worker SHALL delete the message from SQS_Queue
8. THE Video_Worker SHALL continue running indefinitely and process jobs sequentially

### Requirement 4: SQS Queue Configuration

**User Story:** As a backend developer, I want an SQS queue to decouple API requests from video processing, so that the system is reliable and scalable

#### Acceptance Criteria

1. THE SQS_Queue SHALL be created with name "clipsense-processing-queue"
2. WHEN Backend_API receives a processing request, THE Backend_API SHALL send a Processing_Job message to SQS_Queue
3. THE Processing_Job message SHALL include projectId, userId, s3Uri, and processing settings
4. THE SQS_Queue SHALL have a visibility timeout of 3600 seconds (1 hour)
5. THE SQS_Queue SHALL retain messages for 4 days if not processed
6. THE Video_Worker SHALL poll SQS_Queue using long polling (20-second wait time)
7. WHEN Video_Worker completes processing, THE Video_Worker SHALL delete the message from SQS_Queue

### Requirement 5: Storage and Database Verification

**User Story:** As a backend developer, I want to verify S3 and DynamoDB are properly configured, so that the application works correctly in production

#### Acceptance Criteria

1. THE Storage_Service SHALL have separate prefixes for uploads/ and clips/
2. THE Backend_API SHALL successfully upload video files to Storage_Service
3. WHEN a video file is uploaded, THE Storage_Service SHALL generate a presigned URL valid for 3600 seconds
4. THE Storage_Service SHALL configure CORS to allow requests from Amplify domain
5. THE Database_Service SHALL have ClipSenseUsers and ClipSenseProjects tables created
6. THE ClipSenseUsers table SHALL use email as the primary key
7. THE ClipSenseProjects table SHALL use projectId as the primary key

### Requirement 6: Environment Configuration Management

**User Story:** As a DevOps engineer, I want environment variables and secrets managed securely, so that sensitive credentials are not exposed

#### Acceptance Criteria

1. THE Backend_API SHALL store secrets as Lambda environment variables (encrypted by AWS)
2. THE Video_Worker SHALL load secrets from /etc/clipsense/.env file
3. THE /etc/clipsense/.env file SHALL have permissions set to 600 (owner read/write only)
4. THE Frontend_Service SHALL access only NEXT_PUBLIC_* environment variables during build
5. THE deployment scripts SHALL NOT contain hardcoded secrets or credentials
6. THE Lambda function SHALL use an IAM role for AWS service access
7. THE EC2 instance SHALL use an IAM role for AWS service access

### Requirement 7: Infrastructure Setup Scripts

**User Story:** As a DevOps engineer, I want shell scripts to provision AWS resources, so that deployment can be done quickly and consistently

#### Acceptance Criteria

1. THE setup scripts SHALL create an SQS queue named "clipsense-processing-queue"
2. THE setup scripts SHALL create an ECR repository for Lambda container images
3. THE setup scripts SHALL create a Lambda function with container image from ECR
4. THE setup scripts SHALL create an API Gateway HTTP API connected to the Lambda function
5. THE setup scripts SHALL create an EC2 t2.micro instance with Amazon Linux 2023
6. THE setup scripts SHALL create IAM roles for Lambda and EC2 with appropriate permissions
7. THE setup scripts SHALL configure EC2 security group with only port 22 open (SSH)
8. THE setup scripts SHALL output the API Gateway URL and EC2 public IP after completion

### Requirement 8: Deployment Pipeline Automation

**User Story:** As a developer, I want automated deployment via GitHub Actions, so that code changes can be deployed efficiently

#### Acceptance Criteria

1. THE Deployment_Pipeline SHALL build and push Lambda container image to ECR when backend code changes
2. THE Deployment_Pipeline SHALL update Lambda function with new image from ECR
3. THE Deployment_Pipeline SHALL SSH into EC2 and rebuild worker container when backend code changes
4. THE Deployment_Pipeline SHALL trigger Amplify deployment when frontend code changes
5. THE Deployment_Pipeline SHALL run health checks after Lambda deployment completes
6. IF health checks fail, THEN THE Deployment_Pipeline SHALL report deployment failure
7. THE Deployment_Pipeline SHALL complete Lambda deployment in under 5 minutes
8. THE Deployment_Pipeline SHALL complete worker deployment in under 3 minutes

### Requirement 9: Service Health Monitoring

**User Story:** As a DevOps engineer, I want health monitoring for deployed services, so that I can detect and respond to service failures

#### Acceptance Criteria

1. THE Backend_API SHALL expose a Health_Endpoint at /api/health (already implemented)
2. WHEN Health_Endpoint is called, THE Backend_API SHALL verify Database_Service connectivity
3. WHEN Health_Endpoint is called, THE Backend_API SHALL verify Storage_Service accessibility
4. THE Health_Endpoint SHALL return HTTP 200 with status "healthy" when all checks pass
5. IF any health check fails, THEN THE Health_Endpoint SHALL return HTTP 503 with error details
6. THE Video_Worker Docker container SHALL restart automatically if it crashes (using --restart unless-stopped)
7. THE deployment pipeline SHALL verify health endpoint after Lambda deployment

### Requirement 10: Network and Security Configuration

**User Story:** As a security engineer, I want proper network and security controls, so that the application is protected from unauthorized access

#### Acceptance Criteria

1. THE Frontend_Service SHALL serve all content over HTTPS via Amplify CDN
2. THE Backend_API SHALL be accessible only via API_Gateway HTTPS endpoint
3. THE Backend_API SHALL configure CORS headers to allow Amplify origin
4. THE Storage_Service SHALL block public access to all objects by default
5. THE Backend_API SHALL validate JWT tokens for authenticated endpoints (already implemented)
6. THE EC2 security group SHALL allow inbound traffic only on port 22 (SSH from specific IPs)
7. THE Lambda function and EC2 instance SHALL use IAM roles for AWS service access (no hardcoded credentials)
