import React from "react";
import { useNavigate } from "react-router-dom";
import Icon from "./Icon";

interface Props {
  title: string;
  note?: string;
  right?: React.ReactNode;
  onBack?: () => void;
}

/** Hero used by every pushed (non-tab) screen: back button, optional actions, title and a one-line note. */
export default function SubHero({ title, note, right, onBack }: Props) {
  const nav = useNavigate();
  return (
    <header className="hero compact">
      <div className="hero-row">
        <button className="hero-btn" onClick={onBack || (() => nav(-1))} aria-label="Quay lại"><Icon name="back" size={22} /></button>
        {right && <div className="hero-actions">{right}</div>}
      </div>
      <h1 className="detail-title">{title}</h1>
      {note && <div className="hero-note">{note}</div>}
    </header>
  );
}
