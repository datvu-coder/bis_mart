import React from "react";
import type { Order } from "../types";
import { formatDateTime, spanText } from "../utils";
import Icon from "./Icon";

interface Step {
  key: string;
  label: string;
  at: string | null;
}

/** Received, but not everything: the order is either waiting for the rest or was closed short. */
const isShort = (o: Order) => o.status === "partial" || o.status === "closed_short";

/** The four milestones of an order, in order. A missing time means the step has not happened (or was skipped). */
export const orderSteps = (o: Order): Step[] => [
  { key: "created", label: "Tạo đơn", at: o.createdAt },
  { key: "approved", label: "Duyệt đơn", at: o.approvedAt },
  { key: "ordered", label: "Đặt nhà cung cấp", at: o.orderedAt },
  { key: "received", label: isShort(o) ? "Nhận hàng (thiếu)" : "Nhận hàng", at: o.receivedAt },
];

/** Index of the last completed step, or -1. */
const lastDone = (steps: Step[]) => steps.reduce((acc, s, i) => (s.at ? i : acc), -1);

/** 100% only when everything arrived; a short order shows how much of the goods arrived (never 100). */
export const orderPercent = (o: Order): number => {
  if (o.status === "cancelled") return 0;
  if (o.status === "delivered") return 100;
  if (isShort(o)) return o.totalQty > 0 ? Math.min(99, Math.floor((o.receivedQty / o.totalQty) * 100)) : 0;
  const steps = orderSteps(o);
  return Math.round(((lastDone(steps) + 1) / steps.length) * 100);
};

/** Thin segmented bar for list cards. */
export function OrderProgress({ order }: { order: Order }) {
  const steps = orderSteps(order);
  const done = order.status === "cancelled" ? -1 : lastDone(steps);
  const short = isShort(order);
  return (
    <div className={`oprog ${order.status === "cancelled" ? "cancelled" : ""}`} aria-label={`Tiến độ ${orderPercent(order)}%`}>
      {steps.map((s, i) => <i key={s.key} className={`${i <= done ? "on" : ""} ${short && i === 3 ? "short" : ""}`} />)}
      <span>{order.status === "cancelled" ? "Đã huỷ" : `${orderPercent(order)}%`}</span>
    </div>
  );
}

/** Vertical timeline with timestamps and the time spent between steps. */
export default function OrderTimeline({ order }: { order: Order }) {
  const steps = orderSteps(order);
  const cancelled = order.status === "cancelled";
  const done = lastDone(steps);
  const pct = orderPercent(order);
  const nextIdx = done + 1;
  const short = isShort(order);
  const finished = !cancelled && order.status === "delivered";
  const waitingRest = order.status === "partial" && !!order.receivedAt;
  const closed = order.status === "closed_short" && !!order.closedAt;

  return (
    <section className="panel">
      <div className="panel-head">
        <h3>Tiến độ đơn hàng</h3>
        <span className={`count ${cancelled ? "bad" : ""}`}>{cancelled ? "Đã huỷ" : `${pct}%`}</span>
      </div>
      <div className={`oprog big ${cancelled ? "cancelled" : ""}`}>
        {steps.map((s, i) => <i key={s.key} className={`${i <= done ? "on" : ""} ${short && i === 3 ? "short" : ""}`} />)}
      </div>
      <ol className="otl">
        {steps.map((s, i) => {
          const happened = !!s.at;
          const skipped = !happened && i < done; // a later step is done, this one never happened
          const current = !cancelled && !finished && !short && i === nextIdx;
          const prev = [...steps.slice(0, i)].reverse().find((x) => x.at);
          return (
            <li key={s.key} className={`${happened ? "done" : ""} ${current ? "current" : ""} ${skipped ? "skipped" : ""} ${happened && short && i === 3 ? "warn" : ""}`}>
              <span className="otl-dot">{happened ? <Icon name="check" size={13} /> : current ? <i className="pulse" /> : null}</span>
              <div className="otl-body">
                <b>{s.label}</b>
                {happened && <small>{formatDateTime(s.at)}{prev && s.at ? ` · sau ${spanText(prev.at!, s.at)}` : ""}</small>}
                {skipped && <small>Bỏ qua</small>}
                {current && prev?.at && <small className="wait">Đang chờ {spanText(prev.at)}</small>}
                {!happened && !skipped && !current && <small>Chưa thực hiện</small>}
                {s.key === "created" && order.createdByName && <small>{order.createdByName}</small>}
                {s.key === "received" && happened && order.receivedByName && <small>{order.receivedByName}</small>}
              </div>
            </li>
          );
        })}
        {waitingRest && (
          <li className="current">
            <span className="otl-dot"><i className="pulse" /></span>
            <div className="otl-body"><b>Chờ phần hàng còn thiếu</b><small className="wait">Đang chờ {spanText(order.receivedAt!)}</small></div>
          </li>
        )}
        {closed && (
          <li className="done warn">
            <span className="otl-dot"><Icon name="check" size={13} /></span>
            <div className="otl-body">
              <b>Chốt đơn thiếu hàng</b>
              <small>{formatDateTime(order.closedAt)}{order.receivedAt ? ` · sau ${spanText(order.receivedAt, order.closedAt)}` : ""}</small>
              {order.closedByName && <small>{order.closedByName}</small>}
            </div>
          </li>
        )}
        {cancelled && (
          <li className="cancelled">
            <span className="otl-dot"><Icon name="close" size={13} /></span>
            <div className="otl-body"><b>Đã huỷ</b>{order.updatedAt && <small>{formatDateTime(order.updatedAt)}</small>}</div>
          </li>
        )}
      </ol>
      {finished && order.createdAt && order.receivedAt && (
        <div className="hint total">Tổng thời gian từ lúc tạo đến khi nhận hàng: <b>{spanText(order.createdAt, order.receivedAt)}</b></div>
      )}
    </section>
  );
}
