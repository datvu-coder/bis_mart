export interface Member {
  id: number;
  memberCode: string;
  fullName: string;
  phone: string;
  birthday: string | null;
  joinedAt: string;
  totalSpent: number;
  orderCount: number;
  points: number;
  tier: string;
  nextTier: string | null;
  spentToNextTier: number;
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
