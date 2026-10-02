import React from "react";
import { useNavigate } from "react-router-dom";
import { PRIORITY_LABEL, RECURRENCE_LABEL, STATUS_LABEL, Task } from "../types";
import { formatDue } from "../utils";

export default function TaskCard({ task, showAssignee }: { task: Task; showAssignee: boolean }) {
  const nav = useNavigate();
  return (
    <div className={`card prio-${task.priority}`} onClick={() => nav(`/task/${task.id}`)}>
      <div className="card-title">{task.title}</div>
      <div className="chips">
        <span className={`chip status-${task.status}`}>{STATUS_LABEL[task.status]}</span>
        {task.overdue && <span className="chip overdue">Quá hạn</span>}
        {(task.priority === "high" || task.priority === "urgent") && (
          <span className="chip prio">{PRIORITY_LABEL[task.priority]}</span>
        )}
        {task.recurrence !== "none" && <span className="chip">🔁 {RECURRENCE_LABEL[task.recurrence]}</span>}
        {task.requirePhoto && <span className="chip">📷</span>}
      </div>
      <div className="meta">
        {task.dueAt && <span>Hạn: {formatDue(task.dueAt)}</span>}
        {showAssignee && task.assigneeName && <span>👤 {task.assigneeName}</span>}
        {task.storeCode && <span>{task.storeCode}</span>}
      </div>
    </div>
  );
}
