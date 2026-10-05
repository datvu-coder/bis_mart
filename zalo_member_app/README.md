# Bi'S MART Member — Zalo Mini App

Customer app: shop (products from the `products` table), cart & online orders with status tracking, member card (QR),
points & tier, reward redemption, in-store purchase history, store locator. UI follows the design canvas
(https://claude.ai/artifact/Qm9zeSCbvUhrbYWftoFuQp).
Talks to the existing backend (`../backend`, `/api/member/*`).

## Run / deploy
```bash
npm install
npm run build        # production bundle into www/
npx zmp start        # dev server + Zalo simulator
```
Auto-deploy: `.github/workflows/zalo-member-app.yml` (push to `main` touching this folder, or manual run).
One-time setup: create a **new** Mini App in the Zalo console, then set repo variable `ZMP_MEMBER_APP_ID`
and secret `ZMP_MEMBER_TOKEN` (from `zmp login --app-id <id>`).

## Backend env
- `ZALO_APP_SECRET` — the Mini App's secret key. Required: it is used to exchange the phone-number token for a
  verified number at sign-up (`/api/member/register` returns 503 without it).

## How it works
- Sign-up: Zalo access token + phone token → member row (`members` table), one member per phone / Zalo account.
- Purchases are matched by `sales_reports.customer_phone` (last 9 digits), so staff must enter the customer's phone at POS.
- Points = 1 per 10,000đ net spend (revenue minus returns); tiers by lifetime spend: Bạc ≥ 5tr, Vàng ≥ 20tr, Kim cương ≥ 50tr
  (`MEMBER_POINT_UNIT` / `MEMBER_TIERS` in `backend/app.py`). Points are derived, not stored, so there is no redemption yet.
- Online orders (`member_orders`) are created by the app; staff with manage rights see them at `GET /api/member-orders`
  and move them along with `POST /api/member-orders/<id>/status` (`placed|confirmed|shipping|delivered|cancelled`).
  Only `delivered` orders count towards spend/points. Payment method is recorded only (no online payment yet).
- Rewards are rows in `member_rewards` (`name`, `points`, `active`); the "Đổi điểm" section only shows when any exist.
  Balance = earned points − `member_redemptions`.
- Member JWTs carry `typ: "member"` and are rejected by every employee endpoint (`login_required`).
