# Setup ECR repository for ClipSense Lambda container images

$ErrorActionPreference = "Stop"

# Load environment variables
. "$PSScriptRoot\load-env.ps1"

$REPOSITORY_NAME = "clipsense-lambda-api"
$AWS_REGION = $env:AWS_REGION

if (-not $AWS_REGION) {
    Write-Host "Error: AWS_REGION not set in .env file"
    exit 1
}

Write-Host "=========================================="
Write-Host "Setting up ECR Repository"
Write-Host "=========================================="
Write-Host "Repository Name: $REPOSITORY_NAME"
Write-Host "Region: $AWS_REGION"
Write-Host ""

try {

    $REPO_URI = aws ecr describe-repositories `
        --repository-names $REPOSITORY_NAME `
        --region $AWS_REGION `
        --query "repositories[0].repositoryUri" `
        --output text 2>$null

    Write-Host "Repository already exists: $REPO_URI"

}
catch {

    Write-Host "Creating ECR repository..."

    $REPO_URI = aws ecr create-repository `
        --repository-name $REPOSITORY_NAME `
        --region $AWS_REGION `
        --query "repository.repositoryUri" `
        --output text

    Write-Host "Repository created: $REPO_URI"

    Write-Host "Configuring lifecycle policy..."

    $lifecycle = '{"rules":[{"rulePriority":1,"description":"Keep last 5 images","selection":{"tagStatus":"any","countType":"imageCountMoreThan","countNumber":5},"action":{"type":"expire"}}]}'

    aws ecr put-lifecycle-policy `
        --repository-name $REPOSITORY_NAME `
        --region $AWS_REGION `
        --lifecycle-policy-text $lifecycle

    Write-Host "Lifecycle policy configured"
}

Write-Host ""
Write-Host "=========================================="
Write-Host "ECR Repository Setup Complete"
Write-Host "=========================================="
Write-Host "Repository URI: $REPO_URI"
Write-Host ""

Write-Host "To push images:"
Write-Host "aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $REPO_URI"
Write-Host "docker build -f Dockerfile.lambda -t $REPO_URI`:latest ."
Write-Host "docker push $REPO_URI`:latest"