library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity taturana_1 is
  port (
    clk50           :   in      std_logic;                      -- Oscilador de 50 MHz
    clk_bt          :   in      std_logic;                      -- Clock por botão
    up_bt           :   in      std_logic;
    prog_run        :   in      std_logic;                      -- Chave para programação (1 para programar)
    clk_sel         :   in      std_logic;                      -- Chave para selecionar a origem do clock
    leds1, leds0    :   out     std_logic_vector(3 downto 0);   -- Leds para as portas de saída
    sw1, sw0        :   in      std_logic_vector(3 downto 0);   -- Chaves para as portas de entrada ou programação (sw1 = endereço, sw0 = dado)
    d_pc            :   out     std_logic_vector(0 to 6);       -- Display que mostra PC (display 5)
    d_prog_data_h   :   out     std_logic_vector(0 to 6);       -- Display que mostra conteúdo da memória de programa (display 4)
    d_prog_data_l   :   out     std_logic_vector(0 to 6)        -- Display que mostra conteúdo da memória de programa (display 4)
  
  ) ;
end taturana_1;


architecture main of taturana_1 is
  -- Funções
  function display_7seg(data  : std_logic_vector(3 downto 0)) return std_logic_vector is
  begin
    case data is
        when "0000" => return "0000001"; ---0
        when "0001" => return "1001111"; ---1
        when "0010" => return "0010010"; ---2
        when "0011" => return "0000110"; ---3
        when "0100" => return "1001100"; ---4
        when "0101" => return "0100100"; ---5
        when "0110" => return "0100000"; ---6
        when "0111" => return "0001111"; ---7
        when "1000" => return "0000000"; ---8
        when "1001" => return "0000100"; ---9
        when "1010" => return "0001000"; ---a
        when "1011" => return "1100000"; ---b
        when "1100" => return "0110001"; ---c
        when "1101" => return "1000010"; ---d
        when "1110" => return "0110000"; ---e
        when "1111" => return "0111000"; ---f
        when others => return "1111111"; ---null
        end case;

  end function;

  -- Componentes

  component debounce is
    generic(
      counter_size  :  integer := 19);
    port(
      clk     : in  std_logic;
      button  : in  std_logic; 
      result  : out std_logic);
        
  end component debounce;

  component taturana_cpu is
    port (
      clock           :   in      std_logic;
      rst             :   in      std_logic;
      prog_addr       :   out     std_logic_vector(3 downto 0);
      prog_data       :   in      std_logic_vector(7 downto 0);
      cpu_mem_addr    :   out     std_logic_vector(3 downto 0);
      cpu_mem_data_out:   out     std_logic_vector(3 downto 0);
      cpu_mem_data_in :   in      std_logic_vector(3 downto 0);
      cpu_mem_write   :   out     std_logic
      
    ) ;
  end component taturana_cpu;

  component data is
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
			enable        : in  std_logic
			
		);
  end component data;

  component prog is
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
  end component prog;

  component periph is
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
      q		          : out std_logic_vector((DATA_WIDTH -1) downto 0);
      enable        : in  std_logic;
      leds1, leds0  : out std_logic_vector(3 downto 0);   
      sw1, sw0      : in  std_logic_vector(3 downto 0)   
    );
  
  end component periph;

  -- Tipos
  type mode_t     is(
    MODE_RUN,
    MODE_PROG
  );

  type clock_t    is(
    CLOCK_STEP,
    CLOCK_1HZ
  );
  
  -- Sinais
  signal up               : std_logic;
  signal clk1 	           : std_logic;
  signal sys_clk          : std_logic;
  signal mode             : mode_t;
  signal clk_mode         : clock_t;
  signal clk_debounced    : std_logic;
  signal rst              : std_logic;
  signal prog_addr        : std_logic_vector(3 downto 0);
  signal cont_addr        : std_logic_vector(3 downto 0);
  signal addr             : std_logic_vector(3 downto 0);
  signal prog_data        : std_logic_vector(7 downto 0);
  signal prog_in          : std_logic_vector(7 downto 0);
  signal prog_we          : std_logic;
  signal data_addr        : std_logic_vector(3 downto 0);
  signal data_in          : std_logic_vector(3 downto 0);
  signal data_out         : std_logic_vector(3 downto 0);
  signal data_out_ram     : std_logic_vector(3 downto 0);
  signal data_out_per     : std_logic_vector(3 downto 0);
  signal data_write       : std_logic;  
  signal enable_prog      : std_logic;
  signal enable_ram       : std_logic;
  signal enable_per       : std_logic;
     

    

