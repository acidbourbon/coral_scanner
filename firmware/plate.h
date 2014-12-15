#define PHASE_DELAY_US 0





uint8_t move_plate(void);




int32_t get_plate_pos_x(void);
int32_t get_plate_pos_y(void);
void set_plate_pos_x(int32_t value);
void set_plate_pos_y(int32_t value);
int32_t get_target_plate_pos_x(void);
int32_t get_target_plate_pos_y(void);
void set_target_plate_pos_x(int32_t value);
void set_target_plate_pos_y(int32_t value);
void inc_target_plate_pos_x(int32_t value);
void inc_target_plate_pos_y(int32_t value);