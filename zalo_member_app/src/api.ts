import type { Member, Order, PaymentMethod, Product, Purchase, Redemption, Reward, Store } from "./types";

const BASE_URL: string = (import.meta.env.VITE_API_BASE_URL as string | undefined) || "https://api.bismart.id.vn";
const TOKEN_KEY = "bismart_member_token";

export const getToken = (): string => {
  try {
    return localStorage.getItem(TOKEN_KEY) || "";
  } catch {
    return "";
  }
};
export const setToken = (token: string) => {
  try {
    if (token) localStorage.setItem(TOKEN_KEY, token);
    else localStorage.removeItem(TOKEN_KEY);
  } catch {
    /* storage unavailable: session-only */
  }
};

const ERROR_VI: Record<string, string> = {
  "Unauthorized": "Phiên đăng nhập đã hết hạn, vui lòng mở lại ứng dụng.",
  "Invalid Zalo access token": "Không xác thực được tài khoản Zalo. Vui lòng thử lại.",
  "Could not verify phone number": "Không xác thực được số điện thoại. Vui lòng cho phép chia sẻ số điện thoại.",
  "Member registration is not configured": "Hệ thống chưa sẵn sàng đăng ký thành viên. Vui lòng quay lại sau.",
  "Phone or Zalo account already registered": "Số điện thoại hoặc tài khoản Zalo này đã được đăng ký.",
  "Name is required": "Vui lòng nhập họ tên.",
  "Invalid birthday": "Ngày sinh không hợp lệ.",
  "At least one item is required": "Giỏ hàng đang trống.",
  "Too many items": "Giỏ hàng có quá nhiều sản phẩm.",
  "Invalid item": "Sản phẩm không hợp lệ.",
  "Invalid quantity": "Số lượng không hợp lệ.",
  "Invalid payment method": "Hình thức thanh toán không hợp lệ.",
  "Product not found": "Có sản phẩm không còn bán, vui lòng làm mới giỏ hàng.",
  "Address is required": "Vui lòng nhập địa chỉ giao hàng.",
  "Reward not found": "Ưu đãi không còn khả dụng.",
  "Not enough points": "Bạn chưa đủ điểm để đổi ưu đãi này.",
};

export class ApiError extends Error {
  constructor(public status: number, message: string, public code?: string) {
    super(message);
  }
}

let onUnauthorized: () => void = () => {};
export const setUnauthorizedHandler = (fn: () => void) => {
  onUnauthorized = fn;
};

async function request<T>(method: string, path: string, body?: unknown): Promise<T> {
  const token = getToken();
  let res: Response;
  try {
    res = await fetch(`${BASE_URL}${path}`, {
      method,
      headers: {
        "Content-Type": "application/json",
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
      },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
  } catch {
    throw new ApiError(0, "Không kết nối được máy chủ. Vui lòng kiểm tra mạng.");
  }
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    const raw: string = data?.error || `HTTP ${res.status}`;
    if (res.status === 401 && token) onUnauthorized();
    throw new ApiError(res.status, ERROR_VI[raw] || raw, data?.code);
  }
  return data as T;
}

interface Session {
  token: string;
  member: Member;
}

export const api = {
  login: (accessToken: string) => request<Session>("POST", "/api/member/login", { accessToken }),
  register: (p: { accessToken: string; phoneToken: string; fullName: string; birthday?: string }) =>
    request<Session>("POST", "/api/member/register", p),
  me: () => request<{ member: Member }>("GET", "/api/member/me"),
  updateMe: (p: { fullName: string; birthday: string; address: string }) => request<{ member: Member }>("PUT", "/api/member/me", p),
  purchases: () => request<Purchase[]>("GET", "/api/member/purchases"),
  products: () => request<Product[]>("GET", "/api/member/products"),
  orders: () => request<Order[]>("GET", "/api/member/orders"),
  createOrder: (p: {
    items: { productId: number; quantity: number }[];
    paymentMethod: PaymentMethod;
    address: string;
    note: string;
  }) => request<Order>("POST", "/api/member/orders", p),
  rewards: () => request<{ rewards: Reward[]; redemptions: Redemption[] }>("GET", "/api/member/rewards"),
  redeem: (id: number) => request<{ member: Member }>("POST", `/api/member/rewards/${id}/redeem`, {}),
  stores: () => request<Store[]>("GET", "/api/member/stores"),
};
