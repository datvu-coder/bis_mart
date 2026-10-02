import React from "react";
import { Route } from "react-router-dom";
import { AnimationRoutes, App as ZMPApp, SnackbarProvider, ZMPRouter } from "zmp-ui";
import { AuthProvider, useAuth } from "../auth";
import LoginPage from "../pages/login";
import TaskListPage from "../pages/task-list";
import TaskDetailPage from "../pages/task-detail";
import TaskFormPage from "../pages/task-form";
import SummaryPage from "../pages/summary";
import MePage from "../pages/me";

function Routes() {
  const { user, loading } = useAuth();
  if (loading) return <div className="center-note">Đang tải...</div>;
  if (!user) return <LoginPage />;
  return (
    <ZMPRouter>
      <AnimationRoutes>
        <Route path="/" element={<TaskListPage />} />
        <Route path="/task/:id" element={<TaskDetailPage />} />
        <Route path="/task/:id/edit" element={<TaskFormPage />} />
        <Route path="/new" element={<TaskFormPage />} />
        <Route path="/summary" element={<SummaryPage />} />
        <Route path="/me" element={<MePage />} />
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
