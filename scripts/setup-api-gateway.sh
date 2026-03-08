#!/bin/bash
# Setup API Gateway for ClipSense Lambda API

set -e

API_NAME="clipsense-api"
FUNCTION_NAME="clipsense-api"
AWS_REGION="${AWS_REGION:-ap-south-1}"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "=========================================="
echo "Setting up API Gateway"
echo "=========================================="
echo "API Name: $API_NAME"
echo "Region: $AWS_REGION"
echo ""

# Get Lambda function ARN
FUNCTION_ARN=$(aws lambda get-function \
    --function-name "$FUNCTION_NAME" \
    --region "$AWS_REGION" \
    --query 'Configuration.FunctionArn' \
    --output text)

if [ -z "$FUNCTION_ARN" ]; then
    echo "Error: Lambda function not found. Run setup-lambda.sh first."
    exit 1
fi

echo "Lambda ARN: $FUNCTION_ARN"
echo ""

# Check if API already exists
API_ID=$(aws apigatewayv2 get-apis \
    --region "$AWS_REGION" \
    --query "Items[?Name=='$API_NAME'].ApiId" \
    --output text 2>/dev/null || echo "")

if [ -n "$API_ID" ]; then
    echo "✓ API Gateway already exists: $API_ID"
else
    echo "Creating HTTP API Gateway..."
    API_ID=$(aws apigatewayv2 create-api \
        --name "$API_NAME" \
        --protocol-type HTTP \
        --region "$AWS_REGION" \
        --cors-configuration "AllowOrigins=*,AllowMethods=GET,POST,PUT,DELETE,OPTIONS,AllowHeaders=Authorization,Content-Type" \
        --query 'ApiId' \
        --output text)
    
    echo "✓ API created: $API_ID"
fi

# Create integration
echo "Creating Lambda integration..."
INTEGRATION_ID=$(aws apigatewayv2 create-integration \
    --api-id "$API_ID" \
    --integration-type AWS_PROXY \
    --integration-uri "$FUNCTION_ARN" \
    --payload-format-version 2.0 \
    --region "$AWS_REGION" \
    --query 'IntegrationId' \
    --output text 2>/dev/null || \
    aws apigatewayv2 get-integrations \
        --api-id "$API_ID" \
        --region "$AWS_REGION" \
        --query 'Items[0].IntegrationId' \
        --output text)

echo "✓ Integration ID: $INTEGRATION_ID"

# Create route
echo "Creating route..."
aws apigatewayv2 create-route \
    --api-id "$API_ID" \
    --route-key 'ANY /api/{proxy+}' \
    --target "integrations/$INTEGRATION_ID" \
    --region "$AWS_REGION" 2>/dev/null || echo "✓ Route already exists"

# Create default stage
echo "Creating default stage..."
aws apigatewayv2 create-stage \
    --api-id "$API_ID" \
    --stage-name '$default' \
    --auto-deploy \
    --region "$AWS_REGION" 2>/dev/null || echo "✓ Stage already exists"

# Grant API Gateway permission to invoke Lambda
echo "Granting API Gateway invoke permission..."
aws lambda add-permission \
    --function-name "$FUNCTION_NAME" \
    --statement-id "apigateway-invoke" \
    --action "lambda:InvokeFunction" \
    --principal apigateway.amazonaws.com \
    --source-arn "arn:aws:execute-api:${AWS_REGION}:${AWS_ACCOUNT_ID}:${API_ID}/*/*" \
    --region "$AWS_REGION" 2>/dev/null || echo "✓ Permission already exists"

# Get API endpoint
API_ENDPOINT=$(aws apigatewayv2 get-api \
    --api-id "$API_ID" \
    --region "$AWS_REGION" \
    --query 'ApiEndpoint' \
    --output text)

echo ""
echo "=========================================="
echo "API Gateway Setup Complete"
echo "=========================================="
echo "API Endpoint: $API_ENDPOINT"
echo ""
echo "Test the API:"
echo "  curl $API_ENDPOINT/api/health"
echo ""
echo "Add this to your frontend environment:"
echo "  NEXT_PUBLIC_API_URL=$API_ENDPOINT"
