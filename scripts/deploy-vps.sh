#!/usr/bin/env bash
# Direct deploy of the Bismart backend to the VPS via SSH — bypasses Coolify
# entirely. Mirrors the "Giao việc" (quan-ly-van-ban) deploy-vps.sh pattern:
# rsync source -> VPS, build the Docker image on the VPS, roll out with
# docker compose, health-check the result.
#
# Run this from your own machine (needs your SSH key), NOT from CI.
#
# One-time setup on the VPS before the first run:
#   1. mkdir -p /opt/bismart-src /opt/apps/bismart
#   2. Create /opt/apps/bismart/docker-compose.yml (see
#      scripts/bismart-vps-compose.example.yml in this repo for a starting
#      point) and point it at the SAME Docker network bismart-postgres is
#      already on — check with:
#        docker inspect bismart-postgres --format '{{json .NetworkSettings.Networks}}'
#   3. Create /opt/apps/bismart/.env with DATABASE_URL and any other secrets
#      the backend needs (see backend/app.py for required env vars).
#   4. Make sure ~/.ssh/bismart_deploy (or whatever key you use) is
#      authorized on the VPS for the root/deploy user.
set -euo pipefail
cd "$(dirname "$0")/.."

VPS_HOST="root@146.196.64.92"
SSH_KEY="$HOME/.ssh/bismart_deploy"
REMOTE_SRC="/opt/bismart-src"
APP_DIR="/opt/apps/bismart"
IMAGE_TAG="bismart-backend:$(git rev-parse --short HEAD)"

ssh_opts=(-i "$SSH_KEY" -o ConnectTimeout=10 -o ServerAliveInterval=15 -o ServerAliveCountMax=4)

echo "==> Syncing backend/ source to $VPS_HOST:$REMOTE_SRC"
rsync -az --delete --inplace --no-whole-file \
  --exclude='.git' --exclude='.venv' --exclude='__pycache__' \
  --exclude='*.pyc' --exclude='*.db' --exclude='data/' \
  -e "ssh ${ssh_opts[*]}" \
  ./backend/ "$VPS_HOST:$REMOTE_SRC/"

echo "==> Building image $IMAGE_TAG on VPS"
ssh "${ssh_opts[@]}" "$VPS_HOST" "cd $REMOTE_SRC && docker build -t $IMAGE_TAG -t bismart-backend:latest ."

echo "==> Rolling out new container"
ssh "${ssh_opts[@]}" "$VPS_HOST" "cd $APP_DIR && docker compose up -d --force-recreate"

echo "==> Waiting for health check"
sleep 5
ssh "${ssh_opts[@]}" "$VPS_HOST" "docker inspect bis_mart_backend --format 'health={{.State.Health.Status}}'" || true

echo "==> Verifying live domain"
code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 8 "https://api.bismart.id.vn/healthz")
echo "api.bismart.id.vn/healthz -> $code"

echo "==> Done. Image tag: $IMAGE_TAG"
