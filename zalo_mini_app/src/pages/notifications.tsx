import React, { useCallback, useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { Page } from "zmp-ui";
import { api } from "../api";
import Icon, { IconName } from "../components/Icon";
import Skeleton, { EmptyState } from "../components/Skeleton";
import { setUnread, useDataVersion } from "../data";
import type { AppNotification, NotificationKind } from "../types";
import { timeAgo } from "../utils";

const KIND: Record<NotificationKind, { icon: IconName; tone: string }> = {
  assigned: { icon: "tasks", tone: "primary" },
  done: { icon: "checkCircle", tone: "success" },
  comment: { icon: "message", tone: "info" },
  overdue: { icon: "alert", tone: "danger" },
  due_soon: { icon: "clock", tone: "warning" },
  cancelled: { icon: "close", tone: "muted" },
  reopened: { icon: "refresh", tone: "primary" },
  info: { icon: "bell", tone: "primary" },
  fund_new: { icon: "wallet", tone: "info" },
  fund_diff: { icon: "wallet", tone: "danger" },
  fund_review: { icon: "wallet", tone: "success" },
  fund_missing: { icon: "wallet", tone: "warning" },
  order_new: { icon: "cart", tone: "info" },
  order_status: { icon: "cart", tone: "primary" },
  order_short: { icon: "box", tone: "danger" },
  order_received: { icon: "box", tone: "success" },
  announcement: { icon: "megaphone", tone: "primary" },
  ann_remind: { icon: "megaphone", tone: "warning" },
};

export default function NotificationsPage() {
  const nav = useNavigate();
  const version = useDataVersion();
  const [items, setItems] = useState<AppNotification[] | null>(null);
  const [error, setError] = useState("");

  const load = useCallback(async () => {
    setError("");
    try {
      const res = await api.notifications();
      setItems(res.items);
      setUnread(res.unread);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Không tải được thông báo");
    }
  }, []);

  useEffect(() => {
    load();
  }, [load, version]);

  const unread = (items || []).filter((n) => !n.isRead).length;

  const open = async (n: AppNotification) => {
    if (!n.isRead) {
      setItems((cur) => (cur || []).map((x) => (x.id === n.id ? { ...x, isRead: true } : x)));
      api.markNotificationsRead([n.id]).then((r) => setUnread(r.unread)).catch(() => {});
    }
    if (n.link) nav(n.link);
    else if (n.taskId) nav(`/task/${n.taskId}`);
  };

  const readAll = async () => {
    setItems((cur) => (cur || []).map((x) => ({ ...x, isRead: true })));
    try {
      setUnread((await api.markNotificationsRead()).unread);
    } catch {
      load();
    }
  };

  return (
    <Page className="page">
      <header className="hero compact">
        <div className="hero-row">
          <button className="hero-btn" onClick={() => nav(-1)} aria-label="Quay lại"><Icon name="back" size={22} /></button>
          {unread > 0 && <button className="hero-text-btn" onClick={readAll}>Đánh dấu đã đọc tất cả</button>}
        </div>
        <h1 className="detail-title">Thông báo</h1>
        <div className="hero-note">{items ? (unread > 0 ? `${unread} thông báo chưa đọc` : "Bạn đã đọc hết thông báo") : "Đang tải..."}</div>
      </header>

      {error && <div className="error">{error} <button className="link" onClick={load}>Thử lại</button></div>}
      {!items && !error && <Skeleton count={4} />}
      {items && items.length === 0 && (
        <EmptyState icon={<Icon name="bell" size={34} />} title="Chưa có thông báo" hint="Việc mới, trao đổi và nhắc hạn sẽ hiện ở đây" />
      )}
      {items && items.length > 0 && (
        <div className="notif-list">
          {items.map((n) => {
            const k = KIND[n.kind] || KIND.info;
            return (
              <button key={n.id} className={`notif ${n.isRead ? "" : "unread"}`} onClick={() => open(n)}>
                <span className={`notif-icon tone-${k.tone}`}><Icon name={k.icon} size={20} /></span>
                <span className="notif-main">
                  <span className="notif-title">{n.title}</span>
                  <span className="notif-body">{n.body}</span>
                  <span className="notif-time">{timeAgo(n.createdAt)}</span>
                </span>
                {!n.isRead && <i className="notif-dot" aria-label="Chưa đọc" />}
              </button>
            );
          })}
        </div>
      )}
    </Page>
  );
}
