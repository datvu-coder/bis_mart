import React, { useMemo, useState } from "react";
import type { Go } from "../components/App";
import Icon from "../components/Icon";
import ProductTile from "../components/ProductTile";
import { useAuth } from "../auth";
import { useCart } from "../cart";
import { money } from "../utils";

export default function ShopPage({ go }: { go: Go }) {
  const { member } = useAuth();
  const { products, productsError, count, total, add } = useCart();
  const [q, setQ] = useState("");
  const [group, setGroup] = useState("");

  const groups = useMemo(() => Array.from(new Set((products || []).map((p) => p.group).filter(Boolean))), [products]);
  const shown = useMemo(() => {
    const needle = q.trim().toLowerCase();
    return (products || []).filter((p) => (!group || p.group === group) && (!needle || p.name.toLowerCase().includes(needle)));
  }, [products, q, group]);

  return (
    <>
      <header className="top">
        <div className="deliver">
          <span>Giao đến</span>
          <b>{member?.address || "Chưa có địa chỉ"}</b>
        </div>
        <div className="search">
          <label htmlFor="q" className="sr">Tìm sản phẩm</label>
          <Icon name="search" size={18} />
          <input id="q" type="search" placeholder="Bạn muốn mua gì hôm nay?" value={q} onChange={(e) => setQ(e.target.value)} />
        </div>
      </header>
      <div className="scroll">
        {groups.length > 0 && (
          <div className="chips">
            {["", ...groups].map((g) => (
              <button key={g || "all"} className={`chip${group === g ? " on" : ""}`} onClick={() => setGroup(g)}>
                {g || "Tất cả"}
              </button>
            ))}
          </div>
        )}
        {productsError && <p className="note error">{productsError}</p>}
        {!products && !productsError && <p className="note">Đang tải sản phẩm...</p>}
        <div className="grid">
          {shown.map((p) => (
            <div key={p.id} className="pcard">
              <button className="plink" aria-label={p.name} onClick={() => go({ tab: "shop", sub: "product", productId: p.id })}>
                <ProductTile product={p} height={96} />
                <span className="pname">{p.name}</span>
              </button>
              <div className="prow">
                <span className="price">{money(p.price)}</span>
                <button className="add" aria-label={`Thêm ${p.name} vào giỏ`} onClick={() => add(p.id)}>
                  <Icon name="plus" size={22} strokeWidth={2.2} />
                </button>
              </div>
            </div>
          ))}
        </div>
        {products && !shown.length && <p className="note">Không tìm thấy sản phẩm phù hợp.</p>}
      </div>
      {count > 0 && (
        <div className="cartbar-wrap">
          <button className="cartbar" onClick={() => go({ tab: "cart" })}>
            <span>Xem giỏ hàng · {count} món</span>
            <b>{money(total)}</b>
          </button>
        </div>
      )}
    </>
  );
}
