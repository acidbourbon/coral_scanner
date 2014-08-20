#!/bin/bash

left=$1
right=$2

./analyzer.pl > out.dat
cat <<EOF | gnuplot
#set terminal png
set terminal postscript enhanced solid color
set output "plot.ps"
#set xrange [$left:$right]
plot "out.dat" using 1:2
EOF
#display plot.png
