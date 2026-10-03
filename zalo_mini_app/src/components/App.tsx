import React from "react";
import { Route } from "react-router-dom";
import { AnimationRoutes, App as ZMPApp, SnackbarProvider, ZMPRouter } from "zmp-ui";
import { AuthProvider, useAuth } from "../auth";
import LoginPage from "../pages/login";
import HomePage from "../pages/home";
import NotificationsPage from "../pages/notifications";
import TaskDetailPage from "../pages/task-detail";
import TaskFormPage from "../pages/task-form";
import FundPage from "../pages/fund";
import FundFormPage from "../pages/fund-form";
import FundDetailPage from "../pages/fund-detail";
import OrdersPage from "../pages/orders";
import OrderFormPage from "../pages/order-form";
import OrderDetailPage from "../pages/order-detail";
import BoardPage from "../pages/board";
import BoardFormPage from "../pages/board-form";
import BoardDetailPage from "../pages/board-detail";
import GalleryPage from "../pages/gallery";

function Routes() {
  const { user, loading } = useAuth();
  if (loading) return <div className="center-note">Đang tải...</div>;
  if (!user) return <LoginPage />;
  return (
    <ZMPRouter>
      <AnimationRoutes>
        <Route path="/" element={<HomePage />} />
        <Route path="/task/:id" element={<TaskDetailPage />} />
        <Route path="/task/:id/edit" element={<TaskFormPage />} />
        <Route path="/new" element={<TaskFormPage />} />
        <Route path="/notifications" element={<NotificationsPage />} />
        <Route path="/fund" element={<FundPage />} />
        <Route path="/fund/new" element={<FundFormPage />} />
        <Route path="/fund/:id" element={<FundDetailPage />} />
        <Route path="/orders" element={<OrdersPage />} />
        <Route path="/orders/new" element={<OrderFormPage />} />
        <Route path="/orders/:id" element={<OrderDetailPage />} />
        <Route path="/orders/:id/edit" element={<OrderFormPage />} />
        <Route path="/board" element={<BoardPage />} />
        <Route path="/board/new" element={<BoardFormPage />} />
        <Route path="/board/:id" element={<BoardDetailPage />} />
        <Route path="/board/:id/edit" element={<BoardFormPage />} />
        <Route path="/gallery" element={<GalleryPage />} />
      </AnimationRoutes>
    </ZMPRouter>
  );
}

export default function App() {
  return (
    <ZMPApp>
      <SnackbarProvider>
        <AuthProvider>
          <Routes />
        </AuthProvider>
      </SnackbarProvider>
    </ZMPApp>
  );
}
