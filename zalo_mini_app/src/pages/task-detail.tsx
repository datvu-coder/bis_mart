import React, { useCallback, useEffect, useRef, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import { Page, useSnackbar } from "zmp-ui";
import { api, photoSrc } from "../api";
import { bumpData } from "../data";
import { compressImage, pickPhotos, PhotoSource } from "../photos";
import { useAuth } from "../auth";
import Avatar from "../components/Avatar";
import Icon from "../components/Icon";
import PhotoViewer from "../components/PhotoViewer";
import Sheet, { ConfirmSheet } from "../components/Sheet";
import { Assignee, PRIORITY_LABEL, RECURRENCE_LABEL, STATUS_LABEL, TaskDetail } from "../types";
import { dueInfo, formatDateTime } from "../utils";
import TaskTimeline from "../components/TaskTimeline";

const STEPS: { key: "todo" | "doing" | "done"; label: string }[] = [
  { key: "todo", label: "Chưa làm" },
  { key: "doing", label: "Đang làm" },
  { key: "done", label: "Hoàn thành" },
];

type Confirm = null | "cancel" | "delete" | "reopen";

export default function TaskDetailPage() {
  const id = Number(useParams().id);
  const nav = useNavigate();
  const { user } = useAuth();
  const { openSnackbar } = useSnackbar();
  const [task, setTask] = useState<TaskDetail | null>(null);
  const [error, setError] = useState("");
  const [note, setNote] = useState("");
  const [photos, setPhotos] = useState<string[]>([]);
  const [comment, setComment] = useState("");
  const [busy, setBusy] = useState(false);
  const [viewer, setViewer] = useState<string | null>(null);
  const [menu, setMenu] = useState(false);
  const [photoSheet, setPhotoSheet] = useState(false);
  const [confirm, setConfirm] = useState<Confirm>(null);
  const [staff, setStaff] = useState<Assignee[]>([]);
  const [doers, setDoers] = useState<number[]>([]);
  const fileRef = useRef<HTMLInputElement>(null);

  const load = useCallback(async () => {
    try {
      const t = await api.getTask(id);
      setTask(t);
      setPhotos(t.photoUrls);
      setNote(t.completionNote);
      setDoers(t.doerIds);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Không tải được công việc");
    }
  }, [id]);

  useEffect(() => {
    load();
  }, [load]);

  const actable = !!task && !!user && (String(task.assigneeId) === user.id || task.canManage);
  useEffect(() => {
    if (actable) api.taskStaff(id).then((r) => setStaff(r.employees)).catch(() => {});
  }, [actable, id]);

  const run = async (fn: () => Promise<unknown>, okMsg?: string) => {
    setBusy(true);
    try {
      await fn();
      if (okMsg) openSnackbar({ text: okMsg, type: "success" });
      bumpData();
      await load();
      return true;
    } catch (e) {
      openSnackbar({ text: e instanceof Error ? e.message : "Có lỗi xảy ra", type: "error" });
      return false;
    } finally {
      setBusy(false);
    }
  };

  const uploadFiles = async (files: File[]) => {
    if (!files.length) return;
    setBusy(true);
    try {
      let added = 0;
      for (const f of files) {
        const { photoUrl } = await api.uploadPhoto(await compressImage(f));
        setPhotos((p) => [...p, photoUrl]);
        added += 1;
      }
      openSnackbar({ text: `Đã thêm ${added} ảnh`, type: "success" });
    } catch (e) {
      openSnackbar({ text: e instanceof Error ? e.message : "Không tải được ảnh lên", type: "error" });
    } finally {
      setBusy(false);
    }
  };

  const addPhotos = async (source: PhotoSource) => {
    setPhotoSheet(false);
    try {
      await uploadFiles(await pickPhotos(source));
    } catch (e) {
      openSnackbar({ text: e instanceof Error ? e.message : "Không lấy được ảnh", type: "error" });
    }
  };

  const onFallbackPick = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const files = Array.from(e.target.files || []);
    e.target.value = "";
    await uploadFiles(files);
  };

  if (error) return <Page className="page"><div className="error">{error}</div></Page>;
  if (!task) return <Page className="page"><div className="center-note">Đang tải...</div></Page>;

  const isAssignee = user ? String(task.assigneeId) === user.id : false;
  const canAct = (isAssignee || task.canManage) && task.status !== "cancelled";
  const closed = task.status === "done";
  const due = dueInfo(task);
  const stepIndex = task.status === "cancelled" ? -1 : STEPS.findIndex((s) => s.key === task.status);

  const doConfirm = async () => {
    if (confirm === "delete") {
      const ok = await run(() => api.deleteTask(task.id));
      if (ok) { openSnackbar({ text: "Đã xoá công việc", type: "success" }); nav(-1); }
    } else if (confirm === "cancel") {
      await run(() => api.setStatus(task.id, "cancelled"), "Đã huỷ công việc");
    } else if (confirm === "reopen") {
      await run(() => api.setStatus(task.id, "todo"), "Đã mở lại công việc");
    }
    setConfirm(null);
  };

  return (
    <Page className="page with-bar">
      <header className="hero compact">
        <div className="hero-row">
          <button className="hero-btn" onClick={() => nav(-1)} aria-label="Quay lại"><Icon name="back" size={22} /></button>
          {task.canManage && (
            <button className="hero-btn" onClick={() => setMenu(true)} aria-label="Tuỳ chọn"><span className="dots">•••</span></button>
          )}
        </div>
        <h1 className="detail-title">{task.title}</h1>
        <div className="hero-chips">
          <span className={`pill status-${task.status}`}>{STATUS_LABEL[task.status]}</span>
          {task.overdue && <span className="pill overdue">Quá hạn</span>}
          <span className="pill">{PRIORITY_LABEL[task.priority]}</span>
          {task.recurrence !== "none" && <span className="pill"><Icon name="repeat" size={12} /> {RECURRENCE_LABEL[task.recurrence]}</span>}
        </div>
      </header>

      {stepIndex >= 0 && (
        <div className="stepper">
          {STEPS.map((s, i) => (
            <div key={s.key} className={`step ${i <= stepIndex ? "on" : ""} ${i === stepIndex ? "current" : ""}`}>
              <span className="dot">{i < stepIndex || (i === stepIndex && closed) ? <Icon name="check" size={12} /> : i + 1}</span>
              <span className="step-label">{s.label}</span>
            </div>
          ))}
        </div>
      )}

      <div className="panel">
        {task.description && <p className="desc">{task.description}</p>}
        <dl className="info">
          <div><Icon name="user" size={18} /><dt>Người làm</dt><dd>{task.assigneeName ? <><Avatar name={task.assigneeName} size={20} /> {task.assigneeName}</> : "Chưa giao"}</dd></div>
          <div><Icon name="users" size={18} /><dt>Giao bởi</dt><dd>{task.assignedByName || "-"}</dd></div>
          <div><Icon name="pin" size={18} /><dt>Cửa hàng</dt><dd>{task.storeName || task.storeCode || "-"}</dd></div>
          <div><Icon name="calendar" size={18} /><dt>Hạn chót</dt><dd className={due ? `tone-${due.tone}` : ""}>{task.dueAt ? formatDateTime(task.dueAt) : "Không có"}{due && (due.tone === "overdue" || due.tone === "today") && <span className={`tag ${due.tone}`}>{due.tone === "overdue" ? "Quá hạn" : "Hôm nay"}</span>}</dd></div>
          {task.doers.length > 0 && <div><Icon name="users" size={18} /><dt>Thực hiện bởi</dt><dd className="wrap">{task.doers.map((d) => d.name).join(", ")}</dd></div>}
          {task.completedAt && <div><Icon name="checkCircle" size={18} /><dt>Hoàn thành lúc</dt><dd>{formatDateTime(task.completedAt)}</dd></div>}
        </dl>
      </div>

      <TaskTimeline task={task} />

      {(canAct || photos.length > 0) && (
        <div className="panel">
          <div className="panel-head">
            <h3>Kết quả công việc</h3>
            {task.requirePhoto && <span className="req">Bắt buộc ảnh</span>}
          </div>
          <div className="photos">
            {photos.map((p) => (
              <button key={p} className="photo" onClick={() => setViewer(p)}><img src={photoSrc(p)} alt="Ảnh minh chứng" /></button>
            ))}
            {canAct && !closed && (
              <button className="photo-add" onClick={() => setPhotoSheet(true)} disabled={busy}>
                <Icon name="camera" size={22} /><span>Thêm ảnh</span>
              </button>
            )}
          </div>
          <input ref={fileRef} type="file" accept="image/*" multiple hidden onChange={onFallbackPick} />
          {canAct && !closed && staff.length > 0 && (
            <div className="field doers">
              <span>Nhân viên thực hiện</span>
              <div className="chip-row nomargin">
                {staff.map((e) => (
                  <button type="button" key={e.id} className={`chip ${doers.includes(e.id) ? "active" : ""}`}
                    onClick={() => setDoers((cur) => (cur.includes(e.id) ? cur.filter((x) => x !== e.id) : [...cur, e.id]))}>
                    {doers.includes(e.id) && <Icon name="check" size={13} />} {e.fullName}
                  </button>
                ))}
              </div>
            </div>
          )}
          {canAct && !closed && (
            <textarea placeholder="Ghi chú kết quả (không bắt buộc)" value={note} onChange={(e) => setNote(e.target.value)} />
          )}
          {closed && task.completionNote && <p className="desc">{task.completionNote}</p>}
          {photos.length === 0 && closed && <div className="hint">Không có ảnh minh chứng</div>}
        </div>
      )}

      <div className="panel">
        <div className="panel-head"><h3>Trao đổi</h3><span className="count">{task.comments.length}</span></div>
        {task.comments.length === 0 && <div className="hint">Chưa có trao đổi nào</div>}
        {task.comments.map((c) => (
          <div key={c.id} className="comment">
            <Avatar name={c.authorName || "?"} size={30} />
            <div className="bubble">
              <div className="bubble-head"><b>{c.authorName || "Ẩn danh"}</b><small>{formatDateTime(c.createdAt)}</small></div>
              <div>{c.body}</div>
            </div>
          </div>
        ))}
        <div className="composer">
          <input
            placeholder="Viết trao đổi..."
            value={comment}
            onChange={(e) => setComment(e.target.value)}
            onKeyDown={(e) => { if (e.key === "Enter" && comment.trim() && !busy) run(async () => { await api.addComment(task.id, comment.trim()); setComment(""); }); }}
          />
          <button
            className="send"
            disabled={busy || !comment.trim()}
            onClick={() => run(async () => { await api.addComment(task.id, comment.trim()); setComment(""); })}
            aria-label="Gửi"
          >
            <Icon name="send" size={18} />
          </button>
        </div>
      </div>

      {canAct && (
        <div className="action-bar">
          {task.status === "todo" && (
            <button className="btn" disabled={busy} onClick={() => run(() => api.setStatus(task.id, "doing"), "Đã bắt đầu làm")}>
              <Icon name="play" size={16} /> Bắt đầu
            </button>
          )}
          {!closed && (
            <button className="btn primary" disabled={busy} onClick={() => run(() => api.setStatus(task.id, "done", note, photos, doers), "Đã hoàn thành công việc")}>
              <Icon name="check" size={18} /> Hoàn thành
            </button>
          )}
          {closed && task.canManage && (
            <button className="btn" disabled={busy} onClick={() => setConfirm("reopen")}>Mở lại công việc</button>
          )}
        </div>
      )}

      <PhotoViewer name={viewer} onClose={() => setViewer(null)} />

      <Sheet open={photoSheet} title="Thêm ảnh minh chứng" onClose={() => setPhotoSheet(false)}>
        <div className="menu">
          <button onClick={() => addPhotos("camera")}><Icon name="camera" size={20} /> Chụp ảnh mới</button>
          <button onClick={() => addPhotos("album")}><Icon name="inbox" size={20} /> Chọn từ thư viện</button>
          <button className="muted-row" onClick={() => { setPhotoSheet(false); fileRef.current?.click(); }}>Không được? Dùng bộ chọn dự phòng</button>
        </div>
      </Sheet>

      <Sheet open={menu} title="Tuỳ chọn" onClose={() => setMenu(false)}>
        <div className="menu">
          <button onClick={() => { setMenu(false); nav(`/task/${task.id}/edit`); }}><Icon name="edit" size={20} /> Chỉnh sửa công việc</button>
          {task.status !== "cancelled" && !closed && (
            <button onClick={() => { setMenu(false); setConfirm("cancel"); }}><Icon name="close" size={20} /> Huỷ công việc</button>
          )}
          <button className="danger" onClick={() => { setMenu(false); setConfirm("delete"); }}><Icon name="trash" size={20} /> Xoá công việc</button>
        </div>
      </Sheet>

      <ConfirmSheet
        open={confirm !== null}
        title={confirm === "delete" ? "Xoá công việc?" : confirm === "cancel" ? "Huỷ công việc?" : "Mở lại công việc?"}
        message={
          confirm === "delete" ? "Công việc, ảnh và trao đổi sẽ bị xoá vĩnh viễn."
          : confirm === "cancel" ? "Công việc sẽ chuyển sang trạng thái đã huỷ."
          : "Công việc sẽ quay lại trạng thái chưa làm."
        }
        confirmLabel={confirm === "delete" ? "Xoá" : confirm === "cancel" ? "Huỷ việc" : "Mở lại"}
        danger={confirm !== "reopen"}
        busy={busy}
        onConfirm={doConfirm}
        onClose={() => setConfirm(null)}
      />
    </Page>
  );
}
