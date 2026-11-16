import React from "react";
import type { TabKey } from "../components/BottomNav";

type Props = {
  storeCount: number | null;
  canFollow: boolean;
  onFollow: () => void;
  onGo: (k: TabKey) => void;
};

export default function OverviewTab({ storeCount, canFollow, onFollow, onGo }: Props) {
  return (
    <>
      <header className="hero m-hero">
        <div className="m-brand">Bi'S MART</div>
        <h1>Xin chào bạn</h1>
        <div className="hero-note">Chào mừng đến với Bismart Member</div>
      </header>

      <section className="m-grid">
        <button className="m-card m-action" onClick={() => onGo("stores")}>
          <span className="m-ico">📍</span>
          <b>Tìm cửa hàng</b>
          <small>{storeCount != null ? `${storeCount} cửa hàng đang hoạt động` : "Đang tải..."}</small>
        </button>
        <button className="m-card m-action" onClick={onFollow} disabled={!canFollow}>
          <span className="m-ico">🔔</span>
          <b>Theo dõi OA</b>
          <small>Nhận ưu đãi và thông báo trên Zalo</small>
        </button>
        <div className="m-card m-action soon">
          <span className="m-ico">🪪</span>
          <b>Thẻ thành viên</b>
          <small>Sắp ra mắt</small>
          <i className="m-badge">Sắp ra mắt</i>
        </div>
        <div className="m-card m-action soon">
          <span className="m-ico">🎁</span>
          <b>Ưu đãi của tôi</b>
          <small>Sắp ra mắt</small>
          <i className="m-badge">Sắp ra mắt</i>
        </div>
      </section>

      <section className="panel m-about">
        <h2>Về Bi'S MART</h2>
        <p>Chuỗi cửa hàng sữa và dinh dưỡng cho mẹ và bé, với các thương hiệu DELIMIL, DELI, AUMIL, GOODLIFE.</p>
        <button className="btn wide" onClick={() => onGo("about")}>Xem thông tin liên hệ</button>
      </section>
    </>
  );
}
