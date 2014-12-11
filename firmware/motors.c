#include <avr/io.h> 
#include <stdlib.h>
#include <util/delay.h>
#include "motors.h"
#include "misc.h"





/* motor stuff */

uint8_t phase_pattern[4] = { 0b00001010, 0b00001001, 0b00000101, 0b00000110};
    
    
void set_x(uint8_t byte) {
  PORTX0 &= ~(1<<X0);
  PORTX1 &= ~(1<<X1);
  PORTX2 &= ~(1<<X2);
  PORTX3 &= ~(1<<X3);

  PORTX0 |= ((byte & (1<<0))>>0)<<X0;
  PORTX1 |= ((byte & (1<<1))>>1)<<X1;
  PORTX2 |= ((byte & (1<<2))>>2)<<X2;
  PORTX3 |= ((byte & (1<<3))>>3)<<X3;
}

void set_y(uint8_t byte) {
  PORTY0 &= ~(1<<Y0);
  PORTY1 &= ~(1<<Y1);
  PORTY2 &= ~(1<<Y2);
  PORTY3 &= ~(1<<Y3);

  PORTY0 |= ((byte & (1<<0))>>0)<<Y0;
  PORTY1 |= ((byte & (1<<1))>>1)<<Y1;
  PORTY2 |= ((byte & (1<<2))>>2)<<Y2;
  PORTY3 |= ((byte & (1<<3))>>3)<<Y3;
}

void init_motors(void){
  set_x(0);
  set_y(0);
  DDRX0 |= (1<<X0);
  DDRX1 |= (1<<X1);
  DDRX2 |= (1<<X2);
  DDRX3 |= (1<<X3);
  DDRY0 |= (1<<Y0);
  DDRY1 |= (1<<Y1);
  DDRY2 |= (1<<Y2);
  DDRY3 |= (1<<Y3);
}



uint8_t motor_step(uint8_t motor, int8_t direction) { // motor: M1 or M2, direction +1 or -1, 0 for coil deactivation

  uint8_t next_pattern, next_phase;
  static uint8_t phase_memory[2] = { 0, 0 };
  void (*setport)(uint8_t);
  setport = &set_x;
  
  switch(motor) {
    case X:
      setport = &set_x;
      break;
    case Y:
      setport = &set_y;
      break;
  }

  next_phase = (phase_memory[motor] + 4 + direction) % 4;
  phase_memory[motor] = next_phase;
  

  next_pattern = phase_pattern[next_phase];
  if (direction != 0) {
      (*setport)(next_pattern);
  } else {
      (*setport)(0);
  }

  return next_pattern;

}



uint8_t move_plate(int16_t dx, int16_t dy){
  static int16_t todo_x,todo_y = 0;
  int8_t signum;
  uint8_t returnval = 0;
  todo_x += dx;
  todo_y += dy;
  
  signum = sign(todo_x);
  if(signum != 0) {
    returnval++;
  }
  motor_step(X,signum);
  todo_x -= signum;
  
  signum = sign(todo_y);
  if(signum != 0) {
    returnval++;
  }
  motor_step(Y,signum);
  todo_y -= signum;
  _delay_us(PHASE_DELAY_US);
  
  return returnval; // busy
  
}







  


