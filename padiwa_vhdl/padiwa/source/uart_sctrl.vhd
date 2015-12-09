library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.trb_net_std.all;
use work.version.all;

library machxo2;
use machxo2.all;


entity uart_sctrl is
  port(
    CLK     : in  std_logic;
    RESET   : in  std_logic;
    UART_RX : in  std_logic;
    UART_TX : out std_logic;
    
    DATA_OUT  : out std_logic_vector(31 downto 0);
    DATA_IN   : in  std_logic_vector(31 downto 0);
    ADDR_OUT  : out std_logic_vector(7 downto 0);
    WRITE_OUT : out std_logic;
    READ_OUT  : out std_logic;
    READY_IN  : in  std_logic;
    
    DEBUG   : out std_logic_vector(15 downto 0)
    );
end entity;


architecture uart_sctrl_arch of uart_sctrl is

constant CLK_DIV : integer := 133000000/115200;

signal rx_data   : std_logic_vector(7 downto 0);
signal tx_data   : std_logic_vector(7 downto 0);
signal rx_ready  : std_logic;
signal tx_send   : std_logic;
signal tx_ready  : std_logic;

type   rx_state_t is (IDLE,GET_ADDR,GET_BYTE0,GET_BYTE1,GET_BYTE2,GET_BYTE3,DO_WRITE,DO_READ,SEND_BYTE0,SEND_BYTE1,SEND_BYTE2,SEND_BYTE3,SEND_TERM);
signal state     : rx_state_t;
signal addr      : std_logic_vector(7 downto 0) := (others => '0');
signal word      : std_logic_vector(31 downto 0) := (others => '0');
signal timer     : unsigned(25 downto 0) := (others => '0');
signal timeout   : std_logic := '0';
signal cmd_wr    : std_logic := '0';
signal cmd_rd    : std_logic := '0';

begin


THE_RX : entity work.uart_rec
  port map(
    CLK_DIV      => CLK_DIV,
    CLK          => CLK,
    RST          => RESET,
    RX           => UART_RX,
    DATA_OUT     => rx_data,
    DATA_WAITING => rx_ready
    );

THE_TX : entity work.uart_trans
  port map(
    CLK_DIV      => CLK_DIV,
    CLK          => CLK,
    RST          => RESET,
    DATA_IN      => tx_data,
    SEND         => tx_send,
    READY        => tx_ready,
    TX           => UART_TX
    );
    
PROC_RX : process begin
  wait until rising_edge(CLK);
  READ_OUT  <= '0';
  WRITE_OUT <= '0';
  tx_send   <= '0';
  timer     <= timer + 1;
  case state is
    when IDLE =>
      cmd_rd <= '0';
      cmd_wr <= '0';
      timer  <= (others => '0');
      if rx_ready = '1' then
        state <= GET_ADDR;
        if rx_data = x"52" then
          cmd_rd <= '1';
        elsif rx_data = x"57" then
          cmd_wr <= '1';
        else
          state <= IDLE;
        end if;
      end if;

    when GET_ADDR  =>
      if rx_ready = '1' then
        addr <= rx_data;
        if cmd_wr = '1' then
          state <= GET_BYTE3;
        else
          state <= DO_READ;
          READ_OUT <= '1';        
        end if;
      end if;
--Write cycle
    when GET_BYTE3 =>
      if rx_ready = '1' then
        word(31 downto 24) <= rx_data;
        state <= GET_BYTE2;
      end if;
    when GET_BYTE2 =>
      if rx_ready = '1' then
        word(23 downto 16) <= rx_data;
        state <= GET_BYTE1;
      end if;
    when GET_BYTE1 =>
      if rx_ready = '1' then
        word(15 downto 8) <= rx_data;
        state <= GET_BYTE0;
      end if;
    when GET_BYTE0 =>
      if rx_ready = '1' then
        word(7 downto 0) <= rx_data;
        state <= DO_WRITE;
      end if;
    when DO_WRITE =>
      WRITE_OUT <= '1';
      state     <= IDLE;
--Read cycle
    when DO_READ =>
      if READY_IN = '1' then
        word <= DATA_IN;
        tx_send <= '1';
        tx_data <= x"52";
        state   <= SEND_BYTE3;
      end if;
    when SEND_BYTE3=>
      if tx_ready = '1' then
        tx_send <= '1';
        tx_data <= word(31 downto 24);
        state   <= SEND_BYTE2;
      end if;
    when SEND_BYTE2=>
      if tx_ready = '1' then
        tx_send <= '1';
        tx_data <= word(23 downto 16);
        state   <= SEND_BYTE1;
      end if;
    when SEND_BYTE1=>
      if tx_ready = '1' then
        tx_send <= '1';
        tx_data <= word(15 downto 8);
        state   <= SEND_BYTE0;
      end if;
    when SEND_BYTE0=>
      if tx_ready = '1' then
        tx_send <= '1';
        tx_data <= word(7 downto 0);
        state   <= SEND_TERM;
      end if;
    when SEND_TERM=>
      if tx_ready = '1' then
        tx_send <= '1';
        tx_data <= x"0a";
        state   <= IDLE;
      end if;
    
  end case;

  if RESET = '1' or timeout = '1' then
    state <= IDLE;
    timer <= (others => '0');
  end if;
end process;


timeout <= timer(25);


DATA_OUT <= word;
ADDR_OUT <= addr;


end architecture;