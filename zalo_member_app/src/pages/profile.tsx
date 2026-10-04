import React, { useState } from "react";
import { api } from "../api";
import { useAuth } from "../auth";

export default function ProfilePage() {
  const { member, setMember } = useAuth();
  const [name, setName] = useState(member?.fullName || "");
  const [birthday, setBirthday] = useState(member?.birthday || "");
  const [msg, setMsg] = useState("");
  const [busy, setBusy] = useState(false);
  if (!member) return null;

  const save = async () => {
    setBusy(true);
    setMsg("");
    try {
      setMember((await api.updateMe({ fullName: name, birthday })).member);
      setMsg("Đã lưu thông tin.");
    } catch (e) {
      setMsg(e instanceof Error ? e.message : "Lưu thất bại.");
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="card form">
      <h2 className="title">Thông tin cá nhân</h2>
      <label>Số điện thoại</label>
      <input value={member.phone} disabled />
      <label>Họ và tên</label>
      <input value={name} onChange={(e) => setName(e.target.value)} maxLength={120} />
      <label>Ngày sinh</label>
      <input type="date" value={birthday} onChange={(e) => setBirthday(e.target.value)} />
      {msg && <p className="muted">{msg}</p>}
      <button className="primary-btn" disabled={busy} onClick={save}>Lưu</button>
    </div>
  );
}
