import React, { useEffect, useMemo, useRef, useState } from "react";
import { useNavigate, useSearchParams } from "react-router-dom";
import { Page, useSnackbar } from "zmp-ui";
import { api } from "../api";
import Icon from "../components/Icon";
import Skeleton from "../components/Skeleton";
import SubHero from "../components/SubHero";
import { KpiStore } from "../types";
import { FIELDS, money } from "./kpi";

type Row = Record<string, string>;
type Form = Record<string, Row>;

const norm = (s: string) =>
  s.replace(/đ/gi, "d").normalize("NFD").replace(/[̀-ͯ]/g, "").toUpperCase().replace(/BI'?S\s*MART/g, "").replace(/[^A-Z0-9]/g, "");
const monthLabel = (m: string) => `Tháng ${Number(m.slice(5))}/${m.slice(0, 4)}`;
const shortName = (n: string) => n.replace(/^Bi'S MART\s*/i, "");
const fmt = (digits: string) => (digits ? Number(digits).toLocaleString("vi-VN") : "");
const pctOf = (a: string, b: string) => (a && Number(b) ? Math.round((Number(a) / Number(b)) * 100) : null);

// Layout of the entry card: each block is one thing the workbook tracks.
const BLOCKS: { title: string; fields: [string, string][]; goal?: [string, string] }[] = [
  { title: "Doanh số tổng", fields: [["dst", "Doanh số"], ["kpiTotal", "KPI"]], goal: ["dst", "kpiTotal"] },
  { title: "Sữa nhóm 1", fields: [["dsN1", "Doanh số"], ["kpiN1", "KPI"]], goal: ["dsN1", "kpiN1"] },
  { title: "SBPS nhóm 1", fields: [["dsSbpsN1", "Doanh số"], ["kpiSbpsN1", "KPI"]], goal: ["dsSbpsN1", "kpiSbpsN1"] },
  { title: "Cơ cấu doanh số", fields: [["dstSb", "Sữa bột"], ["dstSbps", "SBPS"]] },
  { title: "Tồn kho", fields: [["stockTotal", "Tổng"], ["stockN1", "Nhóm 1"]] },
];

const filled = (row: Row | undefined) => FIELDS.filter((f) => row?.[f.key]).length;

/** Monthly KPI entry: pick a store, fill its figures, save everything at the end. */
export default function KpiImportPage() {
  const nav = useNavigate();
  const { openSnackbar } = useSnackbar();
  const [params] = useSearchParams();
  const month = params.get("month") || "";
  const [stores, setStores] = useState<KpiStore[] | null>(null);
  const [form, setForm] = useState<Form>({});
  const [current, setCurrent] = useState("");
  const [paste, setPaste] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const chips = useRef<HTMLDivElement>(null);

  useEffect(() => {
    api.kpi(month).then((res) => {
      setStores(res.stores);
      setCurrent(res.stores[0]?.storeCode || "");
      setForm(Object.fromEntries(res.stores.map((s) => [s.storeCode, Object.fromEntries(FIELDS.map((f) => [f.key, s[f.key] == null ? "" : String(s[f.key])]))])));
    }).catch((e) => setError(e instanceof Error ? e.message : "Không tải được dữ liệu"));
  }, [month]);

  const store = stores?.find((s) => s.storeCode === current);
  const row = form[current] || {};
  const doneCount = useMemo(() => (stores || []).filter((s) => filled(form[s.storeCode]) > 0).length, [stores, form]);

  const setCell = (key: string, v: string) =>
    setForm((p) => ({ ...p, [current]: { ...p[current], [key]: v.replace(/\D/g, "") } }));

  const pick = (code: string) => {
    setCurrent(code);
    window.scrollTo?.({ top: 0 });
  };
  const idx = stores ? stores.findIndex((s) => s.storeCode === current) : -1;
  const step = (d: number) => stores && stores[idx + d] && pick(stores[idx + d].storeCode);

  useEffect(() => {
    chips.current?.querySelector<HTMLElement>(".kp-chip.on")?.scrollIntoView({ inline: "center", block: "nearest", behavior: "smooth" });
  }, [current]);

  const applyPaste = () => {
    if (!stores) return;
    let matched = 0;
    const next: Form = { ...form };
    paste.split(/\r?\n/).forEach((line) => {
      const cells = line.split(/\t|;/).map((c) => c.trim());
      const name = norm(cells[0] || "");
      const hit = name && stores.find((s) => norm(s.storeName) === name);
      if (!hit) return;
      const nums = cells.slice(1).filter((c) => c !== "" && !c.includes("%"));
      const r = { ...next[hit.storeCode] };
      FIELDS.forEach((f, i) => { if (nums[i] !== undefined) r[f.key] = nums[i].replace(/\D/g, ""); });
      next[hit.storeCode] = r;
      matched += 1;
    });
    setForm(next);
    if (matched) setPaste("");
    openSnackbar({ text: matched ? `Đã điền ${matched} cửa hàng, kiểm tra rồi bấm Lưu` : "Không khớp cửa hàng nào, kiểm tra cột tên cửa hàng", type: matched ? "success" : "error" });
  };

  const save = async () => {
    if (!stores) return;
    setBusy(true);
    try {
      const rows = stores.map((s) => ({ storeCode: s.storeCode, ...form[s.storeCode] }));
      const res = await api.kpiBulk(month, rows);
      openSnackbar({ text: `Đã lưu ${res.saved} cửa hàng`, type: "success" });
      nav(-1);
    } catch (e) {
      openSnackbar({ text: e instanceof Error ? e.message : "Không lưu được", type: "error" });
    } finally {
      setBusy(false);
    }
  };

  return (
    <Page className="page with-bar">
      <SubHero title="Nhập dữ liệu KPI" note={month ? `${monthLabel(month)} · đơn vị nghìn đồng` : ""} />
      {error && <div className="error inline" style={{ margin: "14px" }}>{error}</div>}
      {!stores && !error && <Skeleton count={4} />}
      {stores && (
        <>
          <div className="kp-chips" ref={chips}>
            {stores.map((s) => {
              const n = filled(form[s.storeCode]);
              return (
                <button key={s.storeCode} className={`kp-chip ${s.storeCode === current ? "on" : ""} ${n ? "has" : ""}`} onClick={() => pick(s.storeCode)}>
                  {n > 0 && <Icon name="check" size={13} />}
                  {shortName(s.storeName)}
                </button>
              );
            })}
          </div>
          <div className="kp-progress">Đã nhập {doneCount}/{stores.length} cửa hàng</div>

          {store && (
            <section className="panel kp-store">
              <div className="kp-store-head">
                <b>{shortName(store.storeName)}</b>
                <small>{store.region}</small>
              </div>
              {BLOCKS.map((b) => {
                const pct = b.goal ? pctOf(row[b.goal[0]], row[b.goal[1]]) : null;
                return (
                  <div key={b.title} className="kp-block">
                    <div className="kp-block-top">
                      <span>{b.title}</span>
                      {pct !== null && <em className={pct >= 100 ? "ok" : pct >= 90 ? "warn" : "bad"}>{pct}% KPI</em>}
                    </div>
                    <div className="kp-pair">
                      {b.fields.map(([key, label]) => (
                        <label key={key} className="kp-input">
                          <small>{label}</small>
                          <input inputMode="numeric" placeholder="0" value={fmt(row[key] || "")} onChange={(e) => setCell(key, e.target.value)} />
                          <i>{row[key] ? `≈ ${money(Number(row[key]))}` : " "}</i>
                        </label>
                      ))}
                    </div>
                  </div>
                );
              })}
              <div className="kp-nav">
                <button className="btn" disabled={idx <= 0} onClick={() => step(-1)}><Icon name="back" size={16} /> Trước</button>
                <button className="btn" disabled={idx >= stores.length - 1} onClick={() => step(1)}>Cửa hàng sau <Icon name="chevron" size={16} /></button>
              </div>
            </section>
          )}

          <details className="panel kp-paste">
            <summary>Dán nhiều cửa hàng từ Excel</summary>
            <textarea value={paste} onChange={(e) => setPaste(e.target.value)} placeholder={"Bi'S MART NGÃ BẢY\t1814866\t1900000\t287328\t316000\t116619"} />
            <button className="btn wide" style={{ marginTop: 10 }} disabled={!paste.trim()} onClick={applyPaste}>Điền vào bảng</button>
            <small>Mỗi dòng một cửa hàng: tên cửa hàng, rồi lần lượt Doanh số tổng, KPI tổng, Doanh số nhóm 1, KPI nhóm 1, Doanh số SBPS nhóm 1, KPI SBPS nhóm 1, Sữa bột, SBPS, Tồn kho tổng, Tồn kho nhóm 1. Cột có dấu % được bỏ qua.</small>
          </details>

          <div className="action-bar">
            <button className="btn primary wide" disabled={busy} onClick={save}>{busy ? "Đang lưu..." : `Lưu tất cả (${doneCount}/${stores.length})`}</button>
          </div>
        </>
      )}
    </Page>
  );
}
