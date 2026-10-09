import React, { useCallback, useEffect, useMemo, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import { Page, useSnackbar } from "zmp-ui";
import { api } from "../api";
import Avatar from "../components/Avatar";
import Icon from "../components/Icon";
import { PhotoStrip } from "../components/PhotoField";
import Sheet, { ConfirmSheet } from "../components/Sheet";
import SubHero from "../components/SubHero";
import { bumpData } from "../data";
import { AnnouncementDetail } from "../types";
import { formatDateTime, quickDeadlines } from "../utils";

export default function BoardDetailPage() {
  const { id } = useParams();
  const annId = Number(id);
  const nav = useNavigate();
  const { openSnackbar } = useSnackbar();
  const [a, setA] = useState<AnnouncementDetail | null>(null);
  const [error, setError] = useState("");
  const [tab, setTab] = useState<"unread" | "read">("unread");
  const [busy, setBusy] = useState(false);
  const [taskSheet, setTaskSheet] = useState(false);
  const [onlyUnread, setOnlyUnread] = useState(true);
  const [due, setDue] = useState("");
  const [del, setDel] = useState(false);
  const deadlines = useMemo(quickDeadlines, []);

  const load = useCallback(() => {
    api.announcement(annId).then(setA).catch((e) => setError(e instanceof Error ? e.message : "Không tải được thông báo"));
  }, [annId]);
  useEffect(load, [load]);

  // Opening the post is what counts as "read".
  useEffect(() => {
    api.readAnnouncement(annId).then(() => bumpData()).catch(() => {});
  }, [annId]);

  const run = async (fn: () => Promise<string>) => {
    setBusy(true);
    try {
      openSnackbar({ text: await fn(), type: "success" });
      bumpData();
      load();
    } catch (e) {
      openSnackbar({ text: e instanceof Error ? e.message : "Không xử lý được", type: "error" });
    } finally {
      setBusy(false);
    }
  };

  if (error) return <Page className="page"><SubHero title="Thông báo" /><div className="error">{error}</div></Page>;
  if (!a) return <Page className="page"><SubHero title="Thông báo" /></Page>;

  const unread = a.unread || [];
  const readers = a.readers || [];
  const total = a.audienceCount || 0;
  return (
    <Page className="page">
      <SubHero title="Thông báo"
        right={a.canManage ? <button className="hero-btn" onClick={() => setDel(true)} aria-label="Xoá thông báo"><Icon name="trash" size={20} /></button> : undefined} />

      <section className="panel">
        <h3>{a.title}</h3>
        <div className="hint">{a.authorName} · {formatDateTime(a.createdAt)}</div>
        {a.body ? <p className="desc">{a.body}</p> : <div className="hint">Không có nội dung chi tiết.</div>}
        <PhotoStrip photos={a.imageUrls} />
      </section>

      {a.canManage && (
        <section className="panel">
          <div className="panel-head"><h3>Xác nhận đã đọc</h3><span className="count">{a.readCount || 0}/{total}</span></div>
          <div className="read-bar big"><i style={{ width: `${total ? Math.round(((a.readCount || 0) / total) * 100) : 0}%` }} /></div>
          <div className="seg">
            <button className={tab === "unread" ? "active" : ""} onClick={() => setTab("unread")}>Chưa đọc ({unread.length})</button>
            <button className={tab === "read" ? "active" : ""} onClick={() => setTab("read")}>Đã đọc ({readers.length})</button>
          </div>
          <div className="people short">
            {(tab === "unread" ? unread : readers).length === 0 && <div className="hint">{tab === "unread" ? "Mọi người đều đã đọc 🎉" : "Chưa có ai đọc"}</div>}
            {(tab === "unread" ? unread : readers).map((p) => (
              <div key={p.id} className="person static">
                <Avatar name={p.name} size={32} />
                <span className="person-info"><b>{p.name}</b><small>{p.storeCode} · {p.position}</small></span>
                {"readAt" in p && <small className="muted">{formatDateTime((p as { readAt: string }).readAt)}</small>}
              </div>
            ))}
          </div>
          <div className="sheet-actions entry-actions">
            <button className="btn" disabled={busy || unread.length === 0} onClick={() => run(async () => `Đã nhắc ${(await api.remindAnnouncement(annId)).sent} người`)}><Icon name="bell" size={16} /> Nhắc chưa đọc</button>
            <button className="btn" onClick={() => setTaskSheet(true)}><Icon name="tasks" size={16} /> Biến thành việc</button>
          </div>
        </section>
      )}

      <Sheet open={taskSheet} title="Biến thành công việc" onClose={() => setTaskSheet(false)}>
        <p className="sheet-msg">Tạo một công việc từ thông báo này, giao cho từng người trong nhóm nhận.</p>
        <div className="seg">
          <button className={onlyUnread ? "active" : ""} onClick={() => setOnlyUnread(true)}>Người chưa đọc ({unread.length})</button>
          <button className={!onlyUnread ? "active" : ""} onClick={() => setOnlyUnread(false)}>Tất cả ({total})</button>
        </div>
        <div className="chip-row">
          {deadlines.map((d) => <button key={d.label} className={`chip ${due === d.value ? "active" : ""}`} onClick={() => setDue(due === d.value ? "" : d.value)}>{d.label}</button>)}
        </div>
        <div className="sheet-actions">
          <button className="btn" onClick={() => setTaskSheet(false)}>Huỷ</button>
          <button className="btn primary" disabled={busy || (onlyUnread && unread.length === 0)}
            onClick={() => run(async () => {
              const r = await api.announcementToTask(annId, { dueAt: due || null, assigneeIds: onlyUnread ? unread.map((p) => p.id) : undefined });
              setTaskSheet(false);
              return `Đã giao việc cho ${r.created} người`;
            })}>Giao việc</button>
        </div>
      </Sheet>

      <ConfirmSheet open={del} title="Xoá thông báo?" message="Thông báo sẽ biến mất với mọi người." confirmLabel="Xoá" danger busy={busy}
        onConfirm={async () => { try { await api.deleteAnnouncement(annId); bumpData(); nav(-1); } catch (e) { openSnackbar({ text: e instanceof Error ? e.message : "Không xoá được", type: "error" }); setDel(false); } }}
        onClose={() => setDel(false)} />
    </Page>
  );
}
