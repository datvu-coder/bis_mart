---
name: zalo-mini-app-release
description: Deploy, update or release the Zalo Mini App "Bismart Team" (zalo_mini_app/, app id 1392694436732932143), refresh an expired ZMP_TOKEN, or debug a blank/white screen in Zalo. Use when the user asks to publish, update the live version, send a new version for review, fix "Permission denied. Please login again", or says the Mini App shows a white screen.
---

# Zalo Mini App "Bismart Team" — deploy and release

Two Mini Apps share this repo; never mix them up:
- **Bismart Team** (staff app) — `zalo_mini_app/`, app id `1392694436732932143`, secret `ZMP_TOKEN`, workflow `zalo-mini-app.yml`.
- **Bismart Member** (customer app) — `zalo_member_mini_app/`, app id `142578969708561965`, secret `ZMP_TOKEN_MEMBER`, workflow `zalo-member-mini-app.yml`. zmp tokens are bound to ONE app.

## How versions work
- Push to `main` touching `zalo_mini_app/**` auto-deploys the **Development** version (job "Deploy to Zalo Mini App" prints `Version: zdev-xxxxxxxx`). Development never changes what real users see.
- Manual run (`workflow_dispatch`, input `target`): `development` or `testing`. **Testing** uploads a numbered version (1, 2, 3...). Only a Testing version can be submitted for review.
- The published (live) version is a fixed package. Code changes reach users only after: upload Testing version -> user clicks **Gửi duyệt** in mini.zalo.me -> Zalo approves -> user clicks **Phát hành**. Those console steps are the user's; Claude cannot do them.
- Backend (`backend/`) deploys separately via VPS Ops on push to `main` and takes effect immediately; it needs no Zalo review.
- Batch changes before asking for a review: every submission is re-reviewed (hours to days). Ask the user to check the Development build on their phone first.
- Dev link: `https://zalo.me/s/1392694436732932143/?env=DEVELOPMENT&version=zdev-…`; Testing: `...?env=TESTING&version=N`; live: `https://zalo.me/s/1392694436732932143/` (only after publish).

## Upload a Testing version (to release)
Run the workflow `Zalo Mini App Deploy` on `main` with `target=testing` (GitHub MCP `actions_run_trigger`, or the user via the Actions tab). Read the job log: the "Deploy to Zalo Mini App" step prints `Version: N`. Tell the user which N to submit.

## ZMP_TOKEN expired ("Permission denied. Please login again")
Deploy fails in ~1 second at the "Deploy to Zalo Mini App" step. Claude cannot fix this: `zmp login` needs the owner to approve on Zalo. The user (on a Mac with Node, `zmp-cli`, and `gh auth login` done once) runs:

```
bash zalo_mini_app/refresh-token.sh --deploy
```

It logs in to the staff app only, stores the token in the `ZMP_TOKEN` secret (never printed) and starts a Development deploy. On a fresh Mac: `npm config set prefix ~/.npm-global`, add `~/.npm-global/bin` to PATH, then `npm install -g zmp-cli` (avoids EACCES). Windows: use Git Bash/WSL. Never ask the user to paste a token into chat.

## White screen in Zalo (investigated 2026-10-04)
Same commit, byte-identical build output was white on one Development version and fine on the next, and even a minimal no-React bundle was white. Cause is on Zalo's side (stale version pointer/cache: old css hash returning 404 in the iOS debug Network tab), not in the code. Fix: redeploy Development (workflow_dispatch) and reopen; try the Testing link; ask for a screenshot of the Network tab (which URL is 404) plus the console "Phiên bản" tab. `src/boot.ts` shows a start-up message/error so a blank page that still appears means Zalo never ran the bundle.

## Gotchas learned
- Assign-by-store must send `storeCode` with each task (done in `task-form.tsx`); otherwise the backend uses the assignee's home store.
- A manager of several stores = one `store_managers` row per store. `POST /api/store-managers` with `keepHome: true` keeps the employee's home `store_code` (the permissions screens send it); without it the call transfers the employee to that store.
- Display name lives in `zalo_mini_app/vite.config.ts` (`title`, `headerTitle`) and `src/index.html`; the name in the Zalo console is set by the user there.
- Repo conventions: no PR CI; open PR, merge (squash), then verify the main workflow run via `actions_list` by merge SHA. Chat in Vietnamese; no AI attribution in code/commits/PR text beyond the harness trailers.
