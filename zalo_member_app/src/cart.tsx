import React, { createContext, useCallback, useContext, useEffect, useMemo, useState } from "react";
import { api } from "./api";
import type { Product } from "./types";

interface CartState {
  products: Product[] | null;
  productsError: string;
  qty: Record<number, number>;
  count: number;
  total: number;
  add: (id: number, by?: number) => void;
  set: (id: number, qty: number) => void;
  clear: () => void;
}

const CartContext = createContext<CartState>(null as unknown as CartState);
export const useCart = () => useContext(CartContext);

export function CartProvider({ children }: { children: React.ReactNode }) {
  const [products, setProducts] = useState<Product[] | null>(null);
  const [productsError, setProductsError] = useState("");
  const [qty, setQty] = useState<Record<number, number>>({});

  useEffect(() => {
    api.products().then(setProducts).catch((e) => setProductsError(e.message));
  }, []);

  const set = useCallback((id: number, n: number) => {
    setQty((q) => {
      const next = { ...q };
      if (n <= 0) delete next[id];
      else next[id] = Math.min(99, n);
      return next;
    });
  }, []);
  const add = useCallback((id: number, by = 1) => setQty((q) => ({ ...q, [id]: Math.min(99, (q[id] || 0) + by) })), []);
  const clear = useCallback(() => setQty({}), []);

  const { count, total } = useMemo(() => {
    let c = 0;
    let t = 0;
    for (const p of products || []) {
      const n = qty[p.id] || 0;
      c += n;
      t += n * p.price;
    }
    return { count: c, total: t };
  }, [products, qty]);

  return (
    <CartContext.Provider value={{ products, productsError, qty, count, total, add, set, clear }}>
      {children}
    </CartContext.Provider>
  );
}
