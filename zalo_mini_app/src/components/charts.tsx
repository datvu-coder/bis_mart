import React, { useState } from "react";
import type { Tally } from "../types";

/** Status colours are reserved for state and always paired with a text label and count. */
export const STATUS_SEGMENTS: { key: keyof Pick<Tally, "done" | "doing" | "todo" | "overdue">; label: string; color: string }[] = [
  { key: "done", label: "Hoàn thành", color: "var(--success)" },
  { key: "doing", label: "Đang làm", color: "var(--warning)" },
  { key: "todo", label: "Chưa làm", color: "#cdbfae" },
  { key: "overdue", label: "Quá hạn", color: "var(--error)" },
];

/** Part-to-whole as one horizontal stacked bar (2px gaps), with a labelled legend underneath. */
export function StatusBar({ tally }: { tally: Tally }) {
  const total = tally.total || 1;
  return (
    <div className="status-viz">
      <div className="status-bar" role="img" aria-label={STATUS_SEGMENTS.map((s) => `${s.label} ${tally[s.key]}`).join(", ")}>
        {STATUS_SEGMENTS.filter((s) => tally[s.key] > 0).map((s) => (
          <span key={s.key} style={{ flexGrow: tally[s.key] / total, background: s.color }} />
        ))}
      </div>
      <ul className="status-legend">
        {STATUS_SEGMENTS.map((s) => (
          <li key={s.key}>
            <i style={{ background: s.color }} />
            <span>{s.label}</span>
            <b>{tally[s.key]}</b>
          </li>
        ))}
      </ul>
    </div>
  );
}

interface RateRow {
  key: string;
  label: string;
  sub: string;
  rate: number;
  warn?: boolean;
}

/** Horizontal bars of completion rate, one hue (magnitude), the value written on every row. */
export function RateBars({ rows, onPick }: { rows: RateRow[]; onPick?: (key: string) => void }) {
  return (
    <div className="rate-bars">
      {rows.map((r) => (
        <button key={r.key} className="rate-row" onClick={() => onPick?.(r.key)} disabled={!onPick}>
          <div className="rate-head">
            <span className="rate-label">{r.label}</span>
            <b>{r.rate}%</b>
          </div>
          <div className="rate-track" aria-hidden>
            <span style={{ width: `${Math.max(r.rate, r.rate > 0 ? 2 : 0)}%` }} />
          </div>
          <div className={`rate-sub ${r.warn ? "tone-overdue" : ""}`}>{r.sub}</div>
        </button>
      ))}
    </div>
  );
}

interface DayPoint {
  date: string;
  created: number;
  done: number;
}

const fmtDay = (iso: string) => `${iso.slice(8, 10)}/${iso.slice(5, 7)}`;

/** Columns per day: completed (accent) over created (muted context). Tap a day to read the exact numbers. */
export function DailyChart({ data }: { data: DayPoint[] }) {
  const [sel, setSel] = useState<number | null>(null);
  const W = 320;
  const H = 120;
  const padL = 24;
  const padB = 20;
  const padT = 8;
  const max = Math.max(1, ...data.map((d) => Math.max(d.created, d.done)));
  const niceMax = max <= 4 ? max : Math.ceil(max / 2) * 2;
  const plotW = W - padL;
  const plotH = H - padB - padT;
  const slot = plotW / data.length;
  const bw = Math.max(3, Math.min(14, slot - 4));
  const y = (v: number) => padT + plotH - (v / niceMax) * plotH;
  const idx = sel ?? data.length - 1;
  const cur = data[idx];

  return (
    <div className="daily-viz">
      <svg viewBox={`0 0 ${W} ${H}`} role="img" aria-label="Số việc giao mới và hoàn thành theo ngày">
        {[0, niceMax / 2, niceMax].map((v) => (
          <g key={v}>
            <line x1={padL} x2={W} y1={y(v)} y2={y(v)} className="grid-line" />
            <text x={padL - 6} y={y(v) + 3} textAnchor="end" className="axis-text">{Math.round(v)}</text>
          </g>
        ))}
        {data.map((d, i) => {
          const cx = padL + slot * i + slot / 2;
          const active = i === idx;
          return (
            <g key={d.date} onClick={() => setSel(i)} className="day-col">
              <rect x={padL + slot * i} y={0} width={slot} height={H - padB} fill="transparent" />
              {d.created > 0 && (
                <rect x={cx - bw / 2} y={y(d.created)} width={bw} height={padT + plotH - y(d.created)} rx={Math.min(3, bw / 2)} className={`bar-created ${active ? "on" : ""}`} />
              )}
              {d.done > 0 && (
                <rect x={cx - bw / 2 + bw * 0.2} y={y(d.done)} width={bw * 0.6} height={padT + plotH - y(d.done)} rx={Math.min(3, bw / 3)} className={`bar-done ${active ? "on" : ""}`} />
              )}
            </g>
          );
        })}
        {[0, Math.floor((data.length - 1) / 2), data.length - 1].map((i) => (
          <text key={i} x={padL + slot * i + slot / 2} y={H - 4} textAnchor={i === 0 ? "start" : i === data.length - 1 ? "end" : "middle"} className="axis-text">
            {fmtDay(data[i].date)}
          </text>
        ))}
      </svg>
      <div className="chart-legend">
        <span><i style={{ background: "#d9ccbb" }} /> Giao mới</span>
        <span><i style={{ background: "var(--primary)" }} /> Hoàn thành</span>
      </div>
      <div className="chart-readout">
        <b>{fmtDay(cur.date)}</b>
        <span>Giao mới <b>{cur.created}</b></span>
        <span>Hoàn thành <b>{cur.done}</b></span>
      </div>
    </div>
  );
}
