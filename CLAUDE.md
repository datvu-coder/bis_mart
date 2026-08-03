# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

Bi'S MART is an internal management app for a Vietnamese mother/baby nutrition retail chain (61+ stores; brands DELIMIL, DELI, AUMIL, GOODLIFE). It's a two-part monorepo:

- `backend/` — Flask + PostgreSQL REST API, single-file (`app.py`), deployed to a self-managed VPS.
- `bismart_flutter/` — Flutter app (iOS/Android/Web), the only client. Provider for state management.

There is no staging environment; `main` is the deployable branch for both halves and each half auto-deploys independently on push (see CI/CD below).

## Commands

### Backend (`backend/`)

```bash
# Local dev — PostgreSQL only, no SQLite fallback. Fails fast if unset:
export DATABASE_URL=postgresql://user:pass@localhost:5432/bismart
python3 app.py

# Syntax check (no test suite exists for the backend)
python3 -m py_compile app.py

# Apply schema (idempotent — CREATE TABLE IF NOT EXISTS + ALTER TABLE ADD COLUMN blocks)
psql "$DATABASE_URL" -f schema_postgres.sql

# Production smoke test (against a live deployment, not local)
python3 smoke_test_production.py --backend https://api.bismart.id.vn
```

### Flutter (`bismart_flutter/`)

```bash
flutter pub get

# Run against production API (there is no separate dev/staging backend)
flutter run -d chrome --dart-define=API_BASE_URL=https://api.bismart.id.vn

flutter build web --release --dart-define=API_BASE_URL=https://api.bismart.id.vn
flutter analyze
```

`test/` only contains the default counter widget test — there's no real Flutter test suite to run or extend as part of normal work.

### CI/CD — GitHub Actions (`.github/workflows/`)

Both workflows trigger **only on push to `main`**, each gated by path filters, and there is no CI on pull requests:

- `vps-ops.yml` — fires only when `backend/**` changed. Tars `backend/`, builds a Docker image over SSH on the VPS (`root@146.196.64.92`), rolls the container, and fails the workflow if `https://api.bismart.id.vn/healthz` doesn't return 200 post-deploy. Also supports manual `workflow_dispatch` actions: `diagnose`, `restart_backend`, `deploy_backend`, `set_admin`.
- `ios-testflight.yml` — fires only when `bismart_flutter/**` changed. Builds and uploads to TestFlight on every such push to `main` (deliberately kept as build-on-every-merge, not scheduled/manual).

