# Update Worker Code on EC2
# This script rebuilds and redeploys the worker with the emotion analysis fix

$ErrorActionPreference = "Stop"

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "Updating ClipSense Worker with Emotion Analysis Fix" -ForegroundColor Cyan
Write-Host "============================================================`n" -ForegroundColor Cyan

# Load environment variables
. .\backend\load-env.ps1

$AWS_REGION = $env:AWS_REGION
$AWS_ACCOUNT_ID = (aws sts get-caller-identity --query Account --output text)
$ECR_REPO = "clipsense-worker"
$IMAGE_TAG = "latest"

Write-Host "Step 1: Building Docker image..." -ForegroundColor Yellow
docker build -t $ECR_REPO`:$IMAGE_TAG -f backend/Dockerfile.worker backend/

if ($LASTEXITCODE -ne 0) {
    Write-Host "`n❌ Docker build failed" -ForegroundColor Red
    exit 1
}

Write-Host "`nStep 2: Logging in to ECR..." -ForegroundColor Yellow
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"

Write-Host "`nStep 3: Tagging image..." -ForegroundColor Yellow
docker tag $ECR_REPO`:$IMAGE_TAG "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO`:$IMAGE_TAG"

Write-Host "`nStep 4: Pushing to ECR..." -ForegroundColor Yellow
docker push "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO`:$IMAGE_TAG"

if ($LASTEXITCODE -ne 0) {
    Write-Host "`n❌ Push to ECR failed" -ForegroundColor Red
    exit 1
}

Write-Host "`n✅ Image pushed to ECR successfully!" -ForegroundColor Green
Write-Host "`nStep 5: Updating worker on EC2..." -ForegroundColor Yellow
Write-Host "`nRun these commands in EC2 Session Manager:" -ForegroundColor Cyan
Write-Host @"

# Stop and remove old container
docker stop clipsense-worker
docker rm clipsense-worker

# Login to ECR
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# Pull latest image
docker pull $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO`:$IMAGE_TAG

# Start new container
docker run -d \
  --name clipsense-worker \
  --env-file /etc/clipsense/.env \
  --restart unless-stopped \
  $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO`:$IMAGE_TAG

# Check logs
docker logs clipsense-worker --tail 30

"@ -ForegroundColor White

Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "✅ Worker image updated in ECR!" -ForegroundColor Green
Write-Host "Now update the EC2 container using the commands above" -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Cyan
