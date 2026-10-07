# Bismart Team — Zalo Mini App

Assign tasks to store staff and track store work. Talks to the existing backend (`../backend`).

## Run / deploy
```bash
npm install
cp .env.example .env      # optional; defaults to https://api.bismart.id.vn
npx zmp start             # dev server + Zalo simulator (needs `npm i -g zmp-cli` and `zmp login`)
npm run build             # production bundle into www/
npx zmp deploy            # upload to Zalo Mini App platform (set your App ID first)
```

## Automatic deploy
Every push to `main` that touches `zalo_mini_app/` runs `.github/workflows/zalo-mini-app.yml`, which
type-checks, builds and uploads the Development version with `zmp deploy -e`.
One-time setup: run `zmp login --app-id <id>` locally, then add the `ZMP_TOKEN` value from the generated
`.env` as a GitHub Actions repository secret named `ZMP_TOKEN`. If the token expires, log in again and update the secret.

## Auth
1. First open: employee logs in with their Bi'S MART code/password; the app then calls
   `POST /api/auth/zalo-link` with the Zalo access token (server verifies it with Zalo Graph API).
2. Next opens: `POST /api/auth/zalo-login` signs in with the Zalo token alone.

## Backend env
- `ZALO_OA_ACCESS_TOKEN` — optional. Zalo OA token used to push "new task / completed / comment"
  messages. Employees must have followed the OA. Without it, notifications are skipped silently.
- `TASK_PHOTO_DIR` — where completion-proof photos are stored (default `<POST_VIDEO_DIR>/task_photos` (a persistent volume)).

## Endpoints (backend/app.py)
`GET/POST /api/tasks`, `GET/PUT/DELETE /api/tasks/<id>`, `POST /api/tasks/<id>/status`,
`POST /api/tasks/<id>/comments`, `GET /api/tasks/summary`, `GET /api/tasks/assignees`,
`POST /api/tasks/upload-photo`, `GET /api/tasks/photo/<file>`.
Managers (admin, `can_crud` or `can_employees`) assign within their store scope; staff see only their own tasks.
