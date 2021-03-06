# gnuplot script file
# 
# Fuel burn and CG chart for Test Cards with 1900 lb MTOW
#

reset
#set terminal pdf
set terminal epslatex
#set terminal aqua

set grid xtics ytics mxtics mytics

#set grid lt 4 lw 2 , lt 0 lw 1 	# lt 0 = black dashed line.
									# lt 1 = grey solid line
									# lt 2 & 3 both appear to be grey dashed lines
									# lt 4 is short dashed line
									# lt 5 is long and short dashed line

set nokey	# turn off label in top right hand corner

set xzeroaxis lt -1 lw 2

set output '>>>GNUPLOT_DIR<<<wb_chart.tex'

set size 0.8,1

set label "Start" at <<<START>>> front
set label "Zero Fuel" at <<<END>>> front

set label '\ding{172}' at 78.7,1770 back
set label '\ding{173}' at 78.7,1520 back
set label '\ding{174}' at 86.25,1770 back
set label '\ding{175}' at 78.7,1870 back


set label '\ding{172} Restricted Aerobatic Weight/CG Envelope' at 78,800
set label '\ding{173} Aerobatic Weight/CG Envelope' at 78,730
set label '\ding{174} Normal Weight/CG Envelope' at 78,660
set label '\ding{175} Heavy Weight/CG Envelope' at 78,590

set xlabel "CG (inches aft of datum)"
set ylabel "Weight (lb)"

set xrange [78:88]
set yrange [1100:2000]

set xtics 78,1,88
set mxtics 2     # set minor tics on X-axis, with 5 divisions per major tic
set mytics 2     # set minor tics on Y-axis, with 2 divisions per major tic

unset grid

set key
plot '>>>GNUPLOT_DIR<<<cg_chart_1900.txt' with lines lt -1 lw 2 notitle,\
'>>>GNUPLOT_DIR<<<ft_card_wb.txt' with linespoints lt -1 lw 4 title "Fuel Burn"
