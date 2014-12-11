#define PHASE_DELAY_US 0


#define X 0
#define Y 1


#define X0 4
#define DDRX0 DDRC
#define PORTX0 PORTC
#define PINX0 PINC

#define X1 5
#define DDRX1 DDRC
#define PORTX1 PORTC
#define PINX1 PINC

#define X2 4
#define DDRX2 DDRD
#define PORTX2 PORTD
#define PINX2 PIND

#define X3 6
#define DDRX3 DDRC
#define PORTX3 PORTC
#define PINX3 PINC


#define Y0 7
#define DDRY0 DDRC
#define PORTY0 PORTC
#define PINY0 PINC

#define Y1 6
#define DDRY1 DDRB
#define PORTY1 PORTB
#define PINY1 PINB

#define Y2 7
#define DDRY2 DDRB
#define PORTY2 PORTB
#define PINY2 PINB

#define Y3 5
#define DDRY3 DDRB
#define PORTY3 PORTB
#define PINY3 PINB


void set_x(uint8_t byte);
void set_y(uint8_t byte);
void init_motors(void);
uint8_t motor_step(uint8_t motor, int8_t direction);
uint8_t move_plate(int16_t dx, int16_t dy);







