import React, { useEffect, useMemo, useState } from "react";
import { followOA, getLocation, openWebview } from "zmp-sdk/apis";
import { useSnackbar } from "zmp-ui";
import { api, PublicStore } from "../api";

type Coords = { lat: number; lng: number };
type StoreRow = PublicStore & { km: number | null };

const toRad = (d: number) => (d * Math.PI) / 180;
function distanceKm(a: Coords, lat: number, lng: number): number {
  const dLat = toRad(lat - a.lat);
  const dLng = toRad(lng - a.lng);
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(toRad(a.lat)) * Math.cos(toRad(lat)) * Math.sin(dLng / 2) ** 2;
  return 6371 * 2 * Math.asin(Math.sqrt(h));
}

const norm = (s: string) => s.normalize("NFD").replace(/[̀-ͯ]/g, "").replace(/đ/g, "d").toLowerCase();

export default function HomePage() {
  const { openSnackbar } = useSnackbar();
  const [stores, setStores] = useState<PublicStore[] | null>(null);
  const [error, setError] = useState("");
  const [query, setQuery] = useState("");
  const [me, setMe] = useState<Coords | null>(null);
  const [oaId, setOaId] = useState("");

  useEffect(() => {
    api.stores().then(setStores).catch((e: Error) => setError(e.message || "Không tải được danh sách cửa hàng"));
    api.oaInfo().then((r) => setOaId(r.oaId)).catch(() => {});
  }, []);

  const rows: StoreRow[] = useMemo(() => {
    const q = norm(query.trim());
    return (stores || [])
      .filter((s) => !q || norm(`${s.name} ${s.province || ""} ${s.address || ""}`).includes(q))
      .map((s) => ({ ...s, km: me && s.latitude != null && s.longitude != null ? distanceKm(me, s.latitude, s.longitude) : null }))
      .sort((a, b) => (a.km ?? 1e9) - (b.km ?? 1e9) || a.name.localeCompare(b.name, "vi"));
  }, [stores, query, me]);

  const locate = async () => {
    try {
      const res = (await getLocation({})) as { latitude?: string; longitude?: string };
      const lat = Number(res.latitude);
      const lng = Number(res.longitude);
      if (!Number.isFinite(lat) || !Number.isFinite(lng)) throw new Error("no coords");
      setMe({ lat, lng });
    } catch {
      openSnackbar({ text: "Không lấy được vị trí. Hãy cho phép truy cập vị trí hoặc tìm theo tên, tỉnh.", type: "error" });
    }
  };

  const follow = async () => {
    try {
      await followOA({ id: oaId });
      openSnackbar({ text: "Đã theo dõi OA Bi'S MART. Bạn sẽ nhận ưu đãi và thông báo trên Zalo.", type: "success" });
    } catch (e) {
      const code = (e as { code?: number })?.code;
      openSnackbar({ text: code === -201 ? "Bạn đã từ chối theo dõi OA" : "Không mở được trang theo dõi OA", type: "error" });
    }
  };

  const openMap = async (s: PublicStore) => {
    const q = s.latitude != null && s.longitude != null ? `${s.latitude},${s.longitude}` : encodeURIComponent(s.address || s.name);
    const url = `https://www.google.com/maps/search/?api=1&query=${q}`;
    try {
      await openWebview({ url });
    } catch {
      window.open(url, "_blank");
    }
  };

  return (
    <div className="member">
      <header className="hero">
        <h1>Bismart Member</h1>
        <div className="hero-note">Tìm cửa hàng Bi'S MART gần bạn</div>
      </header>

      <section className="panel">
        <input className="search" value={query} onChange={(e) => setQuery(e.target.value)} placeholder="Tìm theo tên, tỉnh hoặc địa chỉ" />
        <div className="actions">
          <button className="btn" onClick={locate}>{me ? "Cập nhật vị trí" : "Gần tôi"}</button>
          {oaId && <button className="btn primary" onClick={follow}>Theo dõi OA nhận ưu đãi</button>}
        </div>
      </section>

      {error && <div className="error inline">{error}</div>}
      {!stores && !error && <div className="center-note">Đang tải...</div>}
      {stores && rows.length === 0 && <div className="center-note">Không tìm thấy cửa hàng phù hợp</div>}

      <ul className="stores">
        {rows.map((s) => (
          <li key={s.id} className="panel store">
            <div className="store-name">{s.name}{s.km != null && <span className="km">{s.km < 10 ? s.km.toFixed(1) : Math.round(s.km)} km</span>}</div>
            {s.address && <div className="store-addr">{s.address}</div>}
            <div className="actions">
              {s.phone && <a className="btn" href={`tel:${s.phone}`}>Gọi</a>}
              <button className="btn" onClick={() => openMap(s)}>Chỉ đường</button>
            </div>
          </li>
        ))}
      </ul>
    </div>
  );
}
