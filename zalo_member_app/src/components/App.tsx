import React, { useState } from "react";
import { App as ZMPApp, SnackbarProvider } from "zmp-ui";
import { AuthProvider, useAuth } from "../auth";
import Icon, { IconName } from "./Icon";
import RegisterPage from "../pages/register";
import CardPage from "../pages/card";
import PurchasesPage from "../pages/purchases";
import StoresPage from "../pages/stores";
import ProfilePage from "../pages/profile";

type Tab = "card" | "purchases" | "stores" | "profile";

const TABS: { key: Tab; label: string; icon: IconName }[] = [
  { key: "card", label: "Thẻ", icon: "card" },
  { key: "purchases", label: "Lịch sử", icon: "receipt" },
  { key: "stores", label: "Cửa hàng", icon: "pin" },
  { key: "profile", label: "Cá nhân", icon: "user" },
];

function Shell() {
  const { member, loading, needsRegister } = useAuth();
  const [tab, setTab] = useState<Tab>("card");
  if (loading) return <div className="center-note">Đang tải...</div>;
  if (!member) {
    return needsRegister ? (
      <RegisterPage />
    ) : (
      <div className="center-note">Vui lòng mở ứng dụng bằng Zalo để đăng nhập.</div>
    );
  }
  return (
    <div className="page">
      {tab === "card" && <CardPage />}
      {tab === "purchases" && <PurchasesPage />}
      {tab === "stores" && <StoresPage />}
      {tab === "profile" && <ProfilePage />}
      <nav className="bottom-nav">
        {TABS.map((t) => (
          <button key={t.key} className={tab === t.key ? "active" : ""} onClick={() => setTab(t.key)}>
            <span className="nav-pill"><Icon name={t.icon} /></span>
            {t.label}
          </button>
        ))}
      </nav>
    </div>
  );
}

export default function App() {
  return (
    <ZMPApp>
      <SnackbarProvider>
        <AuthProvider>
          <Shell />
        </AuthProvider>
      </SnackbarProvider>
    </ZMPApp>
  );
}
