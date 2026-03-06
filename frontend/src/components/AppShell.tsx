'use client';

import Link from "next/link";
import { usePathname, useSearchParams } from "next/navigation";
import { useAuth } from "@/context/AuthContext";

const NAV = [
  { label: "Upload", href: "/upload" },
  { label: "Projects", href: "/projects" },
  { label: "Analytics", href: "/analytics" },
  { label: "Settings", href: "/settings" },
];

const ADMIN_NAV = [
  { label: "Metrics", href: "/admin?tab=metrics" },
  { label: "Creators", href: "/admin?tab=creators" },
  { label: "Projects", href: "/admin?tab=projects" },
];

export default function AppShell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const searchParams = useSearchParams();
  const { user, logout } = useAuth();

  const isAuthPage = pathname === "/" && !user;
  const isAdminPage = pathname.startsWith("/admin");
  const activeTab = searchParams.get("tab") || "metrics";

  if (isAuthPage) {
    return (
      <div className="min-h-screen w-full px-6 py-12 font-sans bg-[#17503F] flex items-center justify-center">
        <div className="cs-shell p-8 max-w-xl w-full flex flex-col items-center justify-center bg-white/10 backdrop-blur-md shadow-2xl border border-white/20 rounded-[24px]">
          {children}
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen w-full px-6 py-6 font-sans bg-[#17503F]">
      <div className="cs-shell p-4 bg-white/5 backdrop-blur-sm border border-white/10 rounded-[20px]">
        <div className="grid grid-cols-1 md:grid-cols-[260px_1fr] gap-4 min-h-[calc(100vh-96px)]">
          {/* Sidebar */}
          <aside className="wf-main p-6 flex flex-col gap-4 bg-white rounded-[16px]">
            <Link href="/" className="wf-logo text-2xl font-extrabold tracking-wide block mb-4">
              <span style={{ color: "#A89E53" }}>Clip</span>
              <span style={{ color: "#B7561F" }}>Sense</span>
            </Link>

            {user && (
              <div className="flex flex-col gap-3 mt-2">
                {user.role === 'admin' && isAdminPage ? (
                  <>
                    <div className="text-[10px] font-bold text-black/20 uppercase tracking-widest px-4 mb-1">Executive Suite</div>
                    {ADMIN_NAV.map((n) => {
                      const tab = n.href.split('tab=')[1];
                      const active = activeTab === tab;
                      return (
                        <Link
                          key={n.href}
                          href={n.href}
                          className={`wf-pill ${active ? "wf-pill-active" : ""}`}
                        >
                          {n.label}
                        </Link>
                      );
                    })}
                    <div className="mt-4 pt-4 border-t border-black/5">
                      <Link href="/projects" className="wf-view w-full text-center py-2 text-[10px] font-bold uppercase tracking-widest opacity-60 hover:opacity-100">
                        &larr; Switch to Creator View
                      </Link>
                    </div>
                  </>
                ) : (
                  <>
                    {NAV.map((n) => {
                      const active = pathname === n.href || pathname.startsWith(n.href + "/");
                      return (
                        <Link
                          key={n.href}
                          href={n.href}
                          className={`wf-pill ${active ? "wf-pill-active" : ""}`}
                        >
                          {n.label}
                        </Link>
                      );
                    })}
                    {user.role === 'admin' && (
                      <Link
                        href="/admin"
                        className={`wf-pill mt-4`}
                        style={{ borderLeftColor: '#f59e0b', backgroundColor: 'rgba(245, 158, 11, 0.05)' }}
                      >
                        Admin Dashboard &rarr;
                      </Link>
                    )}
                  </>
                )}
              </div>
            )}

            <div className="mt-auto border-t border-black/5 pt-6">
              {user ? (
                <div className="flex flex-col gap-4">
                  <div className="flex items-center gap-3">
                    <div className="h-10 w-10 rounded-full border border-black/10 bg-[#17503F]/5 flex items-center justify-center text-[#17503F] font-bold">
                      {user.email[0].toUpperCase()}
                    </div>
                    <div className="flex-1 overflow-hidden">
                      <div className="text-sm font-semibold truncate" title={user.username || user.email}>
                        {user.username || user.email.split('@')[0]}
                      </div>
                      <div className="text-[10px] text-black/40 truncate">
                        {user.email}
                      </div>
                    </div>
                  </div>
                  <button
                    onClick={logout}
                    className="wf-view w-full text-xs py-2 border-red-100 text-red-600 hover:bg-red-50 hover:border-red-200"
                  >
                    Logout
                  </button>
                </div>
              ) : (
                <Link
                  href="/"
                  className="wf-cta w-full text-center py-2.5"
                >
                  Login / Sign Up
                </Link>
              )}
            </div>
          </aside>

          {/* Main */}
          <main className="wf-main overflow-hidden flex flex-col bg-white rounded-[16px]">
            <div className="wf-topbar px-6 py-3 border-b border-black/5">
              <div className="mx-auto max-w-xl">
                <input className="wf-search" placeholder="Search clips, projects..." />
              </div>
            </div>

            <div className="p-8 flex-1 overflow-auto">{children}</div>
          </main>
        </div>
      </div>
    </div>
  );
}