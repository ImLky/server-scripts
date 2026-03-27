#!/bin/bash
# @cmd: allpull
# @desc: 전체 git pull (Q-MES-* 전체 순회)
# @usage: ser allpull

for dir in Q-MES-*; do
  if [ -d "$dir/.git" ]; then
    echo "=== $dir 디렉토리 git pull 실행 중 ==="
    cd "$dir" || exit
    git pull
    cd ..
  else
    echo "=== $dir 은(는) git 저장소가 아닙니다 ==="
  fi
done
