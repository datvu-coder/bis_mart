import React from "react";

export default function Skeleton({ count = 3 }: { count?: number }) {
  return (
    <div className="list">
      {Array.from({ length: count }).map((_, i) => (
        <div key={i} className="card skeleton">
          <div className="sk sk-title" />
          <div className="sk sk-line" />
          <div className="sk sk-line short" />
        </div>
      ))}
    </div>
  );
}

export function EmptyState({ icon, title, hint }: { icon: React.ReactNode; title: string; hint?: string }) {
  return (
    <div className="empty">
      <div className="empty-icon">{icon}</div>
      <b>{title}</b>
      {hint && <span>{hint}</span>}
    </div>
  );
}
