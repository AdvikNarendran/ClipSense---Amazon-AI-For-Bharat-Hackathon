# Setup Lambda function for ClipSense API

$ErrorActionPreference = "Stop"

# Load environment variables
. "$PSScriptRoot\load-env.ps1"

$FUNCTION_NAME = "clipsense-api"
$ROLE_NAME = "ClipSenseLambdaRole"
$AWS_REGION = $env:AWS_REGION
$AWS_ACCOUNT_ID = aws sts get-caller-identity --query Account --output text

if (-not $AWS_REGION) {
    Write-Host "Error: AWS_REGION not set in .env file"
    exit 1
}

if (-not $env:AWS_S3_BUCKET) {
    Write-Host "Error: AWS_S3_BUCKET not set in .env file"
    exit 1
}

if (-not $env:GEMINI_API_KEY) {
    Write-Host "Error: GEMINI_API_KEY not set in .env file"
    exit 1
}

# Generate JWT_SECRET_KEY if missing
if (-not $env:JWT_SECRET_KEY) {

    Write-Host "JWT_SECRET_KEY not found in .env"

    $JWT_SECRET_KEY = -join ((65..90)+(97..122)+(48..57) |
        Get-Random -Count 32 |
        ForEach-Object {[char]$_})

    Write-Host "Generated JWT_SECRET_KEY: $JWT_SECRET_KEY"

    $env:JWT_SECRET_KEY = $JWT_SECRET_KEY
}

Write-Host "=========================================="
Write-Host "Setting up Lambda Function"
Write-Host "=========================================="
Write-Host "Function Name: $FUNCTION_NAME"
Write-Host "Region: $AWS_REGION"
Write-Host "Account ID: $AWS_ACCOUNT_ID"
Write-Host ""

# Get ECR repository
$REPO_URI = aws ecr describe-repositories `
    --repository-names "clipsense-lambda-api" `
    --region $AWS_REGION `
    --query "repositories[0].repositoryUri" `
    --output text

if (-not $REPO_URI) {
    Write-Host "Error: ECR repository not found. Run setup-ecr.ps1 first."
    exit 1
}

$IMAGE_URI = "$REPO_URI`:latest"

Write-Host "Using image:"
Write-Host $IMAGE_URI
Write-Host ""

# Check IAM role
try {

    $ROLE_ARN = aws iam get-role `
        --role-name $ROLE_NAME `
        --query "Role.Arn" `
        --output text 2>$null

    Write-Host "IAM role already exists:"
    Write-Host $ROLE_ARN
}
catch {

    Write-Host "Creating IAM role..."

$trustPolicy = @"
{
 "Version": "2012-10-17",
 "Statement": [{
   "Effect": "Allow",
   "Principal": {"Service": "lambda.amazonaws.com"},
   "Action": "sts:AssumeRole"
 }]
}
"@

    $trustFile = "$env:TEMP\lambda-trust-policy.json"

    $trustPolicy | Out-File $trustFile -Encoding ascii

    $ROLE_ARN = aws iam create-role `
        --role-name $ROLE_NAME `
        --assume-role-policy-document file://$trustFile `
        --query "Role.Arn" `
        --output text

    Write-Host "Role created:"
    Write-Host $ROLE_ARN

    # Attach Lambda basic policy
    aws iam attach-role-policy `
        --role-name $ROLE_NAME `
        --policy-arn "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"

$policy = @"
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
"@

    $policyFile = "$env:TEMP\lambda-policy.json"

    $policy | Out-File $policyFile -Encoding ascii

    aws iam put-role-policy `
        --role-name $ROLE_NAME `
        --policy-name "ClipSenseLambdaPolicy" `
        --policy-document file://$policyFile

    Write-Host "Policies attached"

    Write-Host "Waiting for IAM propagation..."
    Start-Sleep -Seconds 10
}

# Check Lambda function
try {

    $FUNCTION_ARN = aws lambda get-function `
        --function-name $FUNCTION_NAME `
        --region $AWS_REGION `
        --query "Configuration.FunctionArn" `
        --output text 2>$null

    Write-Host "Lambda function already exists:"
    Write-Host $FUNCTION_ARN
}
catch {

    Write-Host "Creating Lambda function..."

    $SQS_QUEUE_URL = aws sqs get-queue-url `
        --queue-name "clipsense-processing-queue" `
        --region $AWS_REGION `
        --query "QueueUrl" `
        --output text

    $envVars = "AWS_REGION=$AWS_REGION,AWS_S3_BUCKET=$($env:AWS_S3_BUCKET),DYNAMO_USERS_TABLE=$($env:DYNAMO_USERS_TABLE),DYNAMO_PROJECTS_TABLE=$($env:DYNAMO_PROJECTS_TABLE),SQS_QUEUE_URL=$SQS_QUEUE_URL,JWT_SECRET_KEY=$($env:JWT_SECRET_KEY),GEMINI_API_KEY=$($env:GEMINI_API_KEY)"

    $FUNCTION_ARN = aws lambda create-function `
        --function-name $FUNCTION_NAME `
        --package-type Image `
        --code ImageUri=$IMAGE_URI `
        --role $ROLE_ARN `
        --region $AWS_REGION `
        --timeout 30 `
        --memory-size 512 `
        --environment "Variables={$envVars}" `
        --query "FunctionArn" `
        --output text

    Write-Host "Lambda function created:"
    Write-Host $FUNCTION_ARN
}

Write-Host ""
Write-Host "=========================================="
Write-Host "Lambda Setup Complete"
Write-Host "=========================================="
Write-Host "Function ARN:"
Write-Host $FUNCTION_ARN
Write-Host ""
Write-Host "Next step:"
Write-Host "Run setup-api-gateway.ps1 to expose the API"