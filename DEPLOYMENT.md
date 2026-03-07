# ClipSense Cloud Deployment Guide

This guide walks you through deploying ClipSense to AWS using a hybrid architecture: Lambda for API endpoints, EC2 for video processing, and Amplify for frontend hosting.

## Prerequisites

Before you begin, ensure you have:

1. **AWS CLI** installed and configured
   ```bash
   aws configure
   # Enter your AWS Access Key ID, Secret Access Key, and default region (ap-south-1)
   ```

2. **Docker** installed for building container images

3. **GitHub Account** with repository access

4. **Environment Variables in .env file**

   The PowerShell scripts will automatically load variables from `backend/.env`. Ensure your `.env` file contains:

   ```bash
   # Required variables (already in your .env)
   AWS_REGION=ap-south-1
   AWS_S3_BUCKET=clipsense-media-storage-cs
   GEMINI_API_KEY=your-gemini-api-key
   DYNAMO_USERS_TABLE=ClipSense-Users
   DYNAMO_PROJECTS_TABLE=ClipSense-Projects
   ADMIN_EMAIL=clipsense57@gmail.com
   
   # Additional variables needed for deployment
   JWT_SECRET_KEY=your-jwt-secret-key  # Will prompt if missing
   GITHUB_REPO=yourusername/clipsense  # Will prompt if missing
   EC2_KEY_NAME=clipsense-worker-key   # Will prompt if missing
   GOOGLE_CLIENT_ID=your-google-id     # Optional, will prompt
   ```

   **Note**: The scripts will prompt you for any missing required variables.

## Step-by-Step Infrastructure Setup

### 1. Create S3 Bucket

**Linux/Mac:**
```bash
cd backend
chmod +x setup-s3.sh
./setup-s3.sh
```

**Windows (PowerShell):**
```powershell
cd backend
.\setup-s3.ps1
```

This creates the S3 bucket for storing videos and clips with proper encryption and CORS configuration.

### 2. Create DynamoDB Tables

**Linux/Mac:**
```bash
chmod +x setup-dynamodb.sh
./setup-dynamodb.sh
```

**Windows (PowerShell):**
```powershell
.\setup-dynamodb.ps1
```

This creates the `ClipSenseUsers` and `ClipSenseProjects` tables.

### 3. Create SQS Queue

**Linux/Mac:**
```bash
chmod +x setup-sqs.sh
./setup-sqs.sh
```

**Windows (PowerShell):**
```powershell
.\setup-sqs.ps1
```

This creates the SQS queue for video processing jobs. Save the queue URL output.

### 4. Create ECR Repository

**Linux/Mac:**
```bash
chmod +x setup-ecr.sh
./setup-ecr.sh
```

**Windows (PowerShell):**
```powershell
.\setup-ecr.ps1
```

This creates the ECR repository for Lambda container images.

### 5. Build and Push Lambda Image

**Linux/Mac:**
```bash
# Login to ECR
aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.ap-south-1.amazonaws.com

# Build and push
docker build -f Dockerfile.lambda -t <account-id>.dkr.ecr.ap-south-1.amazonaws.com/clipsense-lambda-api:latest .
docker push <account-id>.dkr.ecr.ap-south-1.amazonaws.com/clipsense-lambda-api:latest
```

**Windows (PowerShell):**
```powershell
# Get your account ID
$ACCOUNT_ID = aws sts get-caller-identity --query Account --output text

# Login to ECR
aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin "$ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com"

# Build and push
docker build -f Dockerfile.lambda -t "$ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com/clipsense-lambda-api:latest" .
docker push "$ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com/clipsense-lambda-api:latest"
```

### 6. Create Lambda Function

**Linux/Mac:**
```bash
chmod +x setup-lambda.sh
./setup-lambda.sh
```

**Windows (PowerShell):**
```powershell
.\setup-lambda.ps1
```

This creates the Lambda function with the container image from ECR. Save the function ARN output.

### 7. Create API Gateway

**Linux/Mac:**
```bash
chmod +x setup-api-gateway.sh
./setup-api-gateway.sh
```

**Windows (PowerShell):**
```powershell
.\setup-api-gateway.ps1
```

This creates the API Gateway HTTP API and connects it to Lambda. Save the API endpoint URL.

### 8. Create EC2 Worker Instance

**Linux/Mac:**
```bash
chmod +x setup-ec2.sh
./setup-ec2.sh
```

**Windows (PowerShell):**
```powershell
.\setup-ec2.ps1
```

This launches the EC2 t2.micro instance with Docker and the worker container. Save the public IP.

**Note**: Make sure you have an EC2 key pair created before running this script. If not:

**Linux/Mac:**
```bash
aws ec2 create-key-pair --key-name clipsense-worker-key --query 'KeyMaterial' --output text > ~/.ssh/clipsense-worker-key.pem
chmod 400 ~/.ssh/clipsense-worker-key.pem
```

