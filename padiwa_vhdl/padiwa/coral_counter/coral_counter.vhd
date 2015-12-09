library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.trb_net_std.all;
use work.trb_net_components.all;
use work.version.all;

library machxo2;
use machxo2.all;


entity coral_counter is
  port(
    CON        : out std_logic_vector(16 downto 1);    --Output for pulser signals
    SPARE_LINE : inout std_logic_vector(3 downto 0);     --connection to PC
    LED_GREEN  : out std_logic;
    LED_ORANGE : out std_logic;
    LED_RED    : out std_logic;
    LED_YELLOW : out std_logic;
    TEST_LINE  : out std_logic_vector(15 downto 0);     --connection for debugging
    INP        : in  std_logic_vector(16 downto 1);
    PWM        : out std_logic_vector(16 downto 1)      --PWM DAC output
    );
end entity;

architecture coral_counter_arch of coral_counter is

component OSCH
-- synthesis translate_off
  generic (NOM_FREQ: string := "133.00");
-- synthesis translate_on
  port (
    STDBY :IN std_logic;
    OSC   :OUT std_logic;
    SEDSTDBY :OUT std_logic
    );
end component;




  

attribute NOM_FREQ : string;
attribute NOM_FREQ of clk_source : label is "133.00";
signal clk_i   : std_logic;
signal clk_osc : std_logic;
signal clk_26  : std_logic;

signal led     : std_logic_vector(3 downto 0) := "1010";
signal lcd_data_i : std_logic_vector(255 downto 0) := (others => '0');

signal uart_rx_data : std_logic_vector(31 downto 0);
signal uart_tx_data : std_logic_vector(31 downto 0);
signal uart_addr    : std_logic_vector(7 downto 0);
signal bus_read     : std_logic;
signal bus_write    : std_logic;
signal bus_ready    : std_logic;

signal register_1   : std_logic_vector(31 downto 0);
signal register_2   : std_logic_vector(15 downto 0);


-- signals for PWM generator
signal pwm_i             : std_logic_vector(32 downto 1);
signal pwm_data_i        : std_logic_vector(15 downto 0);
signal pwm_data_o        : std_logic_vector(15 downto 0);
signal pwm_write_i       : std_logic;
signal pwm_addr_i        : std_logic_vector(3 downto 0);
signal pwm_addr_i_read   : std_logic_vector(3 downto 0);
signal pwm_addr_i_write  : std_logic_vector(3 downto 0);
signal compensate_i      : signed(15 downto 0);
signal pwm_addr_i_mux    : std_logic;
signal pwm_data_o_delay  : std_logic_vector(2 downto 0);

-- the PMT counter
signal signal_counter    : std_logic_vector(31 downto 0);
signal veto_counter      : std_logic_vector(31 downto 0);
signal net_counter       : std_logic_vector(31 downto 0);
signal signal_input      : std_logic_vector(1 downto 0);
signal veto_input        : std_logic_vector(1 downto 0);
signal reset_counters    : std_logic;

-- packet pulse counter
signal packet_counts_window_l  : std_logic_vector(31 downto 0) := x"00000001";
signal packet_counts_window_u  : std_logic_vector(31 downto 0) := x"000000FF";
signal packet_pulse_counter    : std_logic_vector(31 downto 0);

-- dead time related signals
signal dead_time                : std_logic_vector(31 downto 0) := x"00000000";
signal signal_dead_time_counter : std_logic_vector(31 downto 0) := x"00000000";
signal veto_dead_time_counter   : std_logic_vector(31 downto 0) := x"00000000";
signal signal_dead              : std_logic;
signal last_signal_dead              : std_logic;
signal veto_dead                : std_logic;

-- signal/veto LED blinking 
signal signal_trigger    : std_logic;
signal veto_trigger      : std_logic;
signal signal_delay_counter : integer range 0 to 1330000 :=0;
signal veto_delay_counter   : integer range 0 to 1330000 :=0;
signal signal_led        : std_logic;
signal veto_led          : std_logic;

-- milliseconds pulser
signal millisecond_counter : integer range 0 to 133000 := 0;
signal millisecond_pulse : std_logic;

-- acquisition acquisition timer
signal acquisition           : std_logic;
signal acquisition_counter   : std_logic_vector(31 downto 0) := (others => '0');
signal acquisition_trigger   : std_logic;
signal acquisition_time      : std_logic_vector(31 downto 0) := x"000003E8"; -- default 1000 ms
signal acquisition_ready     : std_logic := '0';
signal set_acquisition_ready : std_logic;

