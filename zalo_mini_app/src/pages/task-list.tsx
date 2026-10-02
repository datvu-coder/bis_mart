import React, { useCallback, useEffect, useMemo, useState } from "react";
import { useLocation, useNavigate } from "react-router-dom";
import { Page, useSnackbar } from "zmp-ui";
import { api } from "../api";
import { useAuth } from "../auth";
import BottomNav from "../components/BottomNav";
import Icon from "../components/Icon";
import Skeleton, { EmptyState } from "../components/Skeleton";
import TaskCard from "../components/TaskCard";
import { Task } from "../types";
import { firstName, greeting, isDueToday, isOpen, todayLabel } from "../utils";

type Scope = "mine" | "store";
type Filter = "open" | "today" | "overdue" | "done";

const SECTION_ORDER: { key: string; title: string }[] = [
  { key: "overdue", title: "Quá hạn" },
  { key: "today", title: "Hôm nay" },
  { key: "upcoming", title: "Sắp tới" },
  { key: "nodue", title: "Không có hạn" },
];

export default function TaskListPage() {
  const nav = useNavigate();
  const { user } = useAuth();
  const { openSnackbar } = useSnackbar();
  const presetStore = (useLocation().state as { storeCode?: string } | null)?.storeCode || "";
  const [tasks, setTasks] = useState<Task[]>([]);
  const [canManage, setCanManage] = useState(false);
  const [scope, setScope] = useState<Scope>(presetStore ? "store" : "mine");
  const [filter, setFilter] = useState<Filter>("open");
  const [store, setStore] = useState(presetStore);
  const [query, setQuery] = useState("");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  const load = useCallback(async () => {
    setLoading(true);
    setError("");
    try {
      const res = await api.listTasks(scope === "mine" ? { mine: "1" } : {});
      setTasks(res.tasks);
      setCanManage(res.canManage);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Không tải được dữ liệu");
    } finally {
      setLoading(false);
    }
  }, [scope]);

  useEffect(() => {
    load();
  }, [load]);

  const stores = useMemo(
    () => Array.from(new Set(tasks.map((t) => t.storeCode).filter(Boolean))).sort(),
    [tasks]
  );

  const scoped = useMemo(() => {
    const q = query.trim().toLowerCase();
    return tasks.filter(
      (t) =>
        (!store || t.storeCode === store) &&
        (!q || t.title.toLowerCase().includes(q) || t.assigneeName.toLowerCase().includes(q))
    );
  }, [tasks, store, query]);

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
    return SECTION_ORDER.map((s) => ({ ...s, items: visible.filter((t) => bucket(t) === s.key) })).filter((s) => s.items.length);
  }, [visible, filter]);

  const stat = (key: Filter, label: string, tone = "") => (
    <button className={`stat ${filter === key ? "active" : ""} ${tone}`} onClick={() => setFilter(key)}>
      <b>{counts[key]}</b>
      <span>{label}</span>
    </button>
  );

  return (
    <Page className="page">
      <header className="hero">
        <div className="hero-row">
          <div>
            <div className="hero-sub">{todayLabel()}</div>
            <h1>{greeting()}, {firstName(user?.fullName || "bạn")}</h1>
          </div>
          <button className="hero-btn" onClick={load} aria-label="Làm mới"><Icon name="refresh" size={20} /></button>
        </div>
        <div className="hero-note">
          {counts.overdue > 0
            ? `Có ${counts.overdue} việc quá hạn cần xử lý`
            : counts.open > 0 ? `Bạn còn ${counts.open} việc cần làm` : "Mọi việc đã xong, làm tốt lắm!"}
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
          <button className={scope === "mine" ? "active" : ""} onClick={() => { setScope("mine"); setStore(""); }}>Việc của tôi</button>
          <button className={scope === "store" ? "active" : ""} onClick={() => setScope("store")}>Cả cửa hàng</button>
        </div>
      )}

      <div className="toolbar">
        <label className="search">
          <Icon name="search" size={18} />
          <input placeholder="Tìm công việc, nhân viên..." value={query} onChange={(e) => setQuery(e.target.value)} />
          {query && <button onClick={() => setQuery("")} aria-label="Xoá"><Icon name="close" size={16} /></button>}
        </label>
        {scope === "store" && stores.length > 1 && (
          <select className="store-select" value={store} onChange={(e) => setStore(e.target.value)}>
            <option value="">Tất cả CH</option>
            {stores.map((s) => <option key={s} value={s}>{s}</option>)}
          </select>
        )}
      </div>

      {loading && <Skeleton />}
      {error && (
        <div className="error">
          {error} <button className="link" onClick={load}>Thử lại</button>
        </div>
      )}
      {!loading && !error && sections.length === 0 && (
        <EmptyState
          icon={<Icon name={filter === "done" ? "checkCircle" : "inbox"} size={34} />}
          title={query ? "Không tìm thấy công việc phù hợp" : "Chưa có công việc nào"}
          hint={canManage && !query ? "Bấm “Giao việc” để tạo công việc đầu tiên" : undefined}
        />
      )}
      {!loading && sections.map((s) => (
        <section key={s.key}>
          {s.title && <h3 className={`section-title ${s.key}`}>{s.title} <small>{s.items.length}</small></h3>}
          <div className="list">
            {s.items.map((t) => (
              <TaskCard
                key={t.id}
                task={t}
                showAssignee={scope === "store"}
                onChanged={load}
                onError={(text) => openSnackbar({ text, type: "error" })}
              />
            ))}
          </div>
        </section>
      ))}

      {canManage && (
        <button className="fab" onClick={() => nav("/new")}>
          <Icon name="plus" size={20} /> Giao việc
        </button>
      )}
      <BottomNav canManage={canManage} />
    </Page>
  );
}
