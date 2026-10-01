import React, { useEffect, useState } from "react";
import { Page } from "zmp-ui";
import { api } from "../api";
import BottomNav from "../components/BottomNav";
import { StoreSummary } from "../types";

export default function SummaryPage() {
  const [stores, setStores] = useState<StoreSummary[] | null>(null);
  const [error, setError] = useState("");

  useEffect(() => {
    api.summary().then((r) => setStores(r.stores)).catch((e) => setError(e instanceof Error ? e.message : "Lỗi tải dữ liệu"));
  }, []);

  const total = (k: "todo" | "doing" | "done" | "overdue") => (stores || []).reduce((s, x) => s + x[k], 0);

  return (
    <Page className="page">
      <div className="hero small"><h1>Tổng quan cửa hàng</h1></div>
      {error && <div className="error">{error}</div>}
      {!stores && !error && <div className="center-note">Đang tải...</div>}
      {stores && (
        <>
          <div className="stat-card">
            <div><b>{total("todo") + total("doing")}</b>Đang mở</div>
            <div><b className="red">{total("overdue")}</b>Quá hạn</div>
            <div><b className="green">{total("done")}</b>Hoàn thành</div>
          </div>
          <div className="list">
            {stores.map((s) => {
              const all = s.todo + s.doing + s.done;
              const pct = all ? Math.round((s.done / all) * 100) : 0;
              return (
                <div key={s.storeCode} className="card">
                  <div className="card-title">{s.storeName || s.storeCode || "Chưa gán cửa hàng"}</div>
                  <div className="progress"><div style={{ width: `${pct}%` }} /></div>
                  <div className="meta">
                    <span>{pct}% hoàn thành</span>
                    <span>Mở: {s.todo + s.doing}</span>
                    {s.overdue > 0 && <span className="red">Quá hạn: {s.overdue}</span>}
                  </div>
                </div>
              );
            })}
            {stores.length === 0 && <div className="center-note">Chưa có dữ liệu</div>}
          </div>
        </>
      )}
      <BottomNav canManage />
    </Page>
  );
}
