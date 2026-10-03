import React, { useEffect, useRef, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import { Page, useSnackbar } from "zmp-ui";
import { api } from "../api";
import Icon from "../components/Icon";
import Sheet from "../components/Sheet";
import StoreSelect, { useStoreChoice } from "../components/StoreSelect";
import SubHero from "../components/SubHero";
import { bumpData } from "../data";
import { CatalogProduct, OrderItem } from "../types";
import { dmy } from "../utils";

export default function OrderFormPage() {
  const { id } = useParams();
  const editId = id ? Number(id) : null;
  const nav = useNavigate();
  const { openSnackbar } = useSnackbar();
  const [store, setStore] = useStoreChoice();
  const [items, setItems] = useState<OrderItem[]>([]);
  const [supplier, setSupplier] = useState("");
  const [note, setNote] = useState("");
  const [busy, setBusy] = useState(false);
  const [picker, setPicker] = useState(false);
  const [q, setQ] = useState("");
  const [products, setProducts] = useState<CatalogProduct[]>([]);
  const [custom, setCustom] = useState("");
  const timer = useRef<number>();

  useEffect(() => {
    if (!editId) return;
    api.order(editId).then((o) => {
      setItems(o.items.map((i) => ({ productId: i.productId, productName: i.productName, unit: i.unit, qty: i.qty, note: i.note })));
      setSupplier(o.supplier);
      setNote(o.note);
      setStore(o.storeCode);
    }).catch((e) => openSnackbar({ text: e instanceof Error ? e.message : "Không tải được đơn", type: "error" }));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [editId]);

  useEffect(() => {
    if (!picker) return;
    window.clearTimeout(timer.current);
    timer.current = window.setTimeout(() => {
      api.catalog(q.trim()).then((r) => setProducts(r.products)).catch(() => {});
    }, 200);
    return () => window.clearTimeout(timer.current);
  }, [picker, q]);

  const add = (p: { id: number | null; name: string; unit: string }) => {
    setItems((cur) => {
      const at = cur.findIndex((i) => (p.id ? i.productId === p.id : i.productName.toLowerCase() === p.name.toLowerCase()));
      if (at >= 0) return cur.map((i, k) => (k === at ? { ...i, qty: i.qty + 1 } : i));
      return [...cur, { productId: p.id, productName: p.name, unit: p.unit, qty: 1, note: "" }];
    });
  };
  const setQty = (k: number, qty: number) => setItems((cur) => cur.map((i, j) => (j === k ? { ...i, qty: Math.max(0, Math.min(100000, qty)) } : i)));

  const copyLast = async () => {
    try {
      const last = await api.lastOrder(store);
      if (!last.items.length) return openSnackbar({ text: "Cửa hàng chưa có đơn nào trước đó", type: "warning" });
      setItems(last.items.map((i) => ({ productId: i.productId, productName: i.productName, unit: i.unit, qty: i.qty, note: i.note })));
      openSnackbar({ text: `Đã sao chép đơn ngày ${dmy(last.orderDate || "")}`, type: "success" });
    } catch (e) {
      openSnackbar({ text: e instanceof Error ? e.message : "Không sao chép được", type: "error" });
    }
  };

  const submit = async () => {
    setBusy(true);
    try {
      const body = { storeCode: store, supplier: supplier.trim(), note: note.trim(), items: items.filter((i) => i.qty > 0) };
      const o = editId ? await api.updateOrder(editId, body) : await api.createOrder(body);
      openSnackbar({ text: editId ? "Đã cập nhật đơn" : "Đã gửi đơn đặt hàng", type: "success" });
      bumpData();
      nav(`/orders/${o.id}`, { replace: true });
    } catch (e) {
      openSnackbar({ text: e instanceof Error ? e.message : "Không gửi được đơn", type: "error" });
    } finally {
      setBusy(false);
    }
  };

  const valid = items.some((i) => i.qty > 0);
  return (
    <Page className="page with-bar">
      <SubHero title={editId ? "Sửa đơn đặt hàng" : "Đơn đặt hàng mới"} note="Chọn sản phẩm và số lượng cần đặt" />

      {!editId && (
        <section className="panel">
          <h3>Cửa hàng</h3>
          <div className="field-row"><StoreSelect value={store} onChange={setStore} /></div>
          <button type="button" className="btn wide soft" onClick={copyLast}><Icon name="repeat" size={18} /> Sao chép đơn gần nhất</button>
        </section>
      )}

      <section className="panel">
        <div className="panel-head"><h3>Sản phẩm</h3><span className="count">{items.length} mặt hàng</span></div>
        {items.length === 0 && <div className="hint">Chưa có sản phẩm. Bấm "Thêm sản phẩm" bên dưới.</div>}
        {items.map((it, k) => (
          <div key={`${it.productId ?? it.productName}-${k}`} className="line">
            <span className="line-name"><b>{it.productName}</b><small>{it.unit || "—"}</small></span>
            <div className="stepper-mini">
              <button type="button" onClick={() => setQty(k, it.qty - 1)} aria-label="Giảm"><Icon name="minus" size={16} /></button>
              <input inputMode="decimal" value={it.qty || ""} placeholder="0" onChange={(e) => setQty(k, Number(e.target.value.replace(",", ".").replace(/[^\d.]/g, "")) || 0)} />
              <button type="button" onClick={() => setQty(k, it.qty + 1)} aria-label="Tăng"><Icon name="plus" size={16} /></button>
            </div>
            <button type="button" className="icon-btn" onClick={() => setItems((cur) => cur.filter((_, j) => j !== k))} aria-label="Xoá"><Icon name="trash" size={16} /></button>
          </div>
        ))}
        <button type="button" className="btn wide soft" onClick={() => setPicker(true)}><Icon name="plus" size={18} /> Thêm sản phẩm</button>
      </section>

      <section className="panel">
        <h3>Thông tin thêm</h3>
        <label className="field"><span>Nhà cung cấp</span><input value={supplier} onChange={(e) => setSupplier(e.target.value)} placeholder="VD: Kho tổng, NCC Delimil" maxLength={120} /></label>
        <label className="field"><span>Ghi chú</span><textarea value={note} onChange={(e) => setNote(e.target.value)} placeholder="VD: Cần gấp trước thứ 6" /></label>
      </section>

      <div className="action-bar">
        <button className="btn primary wide" disabled={busy || !valid || !store} onClick={submit}>{busy ? "Đang gửi..." : editId ? "Lưu thay đổi" : "Gửi đơn đặt hàng"}</button>
      </div>

      <Sheet open={picker} title="Chọn sản phẩm" onClose={() => setPicker(false)}>
        <label className="search light"><Icon name="search" size={18} /><input placeholder="Tìm sản phẩm..." value={q} onChange={(e) => setQ(e.target.value)} /></label>
        <div className="opt-list tall">
          {products.length === 0 && <div className="hint pad">Không có sản phẩm khớp. Nhập tên bên dưới để thêm tay.</div>}
          {products.map((p) => {
            const have = items.find((i) => i.productId === p.id);
            return (
              <button key={p.id} className={`opt ${have ? "on" : ""}`} onClick={() => add({ id: p.id, name: p.name, unit: p.unit })}>
                <span>{p.name}<small className="muted"> · {p.unit || "—"}</small></span>
                {have ? <b>×{have.qty}</b> : <Icon name="plus" size={16} />}
              </button>
            );
          })}
        </div>
        <div className="composer">
          <input placeholder="Hoặc nhập tên hàng khác" value={custom} onChange={(e) => setCustom(e.target.value)} />
          <button className="send" disabled={!custom.trim()} onClick={() => { add({ id: null, name: custom.trim(), unit: "" }); setCustom(""); }} aria-label="Thêm"><Icon name="plus" size={20} /></button>
        </div>
        <div className="sheet-actions"><button className="btn primary" onClick={() => setPicker(false)}>Xong ({items.length})</button></div>
      </Sheet>
    </Page>
  );
}
