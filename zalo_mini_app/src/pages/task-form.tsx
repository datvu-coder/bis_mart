import React, { useEffect, useMemo, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import { Page, useSnackbar } from "zmp-ui";
import { api } from "../api";
import { bumpData } from "../data";
import Avatar from "../components/Avatar";
import Icon from "../components/Icon";
import { Assignee, PRIORITY_LABEL, RECURRENCE_LABEL, StoreWithManagers } from "../types";
import { fromInputValue, quickDeadlines, toInputValue } from "../utils";

const TEMPLATES = [
  "Vệ sinh cửa hàng",
  "Kiểm kho & đối chiếu tồn",
  "Sắp xếp trưng bày kệ",
  "Mở cửa / chuẩn bị ca",
  "Đóng cửa / tổng kết ca",
  "Kiểm tra hạn sử dụng",
];

export default function TaskFormPage() {
  const { id: idParam } = useParams();
  const editId = idParam ? Number(idParam) : null;
  const nav = useNavigate();
  const { openSnackbar } = useSnackbar();
  const [employees, setEmployees] = useState<Assignee[]>([]);
  const [search, setSearch] = useState("");
  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [selected, setSelected] = useState<number[]>([]);
  const [mode, setMode] = useState<"person" | "store">("person");
  const [stores, setStores] = useState<StoreWithManagers[]>([]);
  const [pickedStores, setPickedStores] = useState<string[]>([]);
  const [priority, setPriority] = useState("normal");
  const [dueAt, setDueAt] = useState("");
  const [recurrence, setRecurrence] = useState("none");
  const [requirePhoto, setRequirePhoto] = useState(false);
  const [busy, setBusy] = useState(false);
  const deadlines = useMemo(quickDeadlines, []);

  useEffect(() => {
    if (!editId) api.taskStores().then((r) => setStores(r.stores)).catch(() => {});
    api.assignees().then((r) => setEmployees(r.employees)).catch(() => openSnackbar({ text: "Không tải được danh sách nhân viên", type: "error" }));
    if (editId) {
      api.getTask(editId).then((t) => {
        setTitle(t.title);
        setDescription(t.description);
        setSelected(t.assigneeId ? [t.assigneeId] : []);
        setPriority(t.priority);
        setDueAt(toInputValue(t.dueAt));
        setRecurrence(t.recurrence);
        setRequirePhoto(t.requirePhoto);
      });
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [editId]);

  const grouped = useMemo(() => {
    const q = search.trim().toLowerCase();
    const list = employees.filter((e) => !q || e.fullName.toLowerCase().includes(q) || e.employeeCode.toLowerCase().includes(q));
    const map = new Map<string, Assignee[]>();
    list.forEach((e) => map.set(e.storeCode || "Khác", [...(map.get(e.storeCode || "Khác") || []), e]));
    return Array.from(map.entries());
  }, [employees, search]);

  const toggle = (empId: number) =>
    setSelected((cur) => (editId ? [empId] : cur.includes(empId) ? cur.filter((x) => x !== empId) : [...cur, empId]));

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setBusy(true);
    const base = {
      title: title.trim(),
      description: description.trim(),
      priority,
      dueAt: fromInputValue(dueAt),
      recurrence,
      requirePhoto,
    };
    try {
      if (editId) {
        await api.updateTask(editId, { ...base, assigneeId: selected[0] ?? null });
      } else if (mode === "store") {
        const targets = stores.filter((st) => pickedStores.includes(st.storeCode) && st.managers.length > 0);
        const results = await Promise.allSettled(targets.map((st) => api.createTask({ ...base, assigneeId: st.managers[0].id })));
        const failed = results.filter((r) => r.status === "rejected").length;
        if (failed) throw new Error(`Giao thành công ${targets.length - failed}/${targets.length} cửa hàng, ${failed} lần lỗi`);
      } else if (selected.length === 0) {
        await api.createTask({ ...base, assigneeId: null });
      } else {
        const results = await Promise.allSettled(selected.map((assigneeId) => api.createTask({ ...base, assigneeId })));
        const failed = results.filter((r) => r.status === "rejected").length;
        if (failed) throw new Error(`Giao thành công ${selected.length - failed}/${selected.length} người, ${failed} lần lỗi`);
      }
      openSnackbar({ text: editId ? "Đã cập nhật công việc" : mode === "store" ? `Đã giao việc cho ${pickedStores.length} cửa hàng` : selected.length > 1 ? `Đã giao việc cho ${selected.length} người` : "Đã giao việc", type: "success" });
      nav(-1);
    } catch (err) {
      openSnackbar({ text: err instanceof Error ? err.message : "Có lỗi xảy ra", type: "error" });
    } finally {
      bumpData();
      setBusy(false);
    }
  };

  return (
    <Page className="page with-bar">
      <header className="hero compact">
        <div className="hero-row">
          <button className="hero-btn" onClick={() => nav(-1)} aria-label="Quay lại"><Icon name="back" size={22} /></button>
        </div>
        <h1 className="detail-title">{editId ? "Chỉnh sửa công việc" : "Giao việc mới"}</h1>
        <div className="hero-note">{editId ? "Cập nhật nội dung và người thực hiện" : "Giao cho một hoặc nhiều nhân viên cùng lúc"}</div>
      </header>

      <form onSubmit={submit}>
        <section className="panel">
          <h3>Nội dung công việc</h3>
          <label className="field">
            <span>Tiêu đề *</span>
            <input value={title} onChange={(e) => setTitle(e.target.value)} placeholder="VD: Kiểm kho sữa bột" maxLength={120} />
          </label>
          {!editId && (
            <div className="chip-row">
              {TEMPLATES.map((t) => (
                <button type="button" key={t} className={`chip ${title === t ? "active" : ""}`} onClick={() => setTitle(t)}>{t}</button>
              ))}
            </div>
          )}
          <label className="field">
            <span>Mô tả chi tiết</span>
            <textarea value={description} onChange={(e) => setDescription(e.target.value)} placeholder="Yêu cầu, lưu ý khi thực hiện..." />
          </label>
        </section>

        {!editId && (
          <div className="seg mode-seg">
            <button type="button" className={mode === "person" ? "active" : ""} onClick={() => setMode("person")}>Giao cho người</button>
            <button type="button" className={mode === "store" ? "active" : ""} onClick={() => setMode("store")}>Giao cho cửa hàng</button>
          </div>
        )}

        {mode === "store" ? (
          <section className="panel">
            <div className="panel-head">
              <h3>Cửa hàng nhận việc</h3>
              <span className="count">{pickedStores.length ? `Đã chọn ${pickedStores.length}` : "Chưa chọn"}</span>
            </div>
            <div className="hint">Việc sẽ giao cho SM (cửa hàng trưởng) của cửa hàng, người này tự phân công nhân viên và báo kết quả.</div>
            <div className="people">
              {stores.length === 0 && <div className="hint">Không có cửa hàng nào</div>}
              {stores.map((st) => {
                const on = pickedStores.includes(st.storeCode);
                const none = st.managers.length === 0;
                return (
                  <button type="button" key={st.storeCode} disabled={none} className={`person ${on ? "on" : ""}`}
                    onClick={() => setPickedStores((cur) => (cur.includes(st.storeCode) ? cur.filter((x) => x !== st.storeCode) : [...cur, st.storeCode]))}>
                    <Avatar name={st.managers[0]?.name || st.storeName} size={34} />
                    <span className="person-info">
                      <b>{st.storeName || st.storeCode}</b>
                      <small>{none ? "Chưa có SM" : `SM: ${st.managers.map((m) => m.name).join(", ")}`}</small>
                    </span>
                    <span className="tick">{on && <Icon name="check" size={14} />}</span>
                  </button>
                );
              })}
            </div>
            {stores.length > 1 && (
              <button type="button" className="link" onClick={() => setPickedStores(stores.filter((x) => x.managers.length).map((x) => x.storeCode))}>Chọn tất cả</button>
            )}
          </section>
        ) : (
        <section className="panel">
          <div className="panel-head">
            <h3>Người thực hiện</h3>
            <span className="count">{selected.length ? `Đã chọn ${selected.length}` : "Chưa chọn"}</span>
          </div>
          <label className="search light">
            <Icon name="search" size={18} />
            <input placeholder="Tìm theo tên hoặc mã NV" value={search} onChange={(e) => setSearch(e.target.value)} />
          </label>
          <div className="people">
            {grouped.length === 0 && <div className="hint">Không có nhân viên phù hợp</div>}
            {grouped.map(([store, list]) => (
              <div key={store}>
                <div className="people-group">{store}</div>
                {list.map((emp) => {
                  const on = selected.includes(emp.id);
                  return (
                    <button type="button" key={emp.id} className={`person ${on ? "on" : ""}`} onClick={() => toggle(emp.id)}>
                      <Avatar name={emp.fullName} size={34} />
                      <span className="person-info"><b>{emp.fullName}</b><small>{emp.employeeCode} · {emp.position}</small></span>
                      <span className="tick">{on && <Icon name="check" size={14} />}</span>
                    </button>
                  );
                })}
              </div>
            ))}
          </div>
        </section>
        )}

        <section className="panel">
          <h3>Thời hạn</h3>
          <div className="chip-row">
            {deadlines.map((d) => (
              <button type="button" key={d.label} className={`chip ${dueAt === toInputValue(d.value) ? "active" : ""}`} onClick={() => setDueAt(toInputValue(d.value))}>{d.label}</button>
            ))}
            {dueAt && <button type="button" className="chip ghost" onClick={() => setDueAt("")}>Bỏ hạn</button>}
          </div>
          <label className="field">
            <span>Hoặc chọn ngày giờ</span>
            <input type="datetime-local" value={dueAt} onChange={(e) => setDueAt(e.target.value)} />
          </label>
        </section>

        <section className="panel">
          <h3>Tuỳ chọn</h3>
          <div className="field">
            <span>Mức ưu tiên</span>
            <div className="seg">
              {Object.entries(PRIORITY_LABEL).map(([k, v]) => (
                <button type="button" key={k} className={`${priority === k ? "active" : ""} prio-${k}`} onClick={() => setPriority(k)}>{v}</button>
              ))}
            </div>
          </div>
          <div className="field">
            <span>Lặp lại</span>
            <div className="seg">
              {Object.entries(RECURRENCE_LABEL).map(([k, v]) => (
                <button type="button" key={k} className={recurrence === k ? "active" : ""} onClick={() => setRecurrence(k)}>{v}</button>
              ))}
            </div>
          </div>
          <button type="button" className="switch-row" onClick={() => setRequirePhoto((v) => !v)}>
            <span><b>Bắt buộc ảnh minh chứng</b><small>Nhân viên phải chụp ảnh mới hoàn thành được</small></span>
            <span className={`switch ${requirePhoto ? "on" : ""}`}><i /></span>
          </button>
        </section>

        <div className="action-bar">
          <button className="btn primary wide" disabled={busy || !title.trim() || (mode === "store" && pickedStores.length === 0)}>
            {busy ? "Đang lưu..." : editId ? "Lưu thay đổi" : mode === "store" ? (pickedStores.length > 1 ? `Giao cho ${pickedStores.length} cửa hàng` : "Giao cho cửa hàng") : selected.length > 1 ? `Giao cho ${selected.length} người` : "Giao việc"}
          </button>
        </div>
      </form>
    </Page>
  );
}
