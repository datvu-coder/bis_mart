/** "2026-10-01T15:30:00" -> "15:30 01/10" (the API stores Vietnam local time). */
export function formatDue(iso: string | null): string {
  if (!iso) return "";
  const [date, time = ""] = iso.split("T");
  const [, m, d] = date.split("-");
  return `${time.slice(0, 5)} ${d}/${m}`.trim();
}

/** datetime-local value <-> API value (seconds suffix). */
export const toInputValue = (iso: string | null) => (iso ? iso.slice(0, 16) : "");
export const fromInputValue = (v: string) => (v ? `${v}:00` : null);
