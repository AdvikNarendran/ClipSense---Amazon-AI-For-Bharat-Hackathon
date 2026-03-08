#!/bin/bash
# Start the ClipSense worker container using existing Docker image

echo "=== Starting ClipSense Worker Container ==="

# Check if container already exists
if docker ps -a | grep -q clipsense-worker; then
    echo "Container exists. Checking status..."
    if docker ps | grep -q clipsense-worker; then
        echo "✅ Container is already running"
        exit 0
    else
        echo "Container exists but is stopped. Starting it..."
        docker start clipsense-worker
        echo "✅ Container started"
        exit 0
    fi
fi

# Container doesn't exist, create it from existing image
echo "Container doesn't exist. Creating new container..."

# Find the most recent clipsense-worker image
IMAGE=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep clipsense-worker | head -1)

if [ -z "$IMAGE" ]; then
    echo "❌ No clipsense-worker image found!"
    echo "Available images:"
    docker images
    exit 1
fi

echo "Using image: $IMAGE"

# Create and start container
docker run -d \
  --name clipsense-worker \
  --env-file /etc/clipsense/.env \
  --restart unless-stopped \
  $IMAGE

if [ $? -eq 0 ]; then
    echo "✅ Container created and started successfully"
    echo ""
    echo "Checking container logs..."
    sleep 3
    docker logs --tail 20 clipsense-worker
else
    echo "❌ Failed to start container"
    exit 1
fi
