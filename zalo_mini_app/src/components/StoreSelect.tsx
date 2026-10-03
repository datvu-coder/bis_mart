import React from "react";
import { useOpsSummary, useStoreList } from "../data";

interface Props {
  value: string;
  onChange: (code: string) => void;
  allowAll?: boolean;
}

/** Store dropdown for managers; renders nothing for single-store staff. */
export default function StoreSelect({ value, onChange, allowAll }: Props) {
  const stores = useStoreList();
  if (stores.length <= 1 && !allowAll) return null;
  return (
    <select className="store-select wide" value={value} onChange={(e) => onChange(e.target.value)} aria-label="Cửa hàng">
      {allowAll && <option value="">Tất cả cửa hàng</option>}
      {stores.map((s) => <option key={s.storeCode} value={s.storeCode}>{s.storeName || s.storeCode}</option>)}
    </select>
  );
}

/** Selected store for ops screens: starts at the user's own store, falls back to the first store they manage. */
export function useStoreChoice(initial?: string): [string, (code: string) => void, { storeCode: string; storeName: string }[]] {
  const stores = useStoreList();
  const [picked, setPicked] = React.useState(initial || "");
  const own = (useOpsSummary()?.storeCode || "").toUpperCase();
  const value = picked || own || stores[0]?.storeCode || "";
  return [value, setPicked, stores];
}
