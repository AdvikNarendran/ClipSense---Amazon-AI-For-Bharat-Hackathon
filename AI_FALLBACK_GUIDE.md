# AI Model Fallback Strategy

## How It Works

ClipSense uses a smart fallback system for AI analysis:

```
1. Try AWS Bedrock (Claude 3 Haiku) ✅
   ↓ (if fails)
2. Fallback to Google Gemini ✅
   ↓ (if fails)
3. Return error ❌
```

## Primary: AWS Bedrock

**Model**: `anthropic.claude-3-haiku-20240307-v1:0`

**Advantages**:
- Fast and cost-effective
- Integrated with AWS
- No additional API keys needed (uses IAM)

**When it fails**:
- Bedrock not enabled in your AWS region
- IAM permissions missing
- Model quota exceeded
- Service temporarily unavailable

## Fallback: Google Gemini

**Models** (tried in order):
1. `gemini-1.5-flash` (fastest, most reliable)
2. `gemini-1.5-pro` (more capable)
3. `gemini-pro` (legacy fallback)

**Advantages**:
- Highly reliable
- Good performance
- Already configured in your .env

**Requirements**:
- `GEMINI_API_KEY` must be set in .env
- `google-generativeai` package installed (already in requirements)

## Configuration

### Your Current Setup

From your `.env` file:
```bash
GEMINI_API_KEY=AIzaSyDp2hsS2hM5JNpt_tP35eqgeuG4gWU-XdM
BEDROCK_MODEL_ID=anthropic.claude-3-haiku-20240307-v1:0
```

✅ Both are configured and ready!

### Enable Bedrock (Optional)

If Bedrock is not working, you need to:

1. **Enable Bedrock in AWS Console**:
   - Go to AWS Bedrock Console
   - Click "Model access"
   - Request access to "Claude 3 Haiku"
   - Wait for approval (usually instant)

2. **Verify IAM Permissions**:
   Your Lambda and EC2 roles need:
   ```json
   {
     "Effect": "Allow",
     "Action": ["bedrock:InvokeModel"],
     "Resource": "arn:aws:bedrock:*::foundation-model/*"
   }
   ```

## Testing

### Test Bedrock
```python
from aws_utils import aws_ai

result = aws_ai.analyze_with_bedrock("Summarize this: Hello world")
print(result)
```

### Test Gemini Fallback
```python
# Temporarily break Bedrock to test fallback
result = aws_ai._fallback_to_gemini("Summarize this: Hello world")
print(result)
```

## Logs

Watch the logs to see which model is being used:

**Bedrock Success**:
```
[INFO] Bedrock analysis successful
```

**Gemini Fallback**:
```
[ERROR] Bedrock Error: ..., falling back to Gemini
[INFO] Gemini fallback successful with model: gemini-1.5-flash
```

**Both Failed**:
```
[ERROR] Bedrock Error: ...
[ERROR] All Gemini models failed
```

## Cost Comparison

| Model | Cost per 1M tokens | Speed |
|-------|-------------------|-------|
| Bedrock Claude 3 Haiku | $0.25 | Fast |
| Gemini 1.5 Flash | FREE (60 req/min) | Very Fast |
| Gemini 1.5 Pro | FREE (2 req/min) | Slower |

**Recommendation**: Use Gemini for development (free), enable Bedrock for production (faster, more reliable).

## Troubleshooting

### Bedrock Not Working
- Check if Bedrock is enabled in your AWS region (ap-south-1)
- Verify IAM permissions include `bedrock:InvokeModel`
- Check CloudWatch logs for detailed errors

### Gemini Not Working
- Verify `GEMINI_API_KEY` is set correctly
- Check API quota limits (60 requests/minute for free tier)
- Ensure `google-generativeai` package is installed

### Both Not Working
- Check internet connectivity
- Verify API keys are valid
- Check application logs for detailed errors

## Summary

✅ **Your setup is ready!**
- Bedrock configured with Claude 3 Haiku
- Gemini configured as fallback
- Automatic failover between models
- No manual intervention needed

The system will automatically use the best available model for each request.
