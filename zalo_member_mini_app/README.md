# Bismart Member — Zalo Mini App

- Zalo Mini App ID: `142578969708561965` (BiS MART Khach Hang)
- Backend: `https://api.bismart.id.vn` (đổi qua `VITE_API_BASE_URL` trong `.env`)
- Khung kỹ thuật sao chép từ `zalo_mini_app/` của repo bis_mart; đã bỏ toàn bộ màn hình nhân viên.
- Hiện có: tìm cửa hàng (gần tôi / theo tên, tỉnh) và theo dõi OA. Dùng API công khai `GET /api/public/stores` và `GET /api/public/oa-info` (backend cần deploy thêm 2 endpoint này).
- Chưa có: thẻ thành viên, điểm, lịch sử mua (chưa có nguồn dữ liệu khách hàng), ưu đãi.

## Chạy / deploy
```bash
npm install
cp .env.example .env
npx zmp login --app-id 142578969708561965   # một lần; tự ghi ZMP_TOKEN vào .env (không commit)
npx zmp start                                # dev server + simulator
npm run build && npx zmp deploy              # tải lên Zalo
```
