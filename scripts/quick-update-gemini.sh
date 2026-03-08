#!/bin/bash
# Quick update script for EC2 worker Gemini API key
# Run this in AWS Session Manager after connecting to EC2 instance

NEW_KEY="AIzaSyD6MTHohggalVZfii0Jbu5AkmgCkcQ59_U"

echo "=========================================="
echo "Updating Gemini API Key on EC2 Worker"
echo "=========================================="
echo ""

# Update the .env file
echo "Updating /etc/clipsense/.env..."
sudo sed -i "s/^GEMINI_API_KEY=.*/GEMINI_API_KEY=$NEW_KEY/" /etc/clipsense/.env

# Verify the update
echo ""
echo "Verifying update..."
sudo grep "GEMINI_API_KEY" /etc/clipsense/.env

# Restart worker
echo ""
echo "Restarting worker container..."
docker restart clipsense-worker

# Wait a moment
sleep 3

# Show logs
echo ""
echo "=========================================="
echo "Worker Status"
echo "=========================================="
docker ps | grep clipsense-worker

echo ""
echo "=========================================="
echo "Recent Worker Logs"
echo "=========================================="
docker logs clipsense-worker --tail 20

echo ""
echo "✅ Gemini API key updated successfully!"
echo ""
echo "To monitor worker in real-time, run:"
echo "  docker logs clipsense-worker -f"
echo ""
