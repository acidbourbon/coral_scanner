#include <avr/io.h> 
#include <stdlib.h>
#include <util/delay.h>
#include "motors.h"
#include "plate.h"
#include "misc.h"
#include "pins.h"



// plate stuff

int32_t plate_pos_x = 0,plate_pos_y = 0;

int32_t get_plate_pos_x(void){
  return plate_pos_x;
}
void set_plate_pos_x(int32_t value){
  plate_pos_x = value;
}
int32_t get_plate_pos_y(void){
  return plate_pos_y;
}
void set_plate_pos_y(int32_t value){
  plate_pos_y = value;
}


uint8_t move_plate(int32_t dx, int32_t dy){
  static int32_t todo_x,todo_y = 0;
  int8_t signum;
  static uint8_t busy = 0;
  todo_x += dx;
  todo_y += dy;
  
  if( (dx!=0) || (dy!=0) ){
    busy = 1;
  };
  

  
  //if end switch closed, stop moving against the stop!
  if(XEND1_state() && (sign(todo_x) == 1) ){
    todo_x = 0;
  }
  if(XEND2_state() && (sign(todo_x) == -1) ){
    todo_x = 0;
  }
  if(YEND1_state() && (sign(todo_y) == 1) ){
    todo_y = 0;
  }
  if(YEND2_state() && (sign(todo_y) == -1) ){
    todo_y = 0;
  }
  
  
  signum = sign(todo_x);
  motor_step(X,signum);
  todo_x -= signum;
  plate_pos_x += signum;
  
  
  
  signum = sign(todo_y);
  motor_step(Y,signum);
  todo_y -= signum;
  plate_pos_y += signum;
  
  
  
  _delay_us(PHASE_DELAY_US);
  
  if( busy && (todo_x==0) && (todo_y==0) ){
    busy=0;
    return 1;
  } else {
    return 0;
  }
}







  


