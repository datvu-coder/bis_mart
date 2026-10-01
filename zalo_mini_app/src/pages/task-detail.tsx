import React, { useCallback, useEffect, useRef, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import { Page, useSnackbar } from "zmp-ui";
import { api, photoSrc } from "../api";
import { useAuth } from "../auth";
import { PRIORITY_LABEL, RECURRENCE_LABEL, STATUS_LABEL, TaskDetail } from "../types";
import { formatDue } from "../utils";

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
  const fileRef = useRef<HTMLInputElement>(null);

  const load = useCallback(async () => {
    try {
      const t = await api.getTask(id);
      setTask(t);
      setPhotos(t.photoUrls);
      setNote(t.completionNote);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Không tải được công việc");
    }
  }, [id]);

  useEffect(() => {
    load();
  }, [load]);

  const run = async (fn: () => Promise<unknown>, okMsg?: string) => {
    setBusy(true);
    try {
      await fn();
      if (okMsg) openSnackbar({ text: okMsg, type: "success" });
      await load();
    } catch (e) {
      openSnackbar({ text: e instanceof Error ? e.message : "Có lỗi xảy ra", type: "error" });
    } finally {
      setBusy(false);
    }
  };

  const onPickPhoto = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    e.target.value = "";
    if (!file) return;
    await run(async () => {
      const { photoUrl } = await api.uploadPhoto(file);
      setPhotos((p) => [...p, photoUrl]);
    });
  };

  if (error) return <Page className="page"><div className="error">{error}</div></Page>;
  if (!task) return <Page className="page"><div className="center-note">Đang tải...</div></Page>;

  const isAssignee = String(task.assigneeId) === user?.id;
  const canAct = (isAssignee || task.canManage) && task.status !== "cancelled";
  const closed = task.status === "done";

  return (
    <Page className="page with-bar">
      <div className="topbar">
        <button className="link" onClick={() => nav(-1)}>‹ Quay lại</button>
        {task.canManage && <button className="link" onClick={() => nav(`/task/${task.id}/edit`)}>Sửa</button>}
      </div>

      <div className="panel">
        <h2>{task.title}</h2>
        <div className="chips">
          <span className={`chip status-${task.status}`}>{STATUS_LABEL[task.status]}</span>
          {task.overdue && <span className="chip overdue">Quá hạn</span>}
          <span className="chip">{PRIORITY_LABEL[task.priority]}</span>
          {task.recurrence !== "none" && <span className="chip">🔁 {RECURRENCE_LABEL[task.recurrence]}</span>}
        </div>
        {task.description && <p className="desc">{task.description}</p>}
        <dl className="kv">
          <dt>Người làm</dt><dd>{task.assigneeName || "Chưa giao"}</dd>
          <dt>Giao bởi</dt><dd>{task.assignedByName || "-"}</dd>
          <dt>Cửa hàng</dt><dd>{task.storeName || task.storeCode || "-"}</dd>
          <dt>Hạn chót</dt><dd>{task.dueAt ? formatDue(task.dueAt) : "Không có"}</dd>
          {task.completedAt && (<><dt>Hoàn thành</dt><dd>{formatDue(task.completedAt)}</dd></>)}
        </dl>
      </div>

      {(canAct || photos.length > 0) && (
        <div className="panel">
          <h3>Kết quả {task.requirePhoto && <small>(bắt buộc ảnh minh chứng)</small>}</h3>
          <div className="photos">
            {photos.map((p) => (
              <img key={p} src={photoSrc(p)} alt="minh chứng" onClick={() => window.open(photoSrc(p))} />
            ))}
            {canAct && !closed && (
              <button className="photo-add" onClick={() => fileRef.current?.click()} disabled={busy}>📷 Thêm ảnh</button>
            )}
          </div>
          <input ref={fileRef} type="file" accept="image/*" capture="environment" hidden onChange={onPickPhoto} />
          {canAct && !closed && (
            <textarea placeholder="Ghi chú (không bắt buộc)" value={note} onChange={(e) => setNote(e.target.value)} />
          )}
          {closed && task.completionNote && <p className="desc">{task.completionNote}</p>}
        </div>
      )}

      <div className="panel">
        <h3>Bình luận</h3>
        {task.comments.length === 0 && <div className="hint">Chưa có bình luận</div>}
        {task.comments.map((c) => (
          <div key={c.id} className="comment">
            <b>{c.authorName || "Ẩn danh"}</b> <small>{formatDue(c.createdAt)}</small>
            <div>{c.body}</div>
          </div>
        ))}
        <div className="row">
          <input placeholder="Viết bình luận..." value={comment} onChange={(e) => setComment(e.target.value)} />
          <button
            className="btn"
            disabled={busy || !comment.trim()}
            onClick={() => run(async () => { await api.addComment(task.id, comment.trim()); setComment(""); })}
          >
            Gửi
          </button>
        </div>
      </div>

      {canAct && (
        <div className="action-bar">
          {task.status === "todo" && (
            <button className="btn" disabled={busy} onClick={() => run(() => api.setStatus(task.id, "doing"), "Đã bắt đầu")}>Bắt đầu làm</button>
          )}
          {!closed && (
            <button
              className="btn primary"
              disabled={busy}
              onClick={() => run(() => api.setStatus(task.id, "done", note, photos), "Đã hoàn thành")}
            >
              ✓ Hoàn thành
            </button>
          )}
          {closed && task.canManage && (
            <button className="btn" disabled={busy} onClick={() => run(() => api.setStatus(task.id, "todo"), "Đã mở lại")}>Mở lại</button>
          )}
          {task.canManage && !closed && (
            <button className="btn danger" disabled={busy} onClick={() => run(() => api.setStatus(task.id, "cancelled"), "Đã huỷ")}>Huỷ việc</button>
          )}
        </div>
      )}
    </Page>
  );
}
