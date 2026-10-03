import type {
  Analytics, Announcement, AnnouncementDetail, AppNotification, Assignee, CatalogProduct, FundEntry, FundReport,
  FundReportDetail, FundSuggest, MediaItem, Order, OrderDetail, OrderItem, OrderSummary, OpsSummary, StoreSummary,
  CareCampaign, OaStatus, StoreWithManagers, Task, TaskDetail, User,
} from "./types";

const BASE_URL: string = (import.meta.env.VITE_API_BASE_URL as string | undefined) || "https://api.bismart.id.vn";
const TOKEN_KEY = "bismart_token";

export const getToken = (): string => {
  try {
    return localStorage.getItem(TOKEN_KEY) || "";
  } catch {
    return "";
  }
};
export const setToken = (token: string) => {
  try {
    if (token) localStorage.setItem(TOKEN_KEY, token);
    else localStorage.removeItem(TOKEN_KEY);
  } catch {
    /* storage unavailable: session-only */
  }
};

const ERROR_VI: Record<string, string> = {
  "Photo proof is required to complete this task": "Việc này bắt buộc có ảnh minh chứng. Hãy thêm ảnh trước khi bấm Hoàn thành.",
  "Forbidden": "Bạn không có quyền thực hiện thao tác này.",
  "Unauthorized": "Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại.",
  "Invalid credentials": "Sai mã nhân viên hoặc mật khẩu.",
  "Task not found": "Không tìm thấy công việc (có thể đã bị xoá).",
  "Title is required": "Vui lòng nhập tiêu đề công việc.",
  "Assignee not found": "Không tìm thấy nhân viên được giao.",
  "Invalid status": "Trạng thái không hợp lệ.",
  "Invalid doers": "Danh sách nhân viên thực hiện không hợp lệ (chỉ chọn nhân viên của cửa hàng).",
  "Invalid priority or recurrence": "Mức ưu tiên hoặc lịch lặp không hợp lệ.",
  "Empty comment": "Nội dung trao đổi đang trống.",
  "file too large": "Ảnh quá lớn (tối đa 10MB).",
  "Zalo account already linked to another employee": "Tài khoản Zalo này đã liên kết với nhân viên khác.",
  "Store is required": "Vui lòng chọn cửa hàng.",
  "Invalid date": "Ngày không hợp lệ.",
  "Report date cannot be in the future": "Không thể chọn ngày trong tương lai.",
  "Invalid denomination count": "Số tờ không hợp lệ.",
  "Invalid amount": "Số tiền không hợp lệ.",
  "Report already approved": "Báo cáo ngày này đã được duyệt, không sửa được nữa.",
  "OA app is not configured": "Chưa cấu hình App ID / Secret Key của ứng dụng OA trên máy chủ (chạy VPS Ops → set_oa_env).",
  "Webhook not configured": "Webhook chưa được cấu hình.",
  "Report not found": "Không tìm thấy báo cáo.",
  "Only an admin can delete an approved report": "Báo cáo đã duyệt chỉ admin mới xoá được.",
  "Report is not awaiting review": "Báo cáo này đã được xử lý rồi.",
  "A note is required to reject a report": "Vui lòng nhập lý do cần đếm lại.",
  "Invalid decision": "Quyết định không hợp lệ.",
  "Invalid fund entry": "Khoản thu/chi chưa hợp lệ (cần số tiền lớn hơn 0).",
  "A reason is required": "Vui lòng nhập lý do thu/chi.",
  "Entry not found": "Không tìm thấy khoản thu/chi.",
  "At least one item is required": "Hãy thêm ít nhất một mặt hàng.",
  "Too many items": "Đơn có quá nhiều mặt hàng.",
  "Invalid quantity": "Số lượng không hợp lệ.",
  "Invalid item": "Mặt hàng không hợp lệ.",
  "Product not found": "Không tìm thấy sản phẩm.",
  "Product name is required": "Vui lòng nhập tên sản phẩm.",
  "Order not found": "Không tìm thấy đơn hàng.",
  "Order can no longer be edited": "Đơn đã được xử lý, không sửa được nữa.",
  "Order is not awaiting approval": "Đơn này không còn ở trạng thái chờ duyệt.",
  "Order cannot be marked as ordered": "Không thể chuyển đơn sang 'Đã đặt NCC'.",
  "Order cannot be cancelled": "Không thể huỷ đơn này.",
  "Order cannot be received": "Đơn này không thể nhận hàng.",
  "Invalid received quantity": "Số lượng nhận không hợp lệ.",
  "Items are required": "Chưa có số lượng nhận.",
  "Announcement not found": "Không tìm thấy thông báo (có thể đã bị xoá).",
  "Invalid reminder time": "Giờ nhắc không hợp lệ.",
  "Invalid deadline": "Hạn chót không hợp lệ.",
  "No recipients": "Không có người nhận phù hợp.",
  "Invalid export": "Loại báo cáo không hợp lệ.",
  "Link expired": "Liên kết tải đã hết hạn, hãy thử lại.",
};

