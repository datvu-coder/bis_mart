import React, { useEffect, useState } from "react";
import { useNavigate, useSearchParams } from "react-router-dom";
import { Page, useSnackbar } from "zmp-ui";
import { api } from "../api";
import Skeleton from "../components/Skeleton";
import SubHero from "../components/SubHero";
import { KpiStore } from "../types";
import { FIELDS } from "./kpi";

type Form = Record<string, Record<string, string>>;

const norm = (s: string) =>
  s.replace(/đ/gi, "d").normalize("NFD").replace(/[̀-ͯ]/g, "").toUpperCase().replace(/BI'?S\s*MART/g, "").replace(/[^A-Z0-9]/g, "");
const monthLabel = (m: string) => `Tháng ${Number(m.slice(5))}/${m.slice(0, 4)}`;

/** Bulk entry of one month: fill the grid by hand or paste rows copied from the workbook. */
export default function KpiImportPage() {
  const nav = useNavigate();
  const { openSnackbar } = useSnackbar();
  const [params] = useSearchParams();
  const month = params.get("month") || "";
  const [stores, setStores] = useState<KpiStore[] | null>(null);
  const [form, setForm] = useState<Form>({});
  const [paste, setPaste] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    api.kpi(month).then((res) => {
      setStores(res.stores);
      setForm(Object.fromEntries(res.stores.map((s) => [s.storeCode, Object.fromEntries(FIELDS.map((f) => [f.key, s[f.key] == null ? "" : String(s[f.key])]))])));
    }).catch((e) => setError(e instanceof Error ? e.message : "Không tải được dữ liệu"));
  }, [month]);

  const setCell = (code: string, key: string, v: string) =>
    setForm((p) => ({ ...p, [code]: { ...p[code], [key]: v.replace(/\D/g, "") } }));

  const applyPaste = () => {
    if (!stores) return;
    let matched = 0;
    const next: Form = { ...form };
    paste.split(/\r?\n/).forEach((line) => {
      const cells = line.split(/\t|;/).map((c) => c.trim());
      const name = norm(cells[0] || "");
      const store = name && stores.find((s) => norm(s.storeName) === name);
      if (!store) return;
      const nums = cells.slice(1).filter((c) => c !== "" && !c.includes("%"));
      const row = { ...next[store.storeCode] };
      FIELDS.forEach((f, i) => { if (nums[i] !== undefined) row[f.key] = nums[i].replace(/\D/g, ""); });
      next[store.storeCode] = row;
      matched += 1;
    });
    setForm(next);
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
      <SubHero title="Nhập dữ liệu KPI" note={month ? `${monthLabel(month)} · số theo nghìn đồng` : ""} />
      {error && <div className="error inline" style={{ margin: "14px" }}>{error}</div>}
      {!stores && !error && <Skeleton count={4} />}
      {stores && (
        <>
          <section className="panel kp-paste">
            <h3>Dán từ Excel</h3>
            <textarea value={paste} onChange={(e) => setPaste(e.target.value)} placeholder={"Bi'S MART NGÃ BẢY\t1814866\t1900000\t287328\t316000\t116619"} />
            <button className="btn wide" style={{ marginTop: 10 }} disabled={!paste.trim()} onClick={applyPaste}>Điền vào bảng bên dưới</button>
            <small>Mỗi dòng một cửa hàng: tên cửa hàng, rồi lần lượt {FIELDS.map((f) => f.label).join(", ")}. Cột có dấu % được bỏ qua, cột thiếu giữ nguyên.</small>
          </section>

          {stores.map((s) => (
            <section key={s.storeCode} className="panel kp-card">
              <h4>{s.storeName}</h4>
              <div className="kp-grid">
                {FIELDS.map((f) => (
                  <label key={f.key} className="field"><span>{f.label}</span>
                    <input inputMode="numeric" placeholder="0" value={form[s.storeCode]?.[f.key] || ""} onChange={(e) => setCell(s.storeCode, f.key, e.target.value)} />
                  </label>
                ))}
              </div>
            </section>
          ))}

          <div className="action-bar">
            <button className="btn primary wide" disabled={busy} onClick={save}>{busy ? "Đang lưu..." : "Lưu tất cả"}</button>
          </div>
        </>
      )}
    </Page>
  );
}
