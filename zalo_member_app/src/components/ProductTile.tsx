import React from "react";
import type { Product } from "../types";
import { tileFor } from "../utils";

export default function ProductTile({ product, height, big }: { product: Product; height: number; big?: boolean }) {
  if (product.imageUrl) {
    return <img className="tile" src={product.imageUrl} alt={product.name} style={{ height }} />;
  }
  const t = tileFor(product.name, product.id);
  return (
    <div className={`tile${big ? " big" : ""}`} style={{ height, background: t.bg, color: t.ink }} role="img" aria-label={product.name}>
      {t.mono}
    </div>
  );
}
