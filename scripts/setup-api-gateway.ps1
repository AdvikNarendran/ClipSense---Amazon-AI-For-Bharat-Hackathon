# Setup API Gateway for ClipSense Lambda API

$ErrorActionPreference = "Stop"

# Load environment variables
. "$PSScriptRoot\load-env.ps1"

$API_NAME = "clipsense-api"
$FUNCTION_NAME = "clipsense-api"
$AWS_REGION = $env:AWS_REGION
$AWS_ACCOUNT_ID = aws sts get-caller-identity --query Account --output text

if (-not $AWS_REGION) {
    Write-Host "Error: AWS_REGION not set in .env"
    exit 1
}

Write-Host "=========================================="
Write-Host "Setting up API Gateway"
Write-Host "=========================================="
Write-Host "API Name: $API_NAME"
Write-Host "Region: $AWS_REGION"
Write-Host ""

# Get Lambda ARN
$FUNCTION_ARN = aws lambda get-function `
    --function-name $FUNCTION_NAME `
    --region $AWS_REGION `
    --query "Configuration.FunctionArn" `
    --output text

if (-not $FUNCTION_ARN) {
    Write-Host "Lambda not found. Run setup-lambda.ps1 first."
    exit 1
}

Write-Host "Lambda ARN:"
Write-Host $FUNCTION_ARN
Write-Host ""

# Check if API exists
$API_ID = aws apigatewayv2 get-apis `
    --region $AWS_REGION `
    --query "Items[?Name=='$API_NAME'].ApiId" `
    --output text

if ($API_ID) {

    Write-Host "API already exists:"
    Write-Host $API_ID

}
else {

    Write-Host "Creating HTTP API..."

    $API_ID = aws apigatewayv2 create-api `
        --name $API_NAME `
        --protocol-type HTTP `
        --region $AWS_REGION `
        --cors-configuration AllowOrigins="*",AllowMethods="GET,POST,PUT,DELETE,OPTIONS",AllowHeaders="Authorization,Content-Type" `
        --query "ApiId" `
        --output text

    Write-Host "API created:"
    Write-Host $API_ID
}

# Create integration
Write-Host "Creating Lambda integration..."

$INTEGRATION_ID = aws apigatewayv2 create-integration `
    --api-id $API_ID `
    --integration-type AWS_PROXY `
    --integration-uri $FUNCTION_ARN `
    --payload-format-version 2.0 `
    --region $AWS_REGION `
    --query "IntegrationId" `
    --output text

Write-Host "Integration ID:"
Write-Host $INTEGRATION_ID

# Create route
Write-Host "Creating route..."

try {

    aws apigatewayv2 create-route `
        --api-id $API_ID `
        --route-key "ANY /api/{proxy+}" `
        --target "integrations/$INTEGRATION_ID" `
        --region $AWS_REGION

}
catch {

    Write-Host "Route already exists"

}

# Create stage
Write-Host "Creating stage..."

try {

    aws apigatewayv2 create-stage `
        --api-id $API_ID `
        --stage-name '$default' `
        --auto-deploy `
        --region $AWS_REGION

}
catch {

    Write-Host "Stage already exists"

}

# Grant invoke permission
Write-Host "Granting API Gateway permission..."

try {

    aws lambda add-permission `
        --function-name $FUNCTION_NAME `
        --statement-id "apigateway-invoke" `
        --action "lambda:InvokeFunction" `
        --principal apigateway.amazonaws.com `
        --source-arn "arn:aws:execute-api:${AWS_REGION}:${AWS_ACCOUNT_ID}:${API_ID}/*/*" `
        --region $AWS_REGION

}
catch {

    Write-Host "Permission already exists"

}

# Get endpoint
$API_ENDPOINT = aws apigatewayv2 get-api `
    --api-id $API_ID `
    --region $AWS_REGION `
    --query "ApiEndpoint" `
    --output text

Write-Host ""
Write-Host "=========================================="
Write-Host "API Gateway Setup Complete"
Write-Host "=========================================="
Write-Host "API Endpoint:"
Write-Host $API_ENDPOINT
Write-Host ""

Write-Host "Test API:"
Write-Host "curl $API_ENDPOINT/api/health"
Write-Host ""

Write-Host "Frontend environment variable:"
Write-Host "NEXT_PUBLIC_API_URL=$API_ENDPOINT"