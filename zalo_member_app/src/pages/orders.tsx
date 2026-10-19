import React, { useEffect, useState } from "react";
import type { Go } from "../components/App";
import Icon from "../components/Icon";
import { api } from "../api";
import { useCart } from "../cart";
import type { Order } from "../types";
import { formatDate, money } from "../utils";

const STEPS = ["Đã đặt hàng", "Cửa hàng xác nhận", "Đang giao", "Đã giao"];
const REACHED: Record<string, number> = { placed: 1, confirmed: 2, shipping: 3, delivered: 4 };

export default function OrdersPage({ go }: { go: Go }) {
  const [orders, setOrders] = useState<Order[] | null>(null);
  const [error, setError] = useState("");
  const [tab, setTab] = useState<"active" | "done">("active");
  const { add } = useCart();

  useEffect(() => {
    api.orders().then(setOrders).catch((e) => setError(e.message));
  }, []);

  const shown = (orders || []).filter((o) => (tab === "done" ? o.status === "delivered" || o.status === "cancelled" : o.status !== "delivered" && o.status !== "cancelled"));

  return (
    <>
      <header className="top">
        <h1 className="h1">Đơn của tôi</h1>
        <div className="chips tight">
          <button className={`chip${tab === "active" ? " on" : ""}`} onClick={() => setTab("active")}>Đang giao</button>
          <button className={`chip${tab === "done" ? " on" : ""}`} onClick={() => setTab("done")}>Đã giao</button>
        </div>
      </header>
      <div className="scroll">
        {error && <p className="note error">{error}</p>}
        {!orders && !error && <p className="note">Đang tải...</p>}
        {orders && !shown.length && <p className="note">Chưa có đơn nào.</p>}
        {shown.map((o) => {
          const reached = REACHED[o.status] || 0;
          return (
            <section key={o.id} className="box ocard">
              <div className="row-between top-align">
                <div className="stack tiny">
                  <b>Đơn #{o.code}</b>
                  <span className="muted">{o.items.map((i) => `${i.quantity} × ${i.name}`).join(", ")}</span>
                  <span className="muted">{formatDate(o.createdAt)}</span>
                </div>
                <span className="osum">{money(o.total)}</span>
              </div>
              {o.status === "cancelled" ? (
                <p className="note error left">Đơn đã huỷ</p>
              ) : (
                <ol className="steps">
                  {STEPS.map((label, i) => {
                    const done = i < reached;
                    return (
                      <li key={label}>
                        <div className="rail">
                          <span className={`dot${done ? " done" : ""}`}>{done && <Icon name="check" size={12} strokeWidth={3} />}</span>
                          {i < STEPS.length - 1 && <span className={`seg${i < reached - 1 ? " done" : ""}`} />}
                        </div>
                        <span className={`step-label${done ? " done" : ""}${i === reached - 1 ? " now" : ""}`}>{label}</span>
                      </li>
                    );
                  })}
                </ol>
              )}
              <button className="outline" onClick={() => { o.items.forEach((i) => add(i.productId, i.quantity)); go({ tab: "cart" }); }}>Mua lại</button>
            </section>
          );
        })}
      </div>
    </>
  );
}
