import React, { useEffect, useMemo, useState } from "react";
import { api } from "../api";
import type { Store } from "../types";

export default function StoresPage() {
  const [rows, setRows] = useState<Store[] | null>(null);
  const [error, setError] = useState("");
  const [q, setQ] = useState("");

  useEffect(() => {
    api.stores().then(setRows).catch((e) => setError(e.message));
  }, []);

  const filtered = useMemo(() => {
    const needle = q.trim().toLowerCase();
    return (rows || []).filter((s) => !needle || `${s.name} ${s.province} ${s.address}`.toLowerCase().includes(needle));
  }, [rows, q]);

  if (error) return <div className="center-note error">{error}</div>;
  if (!rows) return <div className="center-note">Đang tải...</div>;
  return (
    <div className="list">
      <h2 className="title">Hệ thống cửa hàng</h2>
      <input className="search" placeholder="Tìm theo tên, tỉnh/thành, địa chỉ" value={q} onChange={(e) => setQ(e.target.value)} />
      {filtered.map((s) => (
        <div key={s.code} className="card">
          <strong>{s.name}</strong>
          <div className="muted">{s.address || s.province}</div>
          <div className="actions">
            {s.phone && <a href={`tel:${s.phone}`}>Gọi</a>}
            {s.latitude != null && s.longitude != null && (
              <a href={`https://www.google.com/maps/search/?api=1&query=${s.latitude},${s.longitude}`} target="_blank" rel="noreferrer">Chỉ đường</a>
            )}
          </div>
        </div>
      ))}
      {!filtered.length && <div className="center-note">Không tìm thấy cửa hàng phù hợp.</div>}
    </div>
  );
}
