'use client';

import { useEffect } from 'react';
import { configureAmplify } from '@/lib/amplifyClient';

export default function AmplifyProvider({ children }: { children: React.ReactNode }) {
  useEffect(() => {
    configureAmplify();
  }, []);

  return <>{children}</>;
}