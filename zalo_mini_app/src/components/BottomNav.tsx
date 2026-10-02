import React from "react";
import Icon, { IconName } from "./Icon";

export type TabKey = "overview" | "tasks" | "summary" | "me";

interface Props {
  tab: TabKey;
  canManage: boolean;
  onChange: (tab: TabKey) => void;
}

export default function BottomNav({ tab, canManage, onChange }: Props) {
  const items: { key: TabKey; label: string; icon: IconName }[] = [
    { key: "overview", label: "Tổng quan", icon: "chart" },
    { key: "tasks", label: "Công việc", icon: "tasks" },
    ...(canManage ? [{ key: "summary" as TabKey, label: "Cửa hàng", icon: "store" as IconName }] : []),
    { key: "me", label: "Cá nhân", icon: "user" },
  ];
  return (
    <nav className="bottom-nav">
      {items.map((it) => (
        <button key={it.key} className={tab === it.key ? "active" : ""} onClick={() => onChange(it.key)}>
          <span className="nav-pill"><Icon name={it.icon} size={22} /></span>
          {it.label}
        </button>
      ))}
    </nav>
  );
}
