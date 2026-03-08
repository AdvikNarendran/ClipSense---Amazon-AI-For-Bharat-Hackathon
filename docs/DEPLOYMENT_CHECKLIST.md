# ClipSense Deployment Checklist

## Pre-Deployment Setup

### 1. Configure .env File ✅
- [x] AWS_REGION
- [x] AWS_S3_BUCKET
- [x] GEMINI_API_KEY
- [x] DYNAMO_USERS_TABLE
- [x] DYNAMO_PROJECTS_TABLE
- [x] ADMIN_EMAIL
- [ ] JWT_SECRET_KEY (add or will be generated)
- [ ] GITHUB_REPO (add your repo: username/clipsense)
- [ ] EC2_KEY_NAME (add: clipsense-worker-key)
- [ ] GOOGLE_CLIENT_ID (optional)

### 2. Create EC2 Key Pair
```powershell
aws ec2 create-key-pair --key-name clipsense-worker-key --query 'KeyMaterial' --output text | Out-File -FilePath "$env:USERPROFILE\.ssh\clipsense-worker-key.pem" -Encoding ASCII -NoNewline
```

## AWS Infrastructure Setup

Run these scripts in order:

### Step 1: Storage & Database
```powershell
cd backend
.\setup-s3.ps1          # ✅ Creates S3 bucket
.\setup-dynamodb.ps1    # ✅ Creates DynamoDB tables
```

### Step 2: Message Queue
```powershell
.\setup-sqs.ps1         # ✅ Creates SQS queue
# Save the SQS_QUEUE_URL from output
```

### Step 3: Lambda Setup
```powershell
.\setup-ecr.ps1         # ✅ Creates ECR repository

# Build and push Lambda image
$ACCOUNT_ID = aws sts get-caller-identity --query Account --output text
aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin "$ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com"
docker build -f Dockerfile.lambda -t "$ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com/clipsense-lambda-api:latest" .
docker push "$ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com/clipsense-lambda-api:latest"

.\setup-lambda.ps1      # ✅ Creates Lambda function
```

### Step 4: API Gateway
```powershell
.\setup-api-gateway.ps1 # ✅ Creates API Gateway
# Save the API_GATEWAY_URL from output
```

### Step 5: EC2 Worker
```powershell
.\setup-ec2.ps1         # ✅ Creates EC2 worker instance
# Save the EC2_PUBLIC_IP from output
```

## GitHub Configuration

### 1. Push Code to GitHub
```bash
git add .
git commit -m "Add cloud deployment configuration"
git push origin main
```

### 2. Add GitHub Secrets
Go to: GitHub Repo → Settings → Secrets and variables → Actions

Add these 5 secrets:
1. **AWS_ACCESS_KEY_ID**: `<your-aws-access-key-id>`
2. **AWS_SECRET_ACCESS_KEY**: `<your-aws-secret-access-key>`
3. **EC2_WORKER_HOST**: `<your-ec2-public-ip>`
4. **EC2_SSH_KEY**: `<content-of-clipsense-worker-key.pem>`
5. **API_GATEWAY_URL**: `<your-api-gateway-url>`

## AWS Amplify Configuration

### 1. Connect Repository
1. Go to [AWS Amplify Console](https://console.aws.amazon.com/amplify)
2. Click "New app" → "Host web app"
3. Connect GitHub → Select your repo → Select main branch

### 2. Add Environment Variables
In Amplify Console → App Settings → Environment variables:

```
NEXT_PUBLIC_API_URL=<your-api-gateway-url>
NEXT_PUBLIC_AWS_REGION=ap-south-1
NEXT_PUBLIC_S3_BUCKET=clipsense-media-storage-cs
```

### 3. Deploy
Click "Save and deploy" → Wait 5-10 minutes

## Verification

### Test Lambda API
```powershell
curl <your-api-gateway-url>/api/health
```
Expected: `{"status":"healthy",...}`

### Test EC2 Worker
```powershell
ssh -i "$env:USERPROFILE\.ssh\clipsense-worker-key.pem" ec2-user@<ec2-public-ip>
docker logs clipsense-worker --tail 50
```
Expected: Worker polling SQS queue

### Test Frontend
1. Open Amplify URL
2. Register account → ✅ Should work
3. Login → ✅ Should work
4. Upload video → ✅ Should work
5. Wait for processing → ✅ Check worker logs
6. Download clips → ✅ Should work

## 🎉 Deployment Complete!

If all tests pass, your app is fully deployed and working!

### What Happens Now:
- ✅ Frontend hosted on Amplify
- ✅ API running on Lambda
- ✅ Videos processed by EC2 worker
- ✅ Auto-deployment on git push
- ✅ Scalable and cost-effective

### Monitoring:
- Lambda logs: AWS CloudWatch
- Worker logs: SSH into EC2 → `docker logs -f clipsense-worker`
- SQS queue: AWS Console → SQS

### Costs (with Free Tier):
- Lambda: FREE (1M requests/month)
- EC2: FREE for 12 months (750 hours/month)
- S3: FREE (5GB storage)
- DynamoDB: FREE (25GB, 25 RCU/WCU)
- Amplify: ~$1-5/month

**Total: ~$1-5/month for low traffic!**
