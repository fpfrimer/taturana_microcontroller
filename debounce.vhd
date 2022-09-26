--Libraries----------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

--debounce Entity----------------------------------------------------------------------------------

entity debounce is
generic(
	-- counter size
	counter_size  :  integer := 19);

-- Input and output elements
port(
	-- input clock
	clk     : in  std_logic;

	-- input signal to be debounced
	button  : in  std_logic; 
		
	-- debounced signal
	result  : out std_logic);
		
end entity;

--debounce Architecture ---------------------------------------------------------------------------

architecture hardware of debounce is
	
	-- input flip flops
	signal flipflops   : std_logic_vector(1 downto 0); 
	
	-- sync reset to zero
	signal counter_set : std_logic;

	-- counter output
	signal counter_out : std_logic_vector(counter_size downto 0) := (others => '0'); 
begin
	
	-- determine when to start/reset counter
	counter_set <= flipflops(0) xor flipflops(1);   
  
  process(clk)
  begin
    if(clk'event and clk = '1') then
      flipflops(0) <= button;
      flipflops(1) <= flipflops(0);
      if(counter_set = '1') then                  --reset counter because input is changing
        counter_out <= (others => '0');
      elsif(counter_out(counter_size) = '0') then --stable input time is not yet met
        counter_out <= counter_out + 1;
      else                                        --stable input time is met
        result <= flipflops(1);
      end if;    
    end if;
  end process;
end hardware;