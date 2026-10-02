import React from "react";
import { useLocation, useNavigate } from "react-router-dom";

interface Props {
  canManage: boolean;
}

export default function BottomNav({ canManage }: Props) {
  const nav = useNavigate();
  const { pathname } = useLocation();
  const items = [
    { path: "/", label: "Công việc", icon: "📋" },
    ...(canManage ? [{ path: "/summary", label: "Cửa hàng", icon: "🏬" }] : []),
    { path: "/me", label: "Cá nhân", icon: "👤" },
  ];
  return (
    <nav className="bottom-nav">
      {items.map((it) => (
        <button key={it.path} className={pathname === it.path ? "active" : ""} onClick={() => nav(it.path, { replace: true })}>
          <span>{it.icon}</span>
          {it.label}
        </button>
      ))}
    </nav>
  );
}
