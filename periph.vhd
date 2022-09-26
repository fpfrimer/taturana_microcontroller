-- Quartus Prime VHDL Template
-- Single port RAM with single read/write address 

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity periph is

	generic 
	(   
        DATA_WIDTH : natural := 4;
		ADDR_WIDTH : natural := 3
	);
	port 
	(
		
		addr	        : in  std_logic_vector((ADDR_WIDTH-1) downto 0);
		data	        : in  std_logic_vector((DATA_WIDTH-1) downto 0);
		we		        : in  std_logic := '1';
        q		        : out std_logic_vector((DATA_WIDTH -1) downto 0);
        enable          : in  std_logic;
        leds1, leds0    : out std_logic_vector(3 downto 0);   
        sw1, sw0        : in  std_logic_vector(3 downto 0)   
	);

end entity;

architecture rtl of periph is

	-- Build a 2-D array type for the RAM
	subtype word_t is std_logic_vector((DATA_WIDTH-1) downto 0);
	type memory_t is array(0 to 2**ADDR_WIDTH-1) of word_t;-- Quartus Prime VHDL Template

	-- Declare the RAM signal.	
	signal ram : memory_t;
	    

begin

	process(enable, sw0, sw1, we, addr, data)
    begin
		  ram(6) <= sw0;
		  ram(7) <= sw1;
        if enable = '1' then            
                if(we = '1') then
                    case( addr ) is
                        -- data 000 -> 011, ports 100 -> 101
                        when "000"|"001"|"010"|"011"|"100"|"101" =>
                            ram(to_integer(unsigned(addr))) <= data;                        
                        
                        when others =>
                            null;
                    end case ;                    
                end if;                               
            
        end if;
	end process;

   q <= ram(to_integer(unsigned(addr)));
   leds1 <= ram(5);
   leds0 <= ram(4);

end rtl;
