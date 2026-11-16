import React from "react";

export type TabKey = "home" | "stores" | "about";

const TABS: { key: TabKey; label: string; icon: string }[] = [
  { key: "home", label: "Trang chủ", icon: "M3 11l9-8 9 8v9a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1z" },
  { key: "stores", label: "Cửa hàng", icon: "M12 2a7 7 0 0 0-7 7c0 5 7 13 7 13s7-8 7-13a7 7 0 0 0-7-7zm0 9.5A2.5 2.5 0 1 1 12 6.5a2.5 2.5 0 0 1 0 5z" },
  { key: "about", label: "Thông tin", icon: "M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20zm1 15h-2v-6h2zm0-8h-2V7h2z" },
];

export default function BottomNav({ active, onChange }: { active: TabKey; onChange: (k: TabKey) => void }) {
  return (
    <nav className="m-nav">
      {TABS.map((t) => (
        <button key={t.key} className={t.key === active ? "on" : ""} onClick={() => onChange(t.key)} aria-label={t.label}>
          <svg viewBox="0 0 24 24" width="22" height="22" fill="currentColor"><path d={t.icon} /></svg>
          <span>{t.label}</span>
        </button>
      ))}
    </nav>
  );
}
