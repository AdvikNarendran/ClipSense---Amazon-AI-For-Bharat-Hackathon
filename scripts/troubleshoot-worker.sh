#!/bin/bash
# Troubleshooting script for ClipSense worker

echo "=========================================="
echo "ClipSense Worker Troubleshooting"
echo "=========================================="
echo ""

echo "1. Checking SQS Queue for messages..."
echo "----------------------------------------"
aws sqs get-queue-attributes \
    --queue-url "https://sqs.ap-south-1.amazonaws.com/732772501496/clipsense-processing-queue" \
    --attribute-names ApproximateNumberOfMessages,ApproximateNumberOfMessagesNotVisible \
    --region ap-south-1 \
    --output json

echo ""
echo "2. Checking worker container status..."
echo "----------------------------------------"
docker ps | grep clipsense-worker

echo ""
echo "3. Checking recent worker logs..."
echo "----------------------------------------"
docker logs clipsense-worker --tail 50

echo ""
echo "4. Checking if worker can access SQS..."
echo "----------------------------------------"
docker exec clipsense-worker python -c "
import boto3
import os
sqs = boto3.client('sqs', region_name='ap-south-1')
queue_url = os.getenv('SQS_QUEUE_URL')
print(f'Queue URL: {queue_url}')
try:
    response = sqs.get_queue_attributes(QueueUrl=queue_url, AttributeNames=['All'])
    print('✓ Worker can access SQS queue')
    print(f'Messages in queue: {response[\"Attributes\"].get(\"ApproximateNumberOfMessages\", 0)}')
except Exception as e:
    print(f'✗ Error accessing SQS: {e}')
"

echo ""
echo "=========================================="
echo "Troubleshooting Complete"
echo "=========================================="
