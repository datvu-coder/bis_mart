import React, { useEffect, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import { Page, useSnackbar } from "zmp-ui";
import { api } from "../api";
import { Assignee, PRIORITY_LABEL, RECURRENCE_LABEL } from "../types";
import { fromInputValue, toInputValue } from "../utils";

export default function TaskFormPage() {
  const { id: idParam } = useParams();
  const editId = idParam ? Number(idParam) : null;
  const nav = useNavigate();
  const { openSnackbar } = useSnackbar();
  const [employees, setEmployees] = useState<Assignee[]>([]);
  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [assigneeId, setAssigneeId] = useState("");
  const [priority, setPriority] = useState("normal");
  const [dueAt, setDueAt] = useState("");
  const [recurrence, setRecurrence] = useState("none");
  const [requirePhoto, setRequirePhoto] = useState(false);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    api.assignees().then((r) => setEmployees(r.employees)).catch(() => openSnackbar({ text: "Không tải được danh sách nhân viên", type: "error" }));
    if (editId) {
      api.getTask(editId).then((t) => {
        setTitle(t.title);
        setDescription(t.description);
        setAssigneeId(t.assigneeId ? String(t.assigneeId) : "");
        setPriority(t.priority);
        setDueAt(toInputValue(t.dueAt));
        setRecurrence(t.recurrence);
        setRequirePhoto(t.requirePhoto);
      });
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [editId]);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setBusy(true);
    const input = {
      title: title.trim(),
      description: description.trim(),
      assigneeId: assigneeId ? Number(assigneeId) : null,
      priority,
      dueAt: fromInputValue(dueAt),
      recurrence,
      requirePhoto,
    };
    try {
      if (editId) await api.updateTask(editId, input);
      else await api.createTask(input);
      openSnackbar({ text: editId ? "Đã cập nhật" : "Đã giao việc", type: "success" });
      nav(-1);
    } catch (err) {
      openSnackbar({ text: err instanceof Error ? err.message : "Có lỗi xảy ra", type: "error" });
    } finally {
      setBusy(false);
    }
  };

  return (
    <Page className="page">
      <div className="topbar">
        <button className="link" onClick={() => nav(-1)}>‹ Quay lại</button>
        <b>{editId ? "Sửa công việc" : "Giao việc mới"}</b>
        <span />
      </div>
      <form className="panel form" onSubmit={submit}>
        <label>Tiêu đề *<input value={title} onChange={(e) => setTitle(e.target.value)} placeholder="VD: Kiểm kho sữa bột" /></label>
        <label>Mô tả<textarea value={description} onChange={(e) => setDescription(e.target.value)} /></label>
        <label>Giao cho
          <select value={assigneeId} onChange={(e) => setAssigneeId(e.target.value)}>
            <option value="">— Chưa chọn —</option>
            {employees.map((emp) => (
              <option key={emp.id} value={emp.id}>{emp.fullName} ({emp.storeCode || emp.position})</option>
            ))}
          </select>
        </label>
        <label>Mức ưu tiên
          <select value={priority} onChange={(e) => setPriority(e.target.value)}>
            {Object.entries(PRIORITY_LABEL).map(([k, v]) => <option key={k} value={k}>{v}</option>)}
          </select>
        </label>
        <label>Hạn chót<input type="datetime-local" value={dueAt} onChange={(e) => setDueAt(e.target.value)} /></label>
        <label>Lặp lại
          <select value={recurrence} onChange={(e) => setRecurrence(e.target.value)}>
            {Object.entries(RECURRENCE_LABEL).map(([k, v]) => <option key={k} value={k}>{v}</option>)}
          </select>
        </label>
        <label className="check">
          <input type="checkbox" checked={requirePhoto} onChange={(e) => setRequirePhoto(e.target.checked)} />
          Bắt buộc chụp ảnh minh chứng khi hoàn thành
        </label>
        <button className="btn primary" disabled={busy || !title.trim()}>{busy ? "Đang lưu..." : editId ? "Lưu" : "Giao việc"}</button>
      </form>
    </Page>
  );
}
