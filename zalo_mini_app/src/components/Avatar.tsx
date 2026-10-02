import React from "react";
import { avatarColor, initials } from "../utils";

export default function Avatar({ name, size = 28 }: { name: string; size?: number }) {
  return (
    <span
      className="avatar"
      style={{ width: size, height: size, fontSize: size * 0.4, background: avatarColor(name || "?") }}
      title={name}
    >
      {initials(name || "?")}
    </span>
  );
}
