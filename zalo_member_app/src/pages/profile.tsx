import React, { useEffect, useState } from "react";
import type { Go } from "../components/App";
import Icon from "../components/Icon";
import { QRCodeSVG } from "qrcode.react";
import { api } from "../api";
import { useAuth } from "../auth";
import type { Redemption, Reward } from "../types";
import { formatDate, money } from "../utils";

const TIER_CLASS: Record<string, string> = { "Thành viên": "silver", "Bạc": "silver", "Vàng": "gold", "Kim cương": "dark" };

export default function ProfilePage({ go }: { go: Go }) {
  const { member, setMember, logout } = useAuth();
  const [rewards, setRewards] = useState<Reward[]>([]);
  const [redemptions, setRedemptions] = useState<Redemption[]>([]);
  const [msg, setMsg] = useState("");
  const [editing, setEditing] = useState(false);
  const [name, setName] = useState(member?.fullName || "");
  const [birthday, setBirthday] = useState(member?.birthday || "");
  const [address, setAddress] = useState(member?.address || "");

  const load = () => api.rewards().then((r) => { setRewards(r.rewards); setRedemptions(r.redemptions); }).catch(() => {});
  useEffect(() => { load(); }, []);
  if (!member) return null;

  const redeem = async (r: Reward) => {
    setMsg("");
    try {
      setMember((await api.redeem(r.id)).member);
      await load();
    } catch (e) {
      setMsg(e instanceof Error ? e.message : "Đổi ưu đãi thất bại.");
    }
  };
  const save = async () => {
    setMsg("");
    try {
      setMember((await api.updateMe({ fullName: name, birthday, address })).member);
      setEditing(false);
    } catch (e) {
      setMsg(e instanceof Error ? e.message : "Lưu thất bại.");
    }
  };

  const cls = TIER_CLASS[member.tier] || "silver";
  const initials = member.fullName.trim().split(/\s+/).slice(-2).map((w) => w[0]).join("").toUpperCase();

  return (
    <>
      <header className="top who">
        <div className="avatar" role="img" aria-label="Ảnh đại diện">{initials}</div>
        <div className="stack tiny">
          <h1 className="h1 sm">{member.fullName}</h1>
          <span className="muted">{member.phone}</span>
        </div>
      </header>
      <div className="scroll">
        <section className={`mcard ${cls}`} aria-label="Thẻ thành viên">
          <svg aria-hidden="true" className="rings" width="260" height="260" viewBox="0 0 260 260" fill="none">
            {[120, 92, 64, 36].map((r) => <circle key={r} cx="130" cy="130" r={r} stroke="currentColor" strokeWidth="1" />)}
          </svg>
          <div className="row-between rel">
            <span className="brand">Bi'S MART</span>
            <span className="badge">Hạng {member.tier}</span>
          </div>
          <div className="rel pts-row">
            <div className="qr"><QRCodeSVG value={member.phone} size={64} /></div>
            <div className="stack">
              <span className="label dark">Điểm tích luỹ</span>
              <span className="pts">{member.points.toLocaleString("vi-VN")}</span>
            </div>
          </div>
          <div className="rel stack">
            <div className="track" role="progressbar" aria-valuemin={0} aria-valuemax={100} aria-valuenow={Math.round(member.tierProgress * 100)} aria-label="Tiến độ lên hạng">
              <div className="bar" style={{ width: `${Math.round(member.tierProgress * 100)}%` }} />
            </div>
            <div className="row-between small">
              <span>{member.nextTier ? `Còn ${Math.ceil(member.spentToNextTier / 10000).toLocaleString("vi-VN")} điểm để lên hạng ${member.nextTier}` : "Bạn đã đạt hạng cao nhất"}</span>
              <span className="code">{member.memberCode}</span>
            </div>
          </div>
        </section>

        {rewards.length > 0 && (
          <section className="stack" aria-label="Đổi điểm">
            <h2 className="h2">Đổi điểm lấy ưu đãi</h2>
            {rewards.map((r) => {
              const can = member.points >= r.points;
              return (
                <div key={r.id} className="box row-between">
                  <div className="stack tiny"><span className="pname">{r.name}</span><span className="muted">{r.points.toLocaleString("vi-VN")} điểm</span></div>
                  <button className={`redeem${can ? " on" : ""}`} disabled={!can} onClick={() => redeem(r)}>{can ? "Đổi" : "Chưa đủ điểm"}</button>
                </div>
              );
            })}
          </section>
        )}
        {msg && <p className="note error">{msg}</p>}

        {redemptions.length > 0 && (
          <section className="box tight" aria-label="Lịch sử đổi điểm">
            <h2 className="h2 pad">Lịch sử đổi điểm</h2>
            {redemptions.map((h, i) => (
              <div key={i} className="line">
                <div className="stack tiny"><span className="pname">Đổi {h.name}</span><span className="muted">{formatDate(h.date)}</span></div>
                <span className="delta neg">−{h.points.toLocaleString("vi-VN")}</span>
              </div>
            ))}
          </section>
        )}

        <section className="box tight menu">
          <button onClick={() => go({ tab: "profile", sub: "purchases" })}><span>Lịch sử mua tại cửa hàng</span><Icon name="chevron" size={18} strokeWidth={2} /></button>
          <button onClick={() => go({ tab: "profile", sub: "stores" })}><span>Hệ thống cửa hàng</span><Icon name="chevron" size={18} strokeWidth={2} /></button>
          <button onClick={() => setEditing(!editing)}><span>Thông tin cá nhân & địa chỉ</span><Icon name="chevron" size={18} strokeWidth={2} /></button>
        </section>

        {editing && (
          <section className="box stack">
            <label className="label" htmlFor="pn">Họ và tên</label>
            <input id="pn" className="field" value={name} onChange={(e) => setName(e.target.value)} maxLength={120} />
            <label className="label" htmlFor="pb">Ngày sinh</label>
            <input id="pb" className="field" type="date" value={birthday} onChange={(e) => setBirthday(e.target.value)} />
            <label className="label" htmlFor="pa">Địa chỉ giao hàng</label>
            <input id="pa" className="field" value={address} onChange={(e) => setAddress(e.target.value)} maxLength={300} />
            <button className="cta" onClick={save}>Lưu</button>
          </section>
        )}
        <p className="muted center">Tổng chi tiêu {money(member.totalSpent)} · {member.orderCount} đơn</p>
        <button className="outline" onClick={logout}>Đăng xuất</button>
      </div>
    </>
  );
}