**Windows (PowerShell):**
```powershell
# Create .ssh directory if it doesn't exist
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.ssh"

# Create key pair and save
aws ec2 create-key-pair --key-name clipsense-worker-key --query 'KeyMaterial' --output text | Out-File -FilePath "$env:USERPROFILE\.ssh\clipsense-worker-key.pem" -Encoding ASCII -NoNewline
```

## Configure GitHub Secrets

Add these secrets to your GitHub repository (Settings → Secrets and variables → Actions):

```
AWS_ACCESS_KEY_ID=your-access-key-id
AWS_SECRET_ACCESS_KEY=your-secret-access-key
EC2_WORKER_HOST=<ec2-public-ip>
EC2_SSH_KEY=<contents-of-your-private-key>
API_GATEWAY_URL=https://xxxxxx.execute-api.ap-south-1.amazonaws.com
```

## Configure AWS Amplify

1. Go to AWS Amplify Console
2. Click "New app" → "Host web app"
3. Connect your GitHub repository
4. Select the main branch
5. Amplify will detect `amplify.yml` automatically
6. Add environment variables (see AMPLIFY_CONFIG.md):
   - `NEXT_PUBLIC_API_URL`
   - `NEXT_PUBLIC_AWS_REGION`
   - `NEXT_PUBLIC_S3_BUCKET`
7. Click "Save and deploy"

## Manual Deployment

### Deploy Lambda Manually

**Linux/Mac:**
```bash
cd backend

# Build and push image
aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.ap-south-1.amazonaws.com
docker build -f Dockerfile.lambda -t <account-id>.dkr.ecr.ap-south-1.amazonaws.com/clipsense-lambda-api:latest .
docker push <account-id>.dkr.ecr.ap-south-1.amazonaws.com/clipsense-lambda-api:latest

# Update Lambda function
aws lambda update-function-code \
  --function-name clipsense-api \
  --image-uri <account-id>.dkr.ecr.ap-south-1.amazonaws.com/clipsense-lambda-api:latest

# Wait for update
aws lambda wait function-updated --function-name clipsense-api

# Test
curl https://xxxxxx.execute-api.ap-south-1.amazonaws.com/api/health
```

**Windows (PowerShell):**
```powershell
cd backend

# Get account ID
$ACCOUNT_ID = aws sts get-caller-identity --query Account --output text

# Build and push image
aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin "$ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com"
docker build -f Dockerfile.lambda -t "$ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com/clipsense-lambda-api:latest" .
docker push "$ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com/clipsense-lambda-api:latest"

# Update Lambda function
aws lambda update-function-code `
  --function-name clipsense-api `
  --image-uri "$ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com/clipsense-lambda-api:latest"

# Wait for update
aws lambda wait function-updated --function-name clipsense-api

# Test
curl https://xxxxxx.execute-api.ap-south-1.amazonaws.com/api/health
```

### Deploy Worker Manually

**Linux/Mac:**
```bash
# SSH into EC2
ssh -i ~/.ssh/clipsense-worker-key.pem ec2-user@<ec2-public-ip>

# Pull latest code
cd /home/ec2-user/clipsense
git pull origin main

# Rebuild and restart worker
cd backend
docker build -f Dockerfile.worker -t clipsense-worker .
docker stop clipsense-worker
docker rm clipsense-worker
docker run -d \
  --name clipsense-worker \
  --restart unless-stopped \
  --env-file /etc/clipsense/.env \
  clipsense-worker

# Check logs
docker logs -f clipsense-worker
```

**Windows (PowerShell with SSH):**
```powershell
# SSH into EC2 (requires OpenSSH or PuTTY)
ssh -i "$env:USERPROFILE\.ssh\clipsense-worker-key.pem" ec2-user@<ec2-public-ip>

# Once connected, run the same commands as Linux:
cd /home/ec2-user/clipsense
git pull origin main
cd backend
docker build -f Dockerfile.worker -t clipsense-worker .
docker stop clipsense-worker
docker rm clipsense-worker
docker run -d --name clipsense-worker --restart unless-stopped --env-file /etc/clipsense/.env clipsense-worker
docker logs -f clipsense-worker
```

## Verify Deployment

### 1. Test Lambda API

**Linux/Mac:**
```bash
# Health check
curl https://xxxxxx.execute-api.ap-south-1.amazonaws.com/api/health

# Expected response:
# {"status":"healthy","service":"clipsense-lambda-api","dbReady":true,"s3Ready":true,"sqsConfigured":true}
```

**Windows (PowerShell):**
```powershell
# Health check
Invoke-WebRequest -Uri "https://xxxxxx.execute-api.ap-south-1.amazonaws.com/api/health" | Select-Object -ExpandProperty Content

# Or use curl if available
curl https://xxxxxx.execute-api.ap-south-1.amazonaws.com/api/health
```

