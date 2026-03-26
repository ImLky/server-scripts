#!/bin/bash
# @cmd: restart
# @desc: 서비스 재시작 (git pull + 재빌드 + npm install)
# @usage: ser restart <서비스명>
# @example: ser restart test
# restart.sh — git pull + docker compose 서비스 재시작

set -euo pipefail

COMPOSE_FILE="/home/docker/docker-compose.yml"
SERVICE="${1:-}"
REMOTE_HOST="192.168.0.150"
PROJECT_ROOT="/home/mes"   # 실제 프로젝트 폴더들이 있는 경로

# ---------- 필수 입력 확인 ----------
if [ -z "$SERVICE" ]; then
  echo "서비스 이름이 필요합니다."
  echo "예) ./restart.sh test"
  exit 1
fi

# ---------- 폴더 자동 탐색 ----------

FOLDER_PASS=$(awk -v svc="${SERVICE}:" '$1 == svc {found=1} found && $1 == "build:" {print $2; exit}' /home/docker/docker-compose.yml)
FOLDER_NAME=$(basename "$FOLDER_PASS")

TARGET_DIR=$(find "$PROJECT_ROOT" -maxdepth 1 -type d -name ${FOLDER_NAME} | head -n 1)

if [ -z "$TARGET_DIR" ]; then
  echo "[ERROR] '${SERVICE}'에 해당하는 폴더를 찾을 수 없습니다."
  echo "예시 폴더명: Q-MES-25KJ-${SERVICE}-Q249"
  exit 1
fi

echo "[INFO] ${SERVICE} 폴더 확인: $TARGET_DIR"

# ---------- Git Pull ----------
if [ -d "$TARGET_DIR/.git" ]; then
  echo "[INFO] Git pull 실행 중..."
  cd "$TARGET_DIR"
  git reset --hard
  git pull
  cd - >/dev/null
else
  echo "[WARN] Git 저장소가 아닙니다. (${TARGET_DIR})"
fi

# ---------- 서비스 목록 확인 ----------
if ! SERVICES="$(docker compose -f "$COMPOSE_FILE" config --services 2>/dev/null)"; then
  echo "[ERROR] docker compose -f $COMPOSE_FILE config --services 실행 실패"
  exit 1
fi

echo "$SERVICES" | grep -xq "$SERVICE" || {
  echo "[ERROR] docker-compose.yml 내 서비스가 없습니다: $SERVICE"
  exit 1
}

echo "[INFO] $SERVICE 재시작 중..."

# ---------- 서비스 중지 & 삭제 ----------
docker compose -f "$COMPOSE_FILE" stop "$SERVICE"
docker compose -f "$COMPOSE_FILE" rm -f -v "$SERVICE"

# ---------- 이미지 삭제 ----------
IMAGE_ID=$(docker compose -f "$COMPOSE_FILE" images -q "$SERVICE" | head -n1)
if [ -n "$IMAGE_ID" ]; then
  echo "[INFO] 기존 이미지 삭제: $IMAGE_ID"
  docker rmi -f "$IMAGE_ID" || true
fi

# ---------- 서비스 재실행 ----------
docker compose -f "$COMPOSE_FILE" up -d "$SERVICE"

# [추가_260105 고범석] 컨테이너가 켜진 뒤, 내부에서 npm install을 자동으로 실행하게 합니다.
echo "[INFO] 컨테이너 내부 의존성 업데이트 중 (npm install)..."
docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" sh -c "npm install && cd backend && npm install"
echo "[INFO] 라이브러리 반영을 위해 서비스 재시작..."
docker compose -f "$COMPOSE_FILE" restart "$SERVICE"

# ---------- 정리 ----------
docker volume prune -f
docker image prune -af
docker builder prune -af

# ---------- nginx 리로드 ----------
if command -v nginx >/dev/null 2>&1; then
  echo "[INFO] 로컬 nginx 리로드"
  nginx -s reload
else
  echo "[INFO] 원격 nginx 리로드 시도 (${REMOTE_HOST})"
  ssh root@"$REMOTE_HOST" "nginx -s reload"
fi

echo "[INFO] $SERVICE 재시작 완료 ✅"
