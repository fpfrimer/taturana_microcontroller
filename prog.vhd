-- Quartus Prime VHDL Template
-- Single port RAM with single read/write address 

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity prog is

	generic 
	(   
      DATA_WIDTH : natural := 8;
		ADDR_WIDTH : natural := 4
	);
	port 
	(		
		addr	        : in  std_logic_vector((ADDR_WIDTH-1) downto 0);
		data	        : in  std_logic_vector((DATA_WIDTH-1) downto 0);
		we		        : in  std_logic := '1';
      q		        : out std_logic_vector((DATA_WIDTH -1) downto 0);
      enable        : in  std_logic
      
	);

end entity;

architecture rtl of prog is

	-- Build a 2-D array type for the RAM
	subtype word_t is std_logic_vector((DATA_WIDTH-1) downto 0);
	type memory_t is array(0 to 2**ADDR_WIDTH-1) of word_t;-- Quartus Prime VHDL Template

	-- Declare the RAM signal.	
	signal ram : memory_t;
	   

begin

	process(enable, we, data, addr)
    begin
      if enable = '1' then           
         if(we = '1') then
				ram(to_integer(unsigned(addr))) <= data;                                       
         end if;
		end if;
	end process;

    q <= ram(to_integer(unsigned(addr)));    

end rtl;