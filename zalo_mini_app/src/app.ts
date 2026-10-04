import "./boot";
import React from "react";
import { createRoot } from "react-dom/client";
import "zmp-ui/zaui.css";
import "./css/app.css";
import App from "./components/App";

createRoot(document.getElementById("app")!).render(React.createElement(App));
