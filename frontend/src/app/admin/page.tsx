'use client';

import { useEffect, useState } from "react";
import {
    getAdminMetrics,
    getAdminUsers,
    getAdminAllProjects,
    type AdminMetrics,
    type AdminUserStat,
    type Project
} from "@/lib/api";
import { useAuth } from "@/context/AuthContext";
import { useRouter, useSearchParams } from "next/navigation";
import Link from "next/link";
import {
    ResponsiveContainer,
    BarChart, Bar,
    XAxis, YAxis, CartesianGrid, Tooltip,
    Cell
} from "recharts";

type TabType = "metrics" | "creators" | "projects";

export default function AdminDashboard() {
    const { user, loading: authLoading } = useAuth();
    const router = useRouter();
    const searchParams = useSearchParams();

    // The sidebar now drives the active section via URL params
    const activeTab = (searchParams.get("tab") as TabType) || "metrics";

    // Internal state for drill-down filtering
    const [selectedUser, setSelectedUser] = useState<string | null>(null);

    // Data state
    const [metrics, setMetrics] = useState<AdminMetrics | null>(null);
    const [creators, setCreators] = useState<AdminUserStat[]>([]);
    const [allProjects, setAllProjects] = useState<Project[]>([]);

    const [loading, setLoading] = useState(true);
    const [error, setError] = useState<string | null>(null);

    useEffect(() => {
        if (!authLoading) {
            if (!user || user.role !== 'admin') {
                router.push('/projects');
                return;
            }

            const loadData = async () => {
                try {
                    const [m, c, p] = await Promise.all([
                        getAdminMetrics(),
                        getAdminUsers(),
                        getAdminAllProjects()
                    ]);
                    setMetrics(m);
                    setCreators(c);
                    setAllProjects(p);
                } catch (err) {
                    setError("Failed to fetch admin data. Ensure you have proper permissions.");
                } finally {
                    setLoading(false);
                }
            };

            loadData();
            const interval = setInterval(loadData, 10000);
            return () => clearInterval(interval);
        }
    }, [user, authLoading, router]);

    if (authLoading || loading) {
        return <div className="p-10 text-center animate-pulse">Accessing Executive Intelligence...</div>;
    }

    if (error) {
        return (
            <div className="p-10 text-center">
                <div className="bg-red-50 text-red-600 p-6 rounded-2xl border border-red-100 max-w-md mx-auto">
                    {error}
                </div>
            </div>
        );
    }

    const filteredProjects = selectedUser
        ? allProjects.filter(p => p.userId === selectedUser)
        : allProjects;

    return (
        <div className="space-y-8 pb-20">
            <div className="flex items-center justify-between">
                <div>
                    <h1 className="text-3xl font-medium">Executive Dashboard</h1>
                    <p className="text-sm text-black/40 mt-1">Platform-wide oversight and intelligence.</p>
                </div>
                <div className="bg-black/5 px-3 py-1.5 rounded-lg text-[10px] font-bold uppercase tracking-widest text-black/40">
                    Section: {activeTab}
                </div>
            </div>

            {activeTab === "metrics" && metrics && (
                <div className="space-y-10 animate-in fade-in slide-in-from-bottom-2 duration-500">
                    <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
                        <div className="wf-stat rounded-[16px] p-6">
                            <div className="text-[10px] font-bold uppercase tracking-widest text-black/40 mb-1">Active Jobs</div>
                            <div className="text-2xl font-bold">{metrics.activeJobs}</div>
                        </div>
                        <div className="wf-stat rounded-[16px] p-6">
                            <div className="text-[10px] font-bold uppercase tracking-widest text-black/40 mb-1">Queue Length</div>
                            <div className="text-2xl font-bold">{metrics.queueLength}</div>
                        </div>
                        <div className="wf-stat rounded-[16px] p-6">
                            <div className="text-[10px] font-bold uppercase tracking-widest text-black/40 mb-1">Total Processed</div>
                            <div className="text-2xl font-bold">{metrics.totalProcessed}</div>
                        </div>
                        <div className="wf-stat rounded-[16px] p-6">
                            <div className="text-[10px] font-bold uppercase tracking-widest text-black/40 mb-1">Error Rate</div>
                            <div className="text-2xl font-bold text-red-500">{metrics.errorRate}%</div>
                        </div>
                    </div>

                    <div className="grid grid-cols-1 lg:grid-cols-2 gap-10">
                        <div className="wf-panel p-8 rounded-[24px]">
                            <h2 className="text-sm font-bold uppercase tracking-widest text-black/40 mb-6">Pipeline Performance</h2>
                            <div className="h-[300px]">
                                <ResponsiveContainer width="100%" height="100%">
                                    <BarChart data={[{ name: 'Avg Proc Time', value: metrics.avgProcessingTimeSec }]}>
                                        <CartesianGrid strokeDasharray="3 3" vertical={false} opacity={0.1} />
                                        <XAxis dataKey="name" hide />
                                        <YAxis label={{ value: 'Seconds', angle: -90, position: 'insideLeft' }} />
                                        <Tooltip />
                                        <Bar dataKey="value" fill="#B7561F" radius={[10, 10, 0, 0]} barSize={60} />
                                    </BarChart>
                                </ResponsiveContainer>
                            </div>
                        </div>

                        <div className="wf-panel p-8 rounded-[24px]">
                            <h2 className="text-sm font-bold uppercase tracking-widest text-black/40 mb-6">Resource Health</h2>
                            <div className="space-y-6">
                                <StatusRow label="AI ENGINE" status={metrics.engineReady} />
                                <StatusRow label="DATABASE (MONGODB)" status={metrics.dbReady} />
                            </div>
                        </div>
                    </div>
                </div>
            )}

            {activeTab === "creators" && (
                <div className="space-y-10 animate-in fade-in slide-in-from-bottom-2 duration-500">
                    <div className="wf-panel p-8 rounded-[24px]">
                        <h2 className="text-sm font-bold uppercase tracking-widest text-black/40 mb-6">Engagement Benchmarks</h2>
                        <div className="h-[300px]">
                            <ResponsiveContainer width="100%" height="100%">
                                <BarChart data={creators.sort((a, b) => b.avgEngagement - a.avgEngagement).slice(0, 8)}>
                                    <CartesianGrid strokeDasharray="3 3" vertical={false} opacity={0.1} />
                                    <XAxis dataKey="username" fontSize={10} tick={{ fill: '#000', opacity: 0.5 }} />
                                    <YAxis domain={[0, 100]} fontSize={10} tick={{ fill: '#000', opacity: 0.5 }} />
                                    <Tooltip />
                                    <Bar dataKey="avgEngagement" radius={[4, 4, 0, 0]}>
                                        {creators.map((entry, index) => (
                                            <Cell key={`cell-${index}`} fill={entry.avgEngagement > 50 ? '#17503F' : '#B7561F'} />
                                        ))}
                                    </Bar>
                                </BarChart>
                            </ResponsiveContainer>
                        </div>
                    </div>

                    <div className="wf-panel overflow-hidden rounded-[24px] border border-black/5">
                        <table className="w-full text-left">
                            <thead>
                                <tr className="bg-black/5 text-[10px] font-bold uppercase tracking-widest text-black/40">
                                    <th className="px-6 py-4">Creator</th>
                                    <th className="px-6 py-4 text-center">Projects</th>
                                    <th className="px-6 py-4 text-center">Clips</th>
                                    <th className="px-6 py-4 text-right">Avg. Engagement</th>
                                    <th className="px-6 py-4 text-right">Actions</th>
                                </tr>
                            </thead>
                            <tbody className="divide-y divide-black/5 text-sm">
                                {creators.map((c) => (
                                    <tr key={c.email} className="hover:bg-black/[0.02] transition-colors">
                                        <td className="px-6 py-4">
                                            <div className="font-semibold">{c.username || "Anonymous"}</div>
                                            <div className="text-[10px] text-black/40">{c.email}</div>
                                        </td>
                                        <td className="px-6 py-4 text-center font-medium">{c.projectCount}</td>
                                        <td className="px-6 py-4 text-center font-medium">{c.clipCount}</td>
                                        <td className="px-6 py-4 text-right">
                                            <span className={`px-2 py-1 rounded-full text-[10px] font-bold ${c.avgEngagement > 50 ? 'bg-green-100 text-green-700' : 'bg-orange-100 text-orange-700'}`}>
                                                {c.avgEngagement}%
                                            </span>
                                        </td>
                                        <td className="px-6 py-4 text-right">
                                            <button
                                                onClick={() => {
                                                    setSelectedUser(c.email);
                                                    router.push("/admin?tab=projects");
                                                }}
                                                className="text-xs font-bold text-[#B7561F] hover:underline"
                                            >
                                                View Work
                                            </button>
                                        </td>
                                    </tr>
                                ))}
                            </tbody>
                        </table>
                    </div>
                </div>
            )}

            {activeTab === "projects" && (
                <div className="space-y-6 animate-in fade-in slide-in-from-bottom-2 duration-500">
                    <div className="flex items-center justify-between">
                        <h2 className="text-sm font-bold uppercase tracking-widest text-black/40">
                            {selectedUser ? `Work for: ${selectedUser}` : "All Creator Projects"}
                        </h2>
                        {selectedUser && (
                            <button onClick={() => setSelectedUser(null)} className="text-xs font-bold text-[#B7561F]">
                                &larr; Show All Creators
                            </button>
                        )}
                    </div>

                    <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-6">
                        {filteredProjects.map((p) => (
                            <Link key={p.id} href={`/projects/${p.id}`} className="wf-panel p-6 rounded-[24px] group hover:border-[#B7561F]/20 transition-all">
                                <div className="flex justify-between items-start mb-4">
                                    <div className={`h-2 w-2 rounded-full ${p.status === 'done' ? 'bg-green-500' : p.status === 'error' ? 'bg-red-500' : 'bg-orange-400'}`} />
                                    <span className="text-[10px] font-bold uppercase tracking-widest text-black/40">{p.status}</span>
                                </div>
                                <h3 className="font-bold text-lg mb-1 group-hover:text-[#B7561F] transition-colors line-clamp-1">{p.title}</h3>
                                <div className="text-xs text-black/40 mb-4 truncate italic">{p.userId || "System"}</div>
                                <div className="flex justify-between items-center text-[10px] font-bold uppercase tracking-widest text-black/40 pt-4 border-t border-black/5">
                                    <span>{p.clipCount} Clips</span>
                                    <span>{p.avgEngagement}% Eng.</span>
                                </div>
                            </Link>
                        ))}
                    </div>
                    {filteredProjects.length === 0 && (
                        <div className="text-center py-20 bg-black/5 rounded-3xl border border-dashed border-black/10 text-xs font-bold text-black/20 uppercase">
                            No projects found for this selection
                        </div>
                    )}
                </div>
            )}
        </div>
    );
}

function StatusRow({ label, status }: { label: string; status: boolean }) {
    return (
        <div className="space-y-2">
            <div className="flex justify-between text-xs font-bold">
                <span>{label}</span>
                <span className={status ? 'text-green-600' : 'text-red-600'}>{status ? 'READY' : 'OFFLINE'}</span>
            </div>
            <div className="h-2 w-full bg-black/5 rounded-full overflow-hidden">
                <div className={`h-full transition-all duration-1000 ${status ? 'w-full bg-green-500' : 'w-0'}`} />
            </div>
        </div>
    );
}
