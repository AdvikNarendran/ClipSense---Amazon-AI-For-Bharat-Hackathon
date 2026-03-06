'use client';

import React, { createContext, useContext, useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { getMe } from '@/lib/api';

interface User {
    email: string;
    username: string;
    role: string;
}

interface AuthContextType {
    user: User | null;
    token: string | null;
    login: (token: string, user: User) => void;
    logout: () => void;
    refreshUser: () => Promise<void>;
    loading: boolean;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export function AuthProvider({ children }: { children: React.ReactNode }) {
    const [user, setUser] = useState<User | null>(null);
    const [token, setToken] = useState<string | null>(null);
    const [loading, setLoading] = useState(true);
    const router = useRouter();

    useEffect(() => {
        const savedToken = localStorage.getItem('clipsense_token');
        const savedUser = localStorage.getItem('clipsense_user');

        if (savedToken && savedUser) {
            setToken(savedToken);
            setUser(JSON.parse(savedUser));
        }
        setLoading(false);
    }, []);

    const login = (newToken: string, newUser: User) => {
        setToken(newToken);
        setUser(newUser);
        localStorage.setItem('clipsense_token', newToken);
        localStorage.setItem('clipsense_user', JSON.stringify(newUser));
        router.push('/projects');
    };

    const logout = () => {
        setToken(null);
        setUser(null);
        localStorage.removeItem('clipsense_token');
        localStorage.removeItem('clipsense_user');
        router.push('/');
    };

    const refreshUser = async () => {
        try {
            const res = await getMe();
            setUser(res.user);
            localStorage.setItem('clipsense_user', JSON.stringify(res.user));
        } catch (err) {
            console.error("Failed to refresh user:", err);
        }
    };

    return (
        <AuthContext.Provider value={{ user, token, login, logout, refreshUser, loading }}>
            {children}
        </AuthContext.Provider>
    );
}

export function useAuth() {
    const context = useContext(AuthContext);
    if (context === undefined) {
        throw new Error('useAuth must be used within an AuthProvider');
    }
    return context;
}
