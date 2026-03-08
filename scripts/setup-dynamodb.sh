#!/bin/bash
# Setup DynamoDB tables for ClipSense

set -e

AWS_REGION="${AWS_REGION:-ap-south-1}"

echo "=========================================="
echo "Setting up DynamoDB Tables"
echo "=========================================="
echo "Region: $AWS_REGION"
echo ""

# Check and create ClipSenseUsers table
echo "Checking ClipSenseUsers table..."
TABLE_STATUS=$(aws dynamodb describe-table \
    --table-name "ClipSenseUsers" \
    --region "$AWS_REGION" \
    --query 'Table.TableStatus' \
    --output text 2>/dev/null || echo "")

if [ -z "$TABLE_STATUS" ]; then
    echo "Creating ClipSenseUsers table..."
    aws dynamodb create-table \
        --table-name "ClipSenseUsers" \
        --attribute-definitions \
            AttributeName=email,AttributeType=S \
        --key-schema \
            AttributeName=email,KeyType=HASH \
        --provisioned-throughput \
            ReadCapacityUnits=5,WriteCapacityUnits=5 \
        --region "$AWS_REGION"
    
    echo "Waiting for table to be active..."
    aws dynamodb wait table-exists --table-name "ClipSenseUsers" --region "$AWS_REGION"
    echo "✓ ClipSenseUsers table created"
else
    echo "✓ ClipSenseUsers table already exists (Status: $TABLE_STATUS)"
fi

# Check and create ClipSenseProjects table
echo ""
echo "Checking ClipSenseProjects table..."
TABLE_STATUS=$(aws dynamodb describe-table \
    --table-name "ClipSenseProjects" \
    --region "$AWS_REGION" \
    --query 'Table.TableStatus' \
    --output text 2>/dev/null || echo "")

if [ -z "$TABLE_STATUS" ]; then
    echo "Creating ClipSenseProjects table..."
    aws dynamodb create-table \
        --table-name "ClipSenseProjects" \
        --attribute-definitions \
            AttributeName=projectId,AttributeType=S \
        --key-schema \
            AttributeName=projectId,KeyType=HASH \
        --provisioned-throughput \
            ReadCapacityUnits=5,WriteCapacityUnits=5 \
        --region "$AWS_REGION"
    
    echo "Waiting for table to be active..."
    aws dynamodb wait table-exists --table-name "ClipSenseProjects" --region "$AWS_REGION"
    echo "✓ ClipSenseProjects table created"
else
    echo "✓ ClipSenseProjects table already exists (Status: $TABLE_STATUS)"
fi

echo ""
echo "=========================================="
echo "DynamoDB Tables Setup Complete"
echo "=========================================="
echo "Tables:"
echo "  - ClipSenseUsers (email as primary key)"
echo "  - ClipSenseProjects (projectId as primary key)"
echo ""
echo "Provisioned capacity: 5 RCU / 5 WCU per table"
