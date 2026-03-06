'use client';

import React from 'react';
import type { AttentionPoint } from '@/lib/types';
import {
  LineChart,
  Line,
  CartesianGrid,
  XAxis,
  YAxis,
  Tooltip,
  ResponsiveContainer,
} from 'recharts';

export default function AttentionCurveChart({
  data,
  title = 'Attention Curve',
}: {
  data: AttentionPoint[];
  title?: string;
}) {
  return (
    <div className="rounded-2xl border border-white/10 bg-black/40 backdrop-blur p-5">
      <div className="flex items-center justify-between">
        <h3 className="text-white font-bold">{title}</h3>
        <div className="text-xs text-white/60">Y: 0–100 • X: seconds</div>
      </div>

      <div className="h-[320px] mt-4">
        <ResponsiveContainer width="100%" height="100%">
          <LineChart data={data}>
            <CartesianGrid strokeDasharray="3 3" opacity={0.2} />
            <XAxis
              dataKey="t"
              tick={{ fill: 'rgba(255,255,255,0.7)' }}
              label={{ value: 'Time (s)', position: 'insideBottom', offset: -5, fill: 'rgba(255,255,255,0.6)' }}
            />
            <YAxis
              domain={[0, 100]}
              tick={{ fill: 'rgba(255,255,255,0.7)' }}
              label={{ value: 'Attention', angle: -90, position: 'insideLeft', fill: 'rgba(255,255,255,0.6)' }}
            />
            <Tooltip
              contentStyle={{ background: 'rgba(0,0,0,0.8)', border: '1px solid rgba(255,255,255,0.15)' }}
              labelStyle={{ color: 'rgba(255,255,255,0.7)' }}
            />
            <Line type="monotone" dataKey="v" strokeWidth={3} dot={false} />
          </LineChart>
        </ResponsiveContainer>
      </div>
    </div>
  );
}