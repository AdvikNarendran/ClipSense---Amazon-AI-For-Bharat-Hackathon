# Setup DynamoDB tables for ClipSense

$ErrorActionPreference = "Stop"

# Load environment variables from .env file
. "$PSScriptRoot\load-env.ps1"

$AWS_REGION = $env:AWS_REGION

if (-not $AWS_REGION) {
    Write-Host "Error: AWS_REGION not set in .env file"
    exit 1
}

Write-Host "=========================================="
Write-Host "Setting up DynamoDB Tables"
Write-Host "=========================================="
Write-Host "Region: $AWS_REGION"
Write-Host ""

# -----------------------------
# ClipSenseUsers Table
# -----------------------------
Write-Host "Checking ClipSenseUsers table..."

try {
    $TABLE_STATUS = aws dynamodb describe-table --table-name ClipSense-Users --region $AWS_REGION --query "Table.TableStatus" --output text 2>$null
    Write-Host "ClipSenseUsers table already exists (Status: $TABLE_STATUS)"
}
catch {

    Write-Host "Creating ClipSenseUsers table..."

    aws dynamodb create-table --table-name ClipSenseUsers --attribute-definitions AttributeName=email,AttributeType=S --key-schema AttributeName=email,KeyType=HASH --billing-mode PAY_PER_REQUEST --region $AWS_REGION

    Write-Host "Waiting for table to become active..."

    aws dynamodb wait table-exists --table-name ClipSenseUsers --region $AWS_REGION

    Write-Host "ClipSenseUsers table created"
}

# -----------------------------
# ClipSenseProjects Table
# -----------------------------
Write-Host ""
Write-Host "Checking ClipSenseProjects table..."

try {
    $TABLE_STATUS = aws dynamodb describe-table --table-name ClipSense-Projects --region $AWS_REGION --query "Table.TableStatus" --output text 2>$null
    Write-Host "ClipSenseProjects table already exists (Status: $TABLE_STATUS)"
}
catch {

    Write-Host "Creating ClipSenseProjects table..."

    aws dynamodb create-table --table-name ClipSenseProjects --attribute-definitions AttributeName=projectId,AttributeType=S --key-schema AttributeName=projectId,KeyType=HASH --billing-mode PAY_PER_REQUEST --region $AWS_REGION

    Write-Host "Waiting for table to become active..."

    aws dynamodb wait table-exists --table-name ClipSenseProjects --region $AWS_REGION

    Write-Host "ClipSenseProjects table created"
}

Write-Host ""
Write-Host "=========================================="
Write-Host "DynamoDB Tables Setup Complete"
Write-Host "=========================================="
Write-Host "Tables:"
Write-Host "  - ClipSenseUsers (email as primary key)"
Write-Host "  - ClipSenseProjects (projectId as primary key)"
Write-Host ""
Write-Host "Billing mode: PAY_PER_REQUEST (recommended for startups)"