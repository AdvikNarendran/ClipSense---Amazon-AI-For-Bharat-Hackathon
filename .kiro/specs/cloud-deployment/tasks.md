# Implementation Plan: Cloud Deployment

## Overview

This plan implements a hybrid AWS architecture for ClipSense: Lambda for API endpoints (scalable, free tier), EC2 t2.micro for video processing (no timeout limits), SQS for job queuing, and Amplify for frontend hosting. The backend code will be split into lightweight Lambda API and heavy ML worker, with separate Dockerfiles for each. Infrastructure setup scripts will provision all AWS resources, and GitHub Actions will automate deployments.

## Tasks

- [x] 1. Split backend code for Lambda and EC2 architectures
  - [x] 1.1 Create lambda_api.py with lightweight API endpoints only
    - Extract authentication endpoints (register, login, verify_otp, etc.)
    - Extract upload endpoint (save to S3, send SQS message)
    - Extract project management endpoints (list, get, delete)
    - Extract status and clip download endpoints (presigned URLs)
    - Remove all video processing logic and ML imports
    - _Requirements: 1.3, 1.4, 1.5_
  
  - [x] 1.2 Create worker.py for EC2 video processing
    - Implement SQS polling loop with 5-second intervals
    - Implement video processing job handler (download from S3, process, upload clips)
    - Integrate existing _run_processing logic from server.py
    - Update DynamoDB project status throughout processing
    - Delete SQS message after successful processing
    - _Requirements: 3.2, 3.3, 3.4, 3.5, 3.6, 3.7_
  
  - [x] 1.3 Create requirements-lambda.txt with minimal dependencies
    - Include only: Flask, boto3, PyJWT, flask-cors, pymongo (for DynamoDB fallback)
    - Exclude: torch, whisper, mediapipe, moviepy, opencv-python
    - _Requirements: 1.3_

- [x] 2. Create Docker configurations for Lambda and Worker
  - [x] 2.1 Create Dockerfile.lambda for Lambda deployment
    - Use python:3.11-slim base image
    - Copy Lambda Web Adapter from public.ecr.aws/awsguru/aws-lambda-adapter:0.8.3
    - Install requirements-lambda.txt dependencies
    - Copy lambda_api.py and utility files (db.py, aws_utils.py, email_utils.py)
    - Set PORT=5000 and CMD to run lambda_api.py
    - _Requirements: 1.1, 1.2_
  
  - [x] 2.2 Create Dockerfile.worker for EC2 deployment
    - Use python:3.11-slim base image
    - Install full requirements.txt (including ML dependencies)
    - Copy worker.py and utility files
    - Set CMD to run worker.py
    - _Requirements: 3.1_

- [ ] 3. Checkpoint - Verify code split and Docker builds
  - Ensure lambda_api.py and worker.py build successfully with their respective Dockerfiles, ask the user if questions arise.

- [x] 4. Create infrastructure setup scripts
  - [x] 4.1 Create setup-sqs.sh to provision SQS queue
    - Create queue named "clipsense-processing-queue"
    - Set visibility timeout to 3600 seconds
    - Set message retention to 4 days
    - Configure long polling with 20-second wait time
    - Output queue URL
    - _Requirements: 4.1, 4.4, 4.5_
  
  - [x] 4.2 Create setup-ecr.sh to provision ECR repository
    - Create repository named "clipsense-lambda-api"
    - Configure lifecycle policy to keep last 5 images
    - Output repository URI
    - _Requirements: 7.2_
  
  - [x] 4.3 Create setup-lambda.sh to provision Lambda function
    - Create IAM role with S3, DynamoDB, SQS send permissions
    - Create Lambda function with container image from ECR
    - Configure 512MB memory and 30-second timeout
    - Set environment variables (AWS_REGION, S3_BUCKET, DYNAMO tables, SQS_QUEUE_URL, secrets)
    - Output Lambda function ARN
    - _Requirements: 1.1, 1.6, 6.1, 6.6_
  
  - [x] 4.4 Create setup-api-gateway.sh to provision API Gateway
    - Create HTTP API Gateway
    - Create route: ANY /api/{proxy+}
    - Integrate with Lambda function (AWS_PROXY)
    - Configure CORS for Amplify origin
    - Output API Gateway URL
    - _Requirements: 1.7, 10.2, 10.3_
  
  - [x] 4.5 Create setup-ec2.sh to provision EC2 worker instance
    - Create IAM role with S3, DynamoDB, SQS receive/delete, Bedrock, Transcribe, Rekognition permissions
    - Create security group (port 22 SSH only)
    - Launch t2.micro instance with Amazon Linux 2023
    - Configure user data script to install Docker, clone repo, create /etc/clipsense/.env
    - Build and run worker container with --restart unless-stopped
    - Output EC2 public IP
    - _Requirements: 3.1, 6.2, 6.3, 6.7, 7.5, 7.7_
  
  - [x] 4.6 Create setup-dynamodb.sh to verify DynamoDB tables
    - Check if ClipSenseUsers table exists, create if missing
    - Check if ClipSenseProjects table exists, create if missing
    - Configure provisioned capacity (5 RCU, 5 WCU each)
    - _Requirements: 5.5, 5.6, 5.7_
  
  - [x] 4.7 Create setup-s3.sh to verify S3 bucket configuration
    - Check if bucket exists, create if missing
    - Configure CORS for Amplify domain
    - Enable server-side encryption (AES-256)
    - Block public access
    - _Requirements: 5.1, 5.4, 10.4_