export const viError = (msg: string): string => ERROR_VI[msg] || msg;

export class ApiError extends Error {
  constructor(public status: number, message: string, public code?: string) {
    super(message);
  }
}

let onUnauthorized: () => void = () => {};
export const setUnauthorizedHandler = (fn: () => void) => {
  onUnauthorized = fn;
};

async function request<T>(method: string, path: string, body?: unknown, isForm = false, keepSession = false): Promise<T> {
  const headers: Record<string, string> = {};
  const token = getToken();
  if (token) headers.Authorization = `Bearer ${token}`;
  if (body && !isForm) headers["Content-Type"] = "application/json";
  let res: Response;
  try {
    res = await fetch(`${BASE_URL}${path}`, {
      method,
      headers,
      body: body ? (isForm ? (body as FormData) : JSON.stringify(body)) : undefined,
    });
  } catch {
    throw new ApiError(0, "Không kết nối được máy chủ. Kiểm tra mạng và thử lại.");
  }
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    // A wrong current password also returns 401; only treat it as an expired session otherwise.
    if (res.status === 401 && token && !keepSession) onUnauthorized();
    throw new ApiError(res.status, viError(data.error || `Lỗi ${res.status}`), data.code);
  }
  return data as T;
}

export interface TaskInput {
  title: string;
  description: string;
  assigneeId: number | null;
  priority: string;
  dueAt: string | null;
  recurrence: string;
  requirePhoto: boolean;
}

