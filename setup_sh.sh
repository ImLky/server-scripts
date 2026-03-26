#!/bin/bash
# 용도: sh 파일의 줄바꿈(CRLF→LF) 변환 + 실행 권한 부여
# 사용법: ./setup_sh.sh <대상 sh 파일 경로>
# 예시:   ./setup_sh.sh /home/docker/dockerComposeSeting.sh

if [[ $# -lt 1 ]]; then
  echo ""
  echo "========================================"
  echo "  sh 파일 설정 스크립트"
  echo "========================================"
  echo ""
  echo "  용도: Windows에서 만든 sh 파일을 Linux에서 바로 실행 가능하도록 설정"
  echo ""
  echo "  수행 작업:"
  echo "    1. sed -i 's/\r$//' <파일>   — 줄바꿈 변환 (CRLF → LF)"
  echo "    2. chmod +x <파일>           — 실행 권한 부여"
  echo ""
  echo "  사용법:"
  echo "    $0 <대상 sh 파일 경로>"
  echo ""
  echo "  예시:"
  echo "    $0 /home/docker/dockerComposeSeting.sh"
  echo "    $0 ./test.sh"
  echo ""
  echo "========================================"
  exit 1
fi

TARGET="$1"

if [[ ! -f "$TARGET" ]]; then
  echo "[에러] 파일이 존재하지 않습니다: $TARGET"
  exit 1
fi

# CRLF → LF 변환
sed -i 's/\r$//' "$TARGET"
echo "[완료] 줄바꿈 변환 (CRLF→LF): $TARGET"

# 실행 권한 부여
chmod +x "$TARGET"
echo "[완료] 실행 권한 부여: $TARGET"

echo "[완료] 모든 설정 완료 ✅"
