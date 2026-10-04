const BASE_URL: string = (import.meta.env.VITE_API_BASE_URL as string | undefined) || "https://api.bismart.id.vn";

export type PublicStore = {
  id: string;
  name: string;
  province: string | null;
  latitude: number | null;
  longitude: number | null;
  address: string | null;
  phone: string | null;
};

async function get<T>(path: string): Promise<T> {
  const res = await fetch(`${BASE_URL}${path}`);
  if (!res.ok) throw new Error(`Lỗi ${res.status}`);
  return (await res.json()) as T;
}

export const api = {
  stores: () => get<PublicStore[]>("/api/public/stores"),
  oaInfo: () => get<{ oaId: string }>("/api/public/oa-info"),
};
