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
