# Bi'S MART - Flutter App

Hệ thống quản lý chuỗi cửa hàng dinh dưỡng mẹ & bé.

## Mô tả

Bi'S MART là app quản lý nội bộ cho hệ thống 61+ cửa hàng bán sữa bột, thực phẩm dinh dưỡng cho mẹ và bé (DELIMIL, DELI, AUMIL, GOODLIFE...). Hỗ trợ quản lý nhân sự, chấm công, báo cáo doanh số, đào tạo nhân viên, và xếp hạng hiệu suất.

## Tính năng chính

- **Dashboard** - Tổng quan doanh số, biểu đồ, Top 10 nhân viên
- **Nhân sự** - Chấm công, quản lý ca làm việc, bảng xếp hạng
- **Kinh doanh** - Báo cáo doanh số, export PDF/Excel
- **Đào tạo** - Cộng đồng, bài học, lịch học, MomCare AI
- **Cá nhân** - Quản lý profile, cửa hàng, sản phẩm

## Cài đặt

```bash
flutter pub get
flutter run
```

## Chay va build Web

```bash
# Chay web local
flutter run -d chrome --dart-define=API_BASE_URL=https://api.bismart.id.vn

# Build web production
flutter build web --release --dart-define=API_BASE_URL=https://api.bismart.id.vn
```

## Cấu trúc thư mục

```
lib/
├── main.dart              # Entry point
├── app.dart               # App widget + routing
├── core/                  # Constants, theme, utils
├── models/                # Data models
├── screens/               # UI screens
├── widgets/               # Reusable widgets
├── services/              # API & Auth services
└── providers/             # State management
```

## Công nghệ

- Flutter 3.x + Dart
- Provider (State Management)
- fl_chart (Charts)
- table_calendar (Calendar)
- Dio (HTTP Client)

## Phân quyền

| Mã  | Vai trò        | Quyền                          |
|-----|----------------|--------------------------------|
| MNG | Manager        | Toàn quyền hệ thống           |
| ADM | Admin/Chủ Shop | Quản lý cửa hàng, nhân viên   |
| PG  | Promoter Girl  | Tạo báo cáo, học bài          |
| TLD | Trưởng Lĩnh Vực| Quản lý nhóm, xem báo cáo nhóm|
| CS  | Chủ Shop chuỗi | Quản lý toàn chuỗi            |
