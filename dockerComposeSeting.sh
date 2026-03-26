#!/usr/bin/env bash
# @cmd: dcs
# @desc: 서비스 추가 (Docker Compose + Nginx)
# @usage: dcs <서비스명> <디렉토리명> <포트> <주석>
# @example: dcs abc q-mes 10001 '테스트 서비스'
# 목적: 서비스 추가 + 로컬 Nginx 없을 때 원격(192.168.0.150) Nginx 설정 추가, 실패 시 전체 롤백

set -euo pipefail

# ---------- 경로 설정 ----------
FILE="/home/docker/docker-compose.yml"
BACKUPFILE="/home/docker/docker-compose.yml_back/docker-compose.yml.bak"

# 로컬 Nginx 경로 — 없으면 스킵
NGINX_FILE="/etc/nginx/conf.d/150server/150sets.conf"
NGINX_BACKUPFILE="/etc/nginx/conf.d/150server/150sets.conf_back/150sets.conf.bak"

# 원격 Nginx 대상(249)
REMOTE_HOST="192.168.0.150"
REMOTE_NGINX_FILE="/etc/nginx/conf.d/249server/249sets.conf"
REMOTE_NGINX_BACKUPDIR="/etc/nginx/conf.d/249server/249sets.conf_back"

# ---------- 인자/환경 검증 ----------
if [[ $# -lt 4 ]]; then
  echo ""
  echo "================================================================"
  echo "  서비스 추가 스크립트 — 사용 설명서"
  echo "================================================================"
  echo ""
  echo "  용도: Docker Compose 서비스 추가 + Nginx 리버스프록시 자동 설정"
  echo ""
  echo "  사용법:"
  echo "    $0 <서비스명> <디렉토리명> <포트> <주석>"
  echo ""
  echo "  파라미터:"
  echo "    서비스명    — Docker 서비스/컨테이너 이름 (예: abc)"
  echo "    디렉토리명  — /home/mes/ 하위 소스 디렉토리 (예: q-mes)"
  echo "    포트        — 매핑할 포트 번호 (숫자만, 예: 10001)"
  echo "    주석        — docker-compose/Nginx에 남길 설명 (예: '테스트 서비스')"
  echo ""
  echo "  예시:"
  echo "    $0 abc q-mes 10001 '테스트 서비스'"
  echo "    $0 my-app q-mes-demo 10002 '데모 서비스 추가'"
  echo ""
  echo "  동작 흐름:"
  echo "    1. docker-compose.yml 백업 → 서비스 블록 추가"
  echo "    2. docker compose up -d (서비스 기동)"
  echo "    3. Nginx 설정 추가 (로컬 또는 원격 192.168.0.150)"
  echo "    4. 실패 시 전체 자동 롤백"
  echo ""
  echo "  주의사항:"
  echo "    - 동일 서비스명이 이미 있으면 추가하지 않음"
  echo "    - Nginx SSL 인증서 경로: /etc/nginx/ssl/wildcard_ezqai_co_kr__*"
  echo "    - 롤백 시 compose/Nginx 모두 원복됨"
  echo ""
  echo "================================================================"
  exit 1
fi

# ---------- 인자 ----------
a="$1"; b="$2"; c="$3"; shift 3
d="$*"

if [[ -z "${a}" || -z "${b}" || -z "${c}" || -z "${d}" ]]; then
  echo "[에러] 모든 파라미터를 입력해야 합니다."
  echo "사용법: $0 <서비스명> <디렉토리명> <포트> <주석>"
  echo "예) $0 abc q-mes 10001 '설명'"
  exit 1
fi
[[ "${c}" =~ ^[0-9]+$ ]] || { echo "[에러] 포트(c)는 숫자여야 합니다: ${c}"; exit 1; }
[[ -f "$FILE" ]] || { echo "[에러] compose 파일 없음: $FILE"; exit 1; }

# docker compose 커맨드 결정
if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  COMPOSE_CMD=(docker compose)
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE_CMD=(docker-compose)
else
  echo "[에러] docker compose/docker-compose 없음"
  exit 1
fi

# ---------- 롤백 준비 ----------
ts="$(date +%Y%m%d%H%M%S)"
mkdir -p -- "$(dirname -- "$BACKUPFILE")"
COMPOSE_BAK="${BACKUPFILE}.${ts}"
cp -a -- "$FILE" "$COMPOSE_BAK"

NGINX_BAK=""
REMOTE_NGINX_BAK=""
MOD_COMPOSE=0
MOD_NGINX=0
MOD_REMOTE_NGINX=0
STARTED=0

rollback() {
  echo "[롤백] 오류 발생 → 되돌리는 중..."

  # 서비스 종료/삭제
  if (( STARTED )); then
    echo "[롤백] 서비스 종료/삭제: $a"
    "${COMPOSE_CMD[@]}" -f "$FILE" rm -s -f "$a" || true
  fi

  # 로컬 Nginx 복구
  if (( MOD_NGINX )) && [[ -n "${NGINX_BAK}" && -f "${NGINX_BAK}" ]]; then
    echo "[롤백] 로컬 nginx 설정 복구: $NGINX_BAK -> $NGINX_FILE"
    mv -f -- "$NGINX_BAK" "$NGINX_FILE" || true
    if command -v nginx >/dev/null 2>&1; then
      nginx -t || true
      if command -v systemctl >/dev/null 2>&1 && systemctl is-active --quiet nginx; then
        systemctl reload nginx || true
      else
        nginx -s reload || true
      fi
    fi
  fi

  # 원격 Nginx 복구
  if (( MOD_REMOTE_NGINX )) && [[ -n "${REMOTE_NGINX_BAK}" ]]; then
    echo "[롤백] 원격 nginx 설정 복구: ${REMOTE_HOST}:${REMOTE_NGINX_BAK} -> ${REMOTE_NGINX_FILE}"
    ssh "root@${REMOTE_HOST}" bash -c "
      set -euo pipefail
      if [[ -f '${REMOTE_NGINX_BAK}' ]]; then
        mv -f -- '${REMOTE_NGINX_BAK}' '${REMOTE_NGINX_FILE}' || true
        if command -v nginx >/dev/null 2>&1; then
          nginx -t || true
          if command -v systemctl >/dev/null 2>&1 && systemctl is-active --quiet nginx; then
            systemctl reload nginx || true
          else
            nginx -s reload || true
          fi
        fi
      fi
    " || true
  fi

  # compose 복구
  if (( MOD_COMPOSE )); then
    echo "[롤백] compose 복구: $COMPOSE_BAK -> $FILE"
    mv -f -- "$COMPOSE_BAK" "$FILE" || true
  fi

  echo "[롤백 완료]"
}
trap 'rollback; exit 1' ERR INT TERM

# ---------- services: 키 보장 ----------
if ! grep -qE '^[[:space:]]*services:[[:space:]]*$' "$FILE"; then
  printf '\nservices:\n' >> "$FILE"
fi

# ---------- 중복 서비스 방지 ----------
esc_a="$(printf '%s' "$a" | sed 's/[][().^$*+?{}|\\/]/\\&/g')"
if grep -qE "^[[:space:]]{2}${esc_a}:[[:space:]]*$" "$FILE"; then
  echo "이미 존재: 서비스 '${a}' (추가 안 함). 백업: $COMPOSE_BAK"
  trap - ERR INT TERM
  exit 0
fi

# ---------- 서비스 블록 추가 ----------
tmpblk="$(mktemp)"
cat > "$tmpblk" <<EOF

# ${d}
  ${a}:
    build: /home/mes/${b}
    container_name: ${a}
    working_dir: /usr/src/app
    restart: unless-stopped
    ports:
      - "${c}:${c}"
    environment:
      - TZ=Asia/Seoul
      - PORT=${c}
    volumes:
      - /home/mes/${b}:/usr/src/app
      - /usr/src/app/node_modules
      - /usr/src/app/backend/node_modules
      - /etc/localtime:/etc/localtime:ro
    command: npm run start
    networks:
      - docker-network
EOF

awk -v blk="$tmpblk" '
BEGIN { inserted=0 }
$0 ~ /^networks:[[:space:]]*$/ && inserted==0 {
  while ((getline L < blk) > 0) print L
  close(blk); inserted=1
}
{ print }
END {
  if (inserted==0) {
    while ((getline L < blk) > 0) print L
    close(blk)
  }
}
' "$FILE" > "${FILE}.new"
mv -- "${FILE}.new" "$FILE"
rm -f "$tmpblk"
MOD_COMPOSE=1

echo "추가 완료: 서비스 '${a}' (포트 ${c}) → ${FILE}"
echo "compose 백업: $COMPOSE_BAK"

# ---------- compose 검증 & 기동 ----------
"${COMPOSE_CMD[@]}" -f "$FILE" config >/dev/null
"${COMPOSE_CMD[@]}" -f "$FILE" up -d "$a"
STARTED=1

# ---------- Nginx 설정 ----------
if [[ -f "$NGINX_FILE" ]]; then
  # 로컬 Nginx 파일 존재 → 로컬에 추가
  ngts="$(date +%Y%m%d%H%M%S)"
  mkdir -p -- "$(dirname -- "$NGINX_BACKUPFILE")"
  NGINX_BAK="${NGINX_BACKUPFILE}.${ngts}"
  cp -a -- "$NGINX_FILE" "$NGINX_BAK"

  if ! grep -qE "^[[:space:]]*server_name[[:space:]]+${a}\.ezqai\.co\.kr;[[:space:]]*$" "$NGINX_FILE"; then
    cat >> "$NGINX_FILE" <<EOF

## ${d}
server {
    listen 443 ssl;
    server_name ${a}.ezqai.co.kr;
    client_max_body_size 20M;
    ssl_certificate /etc/nginx/ssl/wildcard_ezqai_co_kr__bundle.pem;
    ssl_certificate_key /etc/nginx/ssl/wildcard_ezqai_co_kr__rsa.key;
    location / {
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header Host \$http_host;
        proxy_pass http://192.168.0.150:${c};
    }
}
EOF
    MOD_NGINX=1
    nginx -t
    if command -v systemctl >/dev/null 2>&1 && systemctl is-active --quiet nginx; then
      systemctl reload nginx
    else
      nginx -s reload
    fi
    echo "로컬 Nginx 블록 추가/리로드 완료 → $NGINX_FILE"
  else
    echo "이미 존재: server_name ${a}.ezqai.co.kr (로컬 Nginx 추가 생략). 백업: $NGINX_BAK"
  fi

else
  # 로컬 Nginx 파일 없음 → 원격(249)에서 추가
  echo "[스킵] 로컬 Nginx 설정 없음 → 원격에서 설정 시도: ${REMOTE_HOST}:${REMOTE_NGINX_FILE}"

  rts="$(date +%Y%m%d%H%M%S)"
  REMOTE_NGINX_BAK="${REMOTE_NGINX_BACKUPDIR}/249sets.conf.bak.${rts}"

  # 원격에서 일괄 처리(백업→중복검사→추가→테스트→리로드). 하나라도 실패 시 ERR → trap 롤백.
  ssh "root@${REMOTE_HOST}" bash -s -- "${REMOTE_NGINX_FILE}" "${REMOTE_NGINX_BACKUPDIR}" "${REMOTE_NGINX_BAK}" "${a}" "${c}" "${d}" <<'REMOTE_SCRIPT'
set -euo pipefail
REMOTE_NGINX_FILE="$1"
REMOTE_NGINX_BACKUPDIR="$2"
REMOTE_NGINX_BAK="$3"
SVC_NAME="$4"
SVC_PORT="$5"
SVC_NOTE="$6"

# 백업 디렉토리 생성 및 백업
mkdir -p -- "${REMOTE_NGINX_BACKUPDIR}"
cp -a -- "${REMOTE_NGINX_FILE}" "${REMOTE_NGINX_BAK}"

# server_name 중복 검사
if ! grep -qE "^[[:space:]]*server_name[[:space:]]+${SVC_NAME}\.ezqai\.co\.kr;[[:space:]]*$" "${REMOTE_NGINX_FILE}"; then
  cat >> "${REMOTE_NGINX_FILE}" <<EOF

## ${SVC_NOTE}
server {
    listen 443 ssl;
    server_name ${SVC_NAME}.ezqai.co.kr;
    client_max_body_size 20M;
    ssl_certificate /etc/nginx/ssl/wildcard_ezqai_co_kr__bundle.pem;
    ssl_certificate_key /etc/nginx/ssl/wildcard_ezqai_co_kr__rsa.key;
    location / {
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header Host \$http_host;
        proxy_pass http://192.168.0.249:${SVC_PORT};
    }
}
EOF
fi

# nginx 설정 테스트 & 리로드
nginx -t
if command -v systemctl >/dev/null 2>&1 && systemctl is-active --quiet nginx; then
  systemctl reload nginx
else
  nginx -s reload
fi
REMOTE_SCRIPT

  MOD_REMOTE_NGINX=1
  echo "원격(249) Nginx 블록 추가/리로드 완료 → ${REMOTE_HOST}:${REMOTE_NGINX_FILE}"
fi

# ---------- 정상 종료 ----------
trap - ERR INT TERM
echo "모든 작업 완료 ✅"
echo "compose 백업: $COMPOSE_BAK"
[[ -n "${NGINX_BAK}" ]] && echo "로컬 nginx 백업: $NGINX_BAK"
[[ -n "${REMOTE_NGINX_BAK}" ]] && echo "원격 nginx 백업: ${REMOTE_HOST}:${REMOTE_NGINX_BAK}"
