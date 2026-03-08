# Add ECR permissions to EC2 Worker IAM Role using AWS managed policy

Write-Host "Adding ECR permissions to ClipSenseEC2WorkerRole..." -ForegroundColor Cyan

# Attach AWS managed policy for ECR read access
Write-Host "Attaching AmazonEC2ContainerRegistryReadOnly policy..."
aws iam attach-role-policy `
    --role-name ClipSenseEC2WorkerRole `
    --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ ECR permissions added successfully" -ForegroundColor Green
    Write-Host ""
    Write-Host "=== Setup Complete ===" -ForegroundColor Green
    Write-Host ""
    Write-Host "Now you can pull the image on EC2:"
    Write-Host "aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin 732772501496.dkr.ecr.ap-south-1.amazonaws.com"
    Write-Host "docker pull 732772501496.dkr.ecr.ap-south-1.amazonaws.com/clipsense-worker:latest"
} else {
    Write-Host "✗ Failed to attach policy" -ForegroundColor Red
    Write-Host ""
    Write-Host "Trying alternative approach with inline policy..."
    
    # Create inline policy instead
    $ecrPolicy = @"
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ecr:GetAuthorizationToken",
                "ecr:BatchCheckLayerAvailability",
                "ecr:GetDownloadUrlForLayer",
                "ecr:BatchGetImage"
            ],
            "Resource": "*"
        }
    ]
}
"@
    
    $policyFile = "ecr-inline-policy.json"
    $ecrPolicy | Out-File -FilePath $policyFile -Encoding utf8
    
    aws iam put-role-policy `
        --role-name ClipSenseEC2WorkerRole `
        --policy-name ECRAccess `
        --policy-document file://$policyFile
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Inline policy added successfully" -ForegroundColor Green
    } else {
        Write-Host "✗ Failed to add inline policy" -ForegroundColor Red
    }
    
    Remove-Item $policyFile -ErrorAction SilentlyContinue
}
