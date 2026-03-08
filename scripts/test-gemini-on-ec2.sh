#!/bin/bash
# Quick test script to verify Gemini API key on EC2 worker

echo "============================================================"
echo "Testing Gemini API Key on EC2 Worker"
echo "============================================================"
echo ""

# Check if docker is running
if ! docker ps &> /dev/null; then
    echo "❌ ERROR: Docker is not running or not accessible"
    exit 1
fi

# Check if worker container exists
if ! docker ps -a | grep -q clipsense-worker; then
    echo "❌ ERROR: clipsense-worker container not found"
    exit 1
fi

echo "✓ Docker is running"
echo "✓ Worker container found"
echo ""

# Get the API key from the container's environment
echo "🔍 Checking Gemini API key in worker container..."
API_KEY=$(docker exec clipsense-worker printenv GEMINI_API_KEY 2>/dev/null)

if [ -z "$API_KEY" ]; then
    echo "❌ ERROR: GEMINI_API_KEY not found in container environment"
    echo ""
    echo "Try restarting the worker:"
    echo "  docker restart clipsense-worker"
    exit 1
fi

echo "✓ Found API key: ${API_KEY:0:20}...${API_KEY: -4}"
echo ""

# Test the API key with a simple Python script
echo "🔍 Testing if API key is valid..."
echo ""

docker exec clipsense-worker python3 -c "
import os
import sys

api_key = os.getenv('GEMINI_API_KEY')
print(f'API Key: {api_key[:20]}...{api_key[-4:]}')

try:
    import google.generativeai as genai
    genai.configure(api_key=api_key)
    
    # Try to list models (lightweight test)
    models = list(genai.list_models())
    print(f'✅ SUCCESS! API key is VALID')
    print(f'   Found {len(models)} available Gemini models')
    
    # Quick generation test
    model = genai.GenerativeModel('gemini-1.5-flash')
    response = model.generate_content('Say hello in one word')
    print(f'   Test generation: {response.text.strip()}')
    
except Exception as e:
    print(f'❌ FAILED! API key is INVALID')
    print(f'   Error: {str(e)}')
    sys.exit(1)
"

if [ $? -eq 0 ]; then
    echo ""
    echo "============================================================"
    echo "✅ Gemini API key is working correctly!"
    echo "============================================================"
    exit 0
else
    echo ""
    echo "============================================================"
    echo "❌ Gemini API key test failed"
    echo "============================================================"
    echo ""
    echo "Possible solutions:"
    echo "1. Update the API key in /etc/clipsense/.env"
    echo "2. Restart the worker: docker restart clipsense-worker"
    echo "3. Generate a new key at: https://aistudio.google.com/app/apikey"
    exit 1
fi
