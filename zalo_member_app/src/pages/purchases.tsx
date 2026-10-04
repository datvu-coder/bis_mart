import React, { useEffect, useState } from "react";
import { api } from "../api";
import type { Purchase } from "../types";
import { formatDate, formatVnd } from "../utils";

export default function PurchasesPage() {
  const [rows, setRows] = useState<Purchase[] | null>(null);
  const [error, setError] = useState("");
  const [open, setOpen] = useState<number | null>(null);

  useEffect(() => {
    api.purchases().then(setRows).catch((e) => setError(e.message));
  }, []);

  if (error) return <div className="center-note error">{error}</div>;
  if (!rows) return <div className="center-note">Đang tải...</div>;
  if (!rows.length) return <div className="center-note">Chưa có đơn mua nào gắn với số điện thoại của bạn.</div>;
  return (
    <div className="list">
      <h2 className="title">Lịch sử mua hàng</h2>
      {rows.map((p) => (
        <div key={p.id} className="card" onClick={() => setOpen(open === p.id ? null : p.id)}>
          <div className="row">
            <div>
              <strong>{p.storeName}</strong>
              <div className="muted">{formatDate(p.date)}</div>
            </div>
            <div className="right">
              <strong>{formatVnd(p.total)}</strong>
              <div className="muted">+{p.points} điểm</div>
            </div>
          </div>
          {open === p.id && p.items.length > 0 && (
            <ul className="items">
              {p.items.map((it, i) => (
                <li key={i}>
                  {it.name} × {it.quantity} <span>{formatVnd(it.unitPrice * it.quantity)}</span>
                </li>
              ))}
            </ul>
          )}
        </div>
      ))}
    </div>
  );
}
