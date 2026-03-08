import google.generativeai as genai
import os
from dotenv import load_dotenv

load_dotenv()
genai.configure(api_key=os.getenv("GEMINI_API_KEY"))

for model in genai.list_models():
    # Filter for models that support content generation (e.g., text, images)
    if 'generateContent' in model.supported_generation_methods:
        print(f"Name: {model.name}")
