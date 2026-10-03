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

export type NotificationKind =
  | "assigned" | "done" | "comment" | "cancelled" | "reopened" | "due_soon" | "overdue" | "info"
  | "fund_new" | "fund_diff" | "fund_review" | "fund_missing"
  | "order_new" | "order_status" | "order_short" | "order_received"
  | "announcement" | "ann_remind";

export interface AppNotification {
  id: number;
  kind: NotificationKind;
  title: string;
  body: string;
  taskId: number | null;
  link?: string | null;
  isRead: boolean;
  createdAt: string;
}

// ---------- operations: cash fund ----------
export type FundStatus = "submitted" | "approved" | "rejected";
export const FUND_DENOMS = [500000, 200000, 100000, 50000, 20000, 10000, 5000, 2000, 1000] as const;
export const FUND_STATUS_LABEL: Record<FundStatus, string> = { submitted: "Chờ duyệt", approved: "Đã duyệt", rejected: "Cần đếm lại" };

export interface FundEntry {
  id: number;
  kind: "in" | "out";
  amount: number;
  reason: string;
  photoUrls: string[];
  createdByName: string;
  canDelete?: boolean;
}

export interface FundReport {
  id: number;
  storeCode: string;
  storeName: string;
  reportDate: string;
  counts: Record<string, number>;
  otherAmount: number;
  cashTotal: number;
  systemBalance: number;
  difference: number;
  note: string;
  photoUrls: string[];
  status: FundStatus;
  submittedByName: string;
  reviewedByName: string;
  reviewedAt: string | null;
  reviewNote: string;
  createdAt: string;
}

export interface FundReportDetail extends FundReport {
  canReview: boolean;
  canEdit: boolean;
  entries: FundEntry[];
}

export interface FundSuggest {
  storeCode: string;
  date: string;
  opening: number;
  cashSales: number;
  entriesIn: number;
  entriesOut: number;
  suggested: number;
}

// ---------- operations: purchase orders ----------
export type OrderStatus = "submitted" | "approved" | "ordered" | "partial" | "delivered" | "cancelled";
export const ORDER_STATUS_LABEL: Record<OrderStatus, string> = {
  submitted: "Chờ duyệt",
  approved: "Đã duyệt",
  ordered: "Đã đặt NCC",
  partial: "Nhận thiếu",
  delivered: "Đã nhận đủ",
  cancelled: "Đã huỷ",
};

export interface OrderItem {
  id?: number;
  productId: number | null;
  productName: string;
  unit: string;
  qty: number;
  qtyReceived?: number | null;
  note: string;
}

export interface Order {
  id: number;
  storeCode: string;
  storeName: string;
  orderDate: string;
  status: OrderStatus;
  supplier: string;
  note: string;
  createdByName: string;
  receivedAt: string | null;
  receivedByName: string;
  receiptNote: string;
  receiptPhotos: string[];
  itemCount: number;
  totalQty: number;
  createdAt: string;
}

export interface OrderDetail extends Order {
  items: (OrderItem & { id: number })[];
  canManage: boolean;
  canEdit: boolean;
  canCancel: boolean;
  canReceive: boolean;
}

export interface CatalogProduct {
  id: number;
  name: string;
  unit: string;
  group: string;
}

export interface OrderSummary {
  date: string;
  orders: number;
  items: { productName: string; unit: string; total: number; byStore: { storeCode: string; storeName: string; qty: number }[] }[];
}

// ---------- operations: announcements ----------
export interface Announcement {
  id: number;
  title: string;
  body: string;
  imageUrls: string[];
  pinned: boolean;
  audienceStores: string[];
  audiencePositions: string[];
  remindAt: string | null;
  authorName: string;
  createdAt: string;
  isRead: boolean;
  canManage: boolean;
  audienceCount?: number;
  readCount?: number;
}

export interface Person {
  id: number;
  name: string;
  storeCode: string;
  position: string;
}

export interface AnnouncementDetail extends Announcement {
  readers?: (Person & { readAt: string })[];
  unread?: Person[];
}

// ---------- operations: gallery + hub ----------
export interface MediaItem {
  name: string;
  kind: "task" | "fund" | "order" | "announcement";
  title: string;
  storeCode: string;
  date: string;
  link: string;
}

export interface OpsSummary {
  canManage: boolean;
  storeCode: string;
  fund: { reportedToday: boolean; status: FundStatus | null; missingCount?: number; pendingReview?: number };
  orders: { pendingApproval: number; awaitingReceipt: number };
  board: { unread: number };
}
