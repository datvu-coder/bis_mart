#!/usr/bin/env bash
# Refreshes the ZMP_TOKEN GitHub secret used by the "Zalo Mini App Deploy" workflow.
#
# Usage (from anywhere):   bash zalo_mini_app/refresh-token.sh [--deploy]
#   --deploy   also start a Development deploy once the secret is updated
#
# Needs: Node.js, zmp-cli (npm i -g zmp-cli), GitHub CLI (https://cli.github.com) logged in
# with `gh auth login` as someone allowed to edit this repository's secrets.
set -euo pipefail

APP_ID="1392694436732932143"          # BiS MART staff Mini App ("Bismart Team"), NOT the Member app
REPO="datvu-coder/bis_mart"
SECRET="ZMP_TOKEN"

cd "$(dirname "$0")"

need() { command -v "$1" >/dev/null 2>&1 || { echo "Thiếu '$1'. $2" >&2; exit 1; }; }
need zmp "Cài bằng: npm install -g zmp-cli"
need gh  "Cài GitHub CLI tại https://cli.github.com rồi chạy: gh auth login"
gh auth status >/dev/null 2>&1 || { echo "Chưa đăng nhập GitHub CLI. Chạy: gh auth login" >&2; exit 1; }

echo "1/3 Đăng nhập Zalo cho app $APP_ID (duyệt trên trình duyệt/Zalo khi được hỏi)..."
zmp login --app-id "$APP_ID"

# Read the token without ever printing it; strip whitespace and quotes.
TOKEN="$(grep -E '^ZMP_TOKEN=' .env | tail -n 1 | cut -d= -f2- | tr -d '[:space:]"'"'")"
if [ -z "$TOKEN" ]; then
  echo "Không tìm thấy ZMP_TOKEN trong zalo_mini_app/.env sau khi đăng nhập." >&2
  exit 1
fi
if printf '%s' "$TOKEN" | LC_ALL=C grep -q '[^!-~]'; then
  echo "Token chứa ký tự không hợp lệ, hãy chạy lại script." >&2
  exit 1
fi

echo "2/3 Cập nhật secret $SECRET trên $REPO..."
printf '%s' "$TOKEN" | gh secret set "$SECRET" --repo "$REPO"

echo "3/3 Xong. Secret $SECRET đã được cập nhật."
if [ "${1:-}" = "--deploy" ]; then
  echo "Đang chạy triển khai Development..."
  gh workflow run zalo-mini-app.yml --repo "$REPO" --ref main -f target=development
  echo "Theo dõi tại: https://github.com/$REPO/actions/workflows/zalo-mini-app.yml"
fi
