#!/bin/bash
# @cmd: allrestart
# @desc: 전체 서비스 재시작 (Q-MES-* 전체 순회)
# @usage: ser allrestart
# --------------------------------------------
# Q-MES-로 시작하는 디렉토리의 이름을 추출해 restart.sh 실행
# 예: Q-MES-25G-jcfood-Q249 → ./restart.sh jcfood
# --------------------------------------------

for dir in Q-MES-*; do
  # 디렉토���가 아닌 경우 건너뜀
  [ -d "$dir" ] || continue
  # 디렉토리명에서 4번째 'jcfood' 부분만 추출
  # 형식: Q-MES-고유아이디-이부분-Q서버
  name=$(echo "$dir" | awk -F'-' '{print $4}')
  # name이 비어있지 않은 경우 재시작 실행
  if [ -n "$name" ]; then
    echo ">>> 재시작: $name"
    ./restart.sh "$name" || echo "? 실패: $name"
    sleep 1
  else
    echo "??  디렉토리 형식이 다름: $dir"
  fi
done


# 아래는 수동 리스트 방식 (비활성)
#list=(
#garamjj gsbrew bakefarm alchemaker 2qtech joven gsbio jcfood csbrew persnine
#hanatech kbio hmufood gubang geumsure jntek tamurkorea ucbrew jjtakju haedal
#dkt dmine geumsan sotm htjang scfnb dkfood sandeul gsfood bodeok dongsan sejsys
#systech haeram doorechon yugisaem baeron laolbio lmbio cyfood dameul mirico
#bnbrew altech c2 supiato dawnpack dasolint sejun littlekkoma tobeki onggozip
#)

#for name in "${list[@]}"; do
#  echo ">>> 재시작: $name"
#  ./restart.sh "$name" || echo "? 실패: $name"
#  sleep 1
#done
