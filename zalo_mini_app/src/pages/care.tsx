import React, { useCallback, useEffect, useRef, useState } from "react";
import { Page, useSnackbar } from "zmp-ui";
import { api, photoSrc } from "../api";
import Icon from "../components/Icon";
import PhotoField from "../components/PhotoField";
import { ConfirmSheet } from "../components/Sheet";
import SubHero from "../components/SubHero";
import { CareCampaign } from "../types";

const PERIODS: { value: string; label: string; hint: string }[] = [
  { value: "TODAY", label: "Hôm nay", hint: "Vừa tương tác, chắc chắn gửi được" },
  { value: "YESTERDAY", label: "Hôm qua", hint: "Vừa tương tác, chắc chắn gửi được" },
  { value: "L7D", label: "7 ngày", hint: "Một phần có thể ngoài 48 giờ nên bị Zalo từ chối" },
  { value: "L30D", label: "30 ngày", hint: "Nhiều người có thể ngoài 48 giờ nên bị Zalo từ chối" },
  { value: "ALL", label: "Tất cả", hint: "Người ngoài 48 giờ sẽ bị Zalo từ chối" },
];
const PERIOD_LABEL: Record<string, string> = Object.fromEntries(PERIODS.map((p) => [p.value, p.label]));
const STATUS_LABEL: Record<CareCampaign["status"], string> = { sending: "Đang gửi", done: "Đã gửi xong", failed: "Lỗi", interrupted: "Bị gián đoạn" };

const TEMPLATES: { label: string; text: string }[] = [
  { label: "Khuyến mãi", text: "Bi'S MART gửi mẹ ưu đãi tuần này: giảm 10% các sản phẩm sữa cho bé. Mẹ ghé cửa hàng gần nhất để nhận ưu đãi nhé!" },
  { label: "Cảm ơn", text: "Cảm ơn mẹ đã tin tưởng Bi'S MART. Chúc bé luôn khoẻ mạnh, mau lớn!" },
  { label: "Nhắc mua lại", text: "Bi'S MART nhắc mẹ: sản phẩm của bé sắp hết. Mẹ ghé cửa hàng hoặc nhắn OA để được tư vấn và đặt hàng nhanh nhé." },
];

/** Zalo error text -> something a store owner can act on. */
const friendlyError = (key: string) => {
  if (key.startsWith("-233")) return "đã quá 48 giờ kể từ lần tương tác gần nhất";
  if (key.startsWith("-201")) return "mã người nhận không hợp lệ";
  if (key.startsWith("-213")) return "người này chưa quan tâm OA";
  if (key.startsWith("-210") || key.startsWith("-216")) return "tài khoản OA chưa đủ quyền hoặc hạn mức";
  return key;
};

const fmt = (at: string) => {
  const m = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}:\d{2})/.exec(at || "");
  return m ? `${m[4]} · ${m[3]}/${m[2]}` : at;
};

export default function CarePage() {
  const { openSnackbar } = useSnackbar();
  const [body, setBody] = useState("");
  const [photos, setPhotos] = useState<string[]>([]);
  const [period, setPeriod] = useState("TODAY");
  const [audience, setAudience] = useState<{ count: number; total: number; capped: boolean; source: "zalo" | "webhook" } | null>(null);
  const [audErr, setAudErr] = useState("");
  const [campaigns, setCampaigns] = useState<CareCampaign[]>([]);
  const [busy, setBusy] = useState(false);
  const [confirm, setConfirm] = useState(false);
  const [open, setOpen] = useState<number | null>(null);
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
        <div className="chip-row nomargin care-chips">
          {PERIODS.map((p) => <button type="button" key={p.value} className={`chip ${period === p.value ? "active" : ""}`} onClick={() => setPeriod(p.value)}>{p.label}</button>)}
        </div>
        {audErr ? <div className="error inline">{audErr}</div> : (
          <div className="care-count">
            <b>{audience ? `${audience.count}${audience.capped ? "+" : ""}` : "…"}</b>
            <span>người sẽ nhận tin{audience && audience.source === "webhook" ? " · lấy từ lượt tương tác đã ghi nhận" : audience ? ` · trong ${audience.total} người quan tâm` : ""}</span>
          </div>
        )}
        <div className="care-note"><Icon name="clock" size={16} /><span>Zalo chỉ cho gửi tin tư vấn tới người đã nhắn tin hoặc tương tác với OA trong 48 giờ gần nhất. {hint}.</span></div>
      </section>

      <section className="panel">
        <h3>Nội dung tin</h3>
        <div className="chip-row nomargin care-chips care-templates">
          {TEMPLATES.map((t) => <button type="button" key={t.label} className="chip" onClick={() => setBody(t.text)}>{t.label}</button>)}
        </div>
        <label className="field"><span>Tin nhắn *</span><textarea value={body} onChange={(e) => setBody(e.target.value)} placeholder="VD: Bi'S MART tặng mẹ ưu đãi 10% sữa cho bé trong tuần này..." maxLength={1500} rows={5} /><small className="care-counter">{body.length}/1500</small></label>
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

      <section className="panel">
        <h3>Các đợt đã gửi</h3>
        {campaigns.length === 0 && <div className="empty-hint">Chưa có đợt nào. Soạn tin ở trên, gửi thử cho mình rồi gửi cho khách.</div>}
        {campaigns.slice(0, 8).map((c) => {
          const okPct = c.total ? (c.okCount / c.total) * 100 : 0;
          const failPct = c.total ? (c.failCount / c.total) * 100 : 0;
          const expanded = open === c.id;
          return (
            <button type="button" key={c.id} className={`care-row ${expanded ? "open" : ""}`} onClick={() => setOpen(expanded ? null : c.id)}>
              <div className="care-row-top"><b>{fmt(c.createdAt)} · {PERIOD_LABEL[c.period] || c.period}</b><span className={`tag-soft ${c.status === "done" ? "ok" : c.status === "sending" ? "warn" : "bad"}`}>{STATUS_LABEL[c.status]}</span></div>
              <div className="care-row-text">{c.body}</div>
              <div className="care-bar"><i className="ok" style={{ width: `${okPct}%` }} /><i className="bad" style={{ width: `${failPct}%` }} /></div>
              <div className="care-stats"><span className="ok">{c.okCount} đã nhận</span>{c.failCount > 0 && <span className="bad">{c.failCount} không gửi được</span>}<span>/ {c.total} người</span></div>
              {expanded && (
                <div className="care-detail">
                  {c.imageUrl && <small>Có kèm 1 ảnh</small>}
                  {Object.entries(c.errors).map(([k, n]) => <small key={k} className="care-err">{n} người: {friendlyError(k)}</small>)}
                  {c.finishedAt && <small>Hoàn tất lúc {fmt(c.finishedAt)}</small>}
                </div>
              )}
            </button>
          );
        })}
      </section>

      <div className="action-bar">
        <button className="btn primary wide" disabled={busy || sending || !valid || !audience || audience.count === 0} onClick={() => setConfirm(true)}>
          {sending ? "Đang có đợt gửi chạy..." : `Gửi cho ${audience ? audience.count : "..."} người`}
        </button>
      </div>

      <ConfirmSheet open={confirm} title="Gửi tin cho khách?" message={`Tin sẽ được gửi cho ${audience?.count || 0} người đã quan tâm OA (${PERIOD_LABEL[period]}). Bạn nên gửi thử cho mình trước. Không thu hồi được sau khi gửi.`} confirmLabel="Gửi ngay" onConfirm={send} onClose={() => setConfirm(false)} />
    </Page>
  );
}
