#!/bin/bash

file=deadtime_analysis.dat

>$file

echo -e "#deadtime in us\t#counts"

for t in $(seq 0 1 40)
do
./pmt_ro.pl sub=dead_time value=$t unit=us
counts=$(./pmt_ro.pl sub=count channel=signal delay=5)

echo -e "$t\t$counts" 
echo -e "$t\t$counts" >> $file
done
