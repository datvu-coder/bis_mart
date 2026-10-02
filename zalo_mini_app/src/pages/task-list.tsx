import React, { useCallback, useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { Page } from "zmp-ui";
import { api } from "../api";
import BottomNav from "../components/BottomNav";
import TaskCard from "../components/TaskCard";
import { STATUS_LABEL, Task, TaskStatus } from "../types";

type Scope = "mine" | "store";
type Filter = "open" | TaskStatus;

export default function TaskListPage() {
  const nav = useNavigate();
  const [tasks, setTasks] = useState<Task[]>([]);
  const [canManage, setCanManage] = useState(false);
  const [scope, setScope] = useState<Scope>("mine");
  const [filter, setFilter] = useState<Filter>("open");
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

  const visible = tasks.filter((t) => (filter === "open" ? t.status === "todo" || t.status === "doing" : t.status === filter));
  const overdueCount = tasks.filter((t) => t.overdue).length;

  return (
    <Page className="page">
      <div className="hero small">
        <h1>Công việc</h1>
        {overdueCount > 0 && <p>⚠️ {overdueCount} việc quá hạn</p>}
      </div>

      {canManage && (
        <div className="segmented">
          <button className={scope === "mine" ? "active" : ""} onClick={() => setScope("mine")}>Của tôi</button>
          <button className={scope === "store" ? "active" : ""} onClick={() => setScope("store")}>Cả cửa hàng</button>
        </div>
      )}

      <div className="filters">
        {(["open", "done", "cancelled"] as Filter[]).map((f) => (
          <button key={f} className={filter === f ? "active" : ""} onClick={() => setFilter(f)}>
            {f === "open" ? "Cần làm" : STATUS_LABEL[f]}
          </button>
        ))}
      </div>

      <div className="list">
        {loading && <div className="center-note">Đang tải...</div>}
        {error && <div className="error">{error} <button className="link" onClick={load}>Thử lại</button></div>}
        {!loading && !error && visible.length === 0 && <div className="center-note">Không có công việc nào</div>}
        {visible.map((t) => (
          <TaskCard key={t.id} task={t} showAssignee={scope === "store"} />
        ))}
      </div>

      {canManage && (
        <button className="fab" onClick={() => nav("/new")}>＋ Giao việc</button>
      )}
      <BottomNav canManage={canManage} />
    </Page>
  );
}