-- input register and stretcher
signal input_1 : std_logic;
signal input_2 : std_logic;
signal save_input_1 : std_logic;
-- signal save_input_1_reg : std_logic;
signal save_input_2 : std_logic;
signal input_polarity : std_logic := '1';

-- counts per packet spectrum
type spec_mem_t is array(32 downto 1) of std_logic_vector(31 downto 0);
signal spec_mem : spec_mem_t := (others=>(others=>'0'));
signal ram_purge_counter : integer range 0 to 32 := 0;


begin

---------------------------------------------------------------------------
-- Clock
---------------------------------------------------------------------------
clk_source: OSCH
-- synthesis translate_off
  generic map ( NOM_FREQ => "133.00" )
-- synthesis translate_on
  port map (
    STDBY    => '0',
    OSC      => clk_osc,
    SEDSTDBY => open
  );

THE_PLL : entity work.pll
    port map(
        CLKI   => clk_osc,
        CLKOP  => clk_26, --33
        CLKOS  => clk_i, --133
        LOCK   => open  --no lock available!
        );
  
  
---------------------------------------------------------------------------
-- PWM DAQ
---------------------------------------------------------------------------
THE_PWM_GEN : entity work.pwm_generator
  port map(
    CLK        => clk_i,
    DATA_IN    => pwm_data_i,
    DATA_OUT   => pwm_data_o,
    COMP_IN    => compensate_i,
    WRITE_IN   => pwm_write_i,
    ADDR_IN    => pwm_addr_i,
    PWM        => pwm_i
    );
    
    
compensate_i <= (others => '0');
PWM <= pwm_i(16 downto 1);

-- THE_ONEWIRE : trb_net_onewire
--   generic map(
--     USE_TEMPERATURE_READOUT => 1,
--     PARASITIC_MODE => c_NO,
--     CLK_PERIOD => 33
--     )
--   port map(
--     CLK      => clk_26,
--     RESET    => onewire_reset,
--     READOUT_ENABLE_IN => '1',
--     ONEWIRE  => TEMP_LINE,
--     MONITOR_OUT => onewire_monitor,
--     --connection to id ram, according to memory map in TrbNetRegIO
--     DATA_OUT => id_data_i,
--     ADDR_OUT => id_addr_i,
--     WRITE_OUT=> id_write_i,
--     TEMP_OUT => temperature_i,
--     ID_OUT   => open,
--     STAT     => open
--     );
--   
--   
  
---------------------------------------------------------------------------
-- UART
---------------------------------------------------------------------------
THE_UART : entity work.uart_sctrl
  port map(
    CLK     => clk_i,
    RESET   => '0',
    UART_RX => SPARE_LINE(0),
    UART_TX => SPARE_LINE(2),
    
    DATA_OUT  => uart_rx_data,
    DATA_IN   => uart_tx_data,
    ADDR_OUT  => uart_addr,       
    WRITE_OUT => bus_write,
    READ_OUT  => bus_read,
    READY_IN  => bus_ready,
    
    DEBUG     => open
    );

    
---------------------------------------------------------------------------
-- Registers
---------------------------------------------------------------------------    
PROC_WRITE_REGISTERS : process begin

  wait until rising_edge(clk_i);
  pwm_write_i <= '0';
  pwm_addr_i_mux   <= '0';
  
  acquisition_trigger <= '0'; -- do not latch the trigger
  
  if bus_write= '1' then
--     if uart_addr = x"01" then
--       register_1 <= uart_rx_data;
--     elsif uart_addr = x"02" then
--       register_2 <= uart_rx_data(15 downto 0);
--     end if;
    if unsigned(uart_addr) < 16 then
      pwm_write_i      <= '1';
      pwm_data_i       <= uart_rx_data(15 downto 0);
      pwm_addr_i_write <= uart_addr(3 downto 0);
      pwm_addr_i_mux   <= '1';
    elsif unsigned(uart_addr) = 16 then 
      register_1 <= uart_rx_data;
    elsif unsigned(uart_addr) = 20 then -- trigger acquisition
      acquisition_trigger <= uart_rx_data(0);
    elsif unsigned(uart_addr) = 25 then -- set artificial dead time of signal counters (in clock cycles)
      dead_time <= uart_rx_data;
    elsif unsigned(uart_addr) = 26 then -- set acquisition time (in ms)
      acquisition_time <= uart_rx_data;
    elsif unsigned(uart_addr) = 27 then -- input polarity, if 1 then input polarity is negative
      input_polarity <= uart_rx_data(0);
    elsif unsigned(uart_addr) = 28 then -- set lower end of counts acceptance window
      packet_counts_window_l <= uart_rx_data;
    elsif unsigned(uart_addr) = 29 then -- set upper end of counts acceptance window
      packet_counts_window_u <= uart_rx_data;
    end if;
  end if;
