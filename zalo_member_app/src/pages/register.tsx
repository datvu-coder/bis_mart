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
    <div className="app">
      <div className="scroll reg">
        <h1 className="h1">Bi'S MART Member</h1>
        <p className="muted">Đăng ký thành viên để tích điểm, đặt hàng và nhận ưu đãi tại hơn 60 cửa hàng.</p>
        <section className="box stack">
          <label className="label" htmlFor="rn">Họ và tên</label>
          <input id="rn" className="field" value={name} onChange={(e) => setName(e.target.value)} placeholder="Nguyễn Văn A" maxLength={120} />
          <label className="label" htmlFor="rb">Ngày sinh (không bắt buộc)</label>
          <input id="rb" className="field" type="date" value={birthday} onChange={(e) => setBirthday(e.target.value)} />
          <p className="muted">Số điện thoại Zalo sẽ được dùng để tích điểm các đơn mua tại cửa hàng.</p>
          {error && <p className="note error left">{error}</p>}
          <button className="cta" disabled={busy} onClick={submit}>{busy ? "Đang đăng ký..." : "Đăng ký bằng số điện thoại Zalo"}</button>
        </section>
      </div>
    </div>
  );
}
