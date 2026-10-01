import type { Assignee, StoreSummary, Task, TaskDetail, User } from "./types";

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

export class ApiError extends Error {
  constructor(public status: number, message: string, public code?: string) {
    super(message);
  }
}

let onUnauthorized: () => void = () => {};
export const setUnauthorizedHandler = (fn: () => void) => {
  onUnauthorized = fn;
};

async function request<T>(method: string, path: string, body?: unknown, isForm = false): Promise<T> {
  const headers: Record<string, string> = {};
  const token = getToken();
  if (token) headers.Authorization = `Bearer ${token}`;
  if (body && !isForm) headers["Content-Type"] = "application/json";
  const res = await fetch(`${BASE_URL}${path}`, {
    method,
    headers,
    body: body ? (isForm ? (body as FormData) : JSON.stringify(body)) : undefined,
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    if (res.status === 401 && token) onUnauthorized();
    throw new ApiError(res.status, data.error || `Lỗi ${res.status}`, data.code);
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

  listTasks: (params: Record<string, string> = {}) =>
    request<{ tasks: Task[]; canManage: boolean }>("GET", `/api/tasks?${new URLSearchParams(params)}`),
  getTask: (id: number) => request<TaskDetail>("GET", `/api/tasks/${id}`),
  createTask: (input: TaskInput) => request<Task>("POST", "/api/tasks", input),
  updateTask: (id: number, input: Partial<TaskInput>) => request<Task>("PUT", `/api/tasks/${id}`, input),
  deleteTask: (id: number) => request<{ ok: boolean }>("DELETE", `/api/tasks/${id}`),
  setStatus: (id: number, status: string, note?: string, photoUrls?: string[]) =>
    request<Task>("POST", `/api/tasks/${id}/status`, { status, note, photoUrls }),
  addComment: (id: number, body: string) =>
    request<{ id: number }>("POST", `/api/tasks/${id}/comments`, { body }),
  summary: () => request<{ stores: StoreSummary[] }>("GET", "/api/tasks/summary"),
  assignees: () => request<{ employees: Assignee[] }>("GET", "/api/tasks/assignees"),
  uploadPhoto: (file: File) => {
    const form = new FormData();
    form.append("file", file);
    return request<{ photoUrl: string }>("POST", "/api/tasks/upload-photo", form, true);
  },
};

export const photoSrc = (name: string) => `${BASE_URL}/api/tasks/photo/${encodeURIComponent(name)}`;
