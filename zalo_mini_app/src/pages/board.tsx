import React, { useCallback, useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { Page } from "zmp-ui";
import { api } from "../api";
import Icon from "../components/Icon";
import Skeleton, { EmptyState } from "../components/Skeleton";
import SubHero from "../components/SubHero";
import { useDataVersion } from "../data";
import { Announcement } from "../types";
import { timeAgo } from "../utils";

export default function BoardPage() {
  const nav = useNavigate();
  const version = useDataVersion();
  const [items, setItems] = useState<Announcement[] | null>(null);
  const [canManage, setCanManage] = useState(false);
  const [error, setError] = useState("");

  const load = useCallback(async () => {
    setError("");
    try {
      const res = await api.announcements();
      setItems(res.announcements);
      setCanManage(res.canManage);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Không tải được bảng tin");
    }
  }, []);
  useEffect(() => { load(); }, [load, version]);

  const unread = (items || []).filter((a) => !a.isRead).length;
  return (
    <Page className="page">
      <SubHero title="Bảng tin" note={items ? (unread ? `${unread} thông báo chưa đọc` : "Bạn đã đọc hết thông báo") : "Đang tải..."}
        right={canManage ? <button className="hero-btn" onClick={() => nav("/board/new")} aria-label="Đăng thông báo"><Icon name="plus" size={22} /></button> : undefined} />
      {error && <div className="error">{error} <button className="link" onClick={load}>Thử lại</button></div>}
      {!items && !error && <Skeleton count={3} />}
      {items && items.length === 0 && <EmptyState icon={<Icon name="megaphone" size={34} />} title="Chưa có thông báo" hint={canManage ? "Bấm + để đăng thông báo cho cửa hàng" : "Thông báo từ quản lý sẽ hiện ở đây"} />}
      <div className="list">
        {(items || []).map((a) => (
          <button key={a.id} className={`card ann-card ${a.isRead ? "" : "unread"}`} onClick={() => nav(`/board/${a.id}`)}>
            <div className="card-top">
              <span className="card-title">{a.pinned && <Icon name="flag" size={14} className="pin-ico" />} {a.title}</span>
              {!a.isRead && <i className="notif-dot" aria-label="Chưa đọc" />}
            </div>
            {a.body && <div className="card-desc">{a.body}</div>}
            <div className="meta">
              <span className="meta-item"><Icon name="user" size={14} /> {a.authorName}</span>
              <span className="meta-item"><Icon name="clock" size={14} /> {timeAgo(a.createdAt)}</span>
              {a.imageUrls.length > 0 && <span className="meta-item"><Icon name="image" size={14} /> {a.imageUrls.length}</span>}
            </div>
            {a.canManage && a.audienceCount != null && (
              <div className="read-bar" title="Đã đọc">
                <i style={{ width: `${a.audienceCount ? Math.round(((a.readCount || 0) / a.audienceCount) * 100) : 0}%` }} />
                <span>Đã đọc {a.readCount || 0}/{a.audienceCount}</span>
              </div>
            )}
          </button>
        ))}
      </div>
    </Page>
  );
}
