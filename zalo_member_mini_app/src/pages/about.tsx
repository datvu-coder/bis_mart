import React from "react";

type Props = { canFollow: boolean; onFollow: () => void };

const CONTACT_EMAIL = "nguyenvudat1204@gmail.com";

export default function AboutTab({ canFollow, onFollow }: Props) {
  return (
    <>
      <header className="hero m-hero small">
        <h1>Thông tin</h1>
        <div className="hero-note">Bismart Member</div>
      </header>

      <section className="panel m-about">
        <h2>Bi'S MART</h2>
        <p>Chuỗi cửa hàng sữa và dinh dưỡng cho mẹ và bé. Các thương hiệu: DELIMIL, DELI, AUMIL, GOODLIFE.</p>
      </section>

      <section className="panel m-about">
        <h2>Nhận ưu đãi qua Zalo</h2>
        <p>Theo dõi Zalo OA của Bi'S MART để nhận khuyến mãi và thông báo mới.</p>
        <button className="btn primary wide" onClick={onFollow} disabled={!canFollow}>Theo dõi OA</button>
      </section>

      <section className="panel m-about">
        <h2>Liên hệ</h2>
        <p>Góp ý hoặc hỏi về dữ liệu cá nhân, vui lòng gửi email:</p>
        <a className="btn wide" href={`mailto:${CONTACT_EMAIL}`}>{CONTACT_EMAIL}</a>
      </section>

      <section className="panel m-about">
        <h2>Quyền riêng tư</h2>
        <p>Ứng dụng không yêu cầu đăng nhập và không lưu hồ sơ cá nhân. Vị trí chỉ dùng trên thiết bị để sắp xếp cửa hàng theo khoảng cách, không gửi về máy chủ.</p>
      </section>

      <div className="m-ver">Bismart Member · phiên bản 1.1</div>
    </>
  );
}