end process;
    

PROC_READ_REGISTERS : process begin
  wait until rising_edge(clk_i);
  bus_ready <= '0';
  pwm_data_o_delay(0) <= '0';
  pwm_data_o_delay(1) <= pwm_data_o_delay(0);
  reset_counters <= '0';
  acquisition_ready <= acquisition_ready or set_acquisition_ready;
  
  if bus_read = '1' then
--     if uart_addr = x"01" then
--       uart_tx_data <= register_1;
--     elsif uart_addr = x"02" then
--       uart_tx_data <= x"0000" & register_2;
--     end if;
    if unsigned(uart_addr) < 16 then
      pwm_addr_i_read <= uart_addr(3 downto 0);
      pwm_data_o_delay(0) <= '1';
    elsif unsigned(uart_addr) = 16 then 
      uart_tx_data <= std_logic_vector(unsigned(register_1)+1);
      bus_ready <= '1';
    elsif unsigned(uart_addr) = 17 then 
      uart_tx_data <= x"000000FF";
      bus_ready <= '1';
      
    elsif unsigned(uart_addr) = 19 then -- return 1 if acquisition is ready
      uart_tx_data(0) <= acquisition_ready;
      uart_tx_data(31 downto 1) <= (others=>'0');
      acquisition_ready <= '0';
      bus_ready <= '1';
    elsif unsigned(uart_addr) = 20 then -- return 1 if acquisition is ongoing
      uart_tx_data(0) <= acquisition;
      uart_tx_data(31 downto 1) <= (others=>'0');
      bus_ready <= '1';
    elsif unsigned(uart_addr) = 21 then -- return signal counter
      uart_tx_data <= signal_counter;
      bus_ready <= '1';
    elsif unsigned(uart_addr) = 22 then -- return veto counter
      uart_tx_data <= veto_counter;
      bus_ready <= '1';
    elsif unsigned(uart_addr) = 23 then -- return net counter
      uart_tx_data <= std_logic_vector(unsigned(signal_counter)-unsigned(veto_counter));
      bus_ready <= '1';
    elsif unsigned(uart_addr) = 24 then -- reset all counters and return net counter
      uart_tx_data <= std_logic_vector(unsigned(signal_counter)-unsigned(veto_counter));
      reset_counters <= '1';
      bus_ready <= '1';
    elsif unsigned(uart_addr) = 25 then -- show artificial dead time (in clock cycles)
      uart_tx_data <= dead_time;
      bus_ready <= '1';
    elsif unsigned(uart_addr) = 26 then -- show acquisition time (in ms)
      uart_tx_data <= acquisition_time;
      bus_ready <= '1';
    elsif unsigned(uart_addr) = 27 then -- input polarity, 1 if reversed
      uart_tx_data(0) <= input_polarity;
      uart_tx_data(31 downto 1) <= (others=>'0');
      bus_ready <= '1';
    elsif unsigned(uart_addr) = 28 then -- lower end of counts acceptance window
      uart_tx_data <= packet_counts_window_l;
      bus_ready <= '1';
    elsif unsigned(uart_addr) = 29 then -- upper end of counts acceptance window
      uart_tx_data <= packet_counts_window_u;
      bus_ready <= '1';
    elsif unsigned(uart_addr) > 100 and unsigned(uart_addr) <= 132 then -- read out counts histogram
      uart_tx_data <= spec_mem( to_integer(unsigned(uart_addr)) - 100);
      bus_ready <= '1';
    end if;
  end if;
  
  -- delay 1 clock for pwm dout to get ready
  if pwm_data_o_delay(1) = '1' then
    uart_tx_data <= x"0000" & pwm_data_o;
    bus_ready <= '1';
  end if;
end process;



-- pwm_addr_i has to be accessed from PROC_WRITE_REGISTERS and from
-- PROC_READ_REGISTERS
pwm_addr_i <= pwm_addr_i_write when ( pwm_addr_i_mux = '1' ) else pwm_addr_i_read;

-- PROC_SYNC_INPUT : process begin
--   wait until rising_edge(clk_i);
--   signal_input(0) <= INP(1);
--   veto_input(0)   <= INP(2);
-- end process;

