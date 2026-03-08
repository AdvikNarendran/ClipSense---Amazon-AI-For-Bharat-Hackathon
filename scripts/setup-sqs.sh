#!/bin/bash
# Setup SQS queue for ClipSense video processing jobs

set -e

QUEUE_NAME="clipsense-processing-queue"
AWS_REGION="${AWS_REGION:-ap-south-1}"

echo "=========================================="
echo "Setting up SQS Queue"
echo "=========================================="
echo "Queue Name: $QUEUE_NAME"
echo "Region: $AWS_REGION"
echo ""

# Check if queue already exists
QUEUE_URL=$(aws sqs get-queue-url --queue-name "$QUEUE_NAME" --region "$AWS_REGION" 2>/dev/null | jq -r '.QueueUrl' || echo "")

if [ -n "$QUEUE_URL" ]; then
    echo "✓ Queue already exists: $QUEUE_URL"
else
    echo "Creating SQS queue..."
    QUEUE_URL=$(aws sqs create-queue \
        --queue-name "$QUEUE_NAME" \
        --region "$AWS_REGION" \
        --attributes '{
            "VisibilityTimeout": "3600",
            "MessageRetentionPeriod": "345600",
            "ReceiveMessageWaitTimeSeconds": "20"
        }' \
        --query 'QueueUrl' \
        --output text)
    
    echo "✓ Queue created: $QUEUE_URL"
fi

echo ""
echo "=========================================="
echo "SQS Queue Setup Complete"
echo "=========================================="
echo "Queue URL: $QUEUE_URL"
echo ""
echo "Add this to your environment variables:"
echo "export SQS_QUEUE_URL=\"$QUEUE_URL\""
