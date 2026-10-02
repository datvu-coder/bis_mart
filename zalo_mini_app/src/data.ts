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
  tab: "tasks" as "tasks" | "summary" | "me",
  scope: null as "mine" | "store" | null,
  filter: "open" as "open" | "today" | "overdue" | "done",
  store: "",
  assignee: "",
};
