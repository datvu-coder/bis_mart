export const formatVnd = (n: number): string => `${Math.round(n).toLocaleString("vi-VN")}đ`;

export const formatDate = (iso: string | null | undefined): string => {
  const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(iso || "");
  return m ? `${m[3]}/${m[2]}/${m[1]}` : iso || "";
};

export const money = (n: number): string => `${Math.round(n).toLocaleString("vi-VN")} ₫`;

const TILES: [string, string][] = [
  ["#EFE3D4", "#6B4A2B"], ["#EBDDCF", "#6B3F1D"], ["#F3E3C4", "#7A4B06"],
  ["#F1E6B8", "#6B5A06"], ["#E9E0D3", "#4F4332"], ["#EBD9D2", "#7A3A2A"],
];
/** Stable placeholder colours + two-letter monogram for products without a photo. */
export const tileFor = (name: string, id: number): { bg: string; ink: string; mono: string } => {
  const [bg, ink] = TILES[id % TILES.length];
  const words = name.trim().split(/\s+/);
  const mono = (words.length > 1 ? words[0][0] + words[1][0] : name.slice(0, 2)).toUpperCase();
  return { bg, ink, mono };
};
