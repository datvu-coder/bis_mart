export const formatVnd = (n: number): string => `${Math.round(n).toLocaleString("vi-VN")}đ`;

export const formatDate = (iso: string | null | undefined): string => {
  const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(iso || "");
  return m ? `${m[3]}/${m[2]}/${m[1]}` : iso || "";
};
