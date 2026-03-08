#!/bin/bash
# Setup Lambda function for ClipSense API

set -e

FUNCTION_NAME="clipsense-api"
ROLE_NAME="ClipSenseLambdaRole"
AWS_REGION="${AWS_REGION:-ap-south-1}"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "=========================================="
echo "Setting up Lambda Function"
echo "=========================================="
echo "Function Name: $FUNCTION_NAME"
echo "Region: $AWS_REGION"
echo "Account ID: $AWS_ACCOUNT_ID"
echo ""

# Get ECR repository URI
REPO_URI=$(aws ecr describe-repositories \
    --repository-names "clipsense-lambda-api" \
    --region "$AWS_REGION" \
    --query 'repositories[0].repositoryUri' \
    --output text)

if [ -z "$REPO_URI" ]; then
    echo "Error: ECR repository not found. Run setup-ecr.sh first."
    exit 1
fi

IMAGE_URI="$REPO_URI:latest"
echo "Using image: $IMAGE_URI"
echo ""

# Create IAM role if it doesn't exist
ROLE_ARN=$(aws iam get-role --role-name "$ROLE_NAME" --query 'Role.Arn' --output text 2>/dev/null || echo "")

if [ -z "$ROLE_ARN" ]; then
    echo "Creating IAM role..."
    
    # Trust policy
    cat > /tmp/lambda-trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"Service": "lambda.amazonaws.com"},
    "Action": "sts:AssumeRole"
  }]
}
EOF
    
    ROLE_ARN=$(aws iam create-role \
        --role-name "$ROLE_NAME" \
        --assume-role-policy-document file:///tmp/lambda-trust-policy.json \
        --query 'Role.Arn' \
        --output text)
    
    echo "✓ Role created: $ROLE_ARN"
    
    # Attach policies
    echo "Attaching policies..."
    
    # Lambda basic execution
    aws iam attach-role-policy \
        --role-name "$ROLE_NAME" \
        --policy-arn "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
    
    # Custom policy for S3, DynamoDB, SQS
    cat > /tmp/lambda-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::*",
        "arn:aws:s3:::*/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:DeleteItem",
        "dynamodb:Query",
        "dynamodb:Scan"
      ],
      "Resource": "arn:aws:dynamodb:${AWS_REGION}:${AWS_ACCOUNT_ID}:table/ClipSense*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "sqs:SendMessage",
        "sqs:GetQueueUrl"
      ],
      "Resource": "arn:aws:sqs:${AWS_REGION}:${AWS_ACCOUNT_ID}:clipsense-*"
    }
  ]
}
EOF
    
    aws iam put-role-policy \
        --role-name "$ROLE_NAME" \
        --policy-name "ClipSenseLambdaPolicy" \
        --policy-document file:///tmp/lambda-policy.json
    
    echo "✓ Policies attached"
    echo "Waiting 10 seconds for IAM role to propagate..."
    sleep 10
else
    echo "✓ IAM role already exists: $ROLE_ARN"
fi

# Check if Lambda function exists
FUNCTION_ARN=$(aws lambda get-function \
    --function-name "$FUNCTION_NAME" \
    --region "$AWS_REGION" \
    --query 'Configuration.FunctionArn' \
    --output text 2>/dev/null || echo "")

if [ -z "$FUNCTION_ARN" ]; then
    echo "Creating Lambda function..."
    
    # Get SQS queue URL
    SQS_QUEUE_URL=$(aws sqs get-queue-url --queue-name "clipsense-processing-queue" --region "$AWS_REGION" --query 'QueueUrl' --output text 2>/dev/null || echo "")
    
    FUNCTION_ARN=$(aws lambda create-function \
        --function-name "$FUNCTION_NAME" \
        --package-type Image \
        --code ImageUri="$IMAGE_URI" \
        --role "$ROLE_ARN" \
        --region "$AWS_REGION" \
        --timeout 30 \
        --memory-size 512 \
        --environment "Variables={
            AWS_REGION=$AWS_REGION,
            AWS_S3_BUCKET=${AWS_S3_BUCKET:-clipsense-storage},
            DYNAMO_USERS_TABLE=ClipSenseUsers,
            DYNAMO_PROJECTS_TABLE=ClipSenseProjects,
            SQS_QUEUE_URL=$SQS_QUEUE_URL,
            JWT_SECRET_KEY=${JWT_SECRET_KEY:-clipsense-super-secret-key},
            GEMINI_API_KEY=${GEMINI_API_KEY:-},
            GOOGLE_CLIENT_ID=${GOOGLE_CLIENT_ID:-},
            ADMIN_EMAIL=${ADMIN_EMAIL:-admin@clipsense.ai}
        }" \
        --query 'FunctionArn' \
        --output text)
    
    echo "✓ Lambda function created: $FUNCTION_ARN"
else
    echo "✓ Lambda function already exists: $FUNCTION_ARN"
fi

echo ""
echo "=========================================="
echo "Lambda Function Setup Complete"
echo "=========================================="
echo "Function ARN: $FUNCTION_ARN"
echo ""
echo "Next steps:"
echo "  1. Run setup-api-gateway.sh to create API Gateway"
echo "  2. Update Lambda environment variables if needed:"
echo "     aws lambda update-function-configuration --function-name $FUNCTION_NAME --environment Variables={...}"
