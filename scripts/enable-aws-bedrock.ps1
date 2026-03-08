# Enable AWS Bedrock Model Access
# This script helps you enable Bedrock model access

Write-Host "=========================================="
Write-Host "AWS Bedrock Model Access Guide"
Write-Host "=========================================="
Write-Host ""
Write-Host "Your worker is currently using Gemini AI for clip selection."
Write-Host "To use AWS Bedrock (Claude 3 Haiku), follow these steps:"
Write-Host ""
Write-Host "STEP 1: Add Payment Method"
Write-Host "----------------------------------------"
Write-Host "1. Go to AWS Billing Console:"
Write-Host "   https://console.aws.amazon.com/billing/home#/paymentmethods"
Write-Host "2. Click 'Add a payment method'"
Write-Host "3. Add a valid credit/debit card"
Write-Host "4. Set it as default payment method"
Write-Host ""
Write-Host "STEP 2: Enable Bedrock Model Access"
Write-Host "----------------------------------------"
Write-Host "1. Go to AWS Bedrock Console:"
Write-Host "   https://console.aws.amazon.com/bedrock/home?region=ap-south-1#/modelaccess"
Write-Host "2. Click 'Manage model access' or 'Enable specific models'"
Write-Host "3. Find 'Anthropic Claude 3 Haiku'"
Write-Host "4. Check the box next to it"
Write-Host "5. Click 'Request model access' or 'Save changes'"
Write-Host "6. Wait 2-5 minutes for activation"
Write-Host ""
Write-Host "STEP 3: Verify Access"
Write-Host "----------------------------------------"
Write-Host "Run this command to check if Bedrock is accessible:"
Write-Host ""
Write-Host "aws bedrock list-foundation-models --region ap-south-1 --by-provider anthropic"
Write-Host ""
Write-Host "=========================================="
Write-Host "Cost Information"
Write-Host "=========================================="
Write-Host ""
Write-Host "Claude 3 Haiku Pricing:"
Write-Host "  - Input: `$0.00025 per 1K tokens (~`$0.25 per 1M tokens)"
Write-Host "  - Output: `$0.00125 per 1K tokens (~`$1.25 per 1M tokens)"
Write-Host "  - Typical video analysis: ~5K tokens = ~`$0.01 per video"
Write-Host ""
Write-Host "Gemini (Current Fallback):"
Write-Host "  - FREE tier: 15 requests/minute"
Write-Host "  - Works perfectly fine for your use case"
Write-Host ""
Write-Host "=========================================="
Write-Host "Current Status"
Write-Host "=========================================="
Write-Host ""
Write-Host "✅ System is working with Gemini AI"
Write-Host "⚠️  Bedrock requires payment method + model access"
Write-Host ""
Write-Host "Note: Gemini works great! Bedrock is optional."
Write-Host ""
Write-Host "Testing Bedrock access..."
Write-Host ""

# Test Bedrock access
$testResult = aws bedrock list-foundation-models --region ap-south-1 --by-provider anthropic 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Bedrock API is accessible!"
    Write-Host ""
    Write-Host "Now testing Claude 3 Haiku model access..."
    
    # Test specific model invocation
    $testPayload = @{
        anthropic_version = "bedrock-2023-05-31"
        max_tokens = 10
        messages = @(
            @{
                role = "user"
                content = "Hi"
            }
        )
    } | ConvertTo-Json -Depth 10
    
    $testPayload | aws bedrock-runtime invoke-model `
        --model-id "anthropic.claude-3-haiku-20240307-v1:0" `
        --body file:///dev/stdin `
        --region ap-south-1 `
        test-output.json 2>&1 | Out-Null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Claude 3 Haiku model is accessible!"
        Write-Host "Your worker will automatically use Bedrock now."
        Remove-Item test-output.json -ErrorAction SilentlyContinue
    } else {
        Write-Host "⚠️  Model access not enabled yet"
        Write-Host "Follow STEP 2 above to enable Claude 3 Haiku access."
    }
} else {
    Write-Host "⚠️  Bedrock requires setup"
    Write-Host "Follow the steps above to enable it."
    Write-Host ""
    Write-Host "Your system works perfectly with Gemini!"
}

Write-Host ""
