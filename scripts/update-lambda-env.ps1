#!/usr/bin/env pwsh
# Update Lambda environment variables to include SQS_QUEUE_URL

$ErrorActionPreference = "Stop"

# Load environment variables
. "$PSScriptRoot\backend\load-env.ps1"

$FUNCTION_NAME = "clipsense-api"
$AWS_REGION = $env:AWS_REGION

Write-Host "=========================================="
Write-Host "Updating Lambda Environment Variables"
Write-Host "=========================================="
Write-Host ""

# Get SQS Queue URL
$SQS_QUEUE_URL = aws sqs get-queue-url `
    --queue-name "clipsense-processing-queue" `
    --region $AWS_REGION `
    --query "QueueUrl" `
    --output text

if (-not $SQS_QUEUE_URL) {
    Write-Host "Error: SQS queue not found"
    exit 1
}

Write-Host "SQS Queue URL: $SQS_QUEUE_URL"
Write-Host ""

# Update Lambda environment variables
Write-Host "Updating Lambda function environment..."

# Use AWS CLI with proper JSON escaping (AWS_REGION is automatically set by Lambda)
aws lambda update-function-configuration `
    --function-name $FUNCTION_NAME `
    --region $AWS_REGION `
    --environment "Variables={AWS_S3_BUCKET=$($env:AWS_S3_BUCKET),DYNAMO_USERS_TABLE=$($env:DYNAMO_USERS_TABLE),DYNAMO_PROJECTS_TABLE=$($env:DYNAMO_PROJECTS_TABLE),SQS_QUEUE_URL=$SQS_QUEUE_URL,JWT_SECRET_KEY=$($env:JWT_SECRET_KEY),GEMINI_API_KEY=$($env:GEMINI_API_KEY),BEDROCK_MODEL_ID=$($env:BEDROCK_MODEL_ID)}"

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "Lambda environment variables updated successfully"
    Write-Host ""
    Write-Host "Waiting for Lambda to update..."
    Start-Sleep -Seconds 10
    
    Write-Host ""
    Write-Host "=========================================="
    Write-Host "Update Complete!"
    Write-Host "=========================================="
    Write-Host ""
    Write-Host "Lambda now has SQS_QUEUE_URL configured."
    Write-Host "Try uploading a video again!"
} else {
    Write-Host ""
    Write-Host "Error updating Lambda environment variables"
    Write-Host "Exit code: $LASTEXITCODE"
    exit 1
}
