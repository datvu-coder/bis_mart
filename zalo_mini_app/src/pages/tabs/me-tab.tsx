import React, { useEffect, useMemo, useState } from "react";
import { followOA, openWebview } from "zmp-sdk/apis";
import { useSnackbar } from "zmp-ui";
import { api } from "../../api";
import { useAuth } from "../../auth";
import Avatar from "../../components/Avatar";
import Icon from "../../components/Icon";
import MinimizeButton from "../../components/MinimizeButton";
import NotificationBell from "../../components/NotificationBell";
import Sheet, { ConfirmSheet } from "../../components/Sheet";
import { clearDataCache, clearOps, useOpsSummary } from "../../data";
import { OaStatus, Task } from "../../types";
import { isOpen } from "../../utils";

export default function MeTab({ tasks }: { tasks: Task[] }) {
  const { user, logout } = useAuth();
  const { openSnackbar } = useSnackbar();
  const [confirm, setConfirm] = useState(false);
  const [pwOpen, setPwOpen] = useState(false);
  const [cur, setCur] = useState("");
  const [next, setNext] = useState("");
  const [again, setAgain] = useState("");
  const [busy, setBusy] = useState(false);
  const [pwError, setPwError] = useState("");
  const ops = useOpsSummary();
  const [oaId, setOaId] = useState("");
  const [oaStatus, setOaStatus] = useState<OaStatus | null>(null);
  const [testing, setTesting] = useState(false);

  useEffect(() => { api.oaInfo().then((r) => setOaId(r.oaId)).catch(() => {}); }, []);
  useEffect(() => { if (ops?.isAdmin) api.oaStatus().then(setOaStatus).catch(() => {}); }, [ops?.isAdmin]);

  const follow = async () => {
    try {
      await followOA({ id: oaId });
      openSnackbar({ text: "Đã theo dõi OA. Bạn sẽ nhận thông báo quan trọng trên Zalo.", type: "success" });
      if (ops?.isAdmin) setTimeout(() => api.oaStatus().then(setOaStatus).catch(() => {}), 2500);
    } catch (e) {
      const code = (e as { code?: number })?.code;
      openSnackbar({ text: code === -201 ? "Bạn đã từ chối theo dõi OA" : "Không mở được trang theo dõi OA (chỉ chạy trong Zalo)", type: "error" });
    }
  };
  const connect = async () => {
    try {
      const { url } = await api.oaConnect();
      try {
        await openWebview({ url });
      } catch {
        window.open(url, "_blank");
      }
      setTimeout(() => api.oaStatus().then(setOaStatus).catch(() => {}), 15000);
    } catch (e) {
      openSnackbar({ text: e instanceof Error ? e.message : "Không bắt đầu được kết nối OA", type: "error" });
    }
  };
  const sendTest = async () => {
    setTesting(true);
    try {
      const r = await api.oaTest();
      openSnackbar({ text: r.ok ? "Đã gửi tin thử. Kiểm tra Zalo trên điện thoại." : `Zalo từ chối: ${r.detail}`, type: r.ok ? "success" : "error" });
    } catch (e) {
      openSnackbar({ text: e instanceof Error ? e.message : "Không gửi được", type: "error" });
    } finally {
      setTesting(false);
    }
  };

  const stats = useMemo(() => {
    const mine = tasks.filter((t) => user && String(t.assigneeId) === user.id);
    return { open: mine.filter(isOpen).length, overdue: mine.filter((t) => t.overdue).length, done: mine.filter((t) => t.status === "done").length };
  }, [tasks, user]);

  const name = user?.fullName || "";

  const closePw = () => { setPwOpen(false); setCur(""); setNext(""); setAgain(""); setPwError(""); };
  const submitPw = async () => {
    setPwError("");
    if (next.length < 4) return setPwError("Mật khẩu mới phải có ít nhất 4 ký tự.");
    if (next !== again) return setPwError("Mật khẩu nhập lại không khớp.");
    setBusy(true);
    try {
      await api.changePassword(cur, next);
      openSnackbar({ text: "Đã đổi mật khẩu", type: "success" });
      closePw();
    } catch (e) {
      setPwError(e instanceof Error ? e.message : "Không đổi được mật khẩu");
    } finally {
      setBusy(false);
    }
  };

  return (
    <>
      <header className="hero profile">
        <div className="hero-corner hero-actions"><NotificationBell /><MinimizeButton /></div>
        <Avatar name={name} size={56} />
        <div className="profile-info">
          <h1>{name}</h1>
          <div className="hero-chips">
            <span className="pill">{user?.employeeCode}</span>
            <span className="pill">{user?.position}</span>
          </div>
        </div>
      </header>

      <div className="stat-card three">
        <div className="stat static"><b>{stats.open}</b><span>Đang làm</span></div>
        <div className="stat static danger"><b>{stats.overdue}</b><span>Quá hạn</span></div>
        <div className="stat static success"><b>{stats.done}</b><span>Hoàn thành</span></div>
      </div>

      <div className="panel">
        <dl className="info">
          <div><Icon name="user" size={18} /><dt>Họ tên</dt><dd>{name}</dd></div>
          <div><Icon name="flag" size={18} /><dt>Chức vụ</dt><dd>{user?.position || "-"}</dd></div>
          <div><Icon name="pin" size={18} /><dt>Nơi làm việc</dt><dd>{user?.workLocation || "-"}</dd></div>
        </dl>
      </div>

      <div className="panel menu-panel">
        {oaId && <button className="menu-row" onClick={follow}><Icon name="bell" size={20} /> Nhận thông báo qua Zalo OA <Icon name="chevron" size={16} className="chev" /></button>}
        {ops?.isAdmin && oaStatus && (
          <>
            <button className="menu-row" onClick={connect}>
              <Icon name="refresh" size={20} /> {oaStatus.canRefresh ? "Kết nối lại Zalo OA" : "Kết nối Zalo OA"}
              <span className="row-meta">{oaStatus.employees.zaloLinked}/{oaStatus.employees.total} đã liên kết</span>
              <Icon name="chevron" size={16} className="chev" />
            </button>
            <button className="menu-row" disabled={testing || !oaStatus.configured} onClick={sendTest}>
              <Icon name="send" size={20} /> {testing ? "Đang gửi..." : "Gửi tin thử cho tôi"} <Icon name="chevron" size={16} className="chev" />
            </button>
          </>
        )}
        <button className="menu-row" onClick={() => setPwOpen(true)}><Icon name="edit" size={20} /> Đổi mật khẩu <Icon name="chevron" size={16} className="chev" /></button>
        <button className="menu-row danger" onClick={() => setConfirm(true)}><Icon name="logout" size={20} /> Đăng xuất</button>
      </div>
      <div className="foot-note">Bi'S MART · Công việc</div>

      <Sheet open={pwOpen} title="Đổi mật khẩu" onClose={closePw}>
        <label className="field"><span>Mật khẩu hiện tại</span><input type="password" value={cur} onChange={(e) => setCur(e.target.value)} autoComplete="current-password" /></label>
        <label className="field"><span>Mật khẩu mới</span><input type="password" value={next} onChange={(e) => setNext(e.target.value)} autoComplete="new-password" /></label>
        <label className="field"><span>Nhập lại mật khẩu mới</span><input type="password" value={again} onChange={(e) => setAgain(e.target.value)} autoComplete="new-password" /></label>
        {pwError && <div className="error inline">{pwError}</div>}
        <div className="sheet-actions">
          <button className="btn" onClick={closePw}>Huỷ</button>
          <button className="btn primary" disabled={busy || !cur || !next || !again} onClick={submitPw}>{busy ? "Đang lưu..." : "Lưu"}</button>
        </div>
      </Sheet>

      <ConfirmSheet
        open={confirm}
        title="Đăng xuất?"
        message="Bạn sẽ cần đăng nhập lại bằng mã nhân viên và mật khẩu."
        confirmLabel="Đăng xuất"
        danger
        onConfirm={() => { clearDataCache(); clearOps(); logout(); }}
        onClose={() => setConfirm(false)}
      />
    </>
  );
}
