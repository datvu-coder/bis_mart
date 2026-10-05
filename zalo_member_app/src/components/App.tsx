import React, { useState } from "react";
import { App as ZMPApp, SnackbarProvider } from "zmp-ui";
import { AuthProvider, useAuth } from "../auth";
import { CartProvider } from "../cart";
import Icon, { IconName } from "./Icon";
import RegisterPage from "../pages/register";
import ShopPage from "../pages/shop";
import ProductPage from "../pages/product";
import CartPage from "../pages/cart";
import OrdersPage from "../pages/orders";
import ProfilePage from "../pages/profile";
import StoresPage from "../pages/stores";
import PurchasesPage from "../pages/purchases";

export type Tab = "shop" | "cart" | "orders" | "profile";
export type Route = { tab: Tab; sub?: "product" | "stores" | "purchases"; productId?: number };
export type Go = (r: Route) => void;

const TABS: { key: Tab; label: string; icon: IconName }[] = [
  { key: "shop", label: "Cửa hàng", icon: "home" },
  { key: "cart", label: "Giỏ hàng", icon: "cart" },
  { key: "orders", label: "Đơn hàng", icon: "receipt" },
  { key: "profile", label: "Cá nhân", icon: "user" },
];

function Shell() {
  const { member, loading, needsRegister } = useAuth();
  const [route, setRoute] = useState<Route>({ tab: "shop" });
  if (loading) return <div className="center-note">Đang tải...</div>;
  if (!member) {
    return needsRegister ? <RegisterPage /> : <div className="center-note">Vui lòng mở ứng dụng bằng Zalo để đăng nhập.</div>;
  }
  const go: Go = (r) => setRoute(r);
  return (
    <div className="app">
      <div className="screen">
        {route.tab === "shop" && !route.sub && <ShopPage go={go} />}
        {route.tab === "shop" && route.sub === "product" && <ProductPage id={route.productId!} go={go} />}
        {route.tab === "cart" && <CartPage go={go} />}
        {route.tab === "orders" && <OrdersPage go={go} />}
        {route.tab === "profile" && !route.sub && <ProfilePage go={go} />}
        {route.tab === "profile" && route.sub === "stores" && <StoresPage go={go} />}
        {route.tab === "profile" && route.sub === "purchases" && <PurchasesPage go={go} />}
      </div>
      <nav className="tabbar" aria-label="Điều hướng chính">
        {TABS.map((t) => (
          <button key={t.key} aria-current={route.tab === t.key ? "page" : undefined}
            className={route.tab === t.key ? "active" : ""} onClick={() => go({ tab: t.key })}>
            <Icon name={t.icon} strokeWidth={route.tab === t.key ? 2 : 1.8} />
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
          <CartProvider>
            <Shell />
          </CartProvider>
        </AuthProvider>
      </SnackbarProvider>
    </ZMPApp>
  );
}