begin

  rst <= prog_run;
  prog_in <= sw1 & sw0;
  addr <= prog_addr when prog_run = '0' else cont_addr;
  
  -- Divisor de clock para 1 Hz
  process(clk50, rst)
    variable  x : integer range 0 to 25_000_000;
  begin
    if rst = '1' then
      x := 0;
    elsif rising_edge(clk50) then
      x := x + 1;
      if x = 5_000_000 then
        clk1 <= not clk1;
        x := 0;
      end if;
    end if;
  end process;

    -- Filtro anti-trepidação para o sinal de clock do botão
    u1: debounce
        generic map(counter_size => 19)
        port map(
          clk => clk50,
          button => clk_bt,
          result => clk_debounced
        );
    

    -- Modo de execução programação
    mode <= MODE_RUN when prog_run = '0' else MODE_PROG;

    -- Tipo de clock
    clk_mode <= CLOCK_STEP when (clk_sel = '0' or mode = MODE_PROG) else CLOCK_1HZ;
    sys_clk <= clk1 when clk_mode = CLOCK_1HZ else clk_debounced;    

    -- Decodificador de memória e periféricos
	 data_out <= data_out_ram when data_addr(3) = '0' else data_out_per;

    -- cpu
    cpu: taturana_cpu
        port map(
          clock => sys_clk,
          rst => rst,
          prog_addr => prog_addr,
          prog_data => prog_data,
          cpu_mem_addr => data_addr,
          cpu_mem_data_out => data_in,
          cpu_mem_data_in => data_out,
          cpu_mem_write => data_write
        );

    -- RAM
    data_inst : data
      generic map(
        DATA_WIDTH => 4,
        ADDR_WIDTH => 3
      )
      port map(
        addr => data_addr(2 downto 0),
        data => data_in,
        we => data_write,
        q => data_out_ram,
        enable => enable_ram
      );
      enable_ram <= '1' when data_addr(3) = '0' and data_write = '1' and sys_clk = '0' else '0';

    -- ROM
    prog_inst : prog
      generic map(
        DATA_WIDTH => 8,
        ADDR_WIDTH => 4
      )
      port map (
        addr => addr,
        data => prog_in,
        we => prog_we,
        q => prog_data,
        enable => enable_prog
      );
      enable_prog <= '1' when prog_run = '1' else '0';
      prog_we <= '1' when prog_run = '1' and sys_clk = '0' else '0';

    -- Periféricos
    periph_inst : periph
      generic map(
        DATA_WIDTH => 4,
        ADDR_WIDTH => 3
      )
      port map(        
        addr => data_addr(2 downto 0),
        data => data_in,
        we => data_write,
        q => data_out_per,
        enable => enable_per,
        leds1 => leds1,
        leds0 => leds0,
        sw1 => sw1,
        sw0 => sw0
      );
      enable_per <= '1' when data_addr(3) = '1' and data_write = '1' and sys_clk = '0' else '0';


    -- Lógica de programação
    d_pc <= display_7seg(addr);
    d_prog_data_h <= display_7seg(prog_data(7 downto 4));   
    d_prog_data_l <= display_7seg(prog_data(3 downto 0));

    u2: debounce
        generic map(counter_size => 19)
        port map(
          clk => clk50,
          button => up_bt,
          result => up
        );

    counter : process(up, prog_run)
      variable x : integer range 0 to 15;
    begin
      if prog_run = '0' then
        x := 0;
      elsif rising_edge(up) then
        if x = 15 then
          x := 0;
        else
          x := x + 1;
        end if;
      end if;
      cont_addr <= std_logic_vector(to_unsigned(x,4));
    end process ; -- counter


end main ; -- main