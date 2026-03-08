# Create ECR repository and push worker image

Write-Host "=== Creating ECR Repository for Worker ===" -ForegroundColor Cyan

# Create the repository
Write-Host "1. Creating clipsense-worker repository in ECR..."
aws ecr create-repository `
    --repository-name clipsense-worker `
    --region ap-south-1 `
    --image-scanning-configuration scanOnPush=true `
    2>$null

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Repository created" -ForegroundColor Green
} else {
    Write-Host "Repository might already exist, continuing..." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "2. Logging into ECR..."
aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin 732772501496.dkr.ecr.ap-south-1.amazonaws.com

Write-Host ""
Write-Host "3. Tagging worker image..."
docker tag clipsense-worker:latest 732772501496.dkr.ecr.ap-south-1.amazonaws.com/clipsense-worker:latest

Write-Host ""
Write-Host "4. Pushing to ECR..."
docker push 732772501496.dkr.ecr.ap-south-1.amazonaws.com/clipsense-worker:latest

Write-Host ""
Write-Host "=== Worker Image Pushed to ECR ===" -ForegroundColor Green
Write-Host ""
Write-Host "Next: Update EC2 worker container"
Write-Host "Run these commands via EC2 Instance Connect:"
Write-Host ""
Write-Host "docker pull 732772501496.dkr.ecr.ap-south-1.amazonaws.com/clipsense-worker:latest"
Write-Host "docker stop clipsense-worker"
Write-Host "docker rm clipsense-worker"
Write-Host "docker run -d --name clipsense-worker --env-file /etc/clipsense/.env --restart unless-stopped 732772501496.dkr.ecr.ap-south-1.amazonaws.com/clipsense-worker:latest"
Write-Host "docker logs --tail 30 clipsense-worker"
