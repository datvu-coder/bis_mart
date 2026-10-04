import React from "react";
import { QRCodeSVG } from "qrcode.react";
import { useAuth } from "../auth";
import { formatVnd } from "../utils";

export default function CardPage() {
  const { member } = useAuth();
  if (!member) return null;
  return (
    <div>
      <div className="hero">
        <p className="muted-light">Xin chào,</p>
        <h1>{member.fullName}</h1>
        <span className="tier-badge">{member.tier}</span>
      </div>
      <div className="card member-card">
        <QRCodeSVG value={member.phone} size={168} />
        <div className="member-code">{member.memberCode}</div>
        <p className="muted">Đưa mã này cho nhân viên khi thanh toán để tích điểm.</p>
      </div>
      <div className="card stats">
        <div><strong>{member.points.toLocaleString("vi-VN")}</strong><span>Điểm tích lũy</span></div>
        <div><strong>{member.orderCount}</strong><span>Đơn hàng</span></div>
        <div><strong>{formatVnd(member.totalSpent)}</strong><span>Tổng chi tiêu</span></div>
      </div>
      {member.nextTier && (
        <div className="card">
          Chi tiêu thêm <strong>{formatVnd(member.spentToNextTier)}</strong> để lên hạng <strong>{member.nextTier}</strong>.
        </div>
      )}
    </div>
  );
}
