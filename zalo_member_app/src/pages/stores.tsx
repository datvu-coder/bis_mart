import React, { useEffect, useMemo, useState } from "react";
import type { Go } from "../components/App";
import Icon from "../components/Icon";
import { api } from "../api";
import type { Store } from "../types";

export default function StoresPage({ go }: { go: Go }) {
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

  return (
    <>
      <header className="top">
        <div className="row-gap">
          <button className="sq" aria-label="Quay lại" onClick={() => go({ tab: "profile" })}><Icon name="back" strokeWidth={2} /></button>
          <h1 className="h1 sm">Hệ thống cửa hàng</h1>
        </div>
        <div className="search">
          <label htmlFor="sq" className="sr">Tìm cửa hàng</label>
          <Icon name="search" size={18} />
          <input id="sq" type="search" placeholder="Tìm theo tên, tỉnh/thành, địa chỉ" value={q} onChange={(e) => setQ(e.target.value)} />
        </div>
      </header>
      <div className="scroll">
        {error && <p className="note error">{error}</p>}
        {!rows && !error && <p className="note">Đang tải...</p>}
        {filtered.map((s) => (
          <div key={s.code} className="box stack tiny">
            <b>{s.name}</b>
            <span className="muted">{s.address || s.province}</span>
            <div className="links">
              {s.phone && <a href={`tel:${s.phone}`}>Gọi</a>}
              {s.latitude != null && s.longitude != null && (
                <a href={`https://www.google.com/maps/search/?api=1&query=${s.latitude},${s.longitude}`} target="_blank" rel="noreferrer">Chỉ đường</a>
              )}
            </div>
          </div>
        ))}
        {rows && !filtered.length && <p className="note">Không tìm thấy cửa hàng phù hợp.</p>}
      </div>
    </>
  );
}
