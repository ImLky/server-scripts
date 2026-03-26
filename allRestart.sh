#!/bin/bash
# @cmd: allrestart
# @desc: 전체 서비스 재시작 (Q-MES-* 전체 순회)
# @usage: allrestart
# --------------------------------------------
# Q-MES- �� �����ϴ� �������� �̸� ������ restart.sh ����
# ��: Q-MES-25G-jcfood-Q249 �� ./restart.sh jcfood
# --------------------------------------------

for dir in Q-MES-*; do
  # ������ �ƴ� ��� �ǳʶ�
  [ -d "$dir" ] || continue
  # ���������� �߰� 'jcfood' �κи� ����
  # ����: Q-MES-�����̵�-�̺κ�-Q����
  name=$(echo "$dir" | awk -F'-' '{print $4}')
  # name�� ������� ���� ���� ����
  if [ -n "$name" ]; then
    echo ">>> ����: $name"
    ./restart.sh "$name" || echo "? ����: $name"
    sleep 1
  else
    echo "??  ������ ������ �ٸ�: $dir"
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
#  echo ">>> ����: $name"
#  ./restart.sh "$name" || echo "? ����: $name"  # ���� ǥ��
#  sleep 1
#done
