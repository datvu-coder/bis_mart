import React, { useCallback, useEffect, useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import { Page, useSnackbar } from "zmp-ui";
import { api } from "../api";
import Icon from "../components/Icon";
import Sheet from "../components/Sheet";
import Skeleton, { EmptyState } from "../components/Skeleton";
import SubHero from "../components/SubHero";
import { KpiResponse, KpiStore } from "../types";

// Figures come from the sales workbook and are expressed in thousands of VND.
export const money = (k: number | null | undefined): string => {
  const v = (Number(k) || 0) * 1000;
  if (Math.abs(v) >= 1e9) return `${(v / 1e9).toLocaleString("vi-VN", { maximumFractionDigits: 2 })} tỷ`;
  if (Math.abs(v) >= 1e6) return `${(v / 1e6).toLocaleString("vi-VN", { maximumFractionDigits: 1 })} triệu`;
  return `${Math.round(v).toLocaleString("vi-VN")} đ`;
};
const pct = (x: number | null) => (x === null ? "—" : `${Math.round(x * 100)}%`);
const ratio = (a: number | null | undefined, b: number | null | undefined): number | null => (a != null && b ? a / b : null);
const growth = (a: number | null | undefined, b: number | null | undefined): number | null => (a != null && b ? a / b - 1 : null);
const signed = (x: number | null) => (x === null ? "—" : `${x >= 0 ? "+" : ""}${(x * 100).toFixed(1).replace(".", ",")}%`);
const tone = (x: number | null) => (x === null ? "" : x >= 1 ? "ok" : x >= 0.9 ? "warn" : "bad");
const monthLabel = (m: string) => `Tháng ${Number(m.slice(5))}/${m.slice(0, 4)}`;
const shiftMonth = (m: string, d: number) => {
  const t = Number(m.slice(0, 4)) * 12 + Number(m.slice(5)) - 1 + d;
  return `${Math.floor(t / 12)}-${String((t % 12) + 1).padStart(2, "0")}`;
};

// Same order as the "Thực hiện" sheet of the workbook, so a pasted range lines up column by column.
export const FIELDS: { key: keyof KpiStore; label: string }[] = [
  { key: "dst", label: "Doanh số tổng" },
  { key: "kpiTotal", label: "KPI doanh số tổng" },
  { key: "dsN1", label: "Doanh số sữa nhóm 1" },
  { key: "kpiN1", label: "KPI sữa nhóm 1" },
  { key: "dsSbpsN1", label: "Doanh số SBPS nhóm 1" },
  { key: "kpiSbpsN1", label: "KPI SBPS nhóm 1" },
  { key: "dstSb", label: "Doanh số sữa bột" },
  { key: "dstSbps", label: "Doanh số SBPS" },
  { key: "stockTotal", label: "Tồn kho tổng" },
  { key: "stockN1", label: "Tồn kho nhóm 1" },
];

function Progress({ label, actual, target }: { label: string; actual: number | null; target: number | null }) {
  const r = ratio(actual, target);
  return (
    <div className="kp-line">
      <div className="kp-line-top"><span>{label}</span><b className={tone(r)}>{pct(r)}</b></div>
      <div className="care-bar"><i className={`kp-fill ${tone(r)}`} style={{ width: `${Math.min(100, (r || 0) * 100)}%` }} /></div>
      <small>{target ? `${money(actual)} / ${money(target)}` : actual != null ? `${money(actual)} · chưa đặt KPI` : "Chưa có dữ liệu"}</small>
    </div>
  );
}

export default function KpiPage() {
  const { openSnackbar } = useSnackbar();
  const nav = useNavigate();
  const [month, setMonth] = useState("");
  const [data, setData] = useState<KpiResponse | null>(null);
  const [error, setError] = useState("");
  const [open, setOpen] = useState("");
  const [edit, setEdit] = useState<KpiStore | null>(null);
  const [form, setForm] = useState<Record<string, string>>({});
  const [busy, setBusy] = useState(false);

  const load = useCallback(async (m?: string) => {
    setError("");
    try {
      const res = await api.kpi(m);
      setData(res);
      setMonth(res.month);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Không tải được dữ liệu");
    }
  }, []);
  useEffect(() => { load(); }, [load]);

  const latest = data?.months[0] || "";
  const oldest = data?.months[data.months.length - 1] || "";
  const go = (d: number) => { const m = shiftMonth(month, d); setData(null); load(m); };
  const canPrev = !!data && !!oldest && month > oldest;
  const canNext = !!data && !!latest && (month < latest || (data.canEdit && month === latest));

  const stores = useMemo(() => {
    const list = [...(data?.stores || [])];
    return list.sort((a, b) => (ratio(b.dst, b.kpiTotal) ?? -1) - (ratio(a.dst, a.kpiTotal) ?? -1));
  }, [data]);

  const sum = (k: keyof KpiStore) => stores.reduce((n, s) => n + (Number(s[k]) || 0), 0);
  const totalDst = sum("dst"), totalKpi = sum("kpiTotal");
  const totalN1 = sum("dsN1"), totalKpiN1 = sum("kpiN1");
  const passed = stores.filter((s) => (ratio(s.dst, s.kpiTotal) ?? 0) >= 1).length;
  const withKpi = stores.filter((s) => s.kpiTotal).length;
  const clusterRatio = ratio(totalDst, totalKpi);

  const startEdit = (s: KpiStore) => {
    setEdit(s);
    setForm(Object.fromEntries(FIELDS.map((f) => [f.key, s[f.key] == null ? "" : String(s[f.key])])));
  };
  const save = async () => {
    if (!edit) return;
    setBusy(true);
    try {
      const body: Record<string, string> = {};
      FIELDS.forEach((f) => { body[f.key] = (form[f.key] || "").replace(/\D/g, ""); });
      await api.kpiSave(edit.storeCode, month, body);
      openSnackbar({ text: "Đã lưu KPI", type: "success" });
      setEdit(null);
      load(month);
    } catch (e) {
      openSnackbar({ text: e instanceof Error ? e.message : "Không lưu được", type: "error" });
    } finally {
      setBusy(false);
    }
  };

  return (
    <Page className="page">
      <SubHero title="KPI cửa hàng" note="Doanh số so với chỉ tiêu tháng" />

      <section className="panel kp-month">
        <button className="icon-btn" disabled={!canPrev} onClick={() => go(-1)} aria-label="Tháng trước"><Icon name="back" size={18} /></button>
        <b>{month ? monthLabel(month) : "..."}</b>
        <button className="icon-btn" disabled={!canNext} onClick={() => go(1)} aria-label="Tháng sau"><Icon name="chevron" size={18} /></button>
      </section>

      {data?.canEdit && month && (
        <button className="btn wide kp-import-btn" onClick={() => nav(`/kpi/import?month=${month}`)}><Icon name="edit" size={16} /> Nhập dữ liệu {monthLabel(month).toLowerCase()}</button>
      )}

      {error && <div className="error inline" style={{ margin: "0 14px" }}>{error}</div>}
      {!data && !error && <Skeleton count={4} />}

      {data && stores.length === 0 && <EmptyState icon={<Icon name="chart" size={28} />} title="Chưa có dữ liệu KPI" hint="Tháng này chưa được cập nhật." />}

      {data && stores.length > 0 && (
        <>
          <section className="panel">
            <h3>Toàn cụm</h3>
            <div className="kp-big">
              <b className={tone(clusterRatio)}>{pct(clusterRatio)}</b>
              <span>{withKpi ? `${passed}/${withKpi} cửa hàng đạt KPI` : "Chưa đặt KPI"}</span>
            </div>
            <Progress label="Doanh số tổng" actual={totalDst || null} target={totalKpi || null} />
            <Progress label="Sữa nhóm 1" actual={totalN1 || null} target={totalKpiN1 || null} />
          </section>

          <section className="panel">
            <h3>Xếp hạng cửa hàng</h3>
            {stores.map((s, i) => {
              const r = ratio(s.dst, s.kpiTotal);
              const isOpen = open === s.storeCode;
              const stockDays = s.stockTotal != null && s.dst ? (s.stockTotal / s.dst) * 30 : null;
              const stockDaysN1 = s.stockN1 != null && s.dsN1 ? (s.stockN1 / s.dsN1) * 30 : null;
              return (
                <div key={s.storeCode} className={`kp-row ${isOpen ? "open" : ""}`}>
                  <button className="kp-row-main" onClick={() => setOpen(isOpen ? "" : s.storeCode)}>
                    <span className="kp-rank">{i + 1}</span>
                    <span className="kp-name"><b>{s.storeName.replace(/^Bi'S MART\s*/i, "")}</b><small>{s.region}</small></span>
                    <b className={`kp-pct ${tone(r)}`}>{pct(r)}</b>
                  </button>
                  <div className="care-bar"><i className={`kp-fill ${tone(r)}`} style={{ width: `${Math.min(100, (r || 0) * 100)}%` }} /></div>
                  {isOpen && (
                    <div className="kp-detail">
                      <Progress label="Doanh số tổng" actual={s.dst} target={s.kpiTotal} />
                      <Progress label="Sữa nhóm 1" actual={s.dsN1} target={s.kpiN1} />
                      {(s.kpiSbpsN1 || s.dsSbpsN1) ? <Progress label="SBPS nhóm 1" actual={s.dsSbpsN1} target={s.kpiSbpsN1} /> : null}
                      <div className="kp-facts">
                        <div><small>So với tháng trước</small><b className={(growth(s.dst, s.prevDst) ?? 0) < 0 ? "bad" : "ok"}>{signed(growth(s.dst, s.prevDst))}</b></div>
                        <div><small>So với TB 3 tháng</small><b className={(growth(s.dst, s.moa) ?? 0) < 0 ? "bad" : "ok"}>{signed(growth(s.dst, s.moa))}</b></div>
                        <div><small>Sữa bột / tổng</small><b>{pct(ratio(s.dstSb, s.dst))}</b></div>
                        <div><small>SBPS / tổng</small><b>{pct(ratio(s.dstSbps, s.dst))}</b></div>
                        <div><small>Tồn kho tổng</small><b>{s.stockTotal != null ? money(s.stockTotal) : "—"}</b>{stockDays !== null && <em>{Math.round(stockDays)} ngày</em>}</div>
                        <div><small>Tồn kho nhóm 1</small><b>{s.stockN1 != null ? money(s.stockN1) : "—"}</b>{stockDaysN1 !== null && <em>{Math.round(stockDaysN1)} ngày</em>}</div>
                      </div>
                      {data.canEdit && <button className="btn wide" onClick={() => startEdit(s)}><Icon name="edit" size={16} /> Cập nhật số liệu</button>}
                    </div>
                  )}
                </div>
              );
            })}
            <p className="kp-unit">Số liệu tính theo nghìn đồng, hiển thị quy đổi sang triệu/tỷ.</p>
          </section>
        </>
      )}

      <Sheet open={!!edit} title={edit ? `${edit.storeName.replace(/^Bi'S MART\s*/i, "")} · ${monthLabel(month)}` : ""} onClose={() => setEdit(null)}>
        <p className="sheet-msg">Nhập số theo nghìn đồng. Để trống nếu chưa có.</p>
        <div className="kp-form">
          {FIELDS.map((f) => (
            <label key={f.key} className="field"><span>{f.label}</span>
              <input inputMode="numeric" value={form[f.key] || ""} placeholder="0" onChange={(e) => setForm((p) => ({ ...p, [f.key]: e.target.value.replace(/\D/g, "") }))} />
            </label>
          ))}
        </div>
        <div className="sheet-actions">
          <button className="btn" onClick={() => setEdit(null)}>Huỷ</button>
          <button className="btn primary" disabled={busy} onClick={save}>{busy ? "Đang lưu..." : "Lưu"}</button>
        </div>
      </Sheet>
    </Page>
  );
}
