#!/bin/bash
# Check email configuration on EC2

echo "=== Checking Email Configuration on EC2 ==="

# Check if environment variables are set in the container
echo "1. Checking SENDER_EMAIL:"
docker exec clipsense-worker printenv SENDER_EMAIL

echo ""
echo "2. Checking SENDER_PASSWORD (first 10 chars):"
docker exec clipsense-worker bash -c 'echo $SENDER_PASSWORD | head -c 10'

echo ""
echo "3. Checking if email_utils.py exists:"
docker exec clipsense-worker ls -la /app/email_utils.py

echo ""
echo "=== Email Configuration in /etc/clipsense/.env ==="
grep "SENDER_" /etc/clipsense/.env
