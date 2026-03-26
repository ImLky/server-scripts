#!/bin/bash
# --------------------------------------------
# Q-MES- 로 시작하는 폴더에서 이름 추출해 restart.sh 실행
# 예: Q-MES-25G-jcfood-Q249 → ./restart.sh jcfood
# --------------------------------------------

for dir in Q-MES-*; do
  # 폴더가 아닐 경우 건너뜀
  [ -d "$dir" ] || continue
  # 폴더명에서 중간 'jcfood' 부분만 추출
  # 형식: Q-MES-무엇이든-이부분-Q숫자
  name=$(echo "$dir" | awk -F'-' '{print $4}')
  # name이 비어있지 않을 때만 실행
  if [ -n "$name" ]; then
    echo ">>> 실행: $name"
    ./restart.sh "$name" || echo "? 실패: $name"
    sleep 1
  else
    echo "??  폴더명 형식이 다름: $dir"
  fi
done



#!/bin/bash
#list=(
#garamjj gsbrew bakefarm alchemaker 2qtech joven gsbio jcfood csbrew persnine
#hanatech kbio hmufood gubang geumsure jntek tamurkorea ucbrew jjtakju haedal
#dkt dmine geumsan sotm htjang scfnb dkfood sandeul gsfood bodeok dongsan sejsys
#systech haeram doorechon yugisaem baeron laolbio lmbio cyfood dameul mirico
#bnbrew altech c2 supiato dawnpack dasolint sejun littlekkoma tobeki onggozip
#)

#for name in "${list[@]}"; do
#  echo ">>> 실행: $name"
#  ./restart.sh "$name" || echo "? 실패: $name"  # 오류 표시
#  sleep 1
#done
