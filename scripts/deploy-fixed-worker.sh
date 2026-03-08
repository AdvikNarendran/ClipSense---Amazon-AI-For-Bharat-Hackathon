#!/bin/bash
# Deploy the fixed worker.py to EC2

echo "=== Copying Fixed worker.py to EC2 ==="

# Copy the local worker.py (which has the correct fix) to EC2
scp -i ~/.ssh/clipsense-worker-key.pem backend/worker.py ec2-user@65.2.151.98:/tmp/worker.py

# Then on EC2, copy it into the container
ssh -i ~/.ssh/clipsense-worker-key.pem ec2-user@65.2.151.98 << 'EOF'
# Copy the fixed file into the container
docker cp /tmp/worker.py clipsense-worker:/app/worker.py

# Restart the container
docker restart clipsense-worker

# Verify
sleep 3
docker logs --tail 20 clipsense-worker

echo "✅ Fixed worker.py deployed!"
EOF
