
#include <avr/io.h> 
#include <stdlib.h>
#include "USBtoSerial.h"
#include <util/delay.h>
#include "TM1001A.h"
#include "motors.h"
#include "misc.h"
#include "pins.h"


int16_t plate_pos_x = 0,plate_pos_y = 0;
  
void print_steps_in_mm(int16_t steps) {
  int16_t predot,postdot;
  
  predot = steps/24;
  postdot = ((abs(steps)%24)*417)/10;
  uart_print_signed_number(predot,3);
  uart_putc('.');
  uart_print_number_wlzeros(postdot,3);
  
}
  
void pos_report(void){ 
    uart_puts("x_pos: ");
    print_steps_in_mm(plate_pos_x);
    uart_puts("  y_pos: ");
    print_steps_in_mm(plate_pos_y);
    uart_puts("  end_sw: ");
    uart_print_number_wlzeros(XEND2_state(),1);
    uart_print_number_wlzeros(XEND1_state(),1);
    uart_print_number_wlzeros(YEND2_state(),1);
    uart_print_number_wlzeros(YEND1_state(),1);
    uart_puts("\r\n");
}



typedef enum {POSITION, GOTO, MOVEREL, SETZERO} action_t;

void parse_command(void){
  
  static char cmdbuffer[32];
  static char numbuffer[16];
  static uint16_t predot = 0,postdot = 0;
  static uint8_t cmdPos, curCmdLen, num_start = 0, nums_found = 0;
  uint8_t axis=0;
  action_t action = POSITION;
  int8_t num_sign = 1;
  char byte;
  
  /* Load the next byte from the USART transmit buffer into the USART */
  
  uint16_t pop = uart_getc();
  if(!(pop == EMPTY)){ 
  
    byte = (char) pop;
    
    if (byte == '\r' || byte == '\n') {// end of command, evaluate cemmand!
      uart_puts("\r\n");
      cmdbuffer[cmdPos] = '\0'; // terminate new command string
      curCmdLen = cmdPos;
      cmdPos = 0;
      
      
      if (cmdbuffer[0] == 'g' || cmdbuffer[0] == 'G') { // goto command
        action = GOTO;
      } else if ( cmdbuffer[0] == 'm' || cmdbuffer[0] == 'M') {
        action = MOVEREL;
      } else if ( cmdbuffer[0] == 'z' || cmdbuffer[0] == 'Z' ) {
        action = SETZERO;
      } else {
        action = POSITION;
      }
      
      if (cmdbuffer[1] == 'x' || cmdbuffer[1] == 'X') {
        axis = X;
      } else if (cmdbuffer[1] == 'y' || cmdbuffer[1] == 'Y') {
        axis = Y;
      }
      
      // if you expect coordinate, parse number!
      if (action == GOTO || action == MOVEREL){

        predot = 0;
        postdot = 0;
        num_sign = 1;
        num_start = 0;
        nums_found = 0;
        
        for (uint8_t i=2; i<=curCmdLen; i++) {
           if ( num_start == 0 && cmdbuffer[i] == '-' ) { // if you find a minus before
            // you find a digit, it's a negative number
             num_sign = -1;
           }
           
           if ( cmdbuffer[i] >= 48 && cmdbuffer[i] <= 57 ){ // is it a number?
             if ( num_start == 0) { // this is the first digit in the string
               num_start = i;
             }
           } else { // no digit!
             if ( num_start != 0) { // digits have been found before
                strncpy(numbuffer,cmdbuffer+num_start,i-num_start); // copy number found to
                // numbuffer
                numbuffer[i-num_start] = '\0'; // make sure it's always a terminated string
                nums_found++;
                if(nums_found == 1) { // its the predot digits
                  predot = atoi(numbuffer);
                } else { // its the postdot digits
                  uint8_t postdotlen = i-num_start;
                  if (postdotlen < 3){ // if too small ,fill with zeros
                    for( uint8_t j = postdotlen; j <=2; j++) {
                      numbuffer[j] = '0';
                    }
                  }
                  // crop the number to three post dot digits
                  numbuffer[3] = '\0';
                  
                  postdot = atoi(numbuffer);
                }
                num_start = 0;
             }
           }
        }
        
      }
      
      int16_t steps = 0,dest=0;
      
      switch (action) {
        case GOTO:
          uart_puts("GOTO ");
          uart_putc(88+axis);// x or y
          uart_putc(' ');
          uart_print_signed_number(predot*num_sign,3);
          uart_putc('.');
          uart_print_number_wlzeros(postdot,3);
          uart_puts("\r\n"); 
          
          dest = num_sign *( predot*24 +(postdot*10)/416);
          
          if (axis == X) {
            steps = dest - plate_pos_x; // experimental correction!
            move_plate(steps,0);
            plate_pos_x += steps;
          } else if (axis == Y) {
            steps = dest - plate_pos_y;
            move_plate(0,steps);
            plate_pos_y += steps;
          }
          pos_report();
          
          break;
        case MOVEREL:
          uart_puts("MOVE ");
          uart_putc(88+axis);// x or y
          uart_putc(' ');
          uart_print_signed_number(predot*num_sign,3);
          uart_putc('.');
          uart_print_number_wlzeros(postdot,3);
          uart_puts("\r\n"); 
          
          steps = num_sign *( predot*24 +(postdot*10)/416);
          
          if (axis == X) {
            move_plate(steps,0);
            plate_pos_x += steps;
          } else if (axis == Y) {
            move_plate(0,steps);
            plate_pos_y += steps;
          }
          pos_report();
          break;
          
        case SETZERO:
          plate_pos_x = 0;
          plate_pos_y = 0;
          pos_report();
          break;
          
        case POSITION:
          pos_report();
          break;
        
      }
      
      
      
    } else { // queue command
      if( cmdPos == 0 ){
        uart_puts("\r\n$ ");
      }
      
      if( byte == 8 ){ // backspace
        cmdPos--;
      } else {
        cmdbuffer[cmdPos++] = byte;
      }
      uart_putc(byte);
      

    }
  }
}



int main(void){
 
  init_motors();
  
  SetupHardware();

  touchpad_init(); // you need to call this to setup the I/O pin!
  _delay_ms(500);
  sei();
  
  touchpad_set_rel_mode_100dpi();// use touchpad in relative mode
  int8_t dx, dy = 0;
  uint8_t busy = 0, last_busy = 0;

  while (1) {
    Usb2SerialTask();
    parse_command(); // read data from virtual comport
    touchpad_read(); // read data from touchpad
    dx = 4*delta_x();// returns the amount your finger has moved in x direction since last readout
    dy = -4*delta_y();// returns the amount your finger has moved in y direction since last readout

    plate_pos_x += dx;
    plate_pos_y += dy;
    
    last_busy = busy;
    busy = move_plate(dx,dy);
    
    if (last_busy && !(busy)){
      pos_report();

    }
  }


} // end of main