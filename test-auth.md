# Authentication Test Guide

## Issue
Getting 401 Unauthorized when accessing `/api/projects` endpoint.

## Root Cause
This is **EXPECTED BEHAVIOR** - the `/api/projects` endpoint requires authentication via JWT token.

## How Authentication Works

1. **User Registration/Login Flow:**
   - User visits the Amplify app: `https://main.d3ksgup2cfy60v.amplifyapp.com`
   - User registers or logs in
   - Backend returns JWT token
   - Frontend stores token in `localStorage` as `clipsense_token`
   - All subsequent API calls include this token in the `Authorization: Bearer <token>` header

2. **Token Validation:**
   - Lambda API validates the JWT token using `@jwt_required()` decorator
   - If token is missing or invalid → 401 Unauthorized
   - If token is valid → Request proceeds

## Testing Steps

### Step 1: Test Registration (if you don't have an account)
```bash
curl -X POST https://x1fjliehe8.execute-api.ap-south-1.amazonaws.com/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"testpass123","username":"testuser"}'
```

Expected response:
```json
{"message": "User registered. Check your email for OTP."}
```

Check the Lambda logs for the OTP code (it's logged to console).

### Step 2: Verify OTP
```bash
curl -X POST https://x1fjliehe8.execute-api.ap-south-1.amazonaws.com/api/auth/verify-otp \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","otp":"123456"}'
```

Replace `123456` with the actual OTP from logs.

### Step 3: Login
```bash
curl -X POST https://x1fjliehe8.execute-api.ap-south-1.amazonaws.com/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"identifier":"test@example.com","password":"testpass123"}'
```

Expected response:
```json
{
  "token": "eyJ0eXAiOiJKV1QiLCJhbGc...",
  "user": {
    "email": "test@example.com",
    "username": "testuser",
    "role": "creator",
    "region": "ap-south-1"
  }
}
```

### Step 4: Test Projects Endpoint with Token
```bash
curl -X GET https://x1fjliehe8.execute-api.ap-south-1.amazonaws.com/api/projects \
  -H "Authorization: Bearer YOUR_TOKEN_HERE"
```

Replace `YOUR_TOKEN_HERE` with the token from Step 3.

Expected response:
```json
[]
```
(Empty array if no projects exist yet)

## Frontend Testing

1. Visit: `https://main.d3ksgup2cfy60v.amplifyapp.com`
2. Register a new account or login
3. After successful login, you should be redirected to `/projects`
4. The frontend will automatically include the JWT token in all API requests
5. You should no longer see 401 errors

## Admin Account

If you want admin access, use the email configured in `ADMIN_EMAIL`:
- Email: `clipsense57@gmail.com`
- This email automatically gets admin role on registration

## Troubleshooting

### Still getting 401 after login?
- Check browser console for token: `localStorage.getItem('clipsense_token')`
- Check if token is being sent in request headers (Network tab)
- Token might have expired (default expiration varies)

### Can't receive OTP?
- Check Lambda CloudWatch logs: `/aws/lambda/clipsense-api`
- OTP is logged to console for testing purposes
- Email sending might not be configured (check `SENDER_EMAIL` and `SENDER_PASSWORD` in Lambda env vars)

## Summary

The 401 error is **WORKING AS INTENDED**. The API is correctly rejecting unauthenticated requests. Users need to:
1. Register/Login through the frontend
2. Frontend stores the JWT token
3. All subsequent requests include the token
4. API validates token and allows access

The authentication system is working correctly!
