#!/bin/bash
# Deploy fixed worker image from ECR and add swap space for memory

set -e

echo "=== Step 1: Login to ECR ==="
aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin 732772501496.dkr.ecr.ap-south-1.amazonaws.com

echo ""
echo "=== Step 2: Pull new worker image from ECR ==="
docker pull 732772501496.dkr.ecr.ap-south-1.amazonaws.com/clipsense-worker:latest

echo ""
echo "=== Step 3: Stop and remove old container if exists ==="
docker stop clipsense-worker 2>/dev/null || true
docker rm clipsense-worker 2>/dev/null || true

echo ""
echo "=== Step 4: Start new container with emotion analysis fix ==="
docker run -d \
  --name clipsense-worker \
  --env-file /etc/clipsense/.env \
  --restart unless-stopped \
  732772501496.dkr.ecr.ap-south-1.amazonaws.com/clipsense-worker:latest

echo ""
echo "=== Step 5: Add 2GB swap space (free memory boost) ==="
if [ -f /swapfile ]; then
  echo "Swap file already exists, skipping creation"
else
  echo "Creating 2GB swap file..."
  sudo dd if=/dev/zero of=/swapfile bs=1M count=2048
  sudo chmod 600 /swapfile
  sudo mkswap /swapfile
  sudo swapon /swapfile
  
  # Make swap permanent across reboots
  if ! grep -q '/swapfile' /etc/fstab; then
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
  fi
fi

echo ""
echo "=== Step 6: Verify memory configuration ==="
free -h

echo ""
echo "=== Step 7: Restart worker to use new memory ==="
docker restart clipsense-worker

echo ""
echo "=== Step 8: Check worker logs ==="
sleep 3
docker logs --tail 50 clipsense-worker

echo ""
echo "=== Deployment Complete ==="
echo "✓ Worker deployed with emotion analysis fix"
echo "✓ Swap space added (2GB RAM + 2GB swap = 4GB total)"
echo "✓ Container running with auto-restart enabled"
echo ""
echo "Monitor logs with: docker logs -f clipsense-worker"
