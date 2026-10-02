import React from "react";
import { Route } from "react-router-dom";
import { AnimationRoutes, App as ZMPApp, SnackbarProvider, ZMPRouter } from "zmp-ui";
import { AuthProvider, useAuth } from "../auth";
import LoginPage from "../pages/login";
import HomePage from "../pages/home";
import NotificationsPage from "../pages/notifications";
import TaskDetailPage from "../pages/task-detail";
import TaskFormPage from "../pages/task-form";

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
