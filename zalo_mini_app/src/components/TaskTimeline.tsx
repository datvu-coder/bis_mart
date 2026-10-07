import React from "react";
import type { TaskDetail } from "../types";
import { formatDateTime, parseLocal, spanText } from "../utils";
import Icon from "./Icon";

interface Step {
  key: "created" | "started" | "done";
  label: string;
  at: string | null;
}

const stepsOf = (t: TaskDetail): Step[] => [
  { key: "created", label: "Giao việc", at: t.createdAt },
  { key: "started", label: "Bắt đầu làm", at: t.startedAt },
  { key: "done", label: "Hoàn thành", at: t.completedAt },
];

/** Vertical timeline of a task with the time spent in each step. */
export default function TaskTimeline({ task }: { task: TaskDetail }) {
  const steps = stepsOf(task);
  const cancelled = task.status === "cancelled";
  const closed = task.status === "done";
  // The step being waited on: 'started' while the task is todo, 'done' while it is doing.
  const currentKey = cancelled || closed ? null : task.status === "doing" ? "done" : "started";

  const late = closed && task.dueAt && task.completedAt
    ? parseLocal(task.completedAt).getTime() - parseLocal(task.dueAt).getTime()
    : null;

  return (
    <section className="panel">
      <div className="panel-head"><h3>Tiến độ thực hiện</h3></div>
      <ol className="otl">
        {steps.map((s, i) => {
          const happened = !!s.at;
          // Started time was not recorded (older task, or it jumped straight to done).
          const unrecorded = !happened && s.key === "started" && closed;
          const current = currentKey === s.key;
          const prev = [...steps.slice(0, i)].reverse().find((x) => x.at);
          const doing = current && s.key === "done" && task.startedAt;
          return (
            <li key={s.key} className={`${happened ? "done" : ""} ${current ? "current" : ""} ${unrecorded ? "skipped" : ""}`}>
              <span className="otl-dot">{happened ? <Icon name="check" size={13} /> : current ? <i className="pulse" /> : null}</span>
              <div className="otl-body">
                <b>{s.label}</b>
                {happened && <small>{formatDateTime(s.at)}{prev && s.at && s.key !== "created" ? ` · sau ${spanText(prev.at!, s.at)}` : ""}</small>}
                {s.key === "created" && task.assignedByName && <small>Bởi {task.assignedByName}</small>}
                {current && !doing && prev?.at && <small className="wait">Đang chờ {spanText(prev.at)}</small>}
                {doing && <small className="wait">Đang làm {spanText(task.startedAt!)}</small>}
                {unrecorded && <small>Không ghi nhận thời điểm bắt đầu</small>}
                {s.key === "done" && happened && task.doers.length > 0 && <small>{task.doers.map((d) => d.name).join(", ")}</small>}
                {s.key === "done" && happened && late !== null && (
                  <small className={late > 0 ? "late" : ""}>{late > 0 ? `Trễ ${spanText(task.dueAt!, task.completedAt)} so với hạn` : "Đúng hạn"}</small>
                )}
                {!happened && !current && !unrecorded && <small>Chưa thực hiện</small>}
              </div>
            </li>
          );
        })}
        {cancelled && (
          <li className="cancelled">
            <span className="otl-dot"><Icon name="close" size={13} /></span>
            <div className="otl-body"><b>Đã huỷ</b>{task.updatedAt && <small>{formatDateTime(task.updatedAt)}</small>}</div>
          </li>
        )}
      </ol>
      {closed && task.completedAt && (
        <div className="hint total">
          Tổng thời gian từ lúc giao đến khi hoàn thành: <b>{spanText(task.createdAt, task.completedAt)}</b>
          {task.startedAt && <> · thời gian làm: <b>{spanText(task.startedAt, task.completedAt)}</b></>}
        </div>
      )}
    </section>
  );
}
