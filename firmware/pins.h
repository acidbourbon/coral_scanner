
#define XEND1 7
#define XEND1_DDR DDRD
#define XEND1_PORT PORTD
#define XEND1_PIN PIND

#define XEND2 0
#define XEND2_DDR DDRB
#define XEND2_PORT PORTB
#define XEND2_PIN PINB

#define YEND1 4
#define YEND1_DDR DDRB
#define YEND1_PORT PORTB
#define YEND1_PIN PINB

#define YEND2 3
#define YEND2_DDR DDRB
#define YEND2_PORT PORTB
#define YEND2_PIN PINB


void XEND1_set(uint8_t value);
void XEND1_as_output(void);
void XEND1_as_input(void);
void XEND1_as_pullup(void);
uint8_t XEND1_state(void);


void XEND2_set(uint8_t value);
void XEND2_as_output(void);
void XEND2_as_input(void);
void XEND2_as_pullup(void);
uint8_t XEND2_state(void);


void YEND1_set(uint8_t value);
void YEND1_as_output(void);
void YEND1_as_input(void);
void YEND1_as_pullup(void);
uint8_t YEND1_state(void);


void YEND2_set(uint8_t value);
void YEND2_as_output(void);
void YEND2_as_input(void);
void YEND2_as_pullup(void);
uint8_t YEND2_state(void);