input_1 <= INP(1) xor input_polarity;
input_2 <= INP(2) xor input_polarity;

-- stretcher for input 1
process (input_1,clk_i) begin
  if input_1 = '1' then
      save_input_1 <= '1';
  elsif rising_edge(clk_i) then
    save_input_1 <= '0';
  end if;
end process; 

-- stretcher for input 2
process (input_2,clk_i) begin
  if input_2 = '1' then
      save_input_2 <= '1';
  elsif rising_edge(clk_i) then
    save_input_2 <= '0';
  end if;
end process; 

-- save_input_1 <= (INP(1) or save_input_1) and not save_input_1_reg;
-- save_input_1_reg <= save_input_1 when rising_edge(clk_i); 
-- 


PROC_PMT_COUNTER : process begin

  wait until rising_edge(clk_i);
  signal_input(0)   <= save_input_1;
  signal_input(1)   <= signal_input(0);
  veto_input(0)     <= save_input_2;
  veto_input(1)     <= veto_input(0);
  signal_trigger    <= '0';
  veto_trigger      <= '0';
  last_signal_dead  <= signal_dead;
  
  
  if acquisition = '1' then
  
    if (signal_input = "01") and (signal_dead = '0') then -- trigger the acquisition
      packet_pulse_counter <= x"00000001"; -- you've just counted the first pulse of the packet
      signal_trigger <= '1';
    end if;
    if (signal_input = "01") and (signal_dead = '1') then -- increase counter, when signal has rising edge
      packet_pulse_counter <= std_logic_vector(unsigned(packet_pulse_counter) + 1);
    end if;
    
    
    if (veto_input = "01") and (veto_dead = '0') then -- increase counter, when signal has rising edge
      veto_counter <= std_logic_vector(unsigned(veto_counter) + 1);
      veto_trigger <= '1';
    end if;
  end if;
  
  
  
  if (last_signal_dead = '1' and signal_dead = '0') then -- dead time is over, reset the counter
    packet_pulse_counter <= (others => '0'); -- not really necessary
    -- check if number of pulses registered are in the defined window
    if    (unsigned(packet_pulse_counter) >= unsigned(packet_counts_window_l))
      and (unsigned(packet_pulse_counter) <= unsigned(packet_counts_window_u)) then
      signal_counter <= std_logic_vector(unsigned(signal_counter) + 1);
    end if;
    -- fill the histogram
    spec_mem(to_integer(unsigned(packet_pulse_counter))) <=
      std_logic_vector( unsigned(spec_mem(to_integer(unsigned(packet_pulse_counter)))) +1);
  end if;
  
  
  if reset_counters = '1' then
    signal_counter <= (others=>'0');
    veto_counter   <= (others=>'0');
    net_counter    <= (others=>'0');
    ram_purge_counter <= 1; -- start cleansing the analyzer ram
  end if;
  
  if ram_purge_counter > 0 then 
    spec_mem(ram_purge_counter) <= (others=>'0');
    ram_purge_counter <= ram_purge_counter + 1;
    if ram_purge_counter = 32 then
      ram_purge_counter <= 0;
    end if;
  end if;
  
end process;


PROC_SIGNAL_LED : process begin
  wait until rising_edge(clk_i);
-- make a light pulse with 10 ms duration = 1330000 clock cycles
  if (signal_delay_counter = 0) then --idle position
    signal_led <= '0';
  -- pulse is triggered by trigger signal
    if (signal_trigger = '1') then
      signal_delay_counter <= 1;
    end if;
  else
    if (signal_delay_counter = 1330000) then
      signal_delay_counter <= 0;
    else 
      signal_delay_counter <= signal_delay_counter + 1;
      signal_led <= '1';
    end if;
  end if;
end process;

PROC_veto_LED : process begin
  wait until rising_edge(clk_i);
-- make a light pulse with 10 ms duration = 1330000 clock cycles
  if (veto_delay_counter = 0) then --idle position
    veto_led <= '0';
  -- pulse is triggered by trigger signal
    if (veto_trigger = '1') then
      veto_delay_counter <= 1;
    end if;
  else
    if (veto_delay_counter = 1330000) then
      veto_delay_counter <= 0;
    else 
      veto_delay_counter <= veto_delay_counter + 1;
      veto_led <= '1';
    end if;
  end if;
end process;


