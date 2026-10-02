import React, { useState } from "react";
import { useNavigate } from "react-router-dom";
import { api } from "../api";
import { bumpData } from "../data";
import { useAuth } from "../auth";
import { PRIORITY_LABEL, RECURRENCE_LABEL, STATUS_LABEL, Task } from "../types";
import { dueInfo } from "../utils";
import Avatar from "./Avatar";
import Icon from "./Icon";

interface Props {
  task: Task;
  showAssignee: boolean;
  onError: (msg: string) => void;
}

export default function TaskCard({ task, showAssignee, onError }: Props) {
  const nav = useNavigate();
  const { user } = useAuth();
  const [busy, setBusy] = useState(false);
  const due = dueInfo(task);
  const isAssignee = user ? String(task.assigneeId) === user.id : false;

  const quick = async (status: string) => {
    setBusy(true);
    try {
      await api.setStatus(task.id, status);
      bumpData();
    } catch (e) {
      onError(e instanceof Error ? e.message : "Có lỗi xảy ra");
    } finally {
      setBusy(false);
    }
  };

  let action: React.ReactNode = null;
  if (isAssignee && task.status === "todo") {
    action = (
      <button className="mini-btn" disabled={busy} onClick={(e) => { e.stopPropagation(); quick("doing"); }}>
        <Icon name="play" size={13} /> Bắt đầu
      </button>
    );
  } else if (isAssignee && task.status === "doing") {
    action = task.requirePhoto ? (
      <button className="mini-btn primary" onClick={(e) => { e.stopPropagation(); nav(`/task/${task.id}`); }}>
        <Icon name="camera" size={13} /> Chụp ảnh
      </button>
    ) : (
      <button className="mini-btn primary" disabled={busy} onClick={(e) => { e.stopPropagation(); quick("done"); }}>
        <Icon name="check" size={13} /> Xong
      </button>
    );
  }

  return (
    <div className={`card prio-${task.priority} ${task.status === "done" ? "is-done" : ""}`} onClick={() => nav(`/task/${task.id}`)}>
      <div className="card-top">
        <div className="card-title">{task.title}</div>
        <span className={`badge status-${task.status}`}>{STATUS_LABEL[task.status]}</span>
      </div>
      {task.description && <div className="card-desc">{task.description}</div>}
      <div className="meta">
        {due && (
          <span className={`meta-item tone-${due.tone}`}>
            <Icon name={due.tone === "overdue" ? "alert" : "clock"} size={14} /> {due.text}
          </span>
        )}
        {task.priority !== "normal" && task.priority !== "low" && (
          <span className={`meta-item prio-text-${task.priority}`}><Icon name="flag" size={14} /> {PRIORITY_LABEL[task.priority]}</span>
        )}
        {task.recurrence !== "none" && (
          <span className="meta-item"><Icon name="repeat" size={14} /> {RECURRENCE_LABEL[task.recurrence]}</span>
        )}
        {task.requirePhoto && <span className="meta-item"><Icon name="camera" size={14} /> Cần ảnh</span>}
      </div>
      <div className="card-foot">
        <div className="who">
          {showAssignee && task.assigneeName ? (
            <><Avatar name={task.assigneeName} size={24} /><span>{task.assigneeName}</span></>
          ) : (
            task.storeCode && <><Icon name="pin" size={14} /><span>{task.storeName || task.storeCode}</span></>
          )}
          {showAssignee && !task.assigneeName && <span className="muted">Chưa giao</span>}
        </div>
        {action}
      </div>
    </div>
  );
}
