import React, { useState } from "react";
import { useAuth } from "../auth";
import Icon from "../components/Icon";

export default function LoginPage() {
  const { login } = useAuth();
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [show, setShow] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setBusy(true);
    setError("");
    try {
      await login(username, password);
    } catch (err) {
      const msg = err instanceof Error ? err.message : "";
      setError(msg === "Invalid credentials" ? "Sai mã nhân viên hoặc mật khẩu" : msg || "Đăng nhập thất bại");
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="login">
      <header className="hero login-hero">
        <h1>Giao việc &amp; theo dõi công việc cửa hàng</h1>
        <div className="hero-note">Đăng nhập một lần, lần sau vào thẳng bằng Zalo</div>
      </header>
      <form className="panel login-card" onSubmit={submit}>
        <label className="field">
          <span>Mã nhân viên</span>
          <input value={username} onChange={(e) => setUsername(e.target.value)} autoCapitalize="none" autoComplete="username" placeholder="Nhập mã nhân viên" />
        </label>
        <label className="field">
          <span>Mật khẩu</span>
          <div className="pw">
            <input type={show ? "text" : "password"} value={password} onChange={(e) => setPassword(e.target.value)} autoComplete="current-password" placeholder="Nhập mật khẩu" />
            <button type="button" onClick={() => setShow((v) => !v)} aria-label="Hiện/ẩn mật khẩu"><Icon name={show ? "eyeOff" : "eye"} size={20} /></button>
          </div>
        </label>
        {error && <div className="error inline">{error}</div>}
        <button className="btn primary wide" disabled={busy || !username || !password}>{busy ? "Đang đăng nhập..." : "Đăng nhập"}</button>
        <p className="hint center">Dùng chung tài khoản với ứng dụng Bi'S MART</p>
      </form>
    </div>
  );
}