### 2. Test Worker

**Linux/Mac:**
```bash
# SSH into EC2
ssh -i ~/.ssh/clipsense-worker-key.pem ec2-user@<ec2-public-ip>

# Check worker is running
docker ps | grep clipsense-worker

# Check logs
docker logs clipsense-worker --tail 50
```

**Windows (PowerShell):**
```powershell
# SSH into EC2
ssh -i "$env:USERPROFILE\.ssh\clipsense-worker-key.pem" ec2-user@<ec2-public-ip>

# Once connected, check worker status
docker ps | grep clipsense-worker
docker logs clipsense-worker --tail 50
```

### 3. Test Complete Upload Flow

1. Open the Amplify frontend URL
2. Register a new account
3. Upload a test video
4. Verify:
   - Video appears in S3 bucket
   - SQS message is sent
   - Worker picks up the job
   - Processing completes
   - Clips are generated and uploaded to S3

## Monitoring

### Lambda Logs

**Linux/Mac:**
```bash
aws logs tail /aws/lambda/clipsense-api --follow
```

**Windows (PowerShell):**
```powershell
aws logs tail /aws/lambda/clipsense-api --follow
```

### Worker Logs

**Linux/Mac:**
```bash
ssh -i ~/.ssh/clipsense-worker-key.pem ec2-user@<ec2-public-ip> 'docker logs -f clipsense-worker'
```

**Windows (PowerShell):**
```powershell
ssh -i "$env:USERPROFILE\.ssh\clipsense-worker-key.pem" ec2-user@<ec2-public-ip> "docker logs -f clipsense-worker"
```

### SQS Queue Depth

**Linux/Mac:**
```bash
aws sqs get-queue-attributes \
  --queue-url https://sqs.ap-south-1.amazonaws.com/<account>/clipsense-processing-queue \
  --attribute-names ApproximateNumberOfMessages
```

**Windows (PowerShell):**
```powershell
aws sqs get-queue-attributes `
  --queue-url "https://sqs.ap-south-1.amazonaws.com/<account>/clipsense-processing-queue" `
  --attribute-names ApproximateNumberOfMessages
```

## Troubleshooting

### Lambda Issues

- **Cold start timeout**: Increase Lambda timeout or memory
- **Permission denied**: Check IAM role has S3, DynamoDB, SQS permissions
- **Health check fails**: Check environment variables are set correctly

### Worker Issues

- **Worker not processing**: Check SQS queue URL is correct in `/etc/clipsense/.env`
- **Out of memory**: Upgrade to t2.small or t3.small
- **Container crashes**: Check logs with `docker logs clipsense-worker`

### Frontend Issues

- **API calls fail**: Verify `NEXT_PUBLIC_API_URL` in Amplify environment variables
- **CORS errors**: Check API Gateway CORS configuration
- **Build fails**: Check Amplify build logs

## Cost Estimates

With AWS Free Tier:
- Lambda: FREE (1M requests/month)
- EC2 t2.micro: FREE for 12 months (750 hours/month)
- SQS: FREE (1M requests/month)
- DynamoDB: FREE (25GB, 25 RCU/WCU)
- S3: FREE (5GB storage, 20K GET, 2K PUT)
- Amplify: ~$1-5/month (build minutes free, hosting ~$0.15/GB)

**Total estimated cost**: $1-5/month for low traffic

## Cleanup

To delete all resources:

```bash
# Delete Lambda function
aws lambda delete-function --function-name clipsense-api

# Delete API Gateway
aws apigatewayv2 delete-api --api-id <api-id>

# Terminate EC2 instance
aws ec2 terminate-instances --instance-ids <instance-id>

# Delete SQS queue
aws sqs delete-queue --queue-url <queue-url>

# Delete ECR repository
aws ecr delete-repository --repository-name clipsense-lambda-api --force

# Delete DynamoDB tables
aws dynamodb delete-table --table-name ClipSenseUsers
aws dynamodb delete-table --table-name ClipSenseProjects

# Delete S3 bucket (must be empty first)
aws s3 rm s3://clipsense-storage --recursive
aws s3api delete-bucket --bucket clipsense-storage

# Delete IAM roles
aws iam delete-role-policy --role-name ClipSenseLambdaRole --policy-name ClipSenseLambdaPolicy
aws iam detach-role-policy --role-name ClipSenseLambdaRole --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
aws iam delete-role --role-name ClipSenseLambdaRole

aws iam delete-role-policy --role-name ClipSenseEC2WorkerRole --policy-name ClipSenseEC2WorkerPolicy
aws iam remove-role-from-instance-profile --instance-profile-name ClipSenseEC2WorkerRole --role-name ClipSenseEC2WorkerRole
aws iam delete-instance-profile --instance-profile-name ClipSenseEC2WorkerRole
aws iam delete-role --role-name ClipSenseEC2WorkerRole
```
