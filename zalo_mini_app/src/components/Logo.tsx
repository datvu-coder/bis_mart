import React from "react";

/** App mark: a shopping bag with a check (retail + tasks). Same artwork as branding/logo.svg. */
export default function Logo({ size = 64 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 512 512" role="img" aria-label="Bi'S MART" className="app-logo">
      <defs>
        <linearGradient id="lg-bg" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stopColor="#E08445" />
          <stop offset="1" stopColor="#9A4A1E" />
        </linearGradient>
        <linearGradient id="lg-bag" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#FFFFFF" />
          <stop offset="1" stopColor="#F7E6D6" />
        </linearGradient>
        <clipPath id="lg-clip"><rect width="512" height="512" rx="116" /></clipPath>
      </defs>
      <rect width="512" height="512" rx="116" fill="url(#lg-bg)" />
      <circle cx="400" cy="112" r="150" fill="#FFFFFF" opacity="0.07" clipPath="url(#lg-clip)" />
      <path d="M204 236V188a52 52 0 0 1 104 0v48" fill="none" stroke="#FFFFFF" strokeWidth="24" strokeLinecap="round" />
      <path d="M148 214h216a22 22 0 0 1 22 20l14 148a28 28 0 0 1-28 31H140a28 28 0 0 1-28-31l14-148a22 22 0 0 1 22-20z" fill="url(#lg-bag)" />
      <path d="M190 322l48 48 90-102" fill="none" stroke="#C1622B" strokeWidth="32" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}
