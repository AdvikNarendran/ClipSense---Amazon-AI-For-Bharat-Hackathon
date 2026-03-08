#!/usr/bin/env python3
"""
Quick test script to verify Gemini API key is working on EC2
"""
import os
import sys

def test_gemini_key():
    """Test if Gemini API key is valid and working"""
    
    # Get API key from environment
    api_key = os.getenv('GEMINI_API_KEY')
    
    if not api_key:
        print("❌ ERROR: GEMINI_API_KEY not found in environment")
        return False
    
    print(f"✓ Found API key: {api_key[:20]}...{api_key[-4:]}")
    
    try:
        import google.generativeai as genai
        print("✓ Google Generative AI library imported")
    except ImportError:
        print("❌ ERROR: google-generativeai library not installed")
        print("   Run: pip install google-generativeai")
        return False
    
    try:
        # Configure Gemini
        genai.configure(api_key=api_key)
        print("✓ Gemini configured with API key")
        
        # Try to list models (lightweight test)
        print("\n🔍 Testing API key by listing available models...")
        models = genai.list_models()
        model_count = len(list(models))
        print(f"✓ API key is VALID! Found {model_count} available models")
        
        # Try a simple generation test
        print("\n🔍 Testing text generation...")
        model = genai.GenerativeModel('gemini-1.5-flash')
        response = model.generate_content("Say 'Hello' in one word")
        print(f"✓ Generation test PASSED!")
        print(f"   Response: {response.text.strip()}")
        
        print("\n✅ SUCCESS! Gemini API key is working perfectly!")
        return True
        
    except Exception as e:
        error_msg = str(e)
        print(f"\n❌ ERROR: API key test failed")
        print(f"   Error: {error_msg}")
        
        if "API key not valid" in error_msg or "API_KEY_INVALID" in error_msg:
            print("\n   This means:")
            print("   - The API key format is correct but the key is invalid/expired")
            print("   - You need to generate a new key at: https://aistudio.google.com/app/apikey")
        elif "400" in error_msg:
            print("\n   This means:")
            print("   - The API key might be invalid or disabled")
            print("   - Check if the key was leaked and disabled by Google")
        
        return False

if __name__ == "__main__":
    print("=" * 60)
    print("Gemini API Key Test")
    print("=" * 60)
    print()
    
    success = test_gemini_key()
    
    print()
    print("=" * 60)
    
    sys.exit(0 if success else 1)
