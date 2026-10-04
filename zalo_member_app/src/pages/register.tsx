import React, { useState } from "react";
import { useAuth } from "../auth";

export default function RegisterPage() {
  const { register } = useAuth();
  const [name, setName] = useState("");
  const [birthday, setBirthday] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");

  const submit = async () => {
    if (!name.trim()) return setError("Vui lòng nhập họ tên.");
    setBusy(true);
    setError("");
    try {
      await register(name, birthday);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Đăng ký thất bại.");
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="page register">
      <div className="hero">
        <h1>Bi'S MART Member</h1>
        <p>Đăng ký thành viên để tích điểm và nhận ưu đãi tại hơn 60 cửa hàng.</p>
      </div>
      <div className="card form">
        <label>Họ và tên</label>
        <input value={name} onChange={(e) => setName(e.target.value)} placeholder="Nguyễn Văn A" maxLength={120} />
        <label>Ngày sinh (không bắt buộc)</label>
        <input type="date" value={birthday} onChange={(e) => setBirthday(e.target.value)} />
        <p className="muted">Số điện thoại Zalo sẽ được dùng để tích điểm các đơn mua tại cửa hàng.</p>
        {error && <p className="error">{error}</p>}
        <button className="primary-btn" disabled={busy} onClick={submit}>
          {busy ? "Đang đăng ký..." : "Đăng ký bằng số điện thoại Zalo"}
        </button>
      </div>
    </div>
  );
}
