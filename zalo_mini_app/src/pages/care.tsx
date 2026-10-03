import React, { useCallback, useEffect, useRef, useState } from "react";
import { Page, useSnackbar } from "zmp-ui";
import { api, photoSrc } from "../api";
import Icon from "../components/Icon";
import PhotoField from "../components/PhotoField";
import { ConfirmSheet } from "../components/Sheet";
import SubHero from "../components/SubHero";
import { CareCampaign } from "../types";

const PERIODS: { value: string; label: string; hint: string }[] = [
  { value: "YESTERDAY", label: "Hôm qua", hint: "Vừa tương tác, chắc chắn gửi được" },
  { value: "TODAY", label: "Hôm nay", hint: "Vừa tương tác, chắc chắn gửi được" },
  { value: "L7D", label: "7 ngày", hint: "Một phần có thể ngoài 48 giờ nên bị Zalo từ chối" },
  { value: "L30D", label: "30 ngày", hint: "Nhiều người có thể ngoài 48 giờ nên bị Zalo từ chối" },
  { value: "ALL", label: "Tất cả", hint: "Người ngoài 48 giờ sẽ bị Zalo từ chối" },
];
const PERIOD_LABEL: Record<string, string> = Object.fromEntries(PERIODS.map((p) => [p.value, p.label]));
const STATUS_LABEL: Record<CareCampaign["status"], string> = { sending: "Đang gửi", done: "Đã gửi xong", failed: "Lỗi", interrupted: "Bị gián đoạn" };

const fmt = (at: string) => {
  const m = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}:\d{2})/.exec(at || "");
  return m ? `${m[4]} · ${m[3]}/${m[2]}` : at;
};

