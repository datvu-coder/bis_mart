import React, { useEffect, useState } from "react";
import type { Go } from "../components/App";
import Icon from "../components/Icon";
import { api } from "../api";
import type { Purchase } from "../types";
import { formatDate, money } from "../utils";

export default function PurchasesPage({ go }: { go: Go }) {
  const [rows, setRows] = useState<Purchase[] | null>(null);
  const [error, setError] = useState("");
  const [open, setOpen] = useState<number | null>(null);

  useEffect(() => {
    api.purchases().then(setRows).catch((e) => setError(e.message));
  }, []);

  return (
    <>
      <header className="top row-gap">
        <button className="sq" aria-label="Quay lại" onClick={() => go({ tab: "profile" })}><Icon name="back" strokeWidth={2} /></button>
        <h1 className="h1 sm">Lịch sử mua tại cửa hàng</h1>
      </header>
      <div className="scroll">
        {error && <p className="note error">{error}</p>}
        {!rows && !error && <p className="note">Đang tải...</p>}
        {rows && !rows.length && <p className="note">Chưa có đơn mua nào gắn với số điện thoại của bạn.</p>}
        {(rows || []).map((p) => (
          <button key={p.id} className="box pbtn" aria-expanded={open === p.id} onClick={() => setOpen(open === p.id ? null : p.id)}>
            <div className="row-between">
              <div className="stack tiny"><b>{p.storeName}</b><span className="muted">{formatDate(p.date)}</span></div>
              <div className="stack tiny right"><b>{money(p.total)}</b><span className="delta">+{p.points} điểm</span></div>
            </div>
            {open === p.id && p.items.length > 0 && (
              <ul className="items">
                {p.items.map((it, i) => (
                  <li key={i}>{it.name} × {it.quantity}<span>{money(it.unitPrice * it.quantity)}</span></li>
                ))}
              </ul>
            )}
          </button>
        ))}
      </div>
    </>
  );
}
