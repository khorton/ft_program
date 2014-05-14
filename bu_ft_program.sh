#! /bin/sh

rm ft_program_bu.sql

if [ -f /home/kwh/hg/ft_program/test_card.pl ]; then
  echo "On EeePC"
#  cd /home/kwh/hg/ft_program
  /usr/bin/mysqldump -u ft -pft --order-by-primary --skip-extended-insert ft_program > ft_program_bu.sql
else
  echo "Not on EeePC"
  /sw/bin/mysqldump -u ft -pft --order-by-primary --skip-extended-insert ft_program > ft_program_bu.sql
fi