export default function CarePage() {
  const { openSnackbar } = useSnackbar();
  const [body, setBody] = useState("");
  const [photos, setPhotos] = useState<string[]>([]);
  const [period, setPeriod] = useState("YESTERDAY");
  const [audience, setAudience] = useState<{ count: number; total: number; capped: boolean; source: "zalo" | "webhook" } | null>(null);
  const [audErr, setAudErr] = useState("");
  const [campaigns, setCampaigns] = useState<CareCampaign[]>([]);
  const [busy, setBusy] = useState(false);
  const [confirm, setConfirm] = useState(false);
  const timer = useRef<number>();

  const loadCampaigns = useCallback(() => api.careCampaigns().then((r) => setCampaigns(r.campaigns)).catch(() => {}), []);
  useEffect(() => { loadCampaigns(); }, [loadCampaigns]);
  useEffect(() => {
    setAudience(null); setAudErr("");
    api.careAudience(period).then(setAudience).catch((e) => setAudErr(e instanceof Error ? e.message : "Không lấy được danh sách"));
  }, [period]);

  // Poll while a campaign is running so the counters move.
  const sending = campaigns.some((c) => c.status === "sending");
  useEffect(() => {
    if (!sending) return;
    timer.current = window.setInterval(loadCampaigns, 4000);
    return () => window.clearInterval(timer.current);
  }, [sending, loadCampaigns]);

  const image = photos[0] || "";
  const valid = body.trim().length > 0;

  const test = async () => {
    setBusy(true);
    try {
      const r = await api.careTest(body.trim(), image);
      openSnackbar({ text: r.ok ? "Đã gửi thử, kiểm tra Zalo trên điện thoại" : `Zalo từ chối: ${r.detail.slice(0, 120)}`, type: r.ok ? "success" : "error" });
    } catch (e) {
      openSnackbar({ text: e instanceof Error ? e.message : "Không gửi thử được", type: "error" });
    } finally {
      setBusy(false);
    }
  };

  const send = async () => {
    setConfirm(false);
    setBusy(true);
    try {
      const r = await api.careSend(body.trim(), image, period);
      openSnackbar({ text: `Đang gửi cho ${r.total} người`, type: "success" });
      setBody(""); setPhotos([]);
      await loadCampaigns();
    } catch (e) {
      openSnackbar({ text: e instanceof Error ? e.message : "Không gửi được", type: "error" });
    } finally {
      setBusy(false);
    }
  };

  const hint = PERIODS.find((p) => p.value === period)?.hint || "";

  return (
    <Page className="page with-bar">
      <SubHero title="Chăm sóc khách hàng" note="Gửi tin từ OA cho người đã quan tâm" />

      <section className="panel">
        <h3>Gửi cho ai</h3>
        <div className="chip-row nomargin">
          {PERIODS.map((p) => <button type="button" key={p.value} className={`chip ${period === p.value ? "active" : ""}`} onClick={() => setPeriod(p.value)}>{p.label}</button>)}
        </div>
        <div className="care-audience">
          {audErr ? <div className="error inline">{audErr}</div> : audience ? <><b>{audience.count}{audience.capped ? "+" : ""}</b> người nhận · {audience.source === "webhook" ? "đã ghi nhận" : "tổng"} {audience.total} người quan tâm</> : "Đang đếm..."}
        </div>
        {audience?.source === "webhook" && (
          <p className="hint nopad">Zalo chưa cho app lấy toàn bộ danh sách người quan tâm, nên đang dùng những người đã quan tâm hoặc nhắn tin cho OA từ khi app bắt đầu ghi nhận ({audience.total} người). Danh sách sẽ đầy dần theo thời gian.</p>
        )}
        <p className="hint nopad">Tin tư vấn chỉ gửi được cho người đã tương tác với OA trong 48 giờ gần nhất. {hint}.</p>
      </section>

      <section className="panel">
        <h3>Nội dung tin</h3>
        <label className="field"><span>Tin nhắn *</span><textarea value={body} onChange={(e) => setBody(e.target.value)} placeholder="VD: Bi'S MART tặng mẹ ưu đãi 10% sữa cho bé trong tuần này..." maxLength={1500} rows={5} /></label>
        <div className="field"><span>Ảnh đính kèm (1 ảnh)</span><PhotoField value={photos} onChange={(v) => setPhotos(v.slice(-1))} max={1} /></div>
        {valid && (
          <div className="care-preview">
            <small>Xem trước</small>
            <div className="care-bubble">{body.trim()}</div>
            {image && <img className="care-bubble-img" src={photoSrc(image, 600)} alt="" />}
          </div>
        )}
        <button className="btn wide soft" disabled={busy || !valid} onClick={test}><Icon name="send" size={16} /> Gửi thử cho tôi</button>
      </section>

      {campaigns.length > 0 && (
        <section className="panel">
          <h3>Các đợt đã gửi</h3>
          {campaigns.slice(0, 8).map((c) => {
            const done = c.okCount + c.failCount;
            const pct = c.total ? Math.round((done / c.total) * 100) : 0;
            return (
              <div key={c.id} className="care-row">
                <div className="care-row-top"><b>{fmt(c.createdAt)} · {PERIOD_LABEL[c.period] || c.period}</b><span className={`tag-soft ${c.status === "done" ? "ok" : c.status === "sending" ? "warn" : "bad"}`}>{STATUS_LABEL[c.status]}</span></div>
                <div className="care-row-text">{c.body}</div>
                <div className="bar"><i style={{ width: `${pct}%` }} /></div>
                <small>Thành công {c.okCount}/{c.total}{c.failCount ? ` · không gửi được ${c.failCount}` : ""}</small>
                {Object.entries(c.errors).slice(0, 2).map(([k, n]) => <small key={k} className="care-err">{n} người: {k}</small>)}
              </div>
            );
          })}
        </section>
      )}

      <div className="action-bar">
        <button className="btn primary wide" disabled={busy || sending || !valid || !audience || audience.count === 0} onClick={() => setConfirm(true)}>
          {sending ? "Đang có đợt gửi chạy..." : `Gửi cho ${audience ? audience.count : "..."} người`}
        </button>
      </div>

      <ConfirmSheet open={confirm} title="Gửi tin cho khách?" message={`Tin sẽ được gửi cho ${audience?.count || 0} người đã quan tâm OA (${PERIOD_LABEL[period]}). Bạn nên gửi thử cho mình trước. Không thu hồi được sau khi gửi.`} confirmLabel="Gửi ngay" onConfirm={send} onClose={() => setConfirm(false)} />
    </Page>
  );
}
