'use client';

import { useState } from "react";
import { loginUser, registerUser, verifyOtp, forgotPassword, resetPassword } from "@/lib/api";
import { useAuth } from "@/context/AuthContext";

export default function AuthFlow() {
  const { login } = useAuth();
  const [mode, setMode] = useState<"login" | "register" | "otp" | "forgot" | "reset">("login");

  const [email, setEmail] = useState("");
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [otp, setOtp] = useState("");
  const [newPassword, setNewPassword] = useState("");

  const [loading, setLoading] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const [msg, setMsg] = useState<string | null>(null);

  async function handleRegister(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setErr(null);
    try {
      const res = await registerUser(email, password, username || undefined);
      setMsg(res.message);
      setMode("otp");
    } catch (e: any) {
      setErr(e.message);
    } finally {
      setLoading(false);
    }
  }

  async function handleVerify(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setErr(null);
    try {
      await verifyOtp(email, otp);
      setMsg("Email verified! You can now login.");
      setMode("login");
    } catch (e: any) {
      setErr(e.message);
    } finally {
      setLoading(false);
    }
  }

  async function handleLogin(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setErr(null);
    try {
      const res = await loginUser(email, password);
      login(res.token, res.user);
    } catch (e: any) {
      setErr(e.message);
    } finally {
      setLoading(false);
    }
  }

  async function handleForgotPassword(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setErr(null);
    try {
      const res = await forgotPassword(email);
      setMsg(res.message);
      setOtp("");
      setNewPassword("");
      setMode("reset");
    } catch (e: any) {
      setErr(e.message);
    } finally {
      setLoading(false);
    }
  }

  async function handleResetPassword(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setErr(null);
    try {
      const res = await resetPassword(email, otp, newPassword);
      setMsg(res.message);
      setOtp("");
      setNewPassword("");
      setMode("login");
    } catch (e: any) {
      setErr(e.message);
    } finally {
      setLoading(false);
    }
  }

  const modeLabel = {
    login: "Log in to your dashboard",
    register: "Join the ClipSense creator community",
    otp: "Security Checkpoint",
    forgot: "Reset Your Password",
    reset: "Enter New Password",
  };

  // Shared input style — dark glassmorphism
  const inputClass = "w-full rounded-xl bg-white/10 border border-white/15 text-white placeholder-white/30 focus:bg-white/15 focus:border-[#A89E53]/50 focus:outline-none transition-all py-3.5 px-5 text-sm";
  const labelClass = "block text-[11px] uppercase tracking-widest font-bold text-white/40 mb-2 ml-1";

  return (
    <div className="w-full">
      {/* Header */}
      <div className="mb-10 text-center">
        <h2 className="text-4xl font-extrabold tracking-tight mb-3">
          <span style={{ color: '#A89E53' }}>Clip</span>
          <span style={{ color: '#B7561F' }}>Sense</span>
        </h2>
        <p className="text-white/50 text-sm font-medium">
          {modeLabel[mode]}
        </p>
      </div>

      {/* Main Card — dark glassmorphism */}
      <div className="rounded-[24px] p-8 shadow-2xl border border-white/10" style={{ background: '#1e1e1e' }}>
        {msg && (
          <div className="mb-6 px-4 py-3 bg-green-500/15 border border-green-500/20 text-green-400 text-xs font-semibold rounded-xl text-center">
            {msg}
          </div>
        )}

        {err && (
          <div className="mb-6 px-4 py-3 bg-red-500/15 border border-red-500/20 text-red-400 text-xs font-semibold rounded-xl text-center">
            {err}
          </div>
        )}

        {/* ─── LOGIN ─── */}
        {mode === "login" && (
          <form onSubmit={handleLogin} className="space-y-5">
            <div>
              <label className={labelClass}>Email or Username</label>
              <input
                type="text"
                className={inputClass}
                placeholder="john@example.com or johnny"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                required
              />
            </div>
            <div>
              <label className={labelClass}>Secure Password</label>
              <input
                type="password"
                className={inputClass}
                placeholder="••••••••"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                required
              />
            </div>
            <button
              type="submit"
              disabled={loading}
              className="w-full bg-gradient-to-r from-[#17503F] to-[#1a6b52] text-white font-bold py-4 rounded-xl hover:scale-[1.02] transform transition-all active:scale-[0.98] border border-white/10 shadow-lg shadow-black/20 disabled:opacity-50"
            >
              {loading ? "Authenticating..." : "Enter Dashboard"}
            </button>
            <div className="flex items-center justify-between pt-2">
              <div>
                <span className="text-sm text-white/30">New here? </span>
                <button
                  type="button"
                  className="text-[#B7561F] text-sm font-bold hover:underline"
                  onClick={() => { setErr(null); setMsg(null); setMode("register"); }}
                >
                  Create Account
                </button>
              </div>
              <button
                type="button"
                className="text-[#A89E53] text-xs font-bold hover:underline"
                onClick={() => { setErr(null); setMsg(null); setMode("forgot"); }}
              >
                Forgot Password?
              </button>
            </div>
          </form>
        )}

        {/* ─── REGISTER ─── */}
        {mode === "register" && (
          <form onSubmit={handleRegister} className="space-y-5">
            <div>
              <label className={labelClass}>Email Address</label>
              <input
                type="email"
                className={inputClass}
                placeholder="you@email.com"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                required
              />
            </div>
            <div>
              <label className={labelClass}>Username (Optional)</label>
              <input
                type="text"
                className={inputClass}
                placeholder="unique_handle"
                value={username}
                onChange={(e) => setUsername(e.target.value)}
              />
            </div>
            <div>
              <label className={labelClass}>Choose Password</label>
              <input
                type="password"
                className={inputClass}
                placeholder="••••••••"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                required
              />
            </div>
            <button
              type="submit"
              disabled={loading}
              className="w-full bg-gradient-to-r from-[#17503F] to-[#1a6b52] text-white font-bold py-4 rounded-xl hover:scale-[1.02] transform transition-all active:scale-[0.98] border border-white/10 shadow-lg shadow-black/20 disabled:opacity-50"
            >
              {loading ? "Creating..." : "Start Free Trial"}
            </button>
            <div className="text-center pt-2">
              <span className="text-sm text-white/30">Already a member? </span>
              <button
                type="button"
                className="text-[#B7561F] text-sm font-bold hover:underline"
                onClick={() => { setErr(null); setMsg(null); setMode("login"); }}
              >
                Sign In
              </button>
            </div>
          </form>
        )}

        {/* ─── OTP VERIFICATION ─── */}
        {mode === "otp" && (
          <form onSubmit={handleVerify} className="space-y-6">
            <div className="text-center space-y-2">
              <p className="text-sm text-white/60 leading-relaxed font-semibold">
                We've sent a 6-digit code to: <br />
                <span className="text-white font-bold">{email}</span>
              </p>
              <p className="text-[10px] text-white/30 italic">
                (Check your email for the code)
              </p>
            </div>

            <div className="flex justify-center">
              <input
                type="text"
                maxLength={6}
                className="w-full max-w-[240px] text-center text-3xl font-extrabold tracking-[0.4em] rounded-xl bg-white/10 border border-white/15 text-white placeholder-white/20 focus:bg-white/15 focus:border-[#A89E53]/50 focus:outline-none transition-all py-4 px-2"
                placeholder="000000"
                value={otp}
                onChange={(e) => setOtp(e.target.value)}
                required
              />
            </div>

            <button
              type="submit"
              disabled={loading}
              className="w-full bg-gradient-to-r from-[#17503F] to-[#1a6b52] text-white font-bold py-4 rounded-xl hover:scale-[1.02] transform transition-all active:scale-[0.98] border border-white/10 shadow-lg shadow-black/20 disabled:opacity-50"
            >
              {loading ? "Verifying..." : "Verify & Continue"}
            </button>
            <button
              type="button"
              className="w-full text-xs font-bold uppercase tracking-widest text-white/20 hover:text-white/50 transition-colors"
              onClick={() => setMode("register")}
            >
              Wrong email? Go back
            </button>
          </form>
        )}

        {/* ─── FORGOT PASSWORD ─── */}
        {mode === "forgot" && (
          <form onSubmit={handleForgotPassword} className="space-y-5">
            <div className="text-center mb-2">
              <p className="text-sm text-white/50 leading-relaxed">
                Enter your registered email and we'll send a verification code to reset your password.
              </p>
            </div>
            <div>
              <label className={labelClass}>Email Address</label>
              <input
                type="email"
                className={inputClass}
                placeholder="you@email.com"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                required
              />
            </div>
            <button
              type="submit"
              disabled={loading}
              className="w-full bg-gradient-to-r from-[#B7561F] to-[#d4682f] text-white font-bold py-4 rounded-xl hover:scale-[1.02] transform transition-all active:scale-[0.98] border border-white/10 shadow-lg shadow-black/20 disabled:opacity-50"
            >
              {loading ? "Sending OTP..." : "Send Reset Code"}
            </button>
            <div className="text-center pt-2">
              <button
                type="button"
                className="text-[#A89E53] text-sm font-bold hover:underline"
                onClick={() => { setErr(null); setMsg(null); setMode("login"); }}
              >
                ← Back to Login
              </button>
            </div>
          </form>
        )}

        {/* ─── RESET PASSWORD (OTP + NEW PASS) ─── */}
        {mode === "reset" && (
          <form onSubmit={handleResetPassword} className="space-y-5">
            <div className="text-center space-y-2 mb-2">
              <p className="text-sm text-white/60 leading-relaxed font-semibold">
                Enter the code sent to: <br />
                <span className="text-white font-bold">{email}</span>
              </p>
              <p className="text-[10px] text-white/30 italic">
                (Check your email for the code)
              </p>
            </div>

            <div className="flex justify-center">
              <input
                type="text"
                maxLength={6}
                className="w-full max-w-[240px] text-center text-3xl font-extrabold tracking-[0.4em] rounded-xl bg-white/10 border border-white/15 text-white placeholder-white/20 focus:bg-white/15 focus:border-[#A89E53]/50 focus:outline-none transition-all py-4 px-2"
                placeholder="000000"
                value={otp}
                onChange={(e) => setOtp(e.target.value)}
                required
              />
            </div>

            <div>
              <label className={labelClass}>New Password</label>
              <input
                type="password"
                className={inputClass}
                placeholder="••••••••"
                value={newPassword}
                onChange={(e) => setNewPassword(e.target.value)}
                required
              />
            </div>

            <button
              type="submit"
              disabled={loading}
              className="w-full bg-gradient-to-r from-[#17503F] to-[#1a6b52] text-white font-bold py-4 rounded-xl hover:scale-[1.02] transform transition-all active:scale-[0.98] border border-white/10 shadow-lg shadow-black/20 disabled:opacity-50"
            >
              {loading ? "Resetting..." : "Reset Password"}
            </button>
            <button
              type="button"
              className="w-full text-xs font-bold uppercase tracking-widest text-white/20 hover:text-white/50 transition-colors"
              onClick={() => { setErr(null); setMsg(null); setMode("forgot"); }}
            >
              Didn't get code? Go back
            </button>
          </form>
        )}
      </div>

      <p className="mt-8 text-center text-[10px] text-white/30 uppercase tracking-[0.2em] font-medium">
        Secure & Private Video Intelligence
      </p>
    </div>
  );
}