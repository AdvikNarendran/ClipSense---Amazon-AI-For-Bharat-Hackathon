import logging
import json
import re
import os
import boto3
import librosa
import numpy as np
from dotenv import load_dotenv

load_dotenv()

logger = logging.getLogger("clipsense.emotion")

def analyze_emotions(segments, audio_path=None, engine=None):
    """
    Analyze transcript segments and audio for emotions using Bedrock.
    
    segments: list of dicts {'start': float, 'end': float, 'text': str}
    audio_path: path to the local audio file for acoustic analysis
    engine: AIEngine instance
    """
    if not segments:
        return []

    # 1. Acoustic Feature Extraction (if audio_path is provided)
    acoustic_features = {}
    if audio_path and os.path.exists(audio_path):
        try:
            acoustic_features = _extract_acoustic_features(audio_path, segments)
            logger.info("Acoustic features extracted for %d segments", len(segments))
        except Exception as e:
            logger.error("Error extracting acoustic features: %s", e)

    # 2. Group segments into ~5-second windows
    windows = _create_windows(segments, window_size=5.0)
    if not windows:
        return []

    # 3. AI Generation with centralized fallback
    if engine is None:
        from ai_engine import AIEngine
        engine = AIEngine()
    
    all_scores = []
    batch_size = 20
    
    for i in range(0, len(windows), batch_size):
        batch = windows[i:i + batch_size]
        
        # Build prompt with text AND acoustic data
        prompt_data = []
        for w in batch:
            # Find closest acoustic feature if available
            feature = acoustic_features.get(round(w['start'], 1), {"energy": "medium", "pitch": "normal"})
            prompt_data.append({
                "time": f"{w['start']:.1f}-{w['end']:.1f}s",
                "text": w['text'][:200],
                "acoustic_energy": feature.get("energy"),
                "acoustic_pitch": feature.get("pitch")
            })

        prompt = f"""Analyze the emotional tone of these video segments using both TEXT and ACOUSTIC metadata.
        
        Data (Time, Text, Acoustic Signal):
        {json.dumps(prompt_data, indent=2)}

        Return a valid JSON array of objects (one per segment).
        Metrics (0.0 to 1.0): joy, sadness, anger, surprise, neutral, intensity.
        
        Intensity: How 'high energy' or 'engaging' the moment is.
        Return EXACTLY {len(batch)} objects.
        """
        
        try:
            # Use centralized AIEngine fallback logic (Bedrock -> Gemini)
            text_response = engine.generate_text(prompt)
            
            # Robust JSON extraction
            match = re.search(r'\[\s*\{.*\}\s*\]', text_response, re.DOTALL)
            if match:
                text_response = match.group(0)
            
            # Clean markdown if present
            text_response = text_response.replace('```json', '').replace('```', '').strip()
            
            scores = json.loads(text_response)
            
            for idx, score in enumerate(scores):
                if idx < len(batch):
                    score["timestamp"] = batch[idx]["start"]
                    score["end_time"] = batch[idx]["end"]
                    all_scores.append(score)
                    
        except Exception as e:
            logger.warning("Emotion analysis fallback triggered for segment batch: %s", e)
            for w in batch:
                all_scores.append({
                    "timestamp": w["start"], "end_time": w["end"],
                    "joy": 0.0, "sadness": 0.0, "anger": 0.0, 
                    "surprise": 0.0, "neutral": 1.0, "intensity": 0.1
                })
                
    return all_scores

def _extract_acoustic_features(audio_path, segments):
    """Uses librosa to extract energy and pitch profiles for transcription segments."""
    y, sr = librosa.load(audio_path, sr=22050)
    
    # Calculate Root Mean Square (RMS) energy per frame
    rms = librosa.feature.rms(y=y)[0]
    times = librosa.frames_to_time(np.arange(len(rms)), sr=sr)
    
    features = {}
    for seg in segments:
        start, end = seg['start'], seg['end']
        # Find rms indices for this segment
        mask = (times >= start) & (times <= end)
        if any(mask):
            seg_rms = rms[mask]
            energy_val = np.mean(seg_rms)
            
            # Categorize energy
            if energy_val > 0.1: energy_str = "high"
            elif energy_val > 0.03: energy_str = "medium"
            else: energy_str = "low"
            
            features[round(start, 1)] = {
                "energy": energy_str,
                "pitch": "normal" # Simple placeholder, pitch extraction is more complex
            }
            
    return features

def _create_windows(segments, window_size=5.0):
    if not segments: return []
    total_duration = segments[-1]["end"]
    windows = []
    current_start = 0.0
    while current_start < total_duration:
        window_end = min(current_start + window_size, total_duration)
        texts = [s.get("text", "").strip() for s in segments if s["end"] > current_start and s["start"] < window_end]
        if texts:
            windows.append({"start": current_start, "end": window_end, "text": " ".join(texts)})
        current_start += window_size
    return windows
