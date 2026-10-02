import React from "react";
import { photoSrc } from "../api";
import Icon from "./Icon";

export default function PhotoViewer({ name, onClose }: { name: string | null; onClose: () => void }) {
  if (!name) return null;
  return (
    <div className="viewer" onClick={onClose}>
      <button className="viewer-close" onClick={onClose} aria-label="Đóng"><Icon name="close" size={22} /></button>
      <img src={photoSrc(name)} alt="Ảnh minh chứng" onClick={(e) => e.stopPropagation()} />
    </div>
  );
}
