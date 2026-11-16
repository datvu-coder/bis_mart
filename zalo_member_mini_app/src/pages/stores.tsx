import React, { useMemo, useState } from "react";
import { getLocation, openWebview } from "zmp-sdk/apis";
import { useSnackbar } from "zmp-ui";
import type { PublicStore } from "../api";

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

type Props = { stores: PublicStore[] | null; error: string; onRetry: () => void };

export default function StoresTab({ stores, error, onRetry }: Props) {
  const { openSnackbar } = useSnackbar();
  const [query, setQuery] = useState("");
  const [province, setProvince] = useState("");
  const [me, setMe] = useState<Coords | null>(null);
  const [locating, setLocating] = useState(false);

  const provinces = useMemo(
    () => Array.from(new Set((stores || []).map((s) => s.province).filter((p): p is string => !!p))).sort((a, b) => a.localeCompare(b, "vi")),
    [stores],
  );

  const rows: StoreRow[] = useMemo(() => {
    const q = norm(query.trim());
    return (stores || [])
      .filter((s) => !province || s.province === province)
      .filter((s) => !q || norm(`${s.name} ${s.province || ""} ${s.address || ""}`).includes(q))
      .map((s) => ({ ...s, km: me && s.latitude != null && s.longitude != null ? distanceKm(me, s.latitude, s.longitude) : null }))
      .sort((a, b) => (a.km ?? 1e9) - (b.km ?? 1e9) || a.name.localeCompare(b.name, "vi"));
  }, [stores, query, province, me]);

  const locate = async () => {
    setLocating(true);
    try {
      const res = (await getLocation({})) as { latitude?: string; longitude?: string };
      const lat = Number(res.latitude);
      const lng = Number(res.longitude);
      if (!Number.isFinite(lat) || !Number.isFinite(lng)) throw new Error("no coords");
      setMe({ lat, lng });
      openSnackbar({ text: "Đã sắp xếp cửa hàng theo khoảng cách", type: "success" });
    } catch {
      openSnackbar({ text: "Không lấy được vị trí. Hãy cho phép truy cập vị trí hoặc tìm theo tên, tỉnh.", type: "error" });
    } finally {
      setLocating(false);
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
    <>
      <header className="hero m-hero small">
        <h1>Cửa hàng</h1>
        <div className="hero-note">Tìm cửa hàng Bi'S MART gần bạn</div>
      </header>

      <section className="panel m-search">
        <input className="search" value={query} onChange={(e) => setQuery(e.target.value)} placeholder="Tìm theo tên, tỉnh hoặc địa chỉ" />
        <button className="btn primary wide" onClick={locate} disabled={locating}>{locating ? "Đang lấy vị trí..." : me ? "Cập nhật vị trí của tôi" : "Cửa hàng gần tôi"}</button>
        {provinces.length > 0 && (
          <div className="m-chips">
            <button className={!province ? "on" : ""} onClick={() => setProvince("")}>Tất cả</button>
            {provinces.map((p) => (
              <button key={p} className={province === p ? "on" : ""} onClick={() => setProvince(province === p ? "" : p)}>{p}</button>
            ))}
          </div>
        )}
      </section>

      {error && (
        <div className="panel m-state">
          <div className="error inline">{error}</div>
          <button className="btn wide" onClick={onRetry}>Thử lại</button>
        </div>
      )}
      {!stores && !error && <div className="center-note">Đang tải...</div>}
      {stores && <div className="m-count">{rows.length} cửa hàng</div>}
      {stores && rows.length === 0 && <div className="center-note">Không tìm thấy cửa hàng phù hợp</div>}

      <ul className="stores">
        {rows.map((s) => (
          <li key={s.id} className="panel store">
            <div className="store-name">
              <span>{s.name}</span>
              {s.km != null && <span className="km">{s.km < 10 ? s.km.toFixed(1) : Math.round(s.km)} km</span>}
            </div>
            {s.province && <div className="store-prov">{s.province}</div>}
            {s.address && <div className="store-addr">{s.address}</div>}
            <div className="actions">
              {s.phone && <a className="btn" href={`tel:${s.phone}`}>Gọi</a>}
              <button className="btn" onClick={() => openMap(s)}>Chỉ đường</button>
            </div>
          </li>
        ))}
      </ul>
    </>
  );
}
