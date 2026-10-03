import React, { useCallback, useEffect, useState } from "react";
import { useNavigate, useSearchParams } from "react-router-dom";
import { Page, useSnackbar } from "zmp-ui";
import { api } from "../api";
import Icon from "../components/Icon";
import { OrderProgress } from "../components/OrderTimeline";
import { ConfirmSheet } from "../components/Sheet";
import Skeleton, { EmptyState } from "../components/Skeleton";
import SwipeRow from "../components/SwipeRow";
import SubHero from "../components/SubHero";
import { bumpData, useDataVersion } from "../data";
import { ORDER_STATUS_LABEL, Order, OrderSummary } from "../types";
import { dmy, todayYmd } from "../utils";

export default function OrdersPage() {
  const nav = useNavigate();
  const { openSnackbar } = useSnackbar();
  const version = useDataVersion();
  const [params] = useSearchParams();
  const [view, setView] = useState<"open" | "all" | "sum">(params.get("open") ? "open" : "all");
  const [orders, setOrders] = useState<Order[] | null>(null);
  const [canManage, setCanManage] = useState(false);
  const [error, setError] = useState("");
  const [date, setDate] = useState(todayYmd());
  const [sum, setSum] = useState<OrderSummary | null>(null);
  const [withApproved, setWithApproved] = useState(true);
  const [delOrder, setDelOrder] = useState<Order | null>(null);
  const removeOrder = async () => {
    if (!delOrder) return;
    try {
      await api.deleteOrder(delOrder.id);
      openSnackbar({ text: "Đã xoá đơn hàng", type: "success" });
      bumpData();
    } catch (e) {
      openSnackbar({ text: e instanceof Error ? e.message : "Không xoá được", type: "error" });
    }
    setDelOrder(null);
  };

  const load = useCallback(async () => {
    setError("");
    try {
      const res = await api.orders(view === "open" ? { status: "open" } : {});
      setOrders(res.orders);
      setCanManage(res.canManage);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Không tải được đơn hàng");
    }
  }, [view]);

  useEffect(() => { if (view !== "sum") load(); }, [load, view, version]);
  useEffect(() => {
    if (view !== "sum") return;
    setSum(null);
    api.ordersSummary(date, withApproved ? "submitted,approved" : "submitted,approved,ordered").then(setSum).catch((e) => setError(e instanceof Error ? e.message : "Không tải được tổng hợp"));
  }, [view, date, withApproved, version]);

  useEffect(() => { if (canManage === false && view === "sum") setView("all"); }, [canManage, view]);

  const tabs: [typeof view, string][] = [["all", "Tất cả"], ["open", "Chờ hàng"], ...(canManage || view === "sum" ? [["sum", "Tổng hợp"] as [typeof view, string]] : [])];

  return (
    <Page className="page">
      <SubHero title="Đặt hàng & nhận hàng" note="Tạo đơn, theo dõi và xác nhận hàng về"
        right={<>
          <button className="hero-btn" onClick={() => nav("/orders/new")} aria-label="Tạo đơn mới"><Icon name="plus" size={22} /></button>
        </>} />

      <div className="segmented">
        {tabs.map(([k, v]) => <button key={k} className={view === k ? "active" : ""} onClick={() => setView(k)}>{v}</button>)}
      </div>

      {error && <div className="error">{error} <button className="link" onClick={load}>Thử lại</button></div>}

      {view === "sum" ? (
        <>
          <div className="toolbar">
            <input type="date" value={date} onChange={(e) => setDate(e.target.value)} />
            <button className={`chip ${withApproved ? "" : "active"}`} onClick={() => setWithApproved((v) => !v)}>{withApproved ? "Chưa đặt NCC" : "Gồm cả đã đặt"}</button>
          </div>
          {!sum && !error && <Skeleton count={3} />}
          {sum && <div className="section-title">{sum.orders} đơn · {sum.items.length} mặt hàng · {dmy(sum.date)}</div>}
          {sum && sum.items.length === 0 && <EmptyState icon={<Icon name="cart" size={34} />} title="Chưa có đơn nào" hint="Chọn ngày khác hoặc đợi cửa hàng gửi đơn" />}
          <div className="list">
            {sum?.items.map((p) => (
              <div key={`${p.productName}|${p.unit}`} className="card sum-card">
                <div className="card-top"><span className="card-title">{p.productName}</span><b className="sum-total">{p.total} {p.unit}</b></div>
                <div className="sum-stores">{p.byStore.map((s) => <span key={s.storeCode}>{s.storeName || s.storeCode}: <b>{s.qty}</b></span>)}</div>
              </div>
            ))}
          </div>
        </>
      ) : (
        <>
          {!orders && !error && <Skeleton count={3} />}
          {orders && orders.length === 0 && (
            <EmptyState icon={<Icon name="cart" size={34} />} title={view === "open" ? "Không có đơn nào đang chờ hàng" : "Chưa có đơn đặt hàng"} hint="Bấm + để tạo đơn mới" />
          )}
          <div className="list">
            {(orders || []).map((o) => (
              <SwipeRow key={o.id} onEdit={o.canEdit ? () => nav(`/orders/${o.id}/edit`) : undefined} onDelete={o.canDelete ? () => setDelOrder(o) : undefined}>
              <button className="card order-card" onClick={() => nav(`/orders/${o.id}`)}>
                <div className="card-top">
                  <span className="card-title">{o.storeName} · {dmy(o.orderDate)}</span>
                  <span className={`badge order-${o.status}`}>{ORDER_STATUS_LABEL[o.status]}</span>
                </div>
                <div className="meta">
                  <span className="meta-item"><Icon name="box" size={14} /> {o.itemCount} mặt hàng</span>
                  <span className="meta-item"><Icon name="user" size={14} /> {o.createdByName}</span>
                  {o.supplier && <span className="meta-item"><Icon name="store" size={14} /> {o.supplier}</span>}
                </div>
                <OrderProgress order={o} />
              </button>
              </SwipeRow>
            ))}
          </div>
        </>
      )}
      <ConfirmSheet open={!!delOrder} title="Xoá đơn hàng?" message="Đơn và toàn bộ mặt hàng sẽ bị xoá hẳn, không khôi phục được." confirmLabel="Xoá" danger onConfirm={removeOrder} onClose={() => setDelOrder(null)} />
    </Page>
  );
}
