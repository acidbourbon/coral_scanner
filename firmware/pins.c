#include <avr/io.h> 
#include <stdlib.h>
#include "pins.h"


// functions for pin XEND1

void XEND1_set(uint8_t value){
  XEND1_PORT &= ~(1<<XEND1);
  XEND1_PORT |= (value & 0x01)<<XEND1;
}

void XEND1_as_output(void){
  XEND1_DDR |= 1<<XEND1;
}

void XEND1_as_input(void){
  XEND1_DDR &= ~(1<<XEND1);
}

void XEND1_as_pullup(void){
  XEND1_DDR  &= ~(1<<XEND1);
  XEND1_PORT |= 1<<XEND1;
}

uint8_t XEND1_state(void){
  return (XEND1_PIN & (1<<XEND1))>>XEND1;
}


// functions for pin XEND2

void XEND2_set(uint8_t value){
  XEND2_PORT &= ~(1<<XEND2);
  XEND2_PORT |= (value & 0x01)<<XEND2;
}

void XEND2_as_output(void){
  XEND2_DDR |= 1<<XEND2;
}

void XEND2_as_input(void){
  XEND2_DDR &= ~(1<<XEND2);
}

void XEND2_as_pullup(void){
  XEND2_DDR  &= ~(1<<XEND2);
  XEND2_PORT |= 1<<XEND2;
}

uint8_t XEND2_state(void){
  return (XEND2_PIN & (1<<XEND2))>>XEND2;
}


// functions for pin YEND1

void YEND1_set(uint8_t value){
  YEND1_PORT &= ~(1<<YEND1);
  YEND1_PORT |= (value & 0x01)<<YEND1;
}

void YEND1_as_output(void){
  YEND1_DDR |= 1<<YEND1;
}

void YEND1_as_input(void){
  YEND1_DDR &= ~(1<<YEND1);
}

void YEND1_as_pullup(void){
  YEND1_DDR  &= ~(1<<YEND1);
  YEND1_PORT |= 1<<YEND1;
}

uint8_t YEND1_state(void){
  return (YEND1_PIN & (1<<YEND1))>>YEND1;
}


// functions for pin YEND2

void YEND2_set(uint8_t value){
  YEND2_PORT &= ~(1<<YEND2);
  YEND2_PORT |= (value & 0x01)<<YEND2;
}

void YEND2_as_output(void){
  YEND2_DDR |= 1<<YEND2;
}

void YEND2_as_input(void){
  YEND2_DDR &= ~(1<<YEND2);
}

void YEND2_as_pullup(void){
  YEND2_DDR  &= ~(1<<YEND2);
  YEND2_PORT |= 1<<YEND2;
}

uint8_t YEND2_state(void){
  return (YEND2_PIN & (1<<YEND2))>>YEND2;
}


