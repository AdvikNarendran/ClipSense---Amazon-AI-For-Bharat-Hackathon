'use client';

import AuthFlow from '@/components/AuthFlow';

export default function AuthPage() {
  return (
    <div>
      <h1 className="text-3xl font-medium mb-6">Account</h1>

      <div className="wf-panel p-6">
        <div className="wf-panel p-6 bg-white">
          <AuthFlow />
        </div>
      </div>
    </div>
  );
}