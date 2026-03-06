'use client';

import { useState, useEffect } from "react";
import Link from "next/link";
import { useAuth } from "@/context/AuthContext";
import { updateProfile, requestPasswordChange, confirmPasswordChange, getUserStats, deleteAccount } from "@/lib/api";

export default function SettingsPage() {
  const { user, refreshUser, logout } = useAuth();

  const [username, setUsername] = useState("");
  const [isUpdatingProfile, setIsUpdatingProfile] = useState(false);

  // Password change state
  const [showPasswordFlow, setShowPasswordFlow] = useState(false);
  const [passwordStep, setPasswordStep] = useState<"request" | "verify">("request");
  const [newPassword, setNewPassword] = useState("");
  const [otp, setOtp] = useState("");
  const [isProcessingPass, setIsProcessingPass] = useState(false);

  // Stats
  const [stats, setStats] = useState<{ projectCount: number; clipCount: number }>({ projectCount: 0, clipCount: 0 });

  // Delete account
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false);
  const [isDeleting, setIsDeleting] = useState(false);

  const [msg, setMsg] = useState<{ type: "success" | "error", text: string } | null>(null);

  useEffect(() => {
    if (user) {
      setUsername(user.username || "");
      getUserStats().then(setStats).catch(() => { });
    }
  }, [user]);

  const showMsg = (text: string, type: "success" | "error" = "success") => {
    setMsg({ text, type });
    setTimeout(() => setMsg(null), 5000);
  };

  const handleUpdateUsername = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsUpdatingProfile(true);
    try {
      await updateProfile({ username });
      await refreshUser();
      showMsg("Username updated successfully!");
    } catch (err: any) {
      showMsg(err.message, "error");
    } finally {
      setIsUpdatingProfile(false);
    }
  };

  const handleRequestPasswordOTP = async () => {
    setIsProcessingPass(true);
    try {
      await requestPasswordChange();
      setPasswordStep("verify");
      showMsg("OTP sent to your email!");
    } catch (err: any) {
      showMsg(err.message, "error");
    } finally {
      setIsProcessingPass(false);
    }
  };

  const handleConfirmPassword = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsProcessingPass(true);
    try {
      await confirmPasswordChange(otp, newPassword);
      setShowPasswordFlow(false);
      setPasswordStep("request");
      setNewPassword("");
      setOtp("");
      showMsg("Password changed successfully!");
    } catch (err: any) {
      showMsg(err.message, "error");
    } finally {
      setIsProcessingPass(false);
    }
  };

  const handleDeleteAccount = async () => {
    setIsDeleting(true);
    try {
      await deleteAccount();
      logout();
    } catch (err: any) {
      showMsg(err.message, "error");
      setIsDeleting(false);
    }
  };

  if (!user) {
    return (
      <div className="flex items-center justify-center py-20">
        <div className="animate-spin h-8 w-8 border-4 border-[#A89E53] border-t-transparent rounded-full"></div>
      </div>
    );
  }

  return (
    <div className="max-w-4xl mx-auto">
      <div className="flex items-center justify-between mb-10">
        <div>
          <h1 className="text-4xl font-extrabold tracking-tight">Account Settings</h1>
          <p className="text-black/40 text-sm mt-1 font-medium">Manage your profile and security preferences</p>
        </div>
        <Link href="/projects" className="text-[11px] uppercase tracking-widest font-bold text-black/40 hover:text-black/60 transition-colors">
          ⟵ Back to Projects
        </Link>
      </div>

      {msg && (
        <div className={`mb-8 p-4 rounded-2xl border text-sm font-semibold flex items-center gap-3 ${msg.type === "success" ? "bg-green-50 border-green-100 text-green-700" : "bg-red-50 border-red-100 text-red-700"
          }`}>
          <div className={`h-2 w-2 rounded-full ${msg.type === "success" ? "bg-green-500" : "bg-red-500"}`}></div>
          {msg.text}
        </div>
      )}

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
        {/* Profile Section */}
        <div className="lg:col-span-2 space-y-8">
          <section className="wf-panel bg-white p-8 shadow-sm">
            <h3 className="text-lg font-bold mb-6 flex items-center gap-2">
              <span className="h-6 w-1 bg-[#A89E53] rounded-full"></span>
              Public Profile
            </h3>

            <form onSubmit={handleUpdateUsername} className="space-y-6">
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div>
                  <label className="block text-[11px] uppercase tracking-widest font-bold text-black/30 mb-2 ml-1">Email Address</label>
                  <input
                    className="wf-search w-full bg-black/5 text-black/40 border-transparent cursor-not-allowed opacity-70"
                    value={user.email}
                    disabled
                  />
                  <p className="text-[10px] text-black/20 mt-2 ml-1 italic">Email cannot be changed currently</p>
                </div>
                <div>
                  <label className="block text-[11px] uppercase tracking-widest font-bold text-black/30 mb-2 ml-1">Username / Handle</label>
                  <input
                    className="wf-search w-full bg-black/5 border-transparent focus:bg-white focus:border-[#A89E53]/30 transition-all"
                    placeholder="Set a username"
                    value={username}
                    onChange={(e) => setUsername(e.target.value)}
                    required
                  />
                </div>
              </div>

              <div className="pt-4 flex justify-end">
                <button
                  type="submit"
                  disabled={isUpdatingProfile || username === (user.username || "")}
                  className="wf-cta px-10 bg-[#17503F] text-white font-bold py-3 disabled:opacity-30 disabled:hover:scale-100 transform transition-all active:scale-[0.98]"
                >
                  {isUpdatingProfile ? "Saving..." : "Save Changes"}
                </button>
              </div>
            </form>
          </section>

          <section className="wf-panel bg-white p-8 shadow-sm">
            <h3 className="text-lg font-bold mb-6 flex items-center gap-2">
              <span className="h-6 w-1 bg-[#B7561F] rounded-full"></span>
              Security & Password
            </h3>

            {!showPasswordFlow ? (
              <div className="flex flex-col items-center justify-center py-6 bg-black/5 rounded-2xl border border-dashed border-black/10">
                <p className="text-sm text-black/50 mb-4 font-medium">Want to update your secure password?</p>
                <button
                  onClick={() => setShowPasswordFlow(true)}
                  className="wf-view bg-white text-black font-bold px-8"
                >
                  Edit Password
                </button>
              </div>
            ) : (
              <div className="space-y-6">
                {passwordStep === "request" ? (
                  <div className="space-y-4">
                    <p className="text-sm text-black/60 leading-relaxed">
                      To change your password, we'll need to verify your identity. <br />
                      Click below to generate a <strong>Verification OTP</strong>.
                    </p>
                    <div className="flex gap-3">
                      <button
                        onClick={handleRequestPasswordOTP}
                        disabled={isProcessingPass}
                        className="wf-cta bg-[#B7561F] text-white font-bold"
                      >
                        {isProcessingPass ? "Generating..." : "Generate OTP"}
                      </button>
                      <button
                        onClick={() => setShowPasswordFlow(false)}
                        className="wf-view border-transparent font-semibold"
                      >
                        Cancel
                      </button>
                    </div>
                  </div>
                ) : (
                  <form onSubmit={handleConfirmPassword} className="space-y-6">
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                      <div>
                        <label className="block text-[11px] uppercase tracking-widest font-bold text-black/30 mb-2 ml-1">OTP Code</label>
                        <input
                          className="wf-search w-full bg-black/5 border-transparent text-center font-bold tracking-widest"
                          placeholder="000000"
                          maxLength={6}
                          value={otp}
                          onChange={(e) => setOtp(e.target.value)}
                          required
                        />
                      </div>
                      <div>
                        <label className="block text-[11px] uppercase tracking-widest font-bold text-black/30 mb-2 ml-1">New Password</label>
                        <input
                          type="password"
                          className="wf-search w-full bg-black/5 border-transparent"
                          placeholder="••••••••"
                          value={newPassword}
                          onChange={(e) => setNewPassword(e.target.value)}
                          required
                        />
                      </div>
                    </div>
                    <div className="flex gap-3 justify-end">
                      <button
                        type="button"
                        onClick={() => setPasswordStep("request")}
                        className="wf-view border-transparent font-semibold"
                      >
                        Back
                      </button>
                      <button
                        type="submit"
                        disabled={isProcessingPass}
                        className="wf-cta bg-[#17503F] text-white font-bold px-8"
                      >
                        {isProcessingPass ? "Changing..." : "Confirm New Password"}
                      </button>
                    </div>
                  </form>
                )}
              </div>
            )}
          </section>
        </div>

        {/* Sidebar Info */}
        <div className="space-y-6">
          <div className="wf-panel bg-white p-6 shadow-sm">
            <div className="flex flex-col items-center text-center">
              <div className="h-20 w-20 rounded-full bg-gradient-to-br from-[#17503F] to-[#238054] flex items-center justify-center text-white text-3xl font-black mb-4 shadow-lg">
                {user.email[0].toUpperCase()}
              </div>
              <h4 className="font-bold text-xl">{user.username || user.email.split('@')[0]}</h4>
              <p className="text-[10px] text-black/30 uppercase tracking-[0.2em] font-bold mt-1">Creator Tier</p>

              <div className="w-full h-px bg-black/5 my-6"></div>

              <div className="grid grid-cols-2 w-full gap-4 text-center">
                <div>
                  <div className="text-xl font-black text-[#A89E53]">{stats.projectCount}</div>
                  <div className="text-[9px] text-black/40 uppercase font-bold">Videos</div>
                </div>
                <div>
                  <div className="text-xl font-black text-[#B7561F]">{stats.clipCount}</div>
                  <div className="text-[9px] text-black/40 uppercase font-bold">Clips</div>
                </div>
              </div>
            </div>
          </div>

          <div className="wf-panel bg-red-50/30 border-red-100 p-6">
            <h4 className="text-xs font-black uppercase tracking-widest text-red-700 mb-4">Danger Zone</h4>
            <p className="text-[11px] text-red-600/60 mb-4 leading-relaxed font-medium">
              Deleting your account is permanent. All projects, clips, and data will be erased immediately.
            </p>

            {!showDeleteConfirm ? (
              <button
                onClick={() => setShowDeleteConfirm(true)}
                className="wf-view w-full border-red-200 text-red-600 hover:bg-red-50 hover:border-red-300 font-bold transition-all"
              >
                Delete Account
              </button>
            ) : (
              <div className="space-y-3">
                <p className="text-xs text-red-700 font-bold text-center">Are you absolutely sure?</p>
                <div className="flex gap-2">
                  <button
                    onClick={handleDeleteAccount}
                    disabled={isDeleting}
                    className="flex-1 py-2 text-xs font-bold bg-red-600 text-white rounded-xl hover:bg-red-700 transition-all disabled:opacity-50"
                  >
                    {isDeleting ? "Deleting..." : "Yes, Delete Forever"}
                  </button>
                  <button
                    onClick={() => setShowDeleteConfirm(false)}
                    className="flex-1 py-2 text-xs font-bold border border-black/10 rounded-xl hover:bg-black/5 transition-all"
                  >
                    Cancel
                  </button>
                </div>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
