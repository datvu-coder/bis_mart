import { useCallback, useEffect, useState, useSyncExternalStore } from "react";
import { api } from "./api";
import type { Task } from "./types";

/** Shared data layer: a version counter that mutations bump, plus a cache so screens render instantly. */
const listeners = new Set<() => void>();
let version = 0;

export const bumpData = () => {
  version += 1;
  listeners.forEach((l) => l());
};

const subscribe = (l: () => void) => {
  listeners.add(l);
  return () => listeners.delete(l);
};

export const useDataVersion = () => useSyncExternalStore(subscribe, () => version);

let cache: { tasks: Task[]; canManage: boolean } | null = null;
export const clearDataCache = () => {
  cache = null;
};

export function useTaskData() {
  const v = useDataVersion();
  const [state, setState] = useState({
    tasks: cache?.tasks ?? ([] as Task[]),
    canManage: cache?.canManage ?? false,
    loading: !cache,
    error: "",
  });

  const load = useCallback(async () => {
    setState((s) => (cache ? { ...s, error: "" } : { ...s, loading: true, error: "" }));
    try {
      const res = await api.listTasks();
      cache = { tasks: res.tasks, canManage: res.canManage };
      setState({ tasks: res.tasks, canManage: res.canManage, loading: false, error: "" });
    } catch (e) {
      setState((s) => ({ ...s, loading: false, error: e instanceof Error ? e.message : "Không tải được dữ liệu" }));
    }
  }, []);

  useEffect(() => {
    load();
  }, [v, load]);

  return { ...state, reload: load };
}

/** Remembers filters across navigation (the Home screen is remounted when returning from detail). */
export const uiState = {
  tab: "overview" as "overview" | "tasks" | "summary" | "me",
  overviewDays: 30,
  overviewStore: "",
  scope: null as "mine" | "store" | null,
  filter: "open" as "open" | "today" | "overdue" | "done",
  store: "",
  assignee: "",
};

/** Unread notification count shared by every bell. Polled from one place (HomePage). */
let unread = 0;
const unreadListeners = new Set<() => void>();
export const setUnread = (n: number) => {
  if (n !== unread) {
    unread = n;
    unreadListeners.forEach((l) => l());
  }
};
const subscribeUnread = (l: () => void) => {
  unreadListeners.add(l);
  return () => unreadListeners.delete(l);
};
export const useUnreadCount = () => useSyncExternalStore(subscribeUnread, () => unread);

export async function refreshUnread() {
  try {
    setUnread((await api.unreadCount()).unread);
  } catch {
    /* keep the last known count */
  }
}

/** Mount once: refresh on any data change, every 45s, and whenever the app becomes visible again. */
export function useUnreadPolling() {
  const v = useDataVersion();
  useEffect(() => {
    refreshUnread();
  }, [v]);
  useEffect(() => {
    const id = setInterval(refreshUnread, 45000);
    const onVisible = () => {
      if (document.visibilityState === "visible") refreshUnread();
    };
    document.addEventListener("visibilitychange", onVisible);
    return () => {
      clearInterval(id);
      document.removeEventListener("visibilitychange", onVisible);
    };
  }, []);
}
