/*
             LUFA Library
     Copyright (C) Dean Camera, 2013.

  dean [at] fourwalledcubicle [dot] com
           www.lufa-lib.org
*/

/*
  Copyright 2013  Dean Camera (dean [at] fourwalledcubicle [dot] com)

  Permission to use, copy, modify, distribute, and sell this
  software and its documentation for any purpose is hereby granted
  without fee, provided that the above copyright notice appear in
  all copies and that both that the copyright notice and this
  permission notice and warranty disclaimer appear in supporting
  documentation, and that the name of the author not be used in
  advertising or publicity pertaining to distribution of the
  software without specific, written prior permission.

  The author disclaims all warranties with regard to this
  software, including all implied warranties of merchantability
  and fitness.  In no event shall the author be liable for any
  special, indirect or consequential damages or any damages
  whatsoever resulting from loss of use, data or profits, whether
  in an action of contract, negligence or other tortious action,
  arising out of or in connection with the use or performance of
  this software.
*/

/** \file
 *
 *  Main source file for the USBtoSerial project. This file contains the main tasks of
 *  the project and is responsible for the initial application hardware configuration.
 */
// #define F_CPU 16e6

#include <avr/io.h> 
#include <stdlib.h>
#include "USBtoSerial.h"
#include <util/delay.h>
#include "TM1001A.h"
// #include "rfm70.c"
#include "pins.h"
#include "leds.c"

int16_t plate_pos_x = 0,plate_pos_y = 0;
char stringbuffer[16];

/** Circular buffer to hold data from the host before it is sent to the device via the serial port. */
static RingBuffer_t USBtoUSART_Buffer;

/** Underlying data buffer for \ref USBtoUSART_Buffer, where the stored bytes are located. */
static uint8_t      USBtoUSART_Buffer_Data[128];

/** Circular buffer to hold data from the serial port before it is sent to the host. */
static RingBuffer_t USARTtoUSB_Buffer;

/** Underlying data buffer for \ref USARTtoUSB_Buffer, where the stored bytes are located. */
static uint8_t      USARTtoUSB_Buffer_Data[128];

/** LUFA CDC Class driver interface configuration and state information. This structure is
 *  passed to all CDC Class driver functions, so that multiple instances of the same class
 *  within a device can be differentiated from one another.
 */
USB_ClassInfo_CDC_Device_t VirtualSerial_CDC_Interface =
	{
		.Config =
			{
				.ControlInterfaceNumber         = 0,
				.DataINEndpoint                 =
					{
						.Address                = CDC_TX_EPADDR,
						.Size                   = CDC_TXRX_EPSIZE,
						.Banks                  = 1,
					},
				.DataOUTEndpoint                =
					{
						.Address                = CDC_RX_EPADDR,
						.Size                   = CDC_TXRX_EPSIZE,
						.Banks                  = 1,
					},
				.NotificationEndpoint           =
					{
						.Address                = CDC_NOTIFICATION_EPADDR,
						.Size                   = CDC_NOTIFICATION_EPSIZE,
						.Banks                  = 1,
					},
			},
	};





void Usb2SerialTask(void) {
  
    /* Only try to read in bytes from the CDC interface if the transmit buffer is not full */
    if (!(RingBuffer_IsFull(&USBtoUSART_Buffer)))
    {
      int16_t ReceivedByte = CDC_Device_ReceiveByte(&VirtualSerial_CDC_Interface);

      /* Read bytes from the USB OUT endpoint into the USART transmit buffer */
      if (!(ReceivedByte < 0))
        RingBuffer_Insert(&USBtoUSART_Buffer, ReceivedByte);
    }

    /* Check if the UART receive buffer flush timer has expired or the buffer is nearly full */
    uint16_t BufferCount = RingBuffer_GetCount(&USARTtoUSB_Buffer);
    if (BufferCount)
    {
      Endpoint_SelectEndpoint(VirtualSerial_CDC_Interface.Config.DataINEndpoint.Address);

      /* Check if a packet is already enqueued to the host - if so, we shouldn't try to send more data
       * until it completes as there is a chance nothing is listening and a lengthy timeout could occur */
      if (Endpoint_IsINReady())
      {
        /* Never send more than one bank size less one byte to the host at a time, so that we don't block
         * while a Zero Length Packet (ZLP) to terminate the transfer is sent if the host isn't listening */
        uint8_t BytesToSend = MIN(BufferCount, (CDC_TXRX_EPSIZE - 1));

        /* Read bytes from the USART receive buffer into the USB IN endpoint */
        while (BytesToSend--)
        {
          /* Try to send the next byte of data to the host, abort if there is an error without dequeuing */
          if (CDC_Device_SendByte(&VirtualSerial_CDC_Interface,
                      RingBuffer_Peek(&USARTtoUSB_Buffer)) != ENDPOINT_READYWAIT_NoError)
          {
            break;
          }

          /* Dequeue the already sent byte from the buffer now we have confirmed that no transmission error occurred */
          RingBuffer_Remove(&USARTtoUSB_Buffer);
        }
      }
    }

    /* Load the next byte from the USART transmit buffer into the USART */
//     if (!(RingBuffer_IsEmpty(&USBtoUSART_Buffer))) {
//       Serial_SendByte(RingBuffer_Remove(&USBtoUSART_Buffer));
//      dummy = RingBuffer_Remove(&USBtoUSART_Buffer);
//      sendPayload(&dummy,1,0);
//     }
    CDC_Device_USBTask(&VirtualSerial_CDC_Interface);
    USB_USBTask();
  
}



