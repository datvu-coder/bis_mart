import React, { useEffect, useState } from "react";
import { useNavigate, useSearchParams } from "react-router-dom";
import { Page, useSnackbar } from "zmp-ui";
import { api } from "../api";
import Icon from "../components/Icon";
import PhotoField from "../components/PhotoField";
import StoreSelect, { useStoreChoice } from "../components/StoreSelect";
import SubHero from "../components/SubHero";
import { bumpData } from "../data";
import { FUND_DENOMS, FundSuggest } from "../types";
import { digits, dmy, todayYmd, vnd } from "../utils";

export default function FundFormPage() {
  const nav = useNavigate();
  const { openSnackbar } = useSnackbar();
  const [params] = useSearchParams();
  const [store, setStore] = useStoreChoice(params.get("store") || undefined);
  const [date, setDate] = useState(params.get("date") || todayYmd());
  const [counts, setCounts] = useState<Record<string, string>>({});
  const [other, setOther] = useState("");
  const [system, setSystem] = useState("");
  const [systemTouched, setSystemTouched] = useState(false);
  const [note, setNote] = useState("");
  const [photos, setPhotos] = useState<string[]>([]);
  const [suggest, setSuggest] = useState<FundSuggest | null>(null);
  const [locked, setLocked] = useState(false);
  const [existing, setExisting] = useState(false);
  const [busy, setBusy] = useState(false);

  // Load the expected balance and any report already filed for that store/day (to edit it).
  useEffect(() => {
    if (!store) return;
    let alive = true;
    setSuggest(null);
    api.fundSuggest(store, date).then((s) => {
      if (!alive) return;
      setSuggest(s);
      setSystemTouched((t) => { if (!t) setSystem(String(Math.round(s.suggested))); return t; });
    }).catch(() => {});
    api.fundReports({ storeCode: store, from: date, to: date }).then((r) => {
      if (!alive) return;
      const rep = r.reports[0];
      setExisting(!!rep);
      setLocked(!!rep && rep.canEdit === false);
      if (rep) {
        setCounts(Object.fromEntries(Object.entries(rep.counts).map(([k, v]) => [k, String(v)])));
        setOther(rep.otherAmount ? String(rep.otherAmount) : "");
        setSystem(String(Math.round(rep.systemBalance)));
        setSystemTouched(true);
        setNote(rep.note);
        setPhotos(rep.photoUrls);
      }
    }).catch(() => {});
    return () => { alive = false; };
  }, [store, date]);

  const countOf = (d: number) => Number(counts[String(d)] || 0);
  const setCount = (d: number, n: number) => setCounts((c) => ({ ...c, [String(d)]: String(Math.max(0, Math.min(99999, n))) }));
  const total = FUND_DENOMS.reduce((s, d) => s + d * countOf(d), 0) + Number(other || 0);
  const diff = total - Number(system || 0);

  const submit = async () => {
    setBusy(true);
    try {
      const body = {
        storeCode: store, reportDate: date, otherAmount: Number(other || 0), note: note.trim(), photoUrls: photos,
        systemBalance: system === "" ? "" : Number(system),
        counts: Object.fromEntries(FUND_DENOMS.map((d) => [String(d), countOf(d)]).filter(([, n]) => Number(n) > 0)),
      };
      const rep = await api.saveFundReport(body);
      openSnackbar({ text: "Đã gửi báo cáo quỹ", type: "success" });
      bumpData();
      nav(`/fund/${rep.id}`, { replace: true });
    } catch (e) {
      openSnackbar({ text: e instanceof Error ? e.message : "Không gửi được báo cáo", type: "error" });
    } finally {
      setBusy(false);
    }
  };

  return (
    <Page className="page with-bar">
      <SubHero title={existing ? "Sửa báo cáo quỹ" : "Báo cáo quỹ"} />

      <section className="panel">
        <h3>Cửa hàng & ngày</h3>
        <div className="field-row">
          <StoreSelect value={store} onChange={setStore} />
          <input type="date" value={date} max={todayYmd()} onChange={(e) => { setDate(e.target.value); setSystemTouched(false); }} />
        </div>
      </section>

      <section className="panel">
        <div className="panel-head"><h3>Kiểm đếm tiền mặt</h3><span className="count">{vnd(total)}</span></div>
        <div className="denoms">
          {FUND_DENOMS.map((d) => (
            <div key={d} className={`denom ${countOf(d) ? "has" : ""}`}>
              <b>{d.toLocaleString("vi-VN")}</b>
              <div className="stepper-mini">
                <button type="button" onClick={() => setCount(d, countOf(d) - 1)} disabled={locked || !countOf(d)} aria-label="Giảm"><Icon name="minus" size={16} /></button>
                <input inputMode="numeric" value={counts[String(d)] ?? ""} placeholder="0" disabled={locked}
                  onChange={(e) => setCounts((c) => ({ ...c, [String(d)]: digits(e.target.value).slice(0, 5) }))} />
                <button type="button" onClick={() => setCount(d, countOf(d) + 1)} disabled={locked} aria-label="Tăng"><Icon name="plus" size={16} /></button>
              </div>
              <span className="denom-sum">{countOf(d) ? vnd(d * countOf(d)) : ""}</span>
            </div>
          ))}
        </div>
        <label className="field"><span>Tiền khác (xu, séc... nếu có)</span>
          <input inputMode="numeric" disabled={locked} value={other ? Number(other).toLocaleString("vi-VN") : ""} onChange={(e) => setOther(digits(e.target.value))} placeholder="0" />
        </label>
      </section>

      <section className="panel">
        <h3>Đối chiếu hệ thống</h3>
        <label className="field"><span>Quỹ theo hệ thống (đ)</span>
          <input inputMode="numeric" disabled={locked} value={system ? Number(system).toLocaleString("vi-VN") : ""}
            onChange={(e) => { setSystem(digits(e.target.value)); setSystemTouched(true); }} />
        </label>
        {suggest && (
          <div className="hint suggest">
            Gợi ý: đầu ngày {vnd(suggest.opening)} + tiền mặt bán hàng {vnd(suggest.cashSales)} + thu {vnd(suggest.entriesIn)} − chi {vnd(suggest.entriesOut)} = <b>{vnd(suggest.suggested)}</b>
            {systemTouched && Number(system) !== Math.round(suggest.suggested) && (
              <button type="button" className="link" onClick={() => { setSystem(String(Math.round(suggest.suggested))); }}>Dùng gợi ý</button>
            )}
          </div>
        )}
        <div className={`diff-box ${Math.round(diff) === 0 ? "ok" : diff > 0 ? "warn" : "bad"}`}>
          <span>Chênh lệch</span>
          <b>{Math.round(diff) === 0 ? "Khớp" : `${diff > 0 ? "Thừa" : "Thiếu"} ${vnd(Math.abs(diff))}`}</b>
        </div>
      </section>

      <section className="panel">
        <h3>Ghi chú & ảnh</h3>
        <label className="field"><span>Ghi chú (giải thích chênh lệch nếu có)</span>
          <textarea value={note} disabled={locked} onChange={(e) => setNote(e.target.value)} placeholder="VD: Chi 50k mua túi, chưa ghi vào hệ thống" />
        </label>
        <div className="field"><span>Ảnh tiền kiểm đếm / giấy tờ</span><PhotoField value={photos} onChange={setPhotos} max={4} /></div>
      </section>

      {locked && <div className="error">Báo cáo ngày này đã được duyệt nên không sửa được nữa.</div>}
      <div className="action-bar">
        <button className="btn primary wide" disabled={busy || locked || !store} onClick={submit}>{busy ? "Đang gửi..." : existing ? "Gửi lại báo cáo" : "Gửi báo cáo"}</button>
      </div>
    </Page>
  );
}
