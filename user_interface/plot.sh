#!/bin/bash

./analyzer.pl > out.dat
cat <<EOF | gnuplot
set terminal png
set output "plot.png"
plot "out.dat" using 1:2
EOF
display plot.png
