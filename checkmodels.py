import google.generativeai as genai

genai.configure(api_key="AIzaSyDp2hsS2hM5JNpt_tP35eqgeuG4gWU-XdM")

for model in genai.list_models():
    # Filter for models that support content generation (e.g., text, images)
    if 'generateContent' in model.supported_generation_methods:
        print(f"Name: {model.name}")
