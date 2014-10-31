#!/bin/bash

for i in *.dat; do

datfile=$i
datfilebase=$(echo $datfile| sed 's/.dat//')

cat <<EOF | gnuplot
set terminal png
#set terminal postscript enhanced solid color

set style line 1 lc rgb '#8b1a0e' pt 1 ps 1 lt 1 lw 2 # --- red
set style line 2 lc rgb '#5e9c36' pt 6 ps 1 lt 1 lw 2 # --- green

set style line 11 lc rgb '#808080' lt 1
set border 3 back ls 11
set tics nomirror

set style line 12 lc rgb '#808080' lt 0 lw 1
set grid back ls 12

set xlabel "bins"
set ylabel "counts"


set output "$datfilebase.png"
plot "$datfile" using 1:2
EOF

done