/** Configures the board hardware and chip peripherals for the demo's functionality. */
void SetupHardware(void)
{
	/* Disable watchdog if enabled by bootloader/fuses */
	MCUSR &= ~(1 << WDRF);
	wdt_disable();

	/* Disable clock division */
	clock_prescale_set(clock_div_1);

	/* Hardware Initialization */
// 	LEDs_Init();
	USB_Init();
}

/** Event handler for the library USB Connection event. */
void EVENT_USB_Device_Connect(void)
{
// 	LEDs_SetAllLEDs(LEDMASK_USB_ENUMERATING);
}

/** Event handler for the library USB Disconnection event. */
void EVENT_USB_Device_Disconnect(void)
{
// 	LEDs_SetAllLEDs(LEDMASK_USB_NOTREADY);
}

/** Event handler for the library USB Configuration Changed event. */
void EVENT_USB_Device_ConfigurationChanged(void)
{
	bool ConfigSuccess = true;

	ConfigSuccess &= CDC_Device_ConfigureEndpoints(&VirtualSerial_CDC_Interface);

// 	LEDs_SetAllLEDs(ConfigSuccess ? LEDMASK_USB_READY : LEDMASK_USB_ERROR);
}

/** Event handler for the library USB Control Request reception event. */
void EVENT_USB_Device_ControlRequest(void)
{
	CDC_Device_ProcessControlRequest(&VirtualSerial_CDC_Interface);
}

/** ISR to manage the reception of data from the serial port, placing received bytes into a circular buffer
 *  for later transmission to the host.
 */
ISR(USART1_RX_vect, ISR_BLOCK)
{
	uint8_t ReceivedByte = UDR1;

	if (USB_DeviceState == DEVICE_STATE_Configured)
	  RingBuffer_Insert(&USARTtoUSB_Buffer, ReceivedByte);
}

/** Event handler for the CDC Class driver Line Encoding Changed event.
 *
 *  \param[in] CDCInterfaceInfo  Pointer to the CDC class interface configuration structure being referenced
 */
void EVENT_CDC_Device_LineEncodingChanged(USB_ClassInfo_CDC_Device_t* const CDCInterfaceInfo)
{
	uint8_t ConfigMask = 0;

	switch (CDCInterfaceInfo->State.LineEncoding.ParityType)
	{
		case CDC_PARITY_Odd:
			ConfigMask = ((1 << UPM11) | (1 << UPM10));
			break;
		case CDC_PARITY_Even:
			ConfigMask = (1 << UPM11);
			break;
	}

	if (CDCInterfaceInfo->State.LineEncoding.CharFormat == CDC_LINEENCODING_TwoStopBits)
	  ConfigMask |= (1 << USBS1);

	switch (CDCInterfaceInfo->State.LineEncoding.DataBits)
	{
		case 6:
			ConfigMask |= (1 << UCSZ10);
			break;
		case 7:
			ConfigMask |= (1 << UCSZ11);
			break;
		case 8:
			ConfigMask |= ((1 << UCSZ11) | (1 << UCSZ10));
			break;
	}

	/* Must turn off USART before reconfiguring it, otherwise incorrect operation may occur */
	UCSR1B = 0;
	UCSR1A = 0;
	UCSR1C = 0;

	/* Set the new baud rate before configuring the USART */
	UBRR1  = SERIAL_2X_UBBRVAL(CDCInterfaceInfo->State.LineEncoding.BaudRateBPS);

	/* Reconfigure the USART in double speed mode for a wider baud rate range at the expense of accuracy */
	UCSR1C = ConfigMask;
	UCSR1A = (1 << U2X1);
	UCSR1B = ((1 << RXCIE1) | (1 << TXEN1) | (1 << RXEN1));
}




void uart_putc(unsigned char data)
{

      if (USB_DeviceState == DEVICE_STATE_Configured){
        RingBuffer_Insert(&USARTtoUSB_Buffer, data);
      }
  
}

void uart_puts(const char *s )
{
    while (*s) 
      uart_putc(*s++);

}/* uart_puts */


