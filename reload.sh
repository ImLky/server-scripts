#!/bin/bash
# @cmd: reload
# @desc: 스크립트 최신화 (git pull + bashrc 재적용)
# @usage: ser reload
# 용도: server-scripts 폴더를 git pull로 최신화하고 환경변수 재적용

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "[INFO] 스크립트 최신화 시작..."

# git pull
if [ -d "$SCRIPT_DIR/.git" ]; then
  cd "$SCRIPT_DIR"
  git pull
  echo "[INFO] git pull 완료"
else
  echo "[WARN] $SCRIPT_DIR 은 git 저장소가 아닙니다."
fi

# bashrc 재적용 (set +u: 시스템 bashrc의 미설정 변수 허용)
echo "[INFO] bashrc 재적용..."
set +u
source ~/.bashrc
set -u

echo "[INFO] 스크립트 최신화 완료 ✅"
