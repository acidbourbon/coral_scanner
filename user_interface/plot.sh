#!/bin/bash

left=$1
right=$2

./analyzer.pl > out.dat
cat <<EOF | gnuplot
set terminal png
# set terminal postscript enhanced solid color
set output "plot.png"
#set xrange [$left:$right]


set style line 1 lc rgb '#8b1a0e' pt 1 ps 1 lt 1 lw 2 # --- red
set style line 2 lc rgb '#5e9c36' pt 6 ps 1 lt 1 lw 2 # --- green

set style line 11 lc rgb '#808080' lt 1
set border 3 back ls 11
set tics nomirror

set style line 12 lc rgb '#808080' lt 0 lw 1
set grid back ls 12

set xlabel "bins"
set ylabel "counts"


plot "out.dat" using 1:2

EOF
#display plot.png
