# Setup SQS queue for ClipSense video processing jobs

$ErrorActionPreference = "Stop"

# Load environment variables
. "$PSScriptRoot\load-env.ps1"

$QUEUE_NAME = "clipsense-processing-queue"
$AWS_REGION = $env:AWS_REGION

if (-not $AWS_REGION) {
    Write-Host "Error: AWS_REGION not set in .env file"
    exit 1
}

Write-Host "=========================================="
Write-Host "Setting up SQS Queue"
Write-Host "=========================================="
Write-Host "Queue Name: $QUEUE_NAME"
Write-Host "Region: $AWS_REGION"
Write-Host ""

# Check if queue exists
try {

    $QUEUE_URL = aws sqs get-queue-url `
        --queue-name $QUEUE_NAME `
        --region $AWS_REGION `
        --query "QueueUrl" `
        --output text 2>$null

    Write-Host "Queue already exists: $QUEUE_URL"

}
catch {

    Write-Host "Creating SQS queue..."

    $QUEUE_URL = aws sqs create-queue `
        --queue-name $QUEUE_NAME `
        --region $AWS_REGION `
        --attributes VisibilityTimeout=3600,MessageRetentionPeriod=345600,ReceiveMessageWaitTimeSeconds=20 `
        --query "QueueUrl" `
        --output text

    Write-Host "Queue created: $QUEUE_URL"

}

Write-Host ""
Write-Host "=========================================="
Write-Host "SQS Queue Setup Complete"
Write-Host "=========================================="
Write-Host "Queue URL: $QUEUE_URL"
Write-Host ""
Write-Host "Add this to your environment variables:"
Write-Host "SQS_QUEUE_URL=$QUEUE_URL"