#!/usr/bin/env bash
# @cmd: del
# @desc: 서비스 삭제 (컨테이너/볼륨/이미지/설정 제거)
# @usage: ser del <서비스명>
# @example: ser del test
# --------------------------------------------
# 목적: 서비스 삭제 + compose 및 원격 nginx 설정 제거 + 오류 시 롤백
# --------------------------------------------

set -euo pipefail

# ---------- 인자 ----------
SERVICE="${1:-}"

if [[ -z "$SERVICE" ]]; then
  echo "==========================================="
  echo "🧩 사용법: $0 <서비스명>"
  echo "예시:   $0 test"
  echo "==========================================="
  echo
  echo "		
  		1. 도커 실행중지, 
		2. 컨테이너삭제, 
		3. 볼륨삭제, 
		4. 이미지 삭제, 
		5. compose 텍스트 제거, 
		6. con.f 텍스트 제거 순으로 진행.
		
		
		"
  echo "📁 현재 docker-compose.yml에 정의된 서비스 목록:"
  FILE="/home/docker/docker-compose.yml"
  if [[ -f "$FILE" ]]; then
    grep -E '^[[:space:]]{2}[a-zA-Z0-9_-]+:' "$FILE" \
      | sed -E 's/^[[:space:]]{2}([a-zA-Z0-9_-]+):.*/  - \1/' || true
  else
    echo "⚠️  docker-compose.yml 파일이 없습니다 ($FILE)"
  fi
  echo
  echo "🐳 현재 Docker 컨테이너 목록:"
  if command -v docker >/dev/null 2>&1; then
    if docker compose version >/dev/null 2>&1; then
      docker compose ps -a --format '  - {{.Name}} ({{.State}})' || true
    elif command -v docker-compose >/dev/null 2>&1; then
      docker-compose ps -a --format '  - {{.Name}} ({{.State}})' || true
    else
      echo "⚠️ docker compose 명령을 찾을 수 없습니다."
    fi
  fi
  echo
  echo "==========================================="
  exit 0
fi

# ---------- 기본 경로 ----------
FILE="/home/docker/docker-compose.yml"
REMOTE_HOST="192.168.0.150"
REMOTE_NGINX_FILE="/etc/nginx/conf.d/249server/249sets.conf"
REMOTE_BAK_DIR="/etc/nginx/conf.d/249server/249sets.conf_back"

# ---------- 백업 파일명 ----------
TS="$(date +%Y%m%d%H%M%S)"
BACKUP_DIR="$(dirname "$FILE")/docker-compose.yml_back"
mkdir -p "$BACKUP_DIR"
COMPOSE_BAK="${BACKUP_DIR}/docker-compose.yml.bak.${TS}"
REMOTE_BAK="${REMOTE_BAK_DIR}/249sets.conf.bak.${TS}"

MOD_COMPOSE=0
MOD_REMOTE_NGINX=0

# ---------- 롤백 함수 ----------
rollback() {
  echo "⚠️ 오류 발생 → 롤백 시작..."

  if (( MOD_COMPOSE )) && [[ -f "$COMPOSE_BAK" ]]; then
    mv -f "$COMPOSE_BAK" "$FILE"
    echo "→ docker-compose.yml 복구 완료"
  fi

  if (( MOD_REMOTE_NGINX )); then
    echo "→ 원격 nginx 복구 진행 중..."
    ssh root@"${REMOTE_HOST}" "if [[ -f ${REMOTE_BAK} ]]; then mv -f ${REMOTE_BAK} ${REMOTE_NGINX_FILE} && nginx -t && nginx -s reload; fi" || true
    echo "[원격 롤백 완료]"
  fi

  echo "✅ 롤백 완료"
}
trap 'rollback; exit 1' ERR INT TERM

# ---------- 백업 ----------
cp -a "$FILE" "$COMPOSE_BAK"
MOD_COMPOSE=1
echo "🗂 compose 백업 완료: $COMPOSE_BAK"

if ! ssh root@"${REMOTE_HOST}" "mkdir -p ${REMOTE_BAK_DIR} && cp -a ${REMOTE_NGINX_FILE} ${REMOTE_BAK}"; then
  echo "⚠️ 원격 nginx 백업 실패 → 롤백 실행"
  rollback
  exit 1
fi
MOD_REMOTE_NGINX=1
echo "🗂 원격 nginx 백업 완료: ${REMOTE_HOST}:${REMOTE_BAK}"


# ---------- Docker compose 기반 stop/rm/rmi ----------
echo "🛑 docker compose stop/rm/rmi 실행 중..."

COMPOSE_FILE="/home/docker/docker-compose.yml"

# 1️⃣ 컨테이너 중지
if docker compose -f "$COMPOSE_FILE" ps | grep -q "$SERVICE"; then
  docker compose -f "$COMPOSE_FILE" stop "$SERVICE" >/dev/null 2>&1 && \
    echo "✅ 컨테이너 중지 완료: $SERVICE" || \
    echo "⚠️ 컨테이너 중지 실패 (무시)"
