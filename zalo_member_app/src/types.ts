export interface Member {
  id: number;
  memberCode: string;
  fullName: string;
  phone: string;
  birthday: string | null;
  address: string;
  joinedAt: string;
  totalSpent: number;
  orderCount: number;
  points: number;
  tier: string;
  nextTier: string | null;
  spentToNextTier: number;
  tierProgress: number;
}

export interface PurchaseItem {
  name: string;
  quantity: number;
  unitPrice: number;
}

export interface Purchase {
  id: number;
  date: string;
  storeName: string;
  total: number;
  points: number;
  items: PurchaseItem[];
}

export interface Store {
  code: string;
  name: string;
  province: string;
  address: string;
  phone: string;
  latitude: number | null;
  longitude: number | null;
}

export interface Product {
  id: number;
  name: string;
  unit: string;
  price: number;
  group: string;
  imageUrl: string;
}

export type OrderStatus = "placed" | "confirmed" | "shipping" | "delivered" | "cancelled";
export type PaymentMethod = "cod" | "bank" | "card";

export interface Order {
  id: number;
  code: string;
  status: OrderStatus;
  paymentMethod: PaymentMethod;
  total: number;
  note: string;
  recipient: string;
  phone: string;
  address: string;
  createdAt: string;
  items: { productId: number; name: string; quantity: number; unitPrice: number }[];
}

export interface Reward {
  id: number;
  name: string;
  points: number;
}

export interface Redemption {
  name: string;
  points: number;
  date: string;
}
