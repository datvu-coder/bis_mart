import React, { useCallback, useEffect, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import { Page, useSnackbar } from "zmp-ui";
import { api } from "../api";
import Icon from "../components/Icon";
import PhotoField, { PhotoStrip } from "../components/PhotoField";
import Sheet, { ConfirmSheet } from "../components/Sheet";
import SubHero from "../components/SubHero";
import { bumpData } from "../data";
import { ORDER_STATUS_LABEL, OrderDetail } from "../types";
import { dmy, formatDateTime } from "../utils";

export default function OrderDetailPage() {
  const { id } = useParams();
  const orderId = Number(id);
  const nav = useNavigate();
  const { openSnackbar } = useSnackbar();
  const [o, setO] = useState<OrderDetail | null>(null);
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);
  const [receiving, setReceiving] = useState(false);
  const [recv, setRecv] = useState<Record<number, string>>({});
  const [note, setNote] = useState("");
  const [photos, setPhotos] = useState<string[]>([]);
  const [cancel, setCancel] = useState(false);

  const load = useCallback(() => {
    api.order(orderId).then(setO).catch((e) => setError(e instanceof Error ? e.message : "Không tải được đơn"));
  }, [orderId]);
  useEffect(load, [load]);

  const act = async (fn: () => Promise<unknown>, ok: string) => {
    setBusy(true);
    try {
      await fn();
      openSnackbar({ text: ok, type: "success" });
      bumpData();
      load();
    } catch (e) {
      openSnackbar({ text: e instanceof Error ? e.message : "Không xử lý được", type: "error" });
    } finally {
      setBusy(false);
    }
  };

  const openReceive = () => {
    if (!o) return;
    setRecv(Object.fromEntries(o.items.map((i) => [i.id, String(i.qtyReceived ?? i.qty)])));
    setNote("");
    setPhotos([]);
    setReceiving(true);
  };

  const submitReceive = () =>
    act(async () => {
      await api.receiveOrder(orderId, {
        items: Object.entries(recv).map(([k, v]) => ({ id: Number(k), qtyReceived: Number(v.replace(",", ".")) || 0 })),
        note: note.trim(), photoUrls: photos,
      });
      setReceiving(false);
    }, "Đã xác nhận nhận hàng");

  if (error) return <Page className="page"><SubHero title="Đơn đặt hàng" /><div className="error">{error}</div></Page>;
  if (!o) return <Page className="page"><SubHero title="Đơn đặt hàng" note="Đang tải..." /></Page>;

  const hasBar = o.canReceive || o.canManage;
  const shortCount = o.items.filter((i) => i.qtyReceived != null && i.qtyReceived < i.qty).length;
  return (
    <Page className={`page ${hasBar ? "with-bar" : ""}`}>
      <SubHero title={`${o.storeName} · ${dmy(o.orderDate)}`} note={`${o.createdByName}${o.supplier ? ` · ${o.supplier}` : ""}`}
        right={<>
          {o.canEdit && <button className="hero-btn" onClick={() => nav(`/orders/${o.id}/edit`)} aria-label="Sửa"><Icon name="edit" size={20} /></button>}
          {o.canCancel && <button className="hero-btn" onClick={() => setCancel(true)} aria-label="Huỷ đơn"><Icon name="trash" size={20} /></button>}
        </>} />

      <section className="panel">
        <div className="panel-head"><h3>Trạng thái</h3><span className={`badge order-${o.status}`}>{ORDER_STATUS_LABEL[o.status]}</span></div>
        {o.note && <p className="desc">Ghi chú: {o.note}</p>}
        {o.receivedAt && <div className="hint">{o.receivedByName} nhận hàng lúc {formatDateTime(o.receivedAt)}{shortCount ? ` · thiếu ${shortCount} mặt hàng` : ""}</div>}
        {o.receiptNote && <p className="desc">Ghi chú nhận hàng: {o.receiptNote}</p>}
      </section>

      <section className="panel">
        <div className="panel-head"><h3>Mặt hàng</h3><span className="count">{o.items.length}</span></div>
        {o.items.map((i) => {
          const short = i.qtyReceived != null && i.qtyReceived < i.qty;
          return (
            <div key={i.id} className="line">
              <span className="line-name"><b>{i.productName}</b><small>{i.unit || "—"}</small></span>
              <span className="line-qty">
                <b>{i.qty}</b>
                {i.qtyReceived != null && <small className={short ? "bad" : "ok"}>nhận {i.qtyReceived}</small>}
              </span>
            </div>
          );
        })}
      </section>

      {o.receiptPhotos.length > 0 && <section className="panel"><h3>Ảnh nhận hàng</h3><PhotoStrip photos={o.receiptPhotos} /></section>}

      {hasBar && (
        <div className="action-bar">
          {o.canManage && o.status === "submitted" && <button className="btn" disabled={busy} onClick={() => act(() => api.setOrderStatus(o.id, "approved"), "Đã duyệt đơn")}>Duyệt</button>}
          {o.canManage && (o.status === "submitted" || o.status === "approved") && <button className="btn" disabled={busy} onClick={() => act(() => api.setOrderStatus(o.id, "ordered"), "Đã đánh dấu đặt NCC")}>Đã đặt NCC</button>}
          {o.canReceive && <button className="btn primary" disabled={busy} onClick={openReceive}><Icon name="box" size={18} /> Nhận hàng</button>}
        </div>
      )}

      <Sheet open={receiving} title="Xác nhận nhận hàng" onClose={() => setReceiving(false)}>
        <div className="recv-list">
          {o.items.map((i) => (
            <div key={i.id} className="line">
              <span className="line-name"><b>{i.productName}</b><small>Đặt {i.qty} {i.unit}</small></span>
              <input className="qty-input" inputMode="decimal" value={recv[i.id] ?? ""} onChange={(e) => setRecv((r) => ({ ...r, [i.id]: e.target.value.replace(/[^\d.,]/g, "") }))} />
            </div>
          ))}
        </div>
        <label className="field"><span>Ghi chú (hàng thiếu, hư hỏng...)</span><input value={note} onChange={(e) => setNote(e.target.value)} /></label>
        <div className="field"><span>Ảnh hàng / phiếu giao</span><PhotoField value={photos} onChange={setPhotos} max={4} /></div>
        <div className="sheet-actions">
          <button className="btn" onClick={() => setReceiving(false)}>Huỷ</button>
          <button className="btn primary" disabled={busy} onClick={submitReceive}>{busy ? "Đang lưu..." : "Xác nhận"}</button>
        </div>
      </Sheet>

      <ConfirmSheet open={cancel} title="Huỷ đơn đặt hàng?" message="Đơn sẽ chuyển sang trạng thái đã huỷ và không thể mở lại." confirmLabel="Huỷ đơn" danger busy={busy}
        onConfirm={() => { setCancel(false); act(() => api.setOrderStatus(o.id, "cancelled"), "Đã huỷ đơn"); }} onClose={() => setCancel(false)} />
    </Page>
  );
}
