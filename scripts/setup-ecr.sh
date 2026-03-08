#!/bin/bash
# Setup ECR repository for ClipSense Lambda container images

set -e

REPOSITORY_NAME="clipsense-lambda-api"
AWS_REGION="${AWS_REGION:-ap-south-1}"

echo "=========================================="
echo "Setting up ECR Repository"
echo "=========================================="
echo "Repository Name: $REPOSITORY_NAME"
echo "Region: $AWS_REGION"
echo ""

# Check if repository already exists
REPO_URI=$(aws ecr describe-repositories \
    --repository-names "$REPOSITORY_NAME" \
    --region "$AWS_REGION" \
    --query 'repositories[0].repositoryUri' \
    --output text 2>/dev/null || echo "")

if [ -n "$REPO_URI" ]; then
    echo "✓ Repository already exists: $REPO_URI"
else
    echo "Creating ECR repository..."
    REPO_URI=$(aws ecr create-repository \
        --repository-name "$REPOSITORY_NAME" \
        --region "$AWS_REGION" \
        --query 'repository.repositoryUri' \
        --output text)
    
    echo "✓ Repository created: $REPO_URI"
    
    # Configure lifecycle policy to keep last 5 images
    echo "Configuring lifecycle policy..."
    aws ecr put-lifecycle-policy \
        --repository-name "$REPOSITORY_NAME" \
        --region "$AWS_REGION" \
        --lifecycle-policy-text '{
            "rules": [{
                "rulePriority": 1,
                "description": "Keep last 5 images",
                "selection": {
                    "tagStatus": "any",
                    "countType": "imageCountMoreThan",
                    "countNumber": 5
                },
                "action": {
                    "type": "expire"
                }
            }]
        }'
    
    echo "✓ Lifecycle policy configured"
fi

echo ""
echo "=========================================="
echo "ECR Repository Setup Complete"
echo "=========================================="
echo "Repository URI: $REPO_URI"
echo ""
echo "To push images:"
echo "  aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $REPO_URI"
echo "  docker build -f Dockerfile.lambda -t $REPO_URI:latest ."
echo "  docker push $REPO_URI:latest"
