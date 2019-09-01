#! /bin/sh

if [ -f ft_program_bu.sql ]
then
    rm ft_program_bu.sql
else
    echo "file not found - no need to delete"
fi

if [ -f /home/kwh/hg/ft_program/test_card.pl ]; then
  echo "On EeePC"
#  cd /home/kwh/hg/ft_program
/opt/local/lib/mariadb/bin/mysqldump -u ft -pft --order-by-primary --skip-extended-insert ft_program_multi > ft_program_multi_bu.sql
# /sw/bin/mysqldump -h 127.0.0.1 -u  -u ft -pft --order-by-primary --skip-extended-insert ft_program > ft_program_bu.sql
else
  echo "Not on EeePC"
  /opt/local/lib/mariadb/bin/mysqldump -u ft -pft --order-by-primary --skip-extended-insert ft_program_multi > ft_program_multi_bu.sql
  # /sw/bin/mysqldump -h 127.0.0.1 -u ft -pft --order-by-primary --skip-extended-insert ft_program_multi > ft_program_mulit_bu.sql
fi

