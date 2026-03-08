# Redeploy Lambda Function
# This script rebuilds the Docker image and updates the Lambda function

Write-Host "=== Redeploying Lambda Function ===" -ForegroundColor Cyan

# Change to backend directory
Push-Location $PSScriptRoot

# Get AWS Account ID
$ACCOUNT_ID = aws sts get-caller-identity --query Account --output text
$REGION = "ap-south-1"
$ECR_REPO = "${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/clipsense-lambda-api"

Write-Host "`n1. Logging into ECR..." -ForegroundColor Yellow
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin "${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

Write-Host "`n2. Building Docker image..." -ForegroundColor Yellow
$env:DOCKER_BUILDKIT=0
docker build --platform linux/amd64 -f Dockerfile.lambda -t clipsense-lambda-api:latest .

Write-Host "`n3. Tagging image..." -ForegroundColor Yellow
docker tag clipsense-lambda-api:latest "${ECR_REPO}:latest"

Write-Host "`n4. Pushing to ECR..." -ForegroundColor Yellow
docker push "${ECR_REPO}:latest"

Write-Host "`n5. Updating Lambda function..." -ForegroundColor Yellow
aws lambda update-function-code `
    --function-name clipsense-api `
    --region $REGION `
    --image-uri "${ECR_REPO}:latest"

Write-Host "`n6. Waiting for Lambda to update..." -ForegroundColor Yellow
aws lambda wait function-updated --function-name clipsense-api --region $REGION

Pop-Location

Write-Host "`nLambda function redeployed successfully!" -ForegroundColor Green
Write-Host "`nTesting health endpoint..." -ForegroundColor Yellow
Start-Sleep -Seconds 5
Invoke-WebRequest -Uri "https://x1fjliehe8.execute-api.ap-south-1.amazonaws.com/api/health" -Method GET
