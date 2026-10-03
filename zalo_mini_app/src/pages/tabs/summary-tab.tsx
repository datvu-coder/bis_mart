import React, { useEffect, useState } from "react";
import { api } from "../../api";
import Icon from "../../components/Icon";
import MinimizeButton from "../../components/MinimizeButton";
import NotificationBell from "../../components/NotificationBell";
import Skeleton, { EmptyState } from "../../components/Skeleton";
import { useDataVersion } from "../../data";
import { StoreSummary } from "../../types";

function Ring({ pct }: { pct: number }) {
  const r = 22;
  const c = 2 * Math.PI * r;
  return (
    <svg width="58" height="58" viewBox="0 0 58 58" className="ring">
      <circle cx="29" cy="29" r={r} className="ring-bg" />
      {pct > 0 && (
        <circle cx="29" cy="29" r={r} className="ring-fg" strokeDasharray={`${(c * pct) / 100} ${c}`} transform="rotate(-90 29 29)" />
      )}
      <text x="29" y="33" textAnchor="middle">{pct}%</text>
    </svg>
  );
}

interface Props {
  active: boolean;
  onOpenStore: (storeCode: string) => void;
}

export default function SummaryTab({ active, onOpenStore }: Props) {
  const version = useDataVersion();
  const [stores, setStores] = useState<StoreSummary[] | null>(null);
  const [error, setError] = useState("");

  const load = () => {
    setError("");
    api.summary().then((r) => setStores(r.stores)).catch((e) => setError(e instanceof Error ? e.message : "Lỗi tải dữ liệu"));
  };
  // Refresh whenever the tab becomes visible or any task changes.
  useEffect(() => {
    if (active) load();
  }, [active, version]);

  const total = (k: "todo" | "doing" | "done" | "overdue") => (stores || []).reduce((s, x) => s + x[k], 0);
  const all = total("todo") + total("doing") + total("done");
  const pct = all ? Math.round((total("done") / all) * 100) : 0;

  return (
    <>
      <header className="hero">
        <div className="hero-row">
          <div>
            <div className="hero-sub">{stores ? `${stores.length} cửa hàng · ${pct}% công việc đã hoàn thành` : "Đang tải dữ liệu..."}</div>
            <h1>Tổng quan cửa hàng</h1>
          </div>
          <div className="hero-actions">
            <NotificationBell />
            <MinimizeButton />
          </div>
        </div>
      </header>

      {stores && (
        <div className="stat-card three">
          <div className="stat static"><b>{total("todo") + total("doing")}</b><span>Đang mở</span></div>
          <div className="stat static danger"><b>{total("overdue")}</b><span>Quá hạn</span></div>
          <div className="stat static success"><b>{total("done")}</b><span>Hoàn thành</span></div>
        </div>
      )}

      {error && <div className="error">{error} <button className="link" onClick={load}>Thử lại</button></div>}
      {!stores && !error && <Skeleton />}
      {stores && stores.length === 0 && <EmptyState icon={<Icon name="store" size={34} />} title="Chưa có dữ liệu công việc" hint="Giao việc cho nhân viên để bắt đầu theo dõi" />}
      {stores && stores.length > 0 && <h3 className="section-title">Theo cửa hàng <small>{stores.length}</small></h3>}
      <div className="list">
        {(stores || []).map((s) => {
          const sum = s.todo + s.doing + s.done;
          const p = sum ? Math.round((s.done / sum) * 100) : 0;
          return (
            <button key={s.storeCode} className="card store-card" onClick={() => onOpenStore(s.storeCode)}>
              <Ring pct={p} />
              <div className="store-info">
                <b>{s.storeName || s.storeCode || "Chưa gán cửa hàng"}</b>
                <small>{s.storeCode}</small>
                <div className="store-stats">
                  <span>Mở <b>{s.todo + s.doing}</b></span>
                  <span className={s.overdue ? "tone-overdue" : ""}>Quá hạn <b>{s.overdue}</b></span>
                  <span>Xong <b>{s.done}</b></span>
                </div>
              </div>
              <Icon name="chevron" size={18} className="chev" />
            </button>
          );
        })}
      </div>
    </>
  );
}
