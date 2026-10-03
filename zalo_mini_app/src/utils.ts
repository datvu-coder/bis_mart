import type { Task } from "./types";

const pad = (n: number) => String(n).padStart(2, "0");

/** The API stores Vietnam local time without a zone suffix; parse it as device-local. */
export const parseLocal = (iso: string): Date => new Date(iso.length === 10 ? `${iso}T00:00:00` : iso);

export const toInputValue = (iso: string | null) => (iso ? iso.slice(0, 16) : "");
export const fromInputValue = (v: string) => (v ? `${v}:00` : null);
export const toApiString = (d: Date) =>
  `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}:00`;

export const formatDateTime = (iso: string | null): string => {
  if (!iso) return "";
  const d = parseLocal(iso);
  return `${pad(d.getHours())}:${pad(d.getMinutes())} ${pad(d.getDate())}/${pad(d.getMonth() + 1)}`;
};

const startOfDay = (d: Date) => new Date(d.getFullYear(), d.getMonth(), d.getDate());
const dayDiff = (a: Date, b: Date) => Math.round((startOfDay(a).getTime() - startOfDay(b).getTime()) / 86400000);

export type DueTone = "overdue" | "today" | "soon" | "normal" | "done";
export interface DueInfo {
  text: string;
  tone: DueTone;
}

/** Human readable deadline ("Hôm nay 17:00", "Quá hạn 2 ngày") plus a tone for colouring. */
export function dueInfo(task: Pick<Task, "dueAt" | "status" | "overdue">): DueInfo | null {
  if (!task.dueAt) return null;
  const d = parseLocal(task.dueAt);
  const time = `${pad(d.getHours())}:${pad(d.getMinutes())}`;
  if (task.status === "done" || task.status === "cancelled") {
    return { text: `${pad(d.getDate())}/${pad(d.getMonth() + 1)} ${time}`, tone: "done" };
  }
  const diff = dayDiff(d, new Date());
  if (task.overdue) {
    const days = -diff;
    return { text: days <= 0 ? `Quá hạn ${time}` : `Quá hạn ${days} ngày`, tone: "overdue" };
  }
  if (diff === 0) return { text: `Hôm nay ${time}`, tone: "today" };
  if (diff === 1) return { text: `Ngày mai ${time}`, tone: "soon" };
  if (diff < 7) return { text: `${diff} ngày nữa · ${time}`, tone: "soon" };
  return { text: `${pad(d.getDate())}/${pad(d.getMonth() + 1)} ${time}`, tone: "normal" };
}

export const isDueToday = (t: Task) => !!t.dueAt && dayDiff(parseLocal(t.dueAt), new Date()) === 0;
export const isOpen = (t: Task) => t.status === "todo" || t.status === "doing";

export const initials = (name: string): string => {
  const parts = name.trim().split(/\s+/).filter(Boolean);
  if (parts.length === 0) return "?";
  return (parts.length === 1 ? parts[0].slice(0, 2) : parts[parts.length - 2][0] + parts[parts.length - 1][0]).toUpperCase();
};

export const firstName = (name: string) => name.trim().split(/\s+/).pop() || name;

const AVATAR_COLORS = ["#C1622B", "#4C7A5D", "#B98A2A", "#7A5C9E", "#3E7C9C", "#B14A3D"];
export const avatarColor = (name: string) => {
  let h = 0;
  for (const ch of name) h = (h * 31 + ch.charCodeAt(0)) >>> 0;
  return AVATAR_COLORS[h % AVATAR_COLORS.length];
};

export const greeting = (): string => {
  const h = new Date().getHours();
  return h < 11 ? "Chào buổi sáng" : h < 14 ? "Chào buổi trưa" : h < 18 ? "Chào buổi chiều" : "Chào buổi tối";
};

export const todayLabel = (): string => {
  const d = new Date();
  const days = ["Chủ nhật", "Thứ hai", "Thứ ba", "Thứ tư", "Thứ năm", "Thứ sáu", "Thứ bảy"];
  return `${days[d.getDay()]}, ${pad(d.getDate())}/${pad(d.getMonth() + 1)}/${d.getFullYear()}`;
};

/** Deadline presets for the assign form. */
export const quickDeadlines = (): { label: string; value: string }[] => {
  const at = (addDays: number, h: number) => {
    const d = new Date();
    d.setDate(d.getDate() + addDays);
    d.setHours(h, 0, 0, 0);
    return toApiString(d);
  };
  const toSunday = (7 - new Date().getDay()) % 7;
  return [
    { label: "Hôm nay 17:00", value: at(0, 17) },
    { label: "Ngày mai 10:00", value: at(1, 10) },
    { label: "Cuối tuần", value: at(toSunday, 18) },
    { label: "Tuần sau", value: at(7, 17) },
  ];
};

/** "5 phút trước", "2 giờ trước", ... for notification timestamps. */
export function timeAgo(iso: string): string {
  const d = parseLocal(iso);
  const diff = Date.now() - d.getTime();
  const min = Math.floor(diff / 60000);
  if (min < 1) return "Vừa xong";
  if (min < 60) return `${min} phút trước`;
  const h = Math.floor(min / 60);
  if (h < 24) return `${h} giờ trước`;
  const days = Math.floor(h / 24);
  if (days < 7) return `${days} ngày trước`;
  return `${pad(d.getDate())}/${pad(d.getMonth() + 1)}`;
}

/** 1250000 -> "1.250.000 đ" */
export const vnd = (n: number | null | undefined): string => `${Math.round(Number(n) || 0).toLocaleString("vi-VN")} đ`;

/** "2026-10-03" -> "03/10/2026" */
export const dmy = (iso: string): string => (iso ? `${iso.slice(8, 10)}/${iso.slice(5, 7)}/${iso.slice(0, 4)}` : "");

export const todayYmd = (): string => {
  const d = new Date();
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
};

/** Keep only digits, so money fields accept pasted "1.250.000". */
export const digits = (v: string): string => v.replace(/\D/g, "");
