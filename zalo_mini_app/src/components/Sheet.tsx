import React, { useEffect } from "react";
import { createPortal } from "react-dom";
import Icon from "./Icon";

interface Props {
  open: boolean;
  title?: string;
  onClose: () => void;
  children: React.ReactNode;
}

/** Bottom sheet used for confirmations and pickers. */
export default function Sheet({ open, title, onClose, children }: Props) {
  useEffect(() => {
    if (!open) return;
    const prev = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => {
      document.body.style.overflow = prev;
    };
  }, [open]);
  if (!open) return null;
  // Rendered into <body>: inside a scrollable tab panel iOS creates a stacking context
  // (-webkit-overflow-scrolling) that would trap the sheet underneath the fixed bottom bar.
  return createPortal(
    <div className="sheet-backdrop" onClick={onClose}>
      <div className="sheet" onClick={(e) => e.stopPropagation()}>
        <div className="sheet-grip" />
        <div className="sheet-head">
          <b>{title}</b>
          <button className="icon-btn" onClick={onClose} aria-label="Đóng"><Icon name="close" size={18} /></button>
        </div>
        {children}
      </div>
    </div>,
    document.body
  );
}

interface ConfirmProps {
  open: boolean;
  title: string;
  message: string;
  confirmLabel: string;
  danger?: boolean;
  busy?: boolean;
  onConfirm: () => void;
  onClose: () => void;
}

export function ConfirmSheet({ open, title, message, confirmLabel, danger, busy, onConfirm, onClose }: ConfirmProps) {
  return (
    <Sheet open={open} title={title} onClose={onClose}>
      <p className="sheet-msg">{message}</p>
      <div className="sheet-actions">
        <button className="btn" onClick={onClose}>Quay lại</button>
        <button className={`btn ${danger ? "danger-solid" : "primary"}`} disabled={busy} onClick={onConfirm}>
          {confirmLabel}
        </button>
      </div>
    </Sheet>
  );
}
