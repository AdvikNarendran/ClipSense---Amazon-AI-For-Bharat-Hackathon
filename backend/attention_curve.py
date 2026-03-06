"""
Attention Curve Generator for ClipSense.
Combines emotion intensity and semantic importance into a unified attention timeline.
Identifies peaks as potential clip candidates.
"""

import logging

logger = logging.getLogger("clipsense.attention")


def generate_attention_curve(emotion_scores, semantic_scores=None, video_duration=0):
    """
    Generate a unified attention curve from emotion and semantic signals.
    
    emotion_scores: list of dicts with {timestamp, intensity, joy, sadness, anger, surprise, neutral}
    semantic_scores: optional list of dicts with {start_time, end_time, importance_score}
    video_duration: total video length in seconds
    
    Returns: {
        "curve": [{timestamp, score}],   # 0-100 normalized
        "peaks": [{timestamp, score}],   # local maxima
        "avgAttention": float,
        "peakMoments": int
    }
    """
    if not emotion_scores:
        return {"curve": [], "peaks": [], "avgAttention": 0, "peakMoments": 0}

    # Build emotion intensity timeline
    emotion_map = {}
    for e in emotion_scores:
        t = round(e["timestamp"], 1)
        emotion_map[t] = e.get("intensity", 0.0)

    # Build semantic importance map (if available)
    semantic_map = {}
    if semantic_scores:
        for s in semantic_scores:
            start = s.get("start_time", 0)
            end = s.get("end_time", start + 5)
            score = s.get("importance_score", 50) / 100.0  # normalize to 0-1
            t = round(start, 1)
            while t < end:
                semantic_map[t] = score
                t = round(t + 0.5, 1)

    # Combine signals
    # Weights: emotion=0.5, semantic=0.5 (when both available)
    # When semantic not available: emotion=1.0
    all_timestamps = sorted(set(list(emotion_map.keys()) + list(semantic_map.keys())))
    
    curve = []
    for t in all_timestamps:
        emo = emotion_map.get(t, 0.0)
        sem = semantic_map.get(t, 0.5)  # default to 0.5 (neutral importance) if no semantic data
        
        if semantic_scores:
            raw = 0.5 * emo + 0.5 * sem
        else:
            raw = emo
        
        curve.append({"timestamp": t, "score": raw})

    # Normalize to 0-100
    if curve:
        max_score = max(p["score"] for p in curve) or 1.0
        min_score = min(p["score"] for p in curve)
        score_range = max_score - min_score or 1.0
        
        for p in curve:
            p["score"] = round(((p["score"] - min_score) / score_range) * 100, 1)

    # Find peaks (local maxima with min_distance of 30s)
    peaks = _find_peaks(curve, min_distance=30.0)

    avg_attention = round(sum(p["score"] for p in curve) / len(curve), 1) if curve else 0

    logger.info("Attention curve generated: %d points, %d peaks, avg=%.1f",
                len(curve), len(peaks), avg_attention)

    return {
        "curve": curve,
        "peaks": peaks,
        "avgAttention": avg_attention,
        "peakMoments": len(peaks)
    }


def _find_peaks(curve, min_distance=30.0):
    """Find local maxima in the attention curve."""
    if len(curve) < 3:
        return curve

    peaks = []
    for i in range(1, len(curve) - 1):
        if curve[i]["score"] > curve[i - 1]["score"] and curve[i]["score"] > curve[i + 1]["score"]:
            # Check minimum distance from last peak
            if not peaks or (curve[i]["timestamp"] - peaks[-1]["timestamp"]) >= min_distance:
                peaks.append(curve[i].copy())

    # Sort by score descending
    peaks.sort(key=lambda p: p["score"], reverse=True)
    
    return peaks
