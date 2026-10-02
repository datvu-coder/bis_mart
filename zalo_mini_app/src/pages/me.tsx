import React, { useEffect, useState } from "react";
import { Page } from "zmp-ui";
import { api } from "../api";
import { useAuth } from "../auth";
import BottomNav from "../components/BottomNav";

export default function MePage() {
  const { user, logout } = useAuth();
  const [canManage, setCanManage] = useState(false);

  useEffect(() => {
    api.listTasks({ mine: "1" }).then((r) => setCanManage(r.canManage)).catch(() => {});
  }, []);

  return (
    <Page className="page">
      <div className="hero small"><h1>Cá nhân</h1></div>
      <div className="panel">
        <h2>{user?.fullName}</h2>
        <dl className="kv">
          <dt>Mã NV</dt><dd>{user?.employeeCode}</dd>
          <dt>Chức vụ</dt><dd>{user?.position}</dd>
          <dt>Nơi làm việc</dt><dd>{user?.workLocation || "-"}</dd>
        </dl>
        <button className="btn danger" onClick={logout}>Đăng xuất</button>
      </div>
      <BottomNav canManage={canManage} />
    </Page>
  );
}
