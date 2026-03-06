import { NextResponse } from 'next/server';

export async function POST(req: Request) {
  const body = await req.json().catch(() => null);
  const filename = body?.filename ?? 'video.mp4';

  // Placeholder: return a fake URL so frontend wiring is correct.
  // Replace with your API Gateway URL later or implement real presign here.
  return NextResponse.json({
    uploadUrl: 'https://example.com/replace-with-real-presigned-url',
    objectKey: `uploads/mock/${Date.now()}-${filename}`,
    bucket: 'mock-bucket',
  });
}