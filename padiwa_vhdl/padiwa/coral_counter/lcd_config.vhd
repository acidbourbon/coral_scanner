library ieee;
USE IEEE.std_logic_1164.ALL;
use ieee.numeric_std.all;


package lcd_config is


  type data_t is array (0 to 1023) of std_logic_vector(7 downto 0);
  constant dataram_pack : data_t := (
      x"36",x"48",x"3A",x"55",x"29",x"2A",x"00",x"00",
      x"00",x"EF",x"2B",x"00",x"00",x"01",x"3F",x"2C",
      x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",
      x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",

      
 x"50", x"61", x"64", x"69", x"77", x"61", x"20", x"53", x"74", x"61", x"74", x"75", x"73", x"0a", 
 x"0a", 
 x"54", x"65", x"6d", x"70", x"65", x"72", x"61", x"74", x"75", x"72", x"65", x"20", x"20", x"20", x"20", x"20", x"20", x"84", x"0a", 
 x"55", x"49", x"44", x"20", x"20", x"83",                      x"82",                      x"81",                      x"80", x"0a",
 x"45", x"6e", x"61", x"62", x"6c", x"65", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"85", x"0a", 
 x"49", x"6e", x"76", x"65", x"72", x"74", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"86", x"0a",
 x"49", x"6e", x"70", x"75", x"74", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20",x"20",  x"87", x"0a",  
 x"0a",
 x"54", x"69", x"6d", x"65", x"72", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"8F",                      x"8E", x"0a",
 others => x"00");
    
end;

package body lcd_config is


end package body;