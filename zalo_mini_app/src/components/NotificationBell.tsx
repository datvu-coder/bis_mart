import React from "react";
import { useNavigate } from "react-router-dom";
import { useUnreadCount } from "../data";
import Icon from "./Icon";

/** Bell with a red unread badge; opens the notification list. */
export default function NotificationBell() {
  const nav = useNavigate();
  const count = useUnreadCount();
  return (
    <button className="hero-btn bell" onClick={() => nav("/notifications")} aria-label={count ? `Thông báo, ${count} chưa đọc` : "Thông báo"}>
      <Icon name="bell" size={21} />
      {count > 0 && <span className="badge-dot">{count > 99 ? "99+" : count}</span>}
    </button>
  );
}