- [ ] 5. Checkpoint - Verify infrastructure setup
  - Ensure all setup scripts run successfully and output expected resource identifiers, ask the user if questions arise.

- [x] 6. Create GitHub Actions workflows for CI/CD
  - [x] 6.1 Create .github/workflows/deploy-lambda.yml
    - Trigger on push to main with backend/** path filter
    - Build Dockerfile.lambda and push to ECR with git SHA and latest tags
    - Update Lambda function with new image
    - Wait for function update to complete
    - Run health check against API Gateway URL
    - Fail if health check returns non-200
    - _Requirements: 8.1, 8.2, 8.5, 8.6, 8.7, 9.7_
  
  - [x] 6.2 Create .github/workflows/deploy-worker.yml
    - Trigger on push to main with backend/** path filter
    - SSH into EC2 instance
    - Pull latest code from git
    - Rebuild worker container with Dockerfile.worker
    - Stop and remove old container
    - Start new container with --restart unless-stopped and --env-file /etc/clipsense/.env
    - Verify container is running with docker logs
    - _Requirements: 8.3, 8.8, 9.6_
  
  - [x] 6.3 Create .github/workflows/deploy-frontend.yml (optional)
    - Document that Amplify auto-deploys on push to main
    - Optionally add notification step
    - _Requirements: 8.4_

- [x] 7. Configure AWS Amplify for frontend deployment
  - [x] 7.1 Create amplify.yml build configuration
    - Configure build phase: cd frontend && npm ci && npm run build
    - Set artifacts baseDirectory to frontend/.next
    - Configure cache for node_modules
    - _Requirements: 2.1, 2.2_
  
  - [x] 7.2 Create frontend environment configuration documentation
    - Document NEXT_PUBLIC_API_URL (set to API Gateway URL)
    - Document NEXT_PUBLIC_AWS_REGION (ap-south-1)
    - Document NEXT_PUBLIC_S3_BUCKET
    - Note: These must be configured in Amplify Console
    - _Requirements: 2.5, 6.4_

- [x] 8. Create deployment documentation
  - [x] 8.1 Create DEPLOYMENT.md with setup instructions
    - Document prerequisites (AWS CLI, Docker, GitHub secrets)
    - Document step-by-step infrastructure setup (run all setup-*.sh scripts)
    - Document how to configure GitHub secrets (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, EC2_SSH_KEY, API_GATEWAY_URL)
    - Document how to configure Amplify (connect repo, set environment variables)
    - Document how to manually deploy Lambda (build, push to ECR, update function)
    - Document how to manually deploy worker (SSH, git pull, docker rebuild)
    - Document how to verify deployment (health checks, test upload)
    - _Requirements: 7.8, 10.3_
  
  - [x] 8.2 Create ARCHITECTURE.md with system overview
    - Document hybrid architecture diagram (Lambda API, EC2 Worker, SQS, Amplify)
    - Document data flow (upload → S3 → SQS → Worker → clips → S3)
    - Document AWS services used and their free tier limits
    - Document security model (IAM roles, HTTPS, CORS)
    - _Requirements: 10.3_

- [x] 9. Create helper scripts for local testing
  - [x] 9.1 Create scripts/test-lambda-local.sh
    - Build Dockerfile.lambda locally
    - Run container with test environment variables
    - Test health endpoint with curl
    - Test authentication endpoints
    - _Requirements: 9.1_
  
  - [x] 9.2 Create scripts/test-worker-local.sh
    - Build Dockerfile.worker locally
    - Run container with test environment variables
    - Send test SQS message
    - Verify worker processes message
    - _Requirements: 3.8_

- [ ] 10. Final checkpoint - End-to-end deployment verification
  - Ensure all components are deployed and integrated correctly, test complete upload-to-clip workflow, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- The backend split (Lambda vs Worker) is critical for the hybrid architecture
- Infrastructure scripts should be idempotent (safe to run multiple times)
- GitHub Actions workflows require secrets to be configured in repository settings
- Amplify deployment is automatic once connected to the repository
