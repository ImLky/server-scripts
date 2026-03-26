#!/bin/bash
# @cmd: allpull
# @desc: 전체 git pull (Q-MES-* 전체 순회)
# @usage: allpull

for dir in Q-MES-*; do
  if [ -d "$dir/.git" ]; then
    echo "=== $dir �������� git pull ���� �� ==="
    cd "$dir" || exit
    git pull
    cd ..
  else
    echo "=== $dir ��(��) git ����Ұ� �ƴմϴ� ==="
  fi
done
