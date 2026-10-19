import React, { createContext, useCallback, useContext, useEffect, useState } from "react";
import { getAccessToken, getPhoneNumber } from "zmp-sdk/apis";
import { api, ApiError, getToken, setToken, setUnauthorizedHandler } from "./api";
import type { Member } from "./types";

interface AuthState {
  member: Member | null;
  loading: boolean;
  /** True when the Zalo account has no membership yet and the sign-up form should show. */
  needsRegister: boolean;
  register: (fullName: string, birthday: string) => Promise<void>;
  setMember: (m: Member) => void;
  logout: () => void;
}

const AuthContext = createContext<AuthState>(null as unknown as AuthState);
export const useAuth = () => useContext(AuthContext);

async function zaloAccessToken(): Promise<string> {
  try {
    const token = await getAccessToken({});
    return typeof token === "string" ? token : "";
  } catch {
    return "";
  }
}

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [member, setMember] = useState<Member | null>(null);
  const [loading, setLoading] = useState(true);
  const [needsRegister, setNeedsRegister] = useState(false);

  const logout = useCallback(() => {
    setToken("");
    setMember(null);
  }, []);

  useEffect(() => {
    setUnauthorizedHandler(logout);
    (async () => {
      try {
        if (getToken()) {
          try {
            setMember((await api.me()).member);
            return;
          } catch {
            setToken("");
          }
        }
        const zalo = await zaloAccessToken();
        if (!zalo) return;
        const res = await api.login(zalo);
        setToken(res.token);
        setMember(res.member);
      } catch (e) {
        if (e instanceof ApiError && e.code === "NOT_REGISTERED") setNeedsRegister(true);
        else console.warn(e);
      } finally {
        setLoading(false);
      }
    })();
  }, [logout]);

  const register = useCallback(async (fullName: string, birthday: string) => {
    const accessToken = await zaloAccessToken();
    if (!accessToken) throw new Error("Vui lòng mở ứng dụng trong Zalo và cho phép truy cập.");
    let phoneToken = "";
    try {
      phoneToken = (await getPhoneNumber({})).token || "";
    } catch {
      /* declined */
    }
    if (!phoneToken) throw new Error("Cần cho phép chia sẻ số điện thoại để tích điểm.");
    const res = await api.register({ accessToken, phoneToken, fullName: fullName.trim(), birthday: birthday || undefined });
    setToken(res.token);
    setMember(res.member);
    setNeedsRegister(false);
  }, []);

  return (
    <AuthContext.Provider value={{ member, loading, needsRegister, register, setMember, logout }}>
      {children}
    </AuthContext.Provider>
  );
}
