export type TaskStatus = "todo" | "doing" | "done" | "cancelled";
export type TaskPriority = "low" | "normal" | "high" | "urgent";
export type Recurrence = "none" | "daily" | "weekly";

export interface User {
  id: string;
  fullName: string;
  employeeCode: string;
  position: string;
  workLocation: string;
}

export interface Task {
  id: number;
  title: string;
  description: string;
  storeCode: string;
  storeName: string;
  assigneeId: number | null;
  assigneeName: string;
  assignedById: number | null;
  assignedByName: string;
  priority: TaskPriority;
  status: TaskStatus;
  dueAt: string | null;
  overdue: boolean;
  recurrence: Recurrence;
  requirePhoto: boolean;
  photoUrls: string[];
  completedAt: string | null;
  completionNote: string;
  createdAt: string;
  updatedAt: string;
}

export interface TaskComment {
  id: number;
  body: string;
  createdAt: string;
  authorId: number | null;
  authorName: string;
}

export interface TaskDetail extends Task {
  canManage: boolean;
  comments: TaskComment[];
}

export interface Assignee {
  id: number;
  fullName: string;
  employeeCode: string;
  position: string;
  storeCode: string;
}

export interface StoreSummary {
  storeCode: string;
  storeName: string;
  todo: number;
  doing: number;
  done: number;
  overdue: number;
}

export const STATUS_LABEL: Record<TaskStatus, string> = {
  todo: "Chưa làm",
  doing: "Đang làm",
  done: "Hoàn thành",
  cancelled: "Đã huỷ",
};

export const PRIORITY_LABEL: Record<TaskPriority, string> = {
  low: "Thấp",
  normal: "Bình thường",
  high: "Cao",
  urgent: "Khẩn cấp",
};

export const RECURRENCE_LABEL: Record<Recurrence, string> = {
  none: "Một lần",
  daily: "Hằng ngày",
  weekly: "Hằng tuần",
};

export interface Tally {
  total: number;
  done: number;
  overdue: number;
  doing: number;
  todo: number;
  onTime: number;
  late: number;
  completionRate: number;
  onTimeRate: number | null;
}

export interface Analytics {
  days: number;
  scope: "team" | "mine";
  storeCode: string;
  stores: { storeCode: string; storeName: string }[];
  totals: Tally;
  byStore: (Tally & { storeCode: string; storeName: string })[];
  byAssignee: (Tally & { id: number; name: string; storeCode: string })[];
  daily: { date: string; created: number; done: number }[];
}

export type NotificationKind = "assigned" | "done" | "comment" | "cancelled" | "reopened" | "due_soon" | "overdue" | "info";

export interface AppNotification {
  id: number;
  kind: NotificationKind;
  title: string;
  body: string;
  taskId: number | null;
  isRead: boolean;
  createdAt: string;
}
