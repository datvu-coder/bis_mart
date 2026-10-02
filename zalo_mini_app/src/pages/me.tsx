import React, { useEffect, useState } from "react";
import { Page } from "zmp-ui";
import { api } from "../api";
import { useAuth } from "../auth";
import Avatar from "../components/Avatar";
import BottomNav from "../components/BottomNav";
import Icon from "../components/Icon";
import { ConfirmSheet } from "../components/Sheet";
import { isOpen } from "../utils";

export default function MePage() {
  const { user, logout } = useAuth();
  const [canManage, setCanManage] = useState(false);
  const [stats, setStats] = useState<{ open: number; done: number; overdue: number } | null>(null);
  const [confirm, setConfirm] = useState(false);

  useEffect(() => {
    api.listTasks({ mine: "1" })
      .then((r) => {
        setCanManage(r.canManage);
        setStats({
          open: r.tasks.filter(isOpen).length,
          done: r.tasks.filter((t) => t.status === "done").length,
          overdue: r.tasks.filter((t) => t.overdue).length,
        });
      })
      .catch(() => {});
  }, []);

  const name = user?.fullName || "";
  return (
    <Page className="page">
      <header className="hero profile">
        <Avatar name={name} size={72} />
        <h1>{name}</h1>
        <div className="hero-chips center">
          <span className="pill">{user?.employeeCode}</span>
          <span className="pill">{user?.position}</span>
        </div>
      </header>

      <div className="stat-card three">
        <div className="stat static"><b>{stats?.open ?? "–"}</b><span>Đang làm</span></div>
        <div className="stat static danger"><b>{stats?.overdue ?? "–"}</b><span>Quá hạn</span></div>
        <div className="stat static success"><b>{stats?.done ?? "–"}</b><span>Hoàn thành</span></div>
      </div>

      <div className="panel">
        <dl className="info">
          <div><Icon name="user" size={18} /><dt>Họ tên</dt><dd>{name}</dd></div>
          <div><Icon name="flag" size={18} /><dt>Chức vụ</dt><dd>{user?.position || "-"}</dd></div>
          <div><Icon name="pin" size={18} /><dt>Nơi làm việc</dt><dd>{user?.workLocation || "-"}</dd></div>
        </dl>
      </div>

      <div className="panel">
        <button className="menu-row danger" onClick={() => setConfirm(true)}>
          <Icon name="logout" size={20} /> Đăng xuất
        </button>
      </div>
      <div className="foot-note">Bi'S MART · Công việc</div>

      <ConfirmSheet
        open={confirm}
        title="Đăng xuất?"
        message="Bạn sẽ cần đăng nhập lại bằng mã nhân viên và mật khẩu."
        confirmLabel="Đăng xuất"
        danger
        onConfirm={logout}
        onClose={() => setConfirm(false)}
      />
      <BottomNav canManage={canManage} />
    </Page>
  );
}
