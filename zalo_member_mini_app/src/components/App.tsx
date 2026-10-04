import React from "react";
import { Route } from "react-router-dom";
import { AnimationRoutes, App as ZMPApp, SnackbarProvider, ZMPRouter } from "zmp-ui";
import HomePage from "../pages/home";

export default function App() {
  return (
    <ZMPApp>
      <SnackbarProvider>
        <ZMPRouter>
          <AnimationRoutes>
            <Route path="/" element={<HomePage />} />
          </AnimationRoutes>
        </ZMPRouter>
      </SnackbarProvider>
    </ZMPApp>
  );
}
