#!/usr/bin/env bash
# One-step update for the Mini App: download latest code from main, build, deploy.
# Usage (paste in Terminal):
#   curl -fsSL https://raw.githubusercontent.com/datvu-coder/bis_mart/main/zalo_mini_app/scripts/update-and-deploy.sh | bash
# Requires Node.js and zmp-cli (npm i -g zmp-cli) and a prior `zmp login`.
set -euo pipefail

APP_ID="1392694436732932143"
ZIP_URL="${ZIP_URL:-https://github.com/datvu-coder/bis_mart/archive/refs/heads/main.zip}"
DIR="${MINI_APP_DIR:-$HOME/bismart-mini-app}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

command -v node >/dev/null || { echo "Chua cai Node.js: tai ban LTS tai https://nodejs.org roi chay lai."; exit 1; }
command -v zmp >/dev/null || { echo "Chua cai zmp-cli. Chay: sudo npm install -g zmp-cli  roi chay lai."; exit 1; }

echo "==> 1/4 Tai code moi nhat"
curl -fsSL -o "$TMP/src.zip" "$ZIP_URL"
unzip -qo "$TMP/src.zip" '*/zalo_mini_app/*' -d "$TMP"
SRC="$(ls -d "$TMP"/*/zalo_mini_app)"

echo "==> 2/4 Cap nhat thu muc $DIR"
mkdir -p "$DIR"
find "$DIR" -mindepth 1 -maxdepth 1 ! -name node_modules -exec rm -rf {} +
cp -R "$SRC/." "$DIR/"
cd "$DIR"

echo "==> 3/4 Cai thu vien va build"
npm install --no-audit --no-fund --loglevel=error
npm run build

echo "==> 4/4 Deploy len Zalo (app $APP_ID)"
if ! zmp deploy -e -m "update $(date +%Y-%m-%d_%H:%M)"; then
  echo
  echo "Deploy that bai. Neu bao het phien dang nhap, chay:  zmp login --app-id $APP_ID  roi chay lai lenh cap nhat."
  exit 1
fi
