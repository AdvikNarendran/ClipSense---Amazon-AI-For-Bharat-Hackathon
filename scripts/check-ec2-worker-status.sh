#!/bin/bash
# Check EC2 worker status and available Docker images

echo "=== Checking Docker Container Status ==="
docker ps -a

echo ""
echo "=== Available Docker Images ==="
docker images

echo ""
echo "=== Checking if worker is running ==="
docker ps | grep clipsense-worker || echo "❌ Worker container is NOT running"

echo ""
echo "=== Checking environment file ==="
if [ -f /etc/clipsense/.env ]; then
    echo "✅ Environment file exists at /etc/clipsense/.env"
    echo "Checking Gemini API key..."
    grep "GEMINI_API_KEY" /etc/clipsense/.env | head -c 50
    echo "..."
else
    echo "❌ Environment file NOT found at /etc/clipsense/.env"
fi
