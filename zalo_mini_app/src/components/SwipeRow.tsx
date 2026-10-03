import React, { useRef, useState } from "react";
import Icon from "./Icon";

interface Props {
  onEdit?: () => void;
  onDelete?: () => void;
  /** Rows inside a white panel: no rounded corners / extra margin. */
  inPanel?: boolean;
  children: React.ReactNode;
}

const ACTION_W = 84;
const OPEN_AT = 42;

// Only one row stays open at a time.
let closeOpenRow: (() => void) | null = null;

/** List row with swipe actions: swipe right to edit, swipe left to delete (only the actions that are provided). */
export default function SwipeRow({ onEdit, onDelete, inPanel, children }: Props) {
  const [x, setX] = useState(0);
  const [dragging, setDragging] = useState(false);
  const start = useRef<{ x: number; y: number; base: number } | null>(null);
  const horizontal = useRef<boolean | null>(null);
  const close = useRef(() => setX(0));
  close.current = () => setX(0);

  if (!onEdit && !onDelete) return <>{children}</>;

  const minX = onDelete ? -ACTION_W : 0;
  const maxX = onEdit ? ACTION_W : 0;
  const clamp = (v: number) => Math.max(minX, Math.min(maxX, v));

  const onTouchStart = (e: React.TouchEvent) => {
    const t = e.touches[0];
    start.current = { x: t.clientX, y: t.clientY, base: x };
    horizontal.current = null;
  };
  const onTouchMove = (e: React.TouchEvent) => {
    if (!start.current) return;
    const t = e.touches[0];
    const dx = t.clientX - start.current.x;
    const dy = t.clientY - start.current.y;
    if (horizontal.current === null) {
      if (Math.abs(dx) < 8 && Math.abs(dy) < 8) return;
      horizontal.current = Math.abs(dx) > Math.abs(dy);
      if (horizontal.current) {
        if (closeOpenRow && closeOpenRow !== close.current) closeOpenRow();
        setDragging(true);
      }
    }
    if (horizontal.current) setX(clamp(start.current.base + dx));
  };
  const onTouchEnd = () => {
    if (!start.current) return;
    const wasHorizontal = horizontal.current;
    start.current = null;
    horizontal.current = null;
    setDragging(false);
    if (!wasHorizontal) return;
    const next = x > OPEN_AT ? ACTION_W : x < -OPEN_AT ? -ACTION_W : 0;
    setX(next);
    closeOpenRow = next !== 0 ? close.current : closeOpenRow === close.current ? null : closeOpenRow;
  };

  // While open, a tap on the row only closes it.
  const onClickCapture = (e: React.MouseEvent) => {
    if (x !== 0) {
      e.preventDefault();
      e.stopPropagation();
      setX(0);
    }
  };

  const act = (fn?: () => void) => () => {
    setX(0);
    fn?.();
  };

  return (
    <div className={`swipe ${inPanel ? "in-panel" : ""}`}>
      {onEdit && (
        <button className="swipe-act edit" onClick={act(onEdit)} aria-label="Sửa">
          <Icon name="edit" size={20} /><span>Sửa</span>
        </button>
      )}
      {onDelete && (
        <button className="swipe-act del" onClick={act(onDelete)} aria-label="Xoá">
          <Icon name="trash" size={20} /><span>Xoá</span>
        </button>
      )}
      <div
        className={`swipe-front ${dragging ? "dragging" : ""}`}
        style={{ transform: `translateX(${x}px)` }}
        onTouchStart={onTouchStart}
        onTouchMove={onTouchMove}
        onTouchEnd={onTouchEnd}
        onTouchCancel={onTouchEnd}
        onClickCapture={onClickCapture}
      >
        {children}
      </div>
    </div>
  );
}