else
  echo "ℹ️ '$SERVICE' 관련 컨테이너 없음 (stop 스킵)"
fi

# 2️⃣ 컨테이너 및 볼륨 삭제
if docker compose -f "$COMPOSE_FILE" ps -a | grep -q "$SERVICE"; then
  docker compose -f "$COMPOSE_FILE" rm -f -v "$SERVICE" >/dev/null 2>&1 && \
    echo "✅ 컨테이너 및 볼륨 삭제 완료: $SERVICE" || \
    echo "⚠️ 컨테이너/볼륨 삭제 실패 (무시)"
else
  echo "ℹ️ '$SERVICE' 관련 컨테이너 없음 (rm 스킵)"
fi

# 3️⃣ 이미지 삭제
IMAGE_ID=$(docker compose -f "$COMPOSE_FILE" images -q "$SERVICE" | head -n1)
if [[ -n "$IMAGE_ID" ]]; then
  echo "🧩 기존 이미지 삭제: $IMAGE_ID"
  docker rmi -f "$IMAGE_ID" >/dev/null 2>&1 && \
    echo "✅ 이미지 삭제 완료" || \
    echo "⚠️ 이미지 삭제 실패 (무시)"
else
  echo "ℹ️ '$SERVICE' 관련 이미지 없음 (rmi 스킵)"
fi

echo "✅ docker compose 기반 컨테이너/이미지/볼륨 정리 완료"



# ---------- compose.yml 블록 삭제 ----------
echo "🧹 docker-compose.yml 에서 서비스 블록 제거 중..."

# SERVICE 단어가 처음 등장하는 줄 번호를 찾음
LINE_NUM=$(grep -n "$SERVICE" "$FILE" | head -n 1 | cut -d: -f1 || echo 0)

if [[ "$LINE_NUM" -gt 0 ]]; then
  # 바로 윗줄부터 20줄 삭제
  START=$((LINE_NUM - 1))
  END=$((START + 19))
  sed -i "${START},${END}d" "$FILE"
  echo "✅ ${SERVICE} 관련 블록 (${START}~${END}행) 삭제 완료"
else
  echo "⚠️ '${SERVICE}' 문자열을 docker-compose.yml에서 찾지 못했습니다."
  echo "⚠️ compose 블록 삭제 실패 → 롤백 실행"
  rollback
  exit 1
fi

# ---------- 원격 nginx 블록 삭제 ----------
echo "🌐 원격 nginx 블록 삭제 중..."
if ! ssh root@"${REMOTE_HOST}" "
SERVICE=\"${SERVICE}\"
FILE=\"${REMOTE_NGINX_FILE}\"

# 1️⃣ SERVICE 포함된 첫 줄 번호
LINE_NUM=\$(grep -n \"\${SERVICE}\" \"\$FILE\" | head -n 1 | cut -d: -f1 || echo 0)

if [[ \"\$LINE_NUM\" -gt 0 ]]; then
  # 2️⃣ 위로 올라가며 가장 가까운 ## 시작 줄 번호 탐색
  START=\$(awk -v target=\$LINE_NUM 'NR<=target && /^##/ {pos=NR} END{print pos+0}' \"\$FILE\")
  (( START < 1 )) && START=1  # 파일 맨 위 방지

  # 3️⃣ SERVICE 이후 첫 번째 } 줄 번호
  END_LINE=\$(awk -v start=\$LINE_NUM 'NR>=start && /}/ {print NR; exit}' \"\$FILE\")
  END=\$((END_LINE + 2))  # } 아래로 2줄 포함

  # 4️⃣ 실제 삭제
  sed -i \"\${START},\${END}d\" \"\$FILE\"

  echo \"✅ nginx 블록 (\${START}~\${END}행) 삭제 완료\"
else
  echo \"⚠️ '\${SERVICE}' 문자열을 \${FILE}에서 찾지 못했습니다.\"
  exit 1
fi

# 5️⃣ nginx 설정 리로드 (문법검사 + reload)
if nginx -t >/dev/null 2>&1; then
  nginx -s reload
  echo \"🔄 nginx reload 완료\"
else
  echo \"⚠️ nginx 설정 문법 오류 → reload 건너뜀\"
fi
"; then
  echo "⚠️ 원격 nginx 블록 삭제 실패 → 롤백 실행"
  rollback
  exit 1
fi
echo "✅ 원격 nginx 블록 삭제 완료"


# ---------- 정상 종료 ----------
trap - ERR INT TERM
echo "🎉 모든 삭제 작업 완료"
echo "  compose 백업: $COMPOSE_BAK"
echo "  원격 nginx 백업: ${REMOTE_HOST}:${REMOTE_BAK}"
