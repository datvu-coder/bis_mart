import React, { useState } from "react";
import type { Go } from "../components/App";
import Icon from "../components/Icon";
import ProductTile from "../components/ProductTile";
import { api } from "../api";
import { useAuth } from "../auth";
import { useCart } from "../cart";
import type { PaymentMethod } from "../types";
import { money } from "../utils";

const METHODS: [PaymentMethod, string][] = [["cod", "Khi nhận hàng"], ["bank", "Chuyển khoản"], ["card", "Thẻ"]];

export default function CartPage({ go }: { go: Go }) {
  const { member } = useAuth();
  const { products, qty, total, set, clear } = useCart();
  const [method, setMethod] = useState<PaymentMethod>("cod");
  const [address, setAddress] = useState(member?.address || "");
  const [note, setNote] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");

  const lines = (products || []).filter((p) => (qty[p.id] || 0) > 0);

  const order = async () => {
    if (!address.trim()) return setError("Vui lòng nhập địa chỉ giao hàng.");
    setBusy(true);
    setError("");
    try {
      await api.createOrder({
        items: lines.map((p) => ({ productId: p.id, quantity: qty[p.id] })),
        paymentMethod: method, address: address.trim(), note: note.trim(),
      });
      clear();
      go({ tab: "orders" });
    } catch (e) {
      setError(e instanceof Error ? e.message : "Đặt hàng thất bại.");
    } finally {
      setBusy(false);
    }
  };

  return (
    <>
      <header className="top"><h1 className="h1">Giỏ hàng</h1></header>
      {!lines.length ? (
        <div className="scroll">
          <p className="note">Giỏ hàng đang trống.</p>
          <button className="cta" onClick={() => go({ tab: "shop" })}>Mua sắm ngay</button>
        </div>
      ) : (
        <>
          <div className="scroll">
            <section className="box tight">
              {lines.map((p) => (
                <div key={p.id} className="line">
                  <div className="line-info">
                    <div className="mini"><ProductTile product={p} height={52} /></div>
                    <div className="stack tiny">
                      <span className="pname">{p.name}</span>
                      <span className="muted">{money(p.price * qty[p.id])}</span>
                    </div>
                  </div>
                  <div className="stepper">
                    <button className="sq flat" aria-label={`Giảm số lượng ${p.name}`} onClick={() => set(p.id, qty[p.id] - 1)}><Icon name="minus" strokeWidth={2.2} /></button>
                    <span className="qty sm">{qty[p.id]}</span>
                    <button className="sq flat accent" aria-label={`Tăng số lượng ${p.name}`} onClick={() => set(p.id, qty[p.id] + 1)}><Icon name="plus" strokeWidth={2.2} /></button>
                  </div>
                </div>
              ))}
            </section>
            <section className="box stack">
              <span className="label">Giao đến</span>
              <b>{member?.fullName} · {member?.phone}</b>
              <label htmlFor="addr" className="sr">Địa chỉ giao hàng</label>
              <input id="addr" className="field" placeholder="Địa chỉ giao hàng" value={address} onChange={(e) => setAddress(e.target.value)} maxLength={300} />
            </section>
            <fieldset className="methods">
              <legend className="label">Hình thức thanh toán</legend>
              <div className="three">
                {METHODS.map(([k, label]) => (
                  <button key={k} aria-pressed={method === k} className={`method${method === k ? " on" : ""}`} onClick={() => setMethod(k)}>{label}</button>
                ))}
              </div>
            </fieldset>
            <section className="stack">
              <label htmlFor="note" className="label">Ghi chú cho người giao</label>
              <input id="note" className="field" placeholder="Ví dụ: gọi trước khi đến" value={note} onChange={(e) => setNote(e.target.value)} maxLength={300} />
            </section>
            {error && <p className="note error">{error}</p>}
          </div>
          <div className="footbar col">
            <div className="row-between">
              <span className="label">Tạm tính</span>
              <span className="total">{money(total)}</span>
            </div>
            <button className="cta" disabled={busy} onClick={order}>{busy ? "Đang đặt hàng..." : "Đặt hàng"}</button>
          </div>
        </>
      )}
    </>
  );
}
