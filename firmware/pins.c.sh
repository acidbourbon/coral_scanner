#!/bin/bash

cat <<EOF
#include <avr/io.h> 
#include <stdlib.h>
#include "pins.h"


EOF

for i in $@
do
cat <<EOF
// functions for pin $i

void ${i}_set(uint8_t value){
  ${i}_PORT &= ~(1<<$i);
  ${i}_PORT |= (value & 0x01)<<$i;
}

void ${i}_as_output(void){
  ${i}_DDR |= 1<<$i;
}

void ${i}_as_input(void){
  ${i}_DDR &= ~(1<<$i);
}

void ${i}_as_pullup(void){
  ${i}_DDR  &= ~(1<<$i);
  ${i}_PORT |= 1<<$i;
}

uint8_t ${i}_state(void){
  return (${i}_PIN & (1<<$i))>>$i;
}


EOF
done
