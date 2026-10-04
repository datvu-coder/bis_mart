import React from "react";
import logo from "../assets/logo.png";

/** Bi'S MART brand tile (heart mark + wordmark). Source artwork lives in branding/. */
export default function Logo({ size = 64 }: { size?: number }) {
  return <img src={logo} width={size} height={size} alt="Bi'S MART" className="app-logo" />;
}