// convert an unsigned integer to string
void my_uitoa(uint32_t zahl, char* string, uint8_t no_digits, char leading_char) {
  int8_t i; // schleifenzähler

  string[no_digits] = '\0'; // String Terminator
  for (i = (no_digits - 1); i >= 0; i--) {
    if (zahl == 0 && i < (no_digits - 1)) {
      string[i] = leading_char;
    } else {
      string[i] = (zahl % 10) + '0';
    } // Modulo rechnen, dann den ASCII-Code von '0' addieren
    zahl /= 10;
  }

}

int8_t sign(int16_t x) {
  return (x > 0) - (x < 0);
}


void uart_print_number(uint32_t zahl, uint8_t no_digits) {
  my_uitoa(abs(zahl),stringbuffer,no_digits,' ');
  uart_puts(stringbuffer);
}


void uart_print_number_wlzeros(uint32_t zahl, uint8_t no_digits) {
  my_uitoa(abs(zahl),stringbuffer,no_digits,'0');
  uart_puts(stringbuffer);
}

void uart_print_signed_number(uint32_t zahl, uint8_t no_digits) {
  my_uitoa(abs(zahl),stringbuffer,no_digits,' ');
  if (sign(zahl) < 0) {
    uart_putc('-');
  } else {
    uart_putc('+');
  }
  uart_puts(stringbuffer);
  
}


/** Main program entry point. This routine contains the overall program flow, including initial
 *  setup of all components and the main program loop.
 */

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


uint32_t times_ten_pow(uint8_t exponent) {
  uint32_t val = 1;
  for (uint8_t i = 1; i <= exponent; i++) {
    val *= 10;
  }
  return val;
}

// #define PHASE_DELAY_MS 1
#define PHASE_DELAY_US 0

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
//     uart_print_signed_number(plate_pos_x,6);
    print_steps_in_mm(plate_pos_x);
//     my_uitoa(plate_pos_x, stringbuffer, 6);
//     uart_puts(stringbuffer);
    uart_puts("  y_pos: ");
//     uart_print_signed_number(plate_pos_y,6);
    print_steps_in_mm(plate_pos_y);
    uart_puts("\r");
}

#define POSITION 0
#define GOTO 1
#define MOVEREL 2
#define SETZERO 3

void parse_command(void){
  
  
  static char cmdbuffer[32];
  static char numbuffer[16];
  static uint16_t predot = 0,postdot = 0;
  static uint8_t cmdPos, curCmdLen, num_start = 0, nums_found = 0;
  uint8_t action=0,axis=0;
  int8_t num_sign = 1;
  char byte;
  
  /* Load the next byte from the USART transmit buffer into the USART */
  if (!(RingBuffer_IsEmpty(&USBtoUSART_Buffer))) {
    byte = RingBuffer_Remove(&USBtoUSART_Buffer);
    
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

int main(void)
{
 
  init_motors();
//   init_leds();
//   init_sw();

  
  char dummy;
  uint8_t field_val = 0;
  SetupHardware();



  RingBuffer_InitBuffer(&USBtoUSART_Buffer, USBtoUSART_Buffer_Data, sizeof(USBtoUSART_Buffer_Data));
  RingBuffer_InitBuffer(&USARTtoUSB_Buffer, USARTtoUSB_Buffer_Data, sizeof(USARTtoUSB_Buffer_Data));

//   LEDs_SetAllLEDs(LEDMASK_USB_NOTREADY);
  GlobalInterruptEnable();

  touchpad_init(); // you need to call this to setup the I/O pin!
  _delay_ms(500);
  sei();



  
  uint16_t loopcounter=0;



//   uart_puts("you selected the relative position demo modus:\n\r");
  touchpad_set_rel_mode_100dpi();// use touchpad in relative mode
//  touchpad_set_rel_mode_200dpi(); // uncomment this line if you want double resolution
  int16_t x, y = 0;
  int8_t dx, dy = 0;
  uint8_t busy = 0, last_busy = 0;

  while (1) {
    
//     set_led0(sw0_state());
//     set_led1(sw1_state());
//     set_led2(sw2_state());

    Usb2SerialTask();
//     loopcounter++;
//     if(loopcounter<2000) {
//       continue;
//     }
//     loopcounter=0;
    parse_command(); // read data from virtual comport
   touchpad_read(); // read data from touchpad
//     if(sw0_state()){ // if left switch is active
      dx = -4*delta_x();// returns the amount your finger has moved in x direction since last readout
//     } else {
//       dx = 0;
//     }
//     if(sw1_state()){ // if middle switch is active
      dy = -4*delta_y();// returns the amount your finger has moved in y direction since last readout
//     } else {
//       dy = 0;
//     }

    // increment/decrement some dummy variables with the

    plate_pos_x += dx;
    plate_pos_y += dy;
    
    
    last_busy = busy;
    busy = move_plate(dx,dy);
    
    
    if (last_busy && !(busy)){
      pos_report();
    }
    

  }
  // end of relative mode demo block

// #endif
    
  
  
  


} // end of main