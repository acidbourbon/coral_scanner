#!/bin/bash

mkdir scan_pattern_animation

for i in $(seq 1 0.03 3 | sed 's/,/./g'); do
./table_control.pl sub=save_settings sample_step_size=$i 
./table_control.pl sub=scan_pattern_to_svg 
inkscape scan_pattern.svg --export-png="./scan_pattern_animation/scan_pattern_"$i".png"
done

cd scan_pattern_animation
mencoder mf://*.png -mf w=800:h=600:fps=25:type=png -ovc lavc -lavcopts vcodec=mpeg4:mbd=2:trell -oac copy -o output.avi