Practical upshot: a PR touching only Flutter screen files will show no `VPS Ops` run at all, and vice versa — that's expected, not a misconfiguration. Because there's no PR-time CI, the working pattern for this repo is: open the PR, confirm there are no review comments, merge (squash), then verify the resulting `main` workflow run(s) via `mcp__github__actions_list` (correlate by the merge commit's SHA).

Squash-merging means the feature branch's own commit history diverges from `main` after each merge. Before adding new commits to the same long-lived feature branch, `git fetch origin main && git rebase origin/main` first — otherwise GitHub reports a false "merge conflicts" error on the next PR even when the diff is clean, and a `git rebase` (not a manual conflict resolution) is the fix.

## Architecture

### Backend (`backend/app.py`, ~5000 lines, no blueprints)

- Flask app, `psycopg[binary]` v3 driver, `dict_row` row factory. PostgreSQL is mandatory — the app raises at import time if `DATABASE_URL` is unset. `schema_postgres.sql` is the source of truth; `schema.sql` is a stale SQLite-era leftover.
- Auth: JWT in `Authorization: Bearer` header (`create_token`/`get_current_user`), `@login_required` decorator sets `g.current_user`. Routes use verb-specific decorators (`@app.get`, `@app.post`, etc.), not `@app.route`.
- Authorization model: the `permissions` table is keyed by `position` (free-text role code assigned per employee, e.g. `MNG`/`ADM`/`PG`/`TLD`/`CS`/`TMK`) with boolean capability columns (`can_report`, `can_crud`, `can_manage_attendance`, `can_employees`, `can_switch_store`, etc.) — there's no hardcoded role enum in code. Report/e-invoice endpoints follow an "owner OR crud-permission OR store-scope match" access pattern (see `_can_access_report`).
- Response shaping: every table has a paired `_x_to_api_json(row)` helper that converts snake_case DB columns to the camelCase JSON the Flutter client expects — follow this convention for any new endpoint rather than returning raw rows.
- `sales_reports` is dual-purpose: the same rows back both the Kinh doanh "Báo cáo" (reports) list and the POS "Lịch sử bán hàng" (sales history) screen — they're different Flutter views over one table, not separate data.
- E-invoice issuance (`api_issue_report_einvoice`) dispatches on `einvoice_settings.provider`: `_issue_generic_einvoice` (best-effort POST), `_issue_viettel_invoice` (real S-Invoice REST/JSON API), `_issue_misa_invoice` (real meInvoice REST auth + JSON-wrapped-XML publish), `_issue_vnpt_invoice` (real SOAP `ImportAndPublishInv`). MISA/VNPT share `_compute_invoice_lines()` + `_build_standard_invoice_xml()` (Vietnamese standard `HDon/DLHDon/TTChung/NDHDon` XML — best-effort against the public schema, not verified against an official XSD).
- GPS attendance check-in/out validates distance server-side against the assigned store's stored lat/lng — don't trust client-reported "within range" claims.

### Flutter (`bismart_flutter/lib/`)

- `providers/` (Provider/ChangeNotifier) per domain: `auth`, `employee`, `store`, `product`, `sales`, `training`, `dashboard`, `permission`. Screens read via `context.watch`/`context.read`, never call `ApiService` directly.
- `services/api_service.dart` wraps Dio; `baseUrl` comes from the `API_BASE_URL` dart-define (see run/build commands above) — there is no environment-switching UI, it's compile-time only.
- Navigation: a 5-tab bottom nav (`MainShell`) — Tổng quan (dashboard), Nhân sự, Kinh doanh, Đào tạo, Cá nhân — each tab is one primary screen; former sub-tabs were deliberately consolidated into that single screen with secondary views reached via header actions (see below), not separate tabs. Route constants live in `core/constants/app_routes.dart`.
- Design tokens: `core/constants/app_colors.dart` (`AppColors`), `core/theme/app_theme.dart` (`AppTextStyles`, `AppRadius`, `AppDecorations`). Always reuse these instead of hardcoding hex colors or radii.

#### Established screen-header pattern (all 5 tabs)

Each tab's primary screen has a `_buildScreenHeader()` that returns a gradient "hero" card (`AppColors.primary` → `AppColors.primaryDark`, `AppRadius.panel`, subtle shadow) containing: title + `HeaderActionCluster` "..." menu, a short greeting/context row, and — where the tab has one obvious daily action — a full-width primary CTA button reflecting current state (e.g. Nhân sự's chấm-công vào/ra button, Đào tạo's "Tiếp tục học" shortcut to the in-progress lesson). Secondary stats (counts, KPIs) live in a separate floating white stat card directly below the hero, laid out as equal-width tappable `_buildStatItem` columns separated by `VerticalDivider`s — not as `Wrap`-ped chips inside the header card itself (that was the pre-redesign pattern, now superseded).

`HeaderActionCluster` is the single "..." overflow menu used for every screen's secondary actions (`widgets/common/header_action_cluster.dart`) — always renders the same glyph even for one action, for a consistent tap target across screens. A primary/frequent action is promoted to a standalone `IconButton` placed to the *left* of the cluster rather than buried inside it; anything used less than daily stays inside the menu.

#### `DataPanel` gotcha

`widgets/common/data_panel.dart` defaults to `EdgeInsets.all(22)` padding. Passing a custom `padding` with zero horizontal insets (e.g. `EdgeInsets.fromLTRB(0, y, 0, y)`) makes the title text and content visually touch the outer card border — always use a non-zero horizontal inset (e.g. `12`) when overriding.

#### Top-down detail panels

Where a "drops down from the top" panel is wanted (as opposed to the conventional bottom sheet), use `showGeneralDialog` with a custom `pageBuilder`/`transitionBuilder` (`SlideTransition` from `Offset(0, -1)` to `Offset.zero`) rather than `showModalBottomSheet` + `DraggableScrollableSheet`.

## Conventions

- Communicate with the user in Vietnamese by default (chat replies only — this doesn't apply to code, comments, commit messages, or PR content, which stay in English per existing convention).
- Never attribute commits/PRs to Claude/an AI model in the commit message, PR title, PR body, or code comments — chat-only.
- No local Flutter/Python toolchain is available in this environment: verification is bracket-balance checks + `ast.parse()` (Python) done manually before committing, plus reading CI results after merge — there is no way to run `flutter analyze`/`flutter test`/`python3 -m py_compile` from most sessions unless the tool is confirmed present.
