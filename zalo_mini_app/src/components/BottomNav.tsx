import React from "react";
import { useLocation, useNavigate } from "react-router-dom";
import Icon, { IconName } from "./Icon";

interface Props {
  canManage: boolean;
}

export default function BottomNav({ canManage }: Props) {
  const nav = useNavigate();
  const { pathname } = useLocation();
  const items: { path: string; label: string; icon: IconName }[] = [
    { path: "/", label: "Công việc", icon: "tasks" },
    ...(canManage ? [{ path: "/summary", label: "Cửa hàng", icon: "store" as IconName }] : []),
    { path: "/me", label: "Cá nhân", icon: "user" },
  ];
  return (
    <nav className="bottom-nav">
      {items.map((it) => (
        <button key={it.path} className={pathname === it.path ? "active" : ""} onClick={() => nav(it.path, { replace: true })}>
          <span className="nav-pill"><Icon name={it.icon} size={22} /></span>
          {it.label}
        </button>
      ))}
    </nav>
  );
}
