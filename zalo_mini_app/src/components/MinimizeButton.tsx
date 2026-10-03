import React from "react";
import { minimizeApp } from "zmp-sdk/apis";
import Icon from "./Icon";

/** One-tap "Thu nhỏ": sends the Mini App to Zalo's floating bubble (the stock menu needs two taps). */
export default function MinimizeButton() {
  const minimize = async () => {
    try {
      await minimizeApp();
    } catch {
      /* not running inside Zalo (browser preview): nothing to minimise */
    }
  };
  return (
    <button className="hero-btn" onClick={minimize} aria-label="Thu nhỏ ứng dụng" title="Thu nhỏ">
      <Icon name="minimize" size={20} />
    </button>
  );
}
