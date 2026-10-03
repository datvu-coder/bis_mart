import React from "react";
import { useNavigate } from "react-router-dom";
import Icon, { IconName } from "../../components/Icon";
import MinimizeButton from "../../components/MinimizeButton";
import NotificationBell from "../../components/NotificationBell";
import { refreshOps, useOpsSummary } from "../../data";
import { FUND_STATUS_LABEL } from "../../types";
import { greeting } from "../../utils";

interface Tile {
  key: string;
  icon: IconName;
  title: string;
  hint: string;
  badge?: number;
  tone?: "warn" | "ok" | "danger";
  to: string;
}

export default function OpsTab({ active }: { active: boolean }) {
  const nav = useNavigate();
  const ops = useOpsSummary();
  React.useEffect(() => { if (active) refreshOps(); }, [active]);

  const fund = ops?.fund;
  const fundHint = !fund ? "Đang tải..." : fund.reportedToday ? `Hôm nay: ${FUND_STATUS_LABEL[fund.status || "submitted"]}` : "Hôm nay chưa báo cáo";
  const tiles: Tile[] = [
    { key: "fund", icon: "wallet", title: "Quỹ cuối ngày", hint: fundHint, tone: fund && !fund.reportedToday ? "warn" : "ok", to: "/fund",
      badge: ops?.canManage ? (fund?.pendingReview || 0) : 0 },
    { key: "orders", icon: "cart", title: "Đặt hàng", hint: "Tạo đơn, sao chép đơn gần nhất", to: "/orders",
      badge: ops?.canManage ? ops.orders.pendingApproval : 0 },
    { key: "receive", icon: "box", title: "Nhận hàng", hint: ops ? `${ops.orders.awaitingReceipt} đơn đang chờ hàng về` : "Đang tải...", to: "/orders?open=1",
      badge: ops?.orders.awaitingReceipt || 0 },
    { key: "board", icon: "megaphone", title: "Bảng tin", hint: "Thông báo có xác nhận đã đọc", to: "/board", badge: ops?.board.unread || 0 },
    ...(ops?.canManage ? [{ key: "gallery", icon: "image" as IconName, title: "Kho ảnh", hint: "Ảnh việc, quỹ, nhận hàng, bảng tin", to: "/gallery" }] : []),
  ];

  return (
    <>
      <header className="hero">
        <div className="hero-row">
          <div>
            <div className="hero-sub">{greeting()}</div>
            <h1>Vận hành cửa hàng</h1>
          </div>
          <div className="hero-actions"><MinimizeButton /><NotificationBell /></div>
        </div>
      </header>

      {ops?.canManage && (fund?.missingCount || fund?.pendingReview) ? (
        <div className="alert-card" role="status">
          <Icon name="alert" size={20} />
          <div>
            {!!fund?.missingCount && <div><b>{fund.missingCount}</b> cửa hàng chưa báo cáo quỹ hôm nay</div>}
            {!!fund?.pendingReview && <div><b>{fund.pendingReview}</b> báo cáo quỹ đang chờ duyệt</div>}
          </div>
          <button className="link" onClick={() => nav("/fund")}>Xem</button>
        </div>
      ) : null}

      {!ops?.canManage && fund && !fund.reportedToday && (
        <button className="cta-card" onClick={() => nav("/fund/new")}>
          <Icon name="wallet" size={22} />
          <span><b>Báo cáo quỹ hôm nay</b><small>Đếm tiền, đối chiếu và gửi quản lý</small></span>
          <Icon name="chevron" size={18} />
        </button>
      )}

      <div className="tile-grid">
        {tiles.map((t) => (
          <button key={t.key} className={`tile ${t.tone || ""}`} onClick={() => nav(t.to)}>
            <span className="tile-icon"><Icon name={t.icon} size={24} /></span>
            {!!t.badge && <span className="tile-badge">{t.badge > 99 ? "99+" : t.badge}</span>}
            <b>{t.title}</b>
            <small>{t.hint}</small>
          </button>
        ))}
      </div>
    </>
  );
}
