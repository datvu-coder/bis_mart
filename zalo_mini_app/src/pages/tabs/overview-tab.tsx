import React, { useEffect, useMemo, useState } from "react";
import { api } from "../../api";
import { useAuth } from "../../auth";
import Avatar from "../../components/Avatar";
import { DailyChart, RateBars, StatusBar } from "../../components/charts";
import Icon from "../../components/Icon";
import NotificationBell from "../../components/NotificationBell";
import Skeleton, { EmptyState } from "../../components/Skeleton";
import { uiState, useDataVersion } from "../../data";
import type { Analytics } from "../../types";
import { firstName } from "../../utils";

const RANGES: { days: number; label: string; long: string }[] = [
  { days: 7, label: "7 ngày", long: "7 ngày qua" },
  { days: 30, label: "30 ngày", long: "30 ngày qua" },
  { days: 90, label: "90 ngày", long: "90 ngày qua" },
  { days: 0, label: "Tất cả", long: "toàn thời gian" },
];

export default function OverviewTab({ active }: { active: boolean }) {
  const { user } = useAuth();
  const version = useDataVersion();
  const [days, setDaysState] = useState(uiState.overviewDays);
  const [store, setStoreState] = useState(uiState.overviewStore);
  const [data, setData] = useState<Analytics | null>(null);
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  const setDays = (v: number) => { uiState.overviewDays = v; setDaysState(v); };
  const setStore = (v: string) => { uiState.overviewStore = v; setStoreState(v); };

  const load = () => {
    setLoading(true);
    setError("");
    api.analytics(days, store)
      .then(setData)
      .catch((e) => setError(e instanceof Error ? e.message : "Không tải được số liệu"))
      .finally(() => setLoading(false));
  };

  // Refresh when the tab is shown, filters change, or any task changes.
  useEffect(() => {
    if (active) load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [active, days, store, version]);

  const range = RANGES.find((r) => r.days === days) || RANGES[1];
  const team = data?.scope === "team";
  const t = data?.totals;
  const open = t ? t.doing + t.todo + t.overdue : 0;

  const storeRows = useMemo(
    () =>
      (data?.byStore || [])
        .slice()
        .sort((a, b) => b.completionRate - a.completionRate || b.total - a.total)
        .map((s) => ({
          key: s.storeCode,
          label: s.storeName || s.storeCode || "Chưa gán cửa hàng",
          sub: `${s.done}/${s.total} việc${s.overdue ? ` · ${s.overdue} quá hạn` : ""}`,
          rate: s.completionRate,
          warn: s.overdue > 0,
        })),
    [data]
  );

  const peopleRows = useMemo(
    () =>
      (data?.byAssignee || [])
        .slice()
        .sort((a, b) => b.completionRate - a.completionRate || b.total - a.total)
        .slice(0, 8),
    [data]
  );

  const storeName = data?.stores.find((s) => s.storeCode === store)?.storeName || store;

  return (
    <>
      <header className="hero">
        <div className="hero-row">
          <div>
            <div className="hero-sub">{team ? "Hiệu quả công việc" : `Xin chào, ${firstName(user?.fullName || "bạn")}`}</div>
            <h1>{team ? "Tổng quan" : "Tổng quan của tôi"}</h1>
          </div>
          <div className="hero-actions">
            <NotificationBell />
            <button className="hero-btn" onClick={load} aria-label="Làm mới"><Icon name="refresh" size={20} /></button>
          </div>
        </div>
        <div className="hero-filters">
          <div className="range-chips">
            {RANGES.map((r) => (
              <button key={r.days} className={days === r.days ? "active" : ""} onClick={() => setDays(r.days)}>{r.label}</button>
            ))}
          </div>
          {team && data && data.stores.length > 1 && (
            <select className="hero-select" value={store} onChange={(e) => setStore(e.target.value)} aria-label="Lọc theo cửa hàng">
              <option value="">Tất cả cửa hàng</option>
              {data.stores.map((s) => <option key={s.storeCode} value={s.storeCode}>{s.storeName || s.storeCode}</option>)}
            </select>
          )}
        </div>
      </header>

      {error && <div className="error">{error} <button className="link" onClick={load}>Thử lại</button></div>}
      {!data && !error && <Skeleton count={3} />}

      {data && t && (
        <div className={loading ? "dim" : ""}>
          <div className="kpi-card">
            <div className="kpi-hero">
              <div className="kpi-number">{t.completionRate}<small>%</small></div>
              <div className="kpi-text">
                <b>Tỷ lệ hoàn thành</b>
                <span>{t.done}/{t.total} việc giao trong {range.long}{store ? ` · ${storeName}` : ""}</span>
              </div>
            </div>
            {t.total > 0 ? <StatusBar tally={t} /> : <div className="hint">Chưa có việc nào trong khoảng thời gian này</div>}
            <div className="kpi-row">
              <div><b className={t.onTimeRate !== null && t.onTimeRate < 70 ? "red" : ""}>{t.onTimeRate === null ? "–" : `${t.onTimeRate}%`}</b><span>Hoàn thành đúng hạn</span></div>
              <div><b className={t.overdue ? "red" : ""}>{t.overdue}</b><span>Đang quá hạn</span></div>
              <div><b>{open}</b><span>Đang mở</span></div>
            </div>
          </div>

          {t.total === 0 && (
            <EmptyState icon={<Icon name="chart" size={34} />} title="Chưa có số liệu" hint="Giao việc cho nhân viên để bắt đầu theo dõi tỷ lệ hoàn thành" />
          )}

          {team && !store && storeRows.length > 1 && (
            <section className="panel">
              <div className="panel-head"><h3>Tỷ lệ hoàn thành theo cửa hàng</h3><span className="count">Bấm để lọc</span></div>
              <RateBars rows={storeRows} onPick={setStore} />
            </section>
          )}

          {store && (
            <div className="filter-note">
              Đang xem: <b>{storeName}</b>
              <button className="link" onClick={() => setStore("")}>Xem tất cả cửa hàng</button>
            </div>
          )}

          {t.total > 0 && (
            <section className="panel">
              <div className="panel-head"><h3>Hoàn thành theo ngày</h3><span className="count">{data.daily.length} ngày gần nhất</span></div>
              <DailyChart data={data.daily} />
            </section>
          )}

          {team && peopleRows.length > 0 && (
            <section className="panel">
              <div className="panel-head"><h3>Nhân viên</h3><span className="count">Top {peopleRows.length}</span></div>
              <div className="people-rank">
                {peopleRows.map((p) => (
                  <div key={p.id} className="rank-row">
                    <Avatar name={p.name} size={32} />
                    <div className="rank-main">
                      <div className="rate-head"><span className="rate-label">{p.name}</span><b>{p.completionRate}%</b></div>
                      <div className="rate-track" aria-hidden><span style={{ width: `${Math.max(p.completionRate, p.completionRate > 0 ? 2 : 0)}%` }} /></div>
                      <div className={`rate-sub ${p.overdue ? "tone-overdue" : ""}`}>{p.done}/{p.total} việc{p.overdue ? ` · ${p.overdue} quá hạn` : ""}</div>
                    </div>
                  </div>
                ))}
              </div>
            </section>
          )}
        </div>
      )}
    </>
  );
}
