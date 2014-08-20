#!/bin/bash

for i in *.dat; do

datfile=$i
datfilebase=$(echo $datfile| sed 's/.dat//')

cat <<EOF | gnuplot
#set terminal png
set terminal postscript enhanced solid color
set output "$datfilebase.ps"
plot "$datfile" using 1:2
EOF

done