PROC_SIGNAL_DEAD_TIME : process begin
-- make a pulse of adjustable length (dead_time)
  wait until rising_edge(clk_i);
  if (signal_dead_time_counter = x"00000000") then --idle position
    signal_dead <= '0';
  -- pulse is triggered by trigger signal
    if (signal_trigger = '1') then
      signal_dead_time_counter <= x"00000001";
    end if;
  else
    if (unsigned(signal_dead_time_counter) >= unsigned(dead_time)) then
      signal_dead_time_counter <= x"00000000";
    else 
      signal_dead_time_counter <= std_logic_vector(unsigned(signal_dead_time_counter) + 1);
      signal_dead <= '1';
    end if;
  end if;
end process;

PROC_VETO_DEAD_TIME : process begin
-- make a pulse of adjustable length (dead_time)
  wait until rising_edge(clk_i);
  if (veto_dead_time_counter = x"00000000") then --idle position
    veto_dead <= '0';
  -- pulse is triggered by trigger signal
    if (veto_trigger = '1') then
      veto_dead_time_counter <= x"00000001";
    end if;
  else
    if (unsigned(veto_dead_time_counter) >= unsigned(dead_time)) then
      veto_dead_time_counter <= x"00000000";
    else 
      veto_dead_time_counter <= std_logic_vector(unsigned(veto_dead_time_counter) + 1);
      veto_dead <= '1';
    end if;
  end if;
end process;

PROC_MILLISECOND_PULSER : process begin
-- just make a strobe each millisecond
  wait until rising_edge(clk_i);
  millisecond_pulse <= '0';
  if ( millisecond_counter >= 133000 )  then
    millisecond_counter <= 0;
    millisecond_pulse   <= '1';
  else
    millisecond_counter <= millisecond_counter + 1;
  end if;
end process;

PROC_ACQUISITION_TIMER : process begin
  wait until rising_edge(clk_i);
  
  acquisition <= '0';
  set_acquisition_ready <= '0';
 
  if ( unsigned(acquisition_counter) = 0 ) then
    -- acquisition trigger starts the acquisition counter
    if ( acquisition_trigger = '1' ) then
      acquisition_counter <= std_logic_vector(unsigned(acquisition_counter) + 1);
    else
      acquisition_counter <= 0;
    end if;
      
  elsif( unsigned(acquisition_counter) > unsigned(acquisition_time) ) then
    -- end of acquisition reached
    acquisition_counter <= 0;
    set_acquisition_ready <= '1';
  else
    -- acquisition is ongoing
    acquisition <= '1';
    -- just counting up each millisecond
    if ( millisecond_pulse = '1' ) then
      acquisition_counter <= std_logic_vector(unsigned(acquisition_counter) + 1);
    end if;
  end if;

end process;
---------------------------------------------------------------------------
-- LCD
---------------------------------------------------------------------------    
-- THE_LCD : entity work.lcd 
--   port map(
--     CLK   => clk_26,
--     RESET => '0',
--     
--     MOSI  => TEST_LINE(9),
--     SCK   => TEST_LINE(8),
--     DC    => TEST_LINE(10),
--     CS    => TEST_LINE(12),
--     RST   => TEST_LINE(11),
--     
--     INPUT => lcd_data_i,
--     LED   => open
--     
--     );    
-- 
-- 
-- 
-- lcd_data_i(31 downto 0)    <= register_1;
-- lcd_data_i(63 downto 32)   <= (others => '0');
-- lcd_data_i(79 downto 64)   <= register_2;
-- lcd_data_i(87 downto 80)   <= uart_addr;
-- lcd_data_i(127 downto 96)  <= uart_rx_data(31 downto 0);
-- lcd_data_i(255 downto 128) <= (others => '0');    

    

-- add temperature compensation later
    
    
---------------------------------------------------------------------------
-- Other I/O
---------------------------------------------------------------------------    

TEST_LINE(7 downto 0)   <= x"00";
--TEST_LINE(12 downto 8) used for serial interface
TEST_LINE(15 downto 13) <= (others => '0');

--the two I/O on the pin-header connected to the USB interface
-- SPARE_LINE(1) <= 'Z'; --C1 spare
-- SPARE_LINE(3) <= 'Z'; --C2 spare
SPARE_LINE(1) <= signal_input(0); --C1 spare
SPARE_LINE(3) <= veto_input(0); --C2 spare

LED_GREEN  <= led(0);
-- LED_ORANGE <= led(1);
-- LED_RED    <= led(2);
-- LED_YELLOW <= led(3);
LED_ORANGE <= not(acquisition);
LED_RED    <= not(veto_led);  -- display inputs on on-board LEDs
LED_YELLOW <= not(signal_led);

end architecture;
