import React, { useEffect, useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import { useSnackbar } from "zmp-ui";
import { api } from "../../api";
import { useAuth } from "../../auth";
import Icon from "../../components/Icon";
import MinimizeButton from "../../components/MinimizeButton";
import NotificationBell from "../../components/NotificationBell";
import { ConfirmSheet } from "../../components/Sheet";
import Skeleton, { EmptyState } from "../../components/Skeleton";
import SwipeRow from "../../components/SwipeRow";
import TaskCard from "../../components/TaskCard";
import { bumpData, uiState } from "../../data";
import { Task } from "../../types";
import { firstName, greeting, isDueToday, isOpen, todayLabel } from "../../utils";

type Scope = "mine" | "store";
type Filter = "open" | "today" | "overdue" | "done";

interface Props {
  tasks: Task[];
  canManage: boolean;
  loading: boolean;
  error: string;
  reload: () => void;
  /** Set by the store summary tab to jump here pre-filtered. */
  jump: { store: string; nonce: number } | null;
}

const SECTIONS: { key: string; title: string }[] = [
  { key: "overdue", title: "Quá hạn" },
  { key: "today", title: "Hôm nay" },
  { key: "upcoming", title: "Sắp tới" },
  { key: "nodue", title: "Không có hạn" },
];

export default function TasksTab({ tasks, canManage, loading, error, reload, jump }: Props) {
  const nav = useNavigate();
  const [delTask, setDelTask] = useState<Task | null>(null);
  const removeTask = async () => {
    if (!delTask) return;
    try {
      await api.deleteTask(delTask.id);
      openSnackbar({ text: "Đã xoá công việc", type: "success" });
      bumpData();
    } catch (e) {
      openSnackbar({ text: e instanceof Error ? e.message : "Không xoá được", type: "error" });
    }
    setDelTask(null);
  };
  const { user } = useAuth();
  const { openSnackbar } = useSnackbar();
  const [scope, setScopeState] = useState<Scope>(uiState.scope ?? "mine");
  const [filter, setFilterState] = useState<Filter>(uiState.filter);
  const [store, setStoreState] = useState(uiState.store);
  const [assignee, setAssigneeState] = useState(uiState.assignee);
  const [query, setQuery] = useState("");

  const setScope = (v: Scope) => { uiState.scope = v; setScopeState(v); };
  const setFilter = (v: Filter) => { uiState.filter = v; setFilterState(v); };
  const setStore = (v: string) => { uiState.store = v; setStoreState(v); };
  const setAssignee = (v: string) => { uiState.assignee = v; setAssigneeState(v); };

  // Managers supervise the whole store, so that is their default view.
  useEffect(() => {
    if (uiState.scope === null && canManage) setScope("store");
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [canManage]);

  useEffect(() => {
    if (!jump) return;
    setScope("store");
    setStore(jump.store);
    setAssignee("");
    setFilter("open");
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [jump?.nonce]);

  const effectiveScope: Scope = canManage ? scope : "mine";
  const mine = useMemo(() => tasks.filter((t) => user && String(t.assigneeId) === user.id), [tasks, user]);
  const base = effectiveScope === "mine" ? mine : tasks;

  const stores = useMemo(() => Array.from(new Set(tasks.map((t) => t.storeCode).filter(Boolean))).sort(), [tasks]);
  const people = useMemo(() => {
    const map = new Map<number, string>();
    base.forEach((t) => t.assigneeId && t.assigneeName && map.set(t.assigneeId, t.assigneeName));
    return Array.from(map.entries()).slice(0, 15);
  }, [base]);

  const scoped = useMemo(() => {
    const q = query.trim().toLowerCase();
    return base.filter(
      (t) =>
        (!store || t.storeCode === store) &&
        (!assignee || String(t.assigneeId) === assignee) &&
        (!q || t.title.toLowerCase().includes(q) || t.assigneeName.toLowerCase().includes(q))
    );
  }, [base, store, assignee, query]);

  const counts = useMemo(
    () => ({
      open: scoped.filter(isOpen).length,
      today: scoped.filter((t) => isOpen(t) && isDueToday(t)).length,
      overdue: scoped.filter((t) => t.overdue).length,
      done: scoped.filter((t) => t.status === "done").length,
    }),
    [scoped]
  );

  const visible = useMemo(() => {
    switch (filter) {
      case "open": return scoped.filter(isOpen);
      case "today": return scoped.filter((t) => isOpen(t) && isDueToday(t));
      case "overdue": return scoped.filter((t) => t.overdue);
      default: return scoped.filter((t) => t.status === "done");
    }
  }, [scoped, filter]);

  const sections = useMemo(() => {
    if (filter === "done") return [{ key: "done", title: "", items: visible }];
    const bucket = (t: Task) => (t.overdue ? "overdue" : !t.dueAt ? "nodue" : isDueToday(t) ? "today" : "upcoming");
    return SECTIONS.map((s) => ({ ...s, items: visible.filter((t) => bucket(t) === s.key) })).filter((s) => s.items.length);
  }, [visible, filter]);

  const stat = (key: Filter, label: string, tone = "") => (
    <button className={`stat ${filter === key ? "active" : ""} ${tone}`} onClick={() => setFilter(key)}>
      <b>{counts[key]}</b>
      <span>{label}</span>
    </button>
  );

  return (
    <>
      <header className="hero">
        <div className="hero-row">
          <div>
            <div className="hero-sub">{todayLabel()}</div>
            <h1>{greeting()}, {firstName(user?.fullName || "bạn")}</h1>
          </div>
          <div className="hero-actions">
            <NotificationBell />
            <MinimizeButton />
          </div>
        </div>
      </header>

      <div className="stat-card">
        {stat("open", "Cần làm")}
        {stat("today", "Hôm nay")}
        {stat("overdue", "Quá hạn", "danger")}
        {stat("done", "Hoàn thành", "success")}
      </div>

      {canManage && (
        <div className="segmented">
          <button className={effectiveScope === "mine" ? "active" : ""} onClick={() => { setScope("mine"); setStore(""); setAssignee(""); }}>Việc của tôi</button>
          <button className={effectiveScope === "store" ? "active" : ""} onClick={() => setScope("store")}>Cả cửa hàng</button>
        </div>
      )}

      <div className="toolbar">
        <label className="search">
          <Icon name="search" size={18} />
          <input placeholder="Tìm công việc, nhân viên..." value={query} onChange={(e) => setQuery(e.target.value)} />
          {query && <button onClick={() => setQuery("")} aria-label="Xoá"><Icon name="close" size={16} /></button>}
        </label>
        {effectiveScope === "store" && stores.length > 1 && (
          <select className="store-select" value={store} onChange={(e) => setStore(e.target.value)}>
            <option value="">Tất cả CH</option>
            {stores.map((s) => <option key={s} value={s}>{s}</option>)}
          </select>
        )}
      </div>

      {effectiveScope === "store" && people.length > 1 && (
        <div className="chip-scroll">
          <button className={`chip ${assignee === "" ? "active" : ""}`} onClick={() => setAssignee("")}>Tất cả</button>
          {people.map(([id, name]) => (
            <button key={id} className={`chip ${assignee === String(id) ? "active" : ""}`} onClick={() => setAssignee(assignee === String(id) ? "" : String(id))}>
              {firstName(name)}
            </button>
          ))}
        </div>
      )}

      {loading && <Skeleton />}
      {error && <div className="error">{error} <button className="link" onClick={reload}>Thử lại</button></div>}
      {!loading && !error && sections.length === 0 && (
        <EmptyState
          icon={<Icon name={filter === "done" ? "checkCircle" : "inbox"} size={34} />}
          title={query || assignee || store ? "Không tìm thấy công việc phù hợp" : "Chưa có công việc nào"}
          hint={canManage && !query ? "Bấm nút + để giao việc mới" : undefined}
        />
      )}
      {!loading && sections.map((s) => (
        <section key={s.key}>
          {s.title && <h3 className={`section-title ${s.key}`}>{s.title} <small>{s.items.length}</small></h3>}
          <div className="list">
            {s.items.map((t) => (
              <SwipeRow key={t.id} onEdit={canManage ? () => nav(`/task/${t.id}/edit`) : undefined} onDelete={canManage ? () => setDelTask(t) : undefined}>
                <TaskCard task={t} showAssignee={effectiveScope === "store"} onError={(text) => openSnackbar({ text, type: "error" })} />
              </SwipeRow>
            ))}
          </div>
        </section>
      ))}
      <ConfirmSheet open={!!delTask} title="Xoá công việc?" message={delTask ? `"${delTask.title}" sẽ bị xoá cùng toàn bộ trao đổi và không khôi phục được.` : ""} confirmLabel="Xoá" danger onConfirm={removeTask} onClose={() => setDelTask(null)} />
    </>
  );
}
