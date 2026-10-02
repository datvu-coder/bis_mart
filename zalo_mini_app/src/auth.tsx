import React, { createContext, useCallback, useContext, useEffect, useState } from "react";
import { getAccessToken } from "zmp-sdk/apis";
import { api, ApiError, getToken, setToken, setUnauthorizedHandler } from "./api";
import type { User } from "./types";

interface AuthState {
  user: User | null;
  loading: boolean;
  /** Password login; also links the current Zalo account for one-tap login next time. */
  login: (username: string, password: string) => Promise<void>;
  logout: () => void;
}

const AuthContext = createContext<AuthState>(null as unknown as AuthState);
export const useAuth = () => useContext(AuthContext);

/** Zalo access token, or "" when running outside Zalo (browser dev) or the user declined. */
async function zaloAccessToken(): Promise<string> {
  try {
    const token = await getAccessToken({});
    return typeof token === "string" ? token : "";
  } catch {
    return "";
  }
}

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);

  const logout = useCallback(() => {
    setToken("");
    setUser(null);
  }, []);

  useEffect(() => {
    setUnauthorizedHandler(logout);
    (async () => {
      try {
        if (getToken()) {
          setUser((await api.me()).user);
          return;
        }
        const zalo = await zaloAccessToken();
        if (zalo) {
          const res = await api.zaloLogin(zalo);
          setToken(res.token);
          setUser(res.user);
        }
      } catch (e) {
        // NOT_LINKED or expired token: fall through to the login form.
        if (!(e instanceof ApiError)) console.warn(e);
        setToken("");
      } finally {
        setLoading(false);
      }
    })();
  }, [logout]);

  const login = useCallback(async (username: string, password: string) => {
    const res = await api.login(username.trim(), password);
    setToken(res.token);
    setUser(res.user);
    const zalo = await zaloAccessToken();
    if (zalo) {
      try {
        await api.zaloLink(zalo);
      } catch {
        /* linking is optional; password login still works */
      }
    }
  }, []);

  return <AuthContext.Provider value={{ user, loading, login, logout }}>{children}</AuthContext.Provider>;
}
