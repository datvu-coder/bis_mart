import React, { useState } from "react";
import type { Go } from "../components/App";
import Icon from "../components/Icon";
import ProductTile from "../components/ProductTile";
import { useCart } from "../cart";
import { money } from "../utils";

export default function ProductPage({ id, go }: { id: number; go: Go }) {
  const { products, add } = useCart();
  const [qty, setQty] = useState(1);
  const p = products?.find((x) => x.id === id);
  if (!p) return <div className="center-note">Không tìm thấy sản phẩm.</div>;

  return (
    <>
      <header className="top row-between">
        <button className="sq" aria-label="Quay lại cửa hàng" onClick={() => go({ tab: "shop" })}><Icon name="back" strokeWidth={2} /></button>
      </header>
      <div className="scroll">
        <ProductTile product={p} height={260} big />
        <div className="stack">
          <h1 className="h1">{p.name}</h1>
          <span className="big-price">{money(p.price)}{p.unit ? ` / ${p.unit}` : ""}</span>
          {p.group && <span className="muted">Nhãn hàng: {p.group}</span>}
        </div>
        <section className="box row-between">
          <span className="label">Số lượng</span>
          <div className="stepper">
            <button className="sq" aria-label="Giảm số lượng" onClick={() => setQty(Math.max(1, qty - 1))}><Icon name="minus" strokeWidth={2.2} /></button>
            <span className="qty">{qty}</span>
            <button className="sq fill" aria-label="Tăng số lượng" onClick={() => setQty(Math.min(99, qty + 1))}><Icon name="plus" strokeWidth={2.2} /></button>
          </div>
        </section>
      </div>
      <div className="footbar">
        <button className="cta between" onClick={() => { add(p.id, qty); go({ tab: "cart" }); }}>
          <span>Thêm vào giỏ</span><span>{money(p.price * qty)}</span>
        </button>
      </div>
    </>
  );
}