export const api = {
  login: (username: string, password: string) =>
    request<{ token: string; user: User }>("POST", "/api/auth/login", { username, password }),
  zaloLogin: (accessToken: string) =>
    request<{ token: string; user: User }>("POST", "/api/auth/zalo-login", { accessToken }),
  zaloLink: (accessToken: string) => request<{ ok: boolean }>("POST", "/api/auth/zalo-link", { accessToken }),
  me: () => request<{ user: User }>("GET", "/api/auth/me"),
  changePassword: (currentPassword: string, newPassword: string) =>
    request<{ ok: boolean }>("POST", "/api/auth/change-password", { currentPassword, newPassword }, false, true),

  listTasks: () => request<{ tasks: Task[]; canManage: boolean }>("GET", "/api/tasks"),
  getTask: (id: number) => request<TaskDetail>("GET", `/api/tasks/${id}`),
  createTask: (input: TaskInput) => request<Task>("POST", "/api/tasks", input),
  updateTask: (id: number, input: Partial<TaskInput>) => request<Task>("PUT", `/api/tasks/${id}`, input),
  deleteTask: (id: number) => request<{ ok: boolean }>("DELETE", `/api/tasks/${id}`),
  setStatus: (id: number, status: string, note?: string, photoUrls?: string[], doerIds?: number[]) =>
    request<Task>("POST", `/api/tasks/${id}/status`, { status, note, photoUrls, ...(doerIds ? { doerIds } : {}) }),
  taskStores: () => request<{ stores: StoreWithManagers[] }>("GET", "/api/tasks/stores"),
  taskStaff: (id: number) => request<{ employees: Assignee[] }>("GET", `/api/tasks/${id}/staff`),
  addComment: (id: number, body: string) =>
    request<{ id: number }>("POST", `/api/tasks/${id}/comments`, { body }),
  summary: () => request<{ stores: StoreSummary[] }>("GET", "/api/tasks/summary"),
  notifications: () => request<{ items: AppNotification[]; unread: number }>("GET", "/api/notifications"),
  unreadCount: () => request<{ unread: number }>("GET", "/api/notifications/unread-count"),
  markNotificationsRead: (ids?: number[]) => request<{ unread: number }>("POST", "/api/notifications/read", ids ? { ids } : {}),
  analytics: (days: number, storeCode: string) =>
    request<Analytics>("GET", `/api/tasks/analytics?${new URLSearchParams({ days: String(days), storeCode })}`),
  assignees: () => request<{ employees: Assignee[] }>("GET", "/api/tasks/assignees"),

  // operations: cash fund
  fundSuggest: (storeCode: string, date: string) =>
    request<FundSuggest>("GET", `/api/fund/suggest?${new URLSearchParams({ storeCode, date })}`),
  fundReports: (q: Record<string, string> = {}) =>
    request<{ reports: FundReport[]; canManage: boolean }>("GET", `/api/fund/reports?${new URLSearchParams(q)}`),
  fundReport: (id: number) => request<FundReportDetail>("GET", `/api/fund/reports/${id}`),
  saveFundReport: (body: unknown) => request<FundReport>("POST", "/api/fund/reports", body),
  deleteFundReport: (id: number) => request<{ ok: boolean }>("DELETE", `/api/fund/reports/${id}`),
  reviewFundReport: (id: number, decision: "approve" | "reject", note: string) =>
    request<FundReport>("POST", `/api/fund/reports/${id}/review`, { decision, note }),
  fundMissing: (date: string) =>
    request<{ date: string; stores: { storeCode: string; storeName: string }[] }>("GET", `/api/fund/missing?date=${date}`),
  fundEntries: (storeCode: string, date: string) =>
    request<{ entries: FundEntry[] }>("GET", `/api/fund/entries?${new URLSearchParams({ storeCode, date })}`),
  addFundEntry: (body: unknown) => request<{ id: number }>("POST", "/api/fund/entries", body),
  updateFundEntry: (id: number, body: unknown) => request<{ ok: boolean }>("PUT", `/api/fund/entries/${id}`, body),
  deleteFundEntry: (id: number) => request<{ ok: boolean }>("DELETE", `/api/fund/entries/${id}`),

  // operations: purchase orders
  catalog: (q: string) => request<{ products: CatalogProduct[] }>("GET", `/api/orders/catalog?${new URLSearchParams({ q })}`),
  lastOrder: (storeCode: string) =>
    request<{ orderDate: string | null; items: OrderItem[] }>("GET", `/api/orders/last?${new URLSearchParams({ storeCode })}`),
  orders: (q: Record<string, string> = {}) =>
    request<{ orders: Order[]; canManage: boolean }>("GET", `/api/orders?${new URLSearchParams(q)}`),
  order: (id: number) => request<OrderDetail>("GET", `/api/orders/${id}`),
  createOrder: (body: unknown) => request<Order>("POST", "/api/orders", body),
  updateOrder: (id: number, body: unknown) => request<Order>("PUT", `/api/orders/${id}`, body),
  deleteOrder: (id: number) => request<{ ok: boolean }>("DELETE", `/api/orders/${id}`),
  setOrderStatus: (id: number, status: string) => request<Order>("POST", `/api/orders/${id}/status`, { status }),
  receiveOrder: (id: number, body: unknown) => request<Order>("POST", `/api/orders/${id}/receive`, body),
  ordersSummary: (date: string, statuses: string) =>
    request<OrderSummary>("GET", `/api/orders/summary?${new URLSearchParams({ date, statuses })}`),

  // operations: announcements
  announcements: () => request<{ announcements: Announcement[]; canManage: boolean }>("GET", "/api/announcements"),
  announcement: (id: number) => request<AnnouncementDetail>("GET", `/api/announcements/${id}`),
  createAnnouncement: (body: unknown) => request<Announcement>("POST", "/api/announcements", body),
  readAnnouncement: (id: number) => request<{ ok: boolean }>("POST", `/api/announcements/${id}/read`),
  updateAnnouncement: (id: number, body: unknown) => request<Announcement>("PUT", `/api/announcements/${id}`, body),
  deleteAnnouncement: (id: number) => request<{ ok: boolean }>("DELETE", `/api/announcements/${id}`),
  remindAnnouncement: (id: number) => request<{ sent: number }>("POST", `/api/announcements/${id}/remind`),
  announcementToTask: (id: number, body: unknown) => request<{ created: number }>("POST", `/api/announcements/${id}/to-task`, body),

  // operations: gallery, export, hub
  media: (q: Record<string, string> = {}) =>
    request<{ items: MediaItem[]; total: number }>("GET", `/api/media?${new URLSearchParams(q)}`),
  exportLink: (kind: "fund" | "orders", storeCode = "", from = "", to = "") =>
    request<{ path: string }>("POST", "/api/export-link", { kind, storeCode, from, to }),
  oaInfo: () => request<{ oaId: string }>("GET", "/api/zalo/oa-info"),
  oaStatus: () => request<OaStatus>("GET", "/api/zalo/oa-status"),
  oaConnect: () => request<{ url: string }>("POST", "/api/zalo/oa-connect", {}),
  careAudience: (period: string) => request<{ period: string; count: number; total: number; capped: boolean }>("GET", `/api/oa/care/audience?period=${period}`),
  careTest: (body: string, imageName: string) => request<{ ok: boolean; detail: string }>("POST", "/api/oa/care/test", { body, imageName }),
  careSend: (body: string, imageName: string, period: string) => request<{ id: number; total: number }>("POST", "/api/oa/care/send", { body, imageName, period }),
  careCampaigns: () => request<{ campaigns: CareCampaign[] }>("GET", "/api/oa/care/campaigns"),
  oaTest: () => request<{ ok: boolean; detail: string; target: string | null }>("POST", "/api/zalo/oa-test", {}),
  opsSummary: () => request<OpsSummary>("GET", "/api/ops/summary"),
  uploadPhoto: (file: File) => {
    const form = new FormData();
    form.append("file", file);
    return request<{ photoUrl: string }>("POST", "/api/tasks/upload-photo", form, true);
  },
};

/** Full-size photo, or a server-resized thumbnail when `width` is given (lists and grids). */
export const photoSrc = (name: string, width?: number) =>
  `${BASE_URL}/api/tasks/photo/${encodeURIComponent(name)}${width ? `?w=${width}` : ""}`;

export const absoluteUrl = (path: string) => `${BASE_URL}${path}`;
