import React from "react";
import Icon, { IconName } from "./Icon";

export type TabKey = "overview" | "tasks" | "ops" | "summary" | "me";

interface Props {
  tab: TabKey;
  opsBadge?: number;
  canManage: boolean;
  onChange: (tab: TabKey) => void;
}

export default function BottomNav({ tab, canManage, opsBadge, onChange }: Props) {
  const items: { key: TabKey; label: string; icon: IconName }[] = [
    { key: "overview", label: "Tổng quan", icon: "chart" },
    { key: "tasks", label: "Công việc", icon: "tasks" },
    { key: "ops", label: "Vận hành", icon: "grid" },
    ...(canManage ? [{ key: "summary" as TabKey, label: "Cửa hàng", icon: "store" as IconName }] : []),
    { key: "me", label: "Cá nhân", icon: "user" },
  ];
  return (
    <nav className="bottom-nav">
      {items.map((it) => (
        <button key={it.key} className={tab === it.key ? "active" : ""} onClick={() => onChange(it.key)}>
          <span className="nav-pill"><Icon name={it.icon} size={22} />{it.key === "ops" && !!opsBadge && <i className="nav-dot" />}</span>
          {it.label}
        </button>
      ))}
    </nav>
  );
}
