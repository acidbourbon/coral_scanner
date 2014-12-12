#define PHASE_DELAY_US 0


#define X 0
#define Y 1


#define X0 4
#define X0_DDR DDRC
#define X0_PORT PORTC
#define X0_PIN PINC

#define X1 5
#define X1_DDR DDRC
#define X1_PORT PORTC
#define X1_PIN PINC

#define X2 4
#define X2_DDR DDRD
#define X2_PORT PORTD
#define X2_PIN PIND

#define X3 6
#define X3_DDR DDRC
#define X3_PORT PORTC
#define X3_PIN PINC


#define Y0 7
#define Y0_DDR DDRC
#define Y0_PORT PORTC
#define Y0_PIN PINC

#define Y1 6
#define Y1_DDR DDRB
#define Y1_PORT PORTB
#define Y1_PIN PINB

#define Y2 7
#define Y2_DDR DDRB
#define Y2_PORT PORTB
#define Y2_PIN PINB

#define Y3 5
#define Y3_DDR DDRB
#define Y3_PORT PORTB
#define Y3_PIN PINB


void set_x(uint8_t byte);
void set_y(uint8_t byte);
void init_motors(void);
uint8_t motor_step(uint8_t motor, int8_t direction);
uint8_t move_plate(int32_t dx, int32_t dy);







