import React from "react";

const PATHS = {
  home: "M4 10l8-6 8 6v9a1 1 0 01-1 1H5a1 1 0 01-1-1zM10 20v-6h4v6",
  cart: "M3 4h2l2.2 11h10.6L20 7H6M9 18a1.5 1.5 0 110 3 1.5 1.5 0 010-3zM17 18a1.5 1.5 0 110 3 1.5 1.5 0 010-3z",
  receipt: "M7 3h10a1 1 0 011 1v17l-3-2-3 2-3-2-3 2V4a1 1 0 011-1zM9 8h6M9 12h6",
  user: "M12 12a4 4 0 100-8 4 4 0 000 8zM4 21c0-4 3.6-7 8-7s8 3 8 7",
  search: "M11 18a7 7 0 100-14 7 7 0 000 14zM20 20l-3.5-3.5",
  back: "M15 5l-7 7 7 7",
  chevron: "M9 5l7 7-7 7",
  pin: "M12 21s7-6.2 7-11.5A7 7 0 005 9.5C5 14.8 12 21 12 21zM12 12a2.5 2.5 0 100-5 2.5 2.5 0 000 5z",
  plus: "M12 5v14M5 12h14",
  minus: "M5 12h14",
  check: "M5 12.5l4.5 4.5L19 7.5",
} as const;

export type IconName = keyof typeof PATHS;

interface Props {
  name: IconName;
  size?: number;
  strokeWidth?: number;
}

export default function Icon({ name, size = 22, strokeWidth = 1.8 }: Props) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={strokeWidth}
      strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <path d={PATHS[name]} />
    </svg>
  );
}
