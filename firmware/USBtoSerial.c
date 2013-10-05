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
#define F_CPU 16e6

#include "USBtoSerial.h"
#include <util/delay.h>
#include "TM1001A.c"
// #include "rfm70.c"

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
    if (!(RingBuffer_IsEmpty(&USBtoUSART_Buffer))) {
      Serial_SendByte(RingBuffer_Remove(&USBtoUSART_Buffer));
//      dummy = RingBuffer_Remove(&USBtoUSART_Buffer);
//      sendPayload(&dummy,1,0);
    }
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
void my_uitoa(uint32_t zahl, char* string, uint8_t no_digits) {
  int8_t i; // schleifenzähler

  string[no_digits] = '\0'; // String Terminator
  for (i = (no_digits - 1); i >= 0; i--) {
    if (zahl == 0 && i < (no_digits - 1)) {
      string[i] = ' ';
    } else {
      string[i] = (zahl % 10) + '0';
    } // Modulo rechnen, dann den ASCII-Code von '0' addieren
    zahl /= 10;
  }

}

/** Main program entry point. This routine contains the overall program flow, including initial
 *  setup of all components and the main program loop.
 */
int main(void)
{
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


// setup rfm70 transceiver

//  Begin();
// 
//  setMode(0);// set mode t
//  setChannel(8);
//  _delay_ms(1000);
//  sendPayload("eins",4, 0);
//  _delay_ms(1000);


// end
  
  uint16_t loopcounter=0;

  char stringbuffer[16];
//   for (;;) { // the eternal loop
//     
//     Usb2SerialTask();
//     loopcounter++;
//     if(loopcounter == 0){
//       uart_puts("blah\r\n");
// //       if (USB_DeviceState == DEVICE_STATE_Configured){
// //         RingBuffer_Insert(&USARTtoUSB_Buffer, 'b');
// //       }
//     }
//     
//   }
  
  
  
  
  

    
    
//######################################################################
// uncomment desired demo mode here!

// #define DEMO_MODE KEYPAD_MODE
// #define DEMO_MODE ABSOLUTE_MODE
// #define DEMO_MODE RELATIVE_MODE
//######################################################################

// #if DEMO_MODE == KEYPAD_MODE
  // begin of keypad mode demo block
  // current configuration is: 3 colums, 2 rows => 6 touch buttons
  // this can be changed by the PAD_ROWS/PAD_COLS defines in the TM1001A.c file

  //   -------------------------
  //   | back  |  up   | enter |
  //   -------------------------
  //   | left  |  down | right |
  //   -------------------------

//   uart_puts("you selected the keypad demo modus:\n\r");
  touchpad_set_abs_mode(); // keypad functionality uses the "absolute mode"
  while (1) {
    break; // goto next mode
    
    Usb2SerialTask();
    loopcounter++;
    if(loopcounter<2000) {
      continue;
    }
  loopcounter=0;

    touchpad_read(); // read values from the touchpad

    field_val = decode_field(); // decode_field returns the number of the
    // touch button that was pressed last. or zero if nothing happened

    switch (field_val) {

    case 4:
      uart_puts("left\n\r");
      break;
    case 6:
      uart_puts("right\n\r");
      break;
    case 2:
      uart_puts("up\n\r");
      break;
    case 5:
      uart_puts("down\n\r");
      break;
    case 1:
      uart_puts("back\n\r");
      break;
    case 3:
      uart_puts("enter\n\r");
      break;
    default:
      break;
    }

  }
  // end of keypad mode demo block
// 
// #elif DEMO_MODE == ABSOLUTE_MODE
  // begin of keypad mode demo block
//   uart_puts("you selected the absolute position demo modus:\n\r");
  touchpad_set_abs_mode();// tell the touchpad you want to use it in the "absolute mode"
  while (1) {
    break; // goto next mode
    Usb2SerialTask();
    loopcounter++;
    if(loopcounter< 2000) {
      continue;
    }
    loopcounter=0;

    touchpad_read(); // read data from the touchpad
    uart_puts("x_pos: ");
    my_uitoa(x_abs(),stringbuffer,4);// x_abs returns current x position of your finger
    uart_puts(stringbuffer);
    uart_puts("   y_pos: ");
    my_uitoa(y_abs(),stringbuffer,4);// y_abs returns current y position of your finger
    uart_puts(stringbuffer);
    uart_puts("   z_pressure: ");// z_pressure returns current "pressure" (contact area) of your finger
    my_uitoa(z_pressure(),stringbuffer,4);
    uart_puts(stringbuffer);
    uart_puts("\r");

  }
  // end of absolute mode demo block 
// 
// #elif DEMO_MODE == RELATIVE_MODE
//   begin of relative mode demo block
  uart_puts("you selected the relative position demo modus:\n\r");
  touchpad_set_rel_mode_100dpi();// use touchpad in relative mode
//  touchpad_set_rel_mode_200dpi(); // uncomment this line if you want double resolution
  uint8_t x, y = 0;
  int8_t dx, dy = 0;

  while (1) {

    Usb2SerialTask();
    loopcounter++;
    if(loopcounter<2000) {
      continue;
    }
    loopcounter=0;

    touchpad_read(); // read data from touchpad

    dx = delta_x();// returns the amount your finger has moved in x direction since last readout
    dy = delta_y();// returns the amount your finger has moved in y direction since last readout

    // increment/decrement some dummy variables with the
    if (x + dx > 255) {
      x = 255;
    } else if (x + dx < 0) {
      x = 0;
    } else {
      x = (x + dx);
    }

    if (y + dy > 255) {
      y = 255;
    } else if (y + dy < 0) {
      y = 0;
    } else {
      y = (y + dy);
    }

    uart_puts("x_pos: ");
    my_uitoa(x, stringbuffer, 4);
    uart_puts(stringbuffer);
    uart_puts("  y_pos: ");
    my_uitoa(y, stringbuffer, 4);
    uart_puts(stringbuffer);
    uart_puts("\r");

  }
  // end of relative mode demo block

// #endif
    
  
  
  


} // end of main