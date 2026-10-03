import React, { useEffect, useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import { Page, useSnackbar } from "zmp-ui";
import { api } from "../api";
import PhotoField from "../components/PhotoField";
import SubHero from "../components/SubHero";
import { bumpData, useStoreList } from "../data";
import { Assignee } from "../types";
import { toApiString } from "../utils";

const REMINDS = (() => {
  const inHours = (h: number) => toApiString(new Date(Date.now() + h * 3600000));
  const tomorrow8 = () => { const d = new Date(); d.setDate(d.getDate() + 1); d.setHours(8, 0, 0, 0); return toApiString(d); };
  return [
    { label: "Không nhắc", value: "" },
    { label: "Sau 2 giờ", value: () => inHours(2) },
    { label: "Sáng mai 8:00", value: tomorrow8 },
  ] as { label: string; value: string | (() => string) }[];
})();

export default function BoardFormPage() {
  const nav = useNavigate();
  const { openSnackbar } = useSnackbar();
  const stores = useStoreList();
  const [people, setPeople] = useState<Assignee[]>([]);
  const [title, setTitle] = useState("");
  const [body, setBody] = useState("");
  const [photos, setPhotos] = useState<string[]>([]);
  const [selStores, setSelStores] = useState<string[]>([]);
  const [selPos, setSelPos] = useState<string[]>([]);
  const [pinned, setPinned] = useState(false);
  const [remind, setRemind] = useState(0);
  const [busy, setBusy] = useState(false);

  useEffect(() => { api.assignees().then((r) => setPeople(r.employees)).catch(() => {}); }, []);
  const positions = useMemo(() => Array.from(new Set(people.map((p) => p.position).filter(Boolean))).sort(), [people]);
  const toggle = (list: string[], set: (v: string[]) => void, v: string) => set(list.includes(v) ? list.filter((x) => x !== v) : [...list, v]);

  const audience = useMemo(() => people.filter((p) =>
    (!selStores.length || selStores.includes(p.storeCode.toUpperCase())) && (!selPos.length || selPos.includes(p.position))).length, [people, selStores, selPos]);

  const submit = async () => {
    setBusy(true);
    try {
      const r = REMINDS[remind].value;
      await api.createAnnouncement({
        title: title.trim(), body: body.trim(), imageUrls: photos, stores: selStores, positions: selPos, pinned,
        remindAt: typeof r === "function" ? r() : r || null,
      });
      openSnackbar({ text: "Đã đăng thông báo", type: "success" });
      bumpData();
      nav(-1);
    } catch (e) {
      openSnackbar({ text: e instanceof Error ? e.message : "Không đăng được thông báo", type: "error" });
    } finally {
      setBusy(false);
    }
  };

  return (
    <Page className="page with-bar">
      <SubHero title="Đăng thông báo" note="Nhân viên sẽ nhận thông báo và bạn xem được ai đã đọc" />
      <section className="panel">
        <h3>Nội dung</h3>
        <label className="field"><span>Tiêu đề *</span><input value={title} onChange={(e) => setTitle(e.target.value)} placeholder="VD: Khuyến mãi tuần này" maxLength={200} /></label>
        <label className="field"><span>Nội dung</span><textarea value={body} onChange={(e) => setBody(e.target.value)} placeholder="Chi tiết thông báo..." /></label>
        <div className="field"><span>Ảnh đính kèm</span><PhotoField value={photos} onChange={setPhotos} max={6} /></div>
      </section>

      <section className="panel">
        <div className="panel-head"><h3>Gửi cho</h3><span className="count">{people.length ? `${audience} người` : ""}</span></div>
        {stores.length > 1 && (
          <div className="field"><span>Cửa hàng (bỏ trống = tất cả)</span>
            <div className="chip-row nomargin">
              {stores.map((s) => (
                <button type="button" key={s.storeCode} className={`chip ${selStores.includes(s.storeCode.toUpperCase()) ? "active" : ""}`} onClick={() => toggle(selStores, setSelStores, s.storeCode.toUpperCase())}>{s.storeName || s.storeCode}</button>
              ))}
            </div>
          </div>
        )}
        {positions.length > 1 && (
          <div className="field"><span>Chức vụ (bỏ trống = tất cả)</span>
            <div className="chip-row nomargin">
              {positions.map((p) => <button type="button" key={p} className={`chip ${selPos.includes(p) ? "active" : ""}`} onClick={() => toggle(selPos, setSelPos, p)}>{p}</button>)}
            </div>
          </div>
        )}
      </section>

      <section className="panel">
        <h3>Tuỳ chọn</h3>
        <div className="field"><span>Nhắc người chưa đọc</span>
          <div className="seg">{REMINDS.map((r, k) => <button type="button" key={r.label} className={remind === k ? "active" : ""} onClick={() => setRemind(k)}>{r.label}</button>)}</div>
        </div>
        <button type="button" className="switch-row" onClick={() => setPinned((v) => !v)}>
          <span><b>Ghim lên đầu</b><small>Thông báo quan trọng luôn hiện trên cùng</small></span>
          <span className={`switch ${pinned ? "on" : ""}`}><i /></span>
        </button>
      </section>

      <div className="action-bar"><button className="btn primary wide" disabled={busy || !title.trim()} onClick={submit}>{busy ? "Đang đăng..." : "Đăng thông báo"}</button></div>
    </Page>
  );
}
