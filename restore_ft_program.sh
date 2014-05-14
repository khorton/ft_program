#! /bin/sh

if [ -f /home/kwh/hg/ft_program/test_card.pl ]; then
  echo "On EeePC"
#  cd /home/kwh/hg/ft_program
  /usr/bin/mysql -u ft -pft ft_program < ft_program_bu.sql
else
  echo "Not on EeePC"
  /sw/bin/mysql -u ft -pft ft_program < ft_program_bu.sql
fi

