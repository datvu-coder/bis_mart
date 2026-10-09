import React from "react";
import { useNavigate } from "react-router-dom";
import Icon from "./Icon";

interface Props {
  title: string;
  /** Short badge beside the title (a date, a count). */
  chip?: string;
  right?: React.ReactNode;
  onBack?: () => void;
}

/**
 * Header of every pushed (non-tab) screen: one slim row with the title, an optional chip and the actions.
 * Zalo already draws a back arrow in its own bar, so ours only shows when the screen was opened first
 * (a deep link) and there is nothing to go back to, or when a screen passes its own onBack.
 */
export default function SubHero({ title, chip, right, onBack }: Props) {
  const nav = useNavigate();
  const showBack = !!onBack || window.history.length <= 1;
  return (
    <header className="hero slim">
      {showBack && <button className="hero-btn" onClick={onBack || (() => nav("/", { replace: true }))} aria-label="Quay lại"><Icon name="back" size={22} /></button>}
      <div className="hero-title">
        <h1>{title}</h1>
        {chip && <span className="hero-chip">{chip}</span>}
      </div>
      {right && <div className="hero-actions">{right}</div>}
    </header>
  );
}
