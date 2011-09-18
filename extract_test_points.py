#! /sw/bin/python2.5
# -*- coding: utf-8 -*-

# pull RV8 test points MySQL, parse them, then output selected data delimited by tabs.

"""
Connect to the local MySQL RV-8 test point database.  Extract the list of test points.

Output selected columns in a tab delimited file.

"""

import MySQLdb

columns = [
    ('phase', 'Test Phase'),
    ('tp', 'Test Point #'),
    ('test', 'Test'),
    ('speed', 'Air Speed (KIAS)'),
    ('altitude', 'Altitude (ft)'),
    ('power', 'Power'),
    ('flaps', 'Flap Position'),
    ('wt', 'Weight'),
    ('cg', 'CG'),
    ('status', 'Status'),
    ('remarks', 'Remarks'),
    ]

tp_db = MySQLdb.connect(host='localhost', user='ft', passwd='ft',
                        db='ft_program')

c = tp_db.cursor()

select_line = 'SELECT ' + ', '.join([x[0] for x in columns])\
     + ' FROM test_program ORDER BY ID'
c.execute(select_line)

result = c.fetchall()

# print header for columns
print '\t'.join([x[1] for x in columns])

# print data
for item in result:
    item = list(item)
    for (n, data_item) in enumerate(item):
        item[n] = str(data_item)
    print '\t'.join(item)
