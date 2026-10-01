import React, { useState } from "react";
import { useAuth } from "../auth";

export default function LoginPage() {
  const { login } = useAuth();
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setBusy(true);
    setError("");
    try {
      await login(username, password);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Đăng nhập thất bại");
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="login">
      <div className="hero">
        <h1>Bi'S MART</h1>
        <p>Giao việc &amp; theo dõi công việc cửa hàng</p>
      </div>
      <form className="panel" onSubmit={submit}>
        <p className="hint">Đăng nhập bằng tài khoản Bi'S MART lần đầu để liên kết với Zalo. Lần sau bạn vào thẳng, không cần nhập lại.</p>
        <input placeholder="Mã nhân viên" value={username} onChange={(e) => setUsername(e.target.value)} autoCapitalize="none" />
        <input type="password" placeholder="Mật khẩu" value={password} onChange={(e) => setPassword(e.target.value)} />
        {error && <div className="error">{error}</div>}
        <button className="btn primary" disabled={busy || !username || !password}>
          {busy ? "Đang đăng nhập..." : "Đăng nhập"}
        </button>
      </form>
    </div>
  );
}
