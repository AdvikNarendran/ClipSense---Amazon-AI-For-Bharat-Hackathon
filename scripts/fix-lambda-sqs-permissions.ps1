# Fix Lambda SQS Permissions
# This script adds SQS SendMessage permissions to the Lambda IAM role

Write-Host "=========================================="
Write-Host "Adding SQS Permissions to Lambda IAM Role"
Write-Host "=========================================="

$ROLE_NAME = "clipsense-api-role-6d4z4elb"
$QUEUE_ARN = "arn:aws:sqs:ap-south-1:732772501496:clipsense-processing-queue"

Write-Host "Role: $ROLE_NAME"
Write-Host "Queue ARN: $QUEUE_ARN"
Write-Host ""

# Create policy document
$policyDocument = @"
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "sqs:SendMessage",
        "sqs:GetQueueUrl"
      ],
      "Resource": "$QUEUE_ARN"
    }
  ]
}
"@

Write-Host "Adding SQS permissions to Lambda role..."

# Add inline policy to the role
aws iam put-role-policy `
    --role-name $ROLE_NAME `
    --policy-name SQSSendMessagePolicy `
    --policy-document $policyDocument

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "=========================================="
    Write-Host "✅ Permissions Added Successfully!"
    Write-Host "=========================================="
    Write-Host ""
    Write-Host "Lambda can now send messages to SQS queue."
    Write-Host "Try uploading a video to test end-to-end processing!"
} else {
    Write-Host ""
    Write-Host "❌ Failed to add permissions"
    Write-Host "Exit code: $LASTEXITCODE"
}
