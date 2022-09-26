-----------------------------------------------------------------------------------------------------------
-- Taturana CPU versão 1.0
-- Autor:   Felipe Walter Dafico Pfrimer
-- Data:    15/12/2018
--
-- Descrição:
--      Processador de 4 bits para fins didáticos. O código é uma versão simplificada do NibblerCPU, cuja
--      programação encontra-se em https://gist.github.com/erincandescent/347577465129882abc97. No entanto,
--      as instruções do Taturana são um pouco diferentes em relação ao NibblerCPU e os periférico devem 
--      ser mapeados na memória de dados. Adicionalmente, o Taturana possui tanto a memória de dados como
--      a memória de programa bastante reduzidas, pois trata-se de um processador conceito para fins 
--      educacionais.
--
-- Especificações:
--      - Até 16 bytes de memória de programa (16 x 8 bits);
--      - Até 16 nibbles de memória de dados (16 x 4 bits);
--      - 16 instruções;
--      - Não possui apontador de pilha (Stack Pointer) devido à memória limitada;
--      - 2 ciclos de clock por ciclo de máquina para todas as instruções;
--
-- Observações:
--      1 - A memória de dados e a memória de programa devem ser assíncronas;
--      2 - Periféricos, como portas de entrada e saída devem ser mapeados na memória de dados;
--      3 - O processador é ideal para ser gravado em um CPLD ou FPGA.  
-----------------------------------------------------------------------------------------------------------

-- Bibliotecas --------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;        -- Para uso das interfaces (sinais na entidade)
use ieee.numeric_std.all;           -- Para operações aritméticas na Unidade Lógica Aritmética (ULA)

-- Entidade ----------------------------------------------------------------------------------------------
entity taturana_cpu is
  port (
    clock           :   in      std_logic;                      -- Clock do sistema
    rst             :   in      std_logic;                      -- Reset do sistema
    
    -- Meméria de programa (ROM):
    prog_addr       :   out     std_logic_vector(3 downto 0);   -- Endereço da memória de programa
    prog_data       :   in      std_logic_vector(7 downto 0);   -- Dado da memória de programa

    -- Memória de dados:
    cpu_mem_addr    :   out     std_logic_vector(3 downto 0);   -- Endereço da memória de dados
    cpu_mem_data_out:   out     std_logic_vector(3 downto 0);   -- Saída de dados da CPU para a memória
    cpu_mem_data_in :   in      std_logic_vector(3 downto 0);   -- Entrada de dados da memória para a CPU
    cpu_mem_write   :   out     std_logic                       -- Sinal de controle para habilitar a
                                                                --      escrita de dados na memória
  ) ;
end taturana_cpu;

architecture main of taturana_cpu is

    -- Constantes -----------------------------------------------------------------------------------------
    -- Set de instruções:
    constant NOP_OP   :   std_logic_vector(3 downto 0) := "0000";   -- No operation
    constant JNZ_OP   :   std_logic_vector(3 downto 0) := "0001";   -- Jump if not zero
    constant JNC_OP   :   std_logic_vector(3 downto 0) := "0010";   -- Jump if not carry
    constant JMP_OP   :   std_logic_vector(3 downto 0) := "0011";   -- Incondicional Jump
    constant LDI_OP   :   std_logic_vector(3 downto 0) := "0100";   -- Load accumulator with immediate data
    constant LDR_OP   :   std_logic_vector(3 downto 0) := "0101";   -- Load accumulator with ram data
    constant STR_OP   :   std_logic_vector(3 downto 0) := "0110";   -- Store accumulator value 
    constant XRI_OP   :   std_logic_vector(3 downto 0) := "0111";   -- XOR with immediate data
    constant CPM_OP   :   std_logic_vector(3 downto 0) := "1000";   -- Compare with ram data
    constant CPI_OP   :   std_logic_vector(3 downto 0) := "1001";   -- Compare with immediate data
    constant SUB_OP   :   std_logic_vector(3 downto 0) := "1010";   -- Subtract with ram data
    constant XOR_OP   :   std_logic_vector(3 downto 0) := "1011";   -- XOR with ram data
    constant ADD_OP   :   std_logic_vector(3 downto 0) := "1100";   -- Add with ram data
    constant ADI_OP   :   std_logic_vector(3 downto 0) := "1101";   -- Add with immediate data
    constant AND_OP   :   std_logic_vector(3 downto 0) := "1110";   -- AND with ram data
    constant ANI_OP   :   std_logic_vector(3 downto 0) := "1111";   -- AND with immediate data
    
    -- Tipos ----------------------------------------------------------------------------------------------
    type phase_t        is (
        FETCH,              -- Busca por instrução
        EXECUTE             -- Executa                 
        
    );

    type pc_action_t    is (
        PC_INCREMENT,       -- Incrementa o contador de programa (PC)
        PC_LOAD,            -- Carrega o contador de programa
        PC_NOP              -- PC não atualiza
    );

    type alu_source_t   is (
        ALU_IMMEDIATE,      -- Dado imadiato
        ALU_MEMORY          -- Dado da memória
    );

    type alu_action_t   is (
        ALU_OP_B,           -- Passa dado da entrada B da ALU
        ALU_OP_ADD,         -- Operação de adição
        ALU_OP_SUB,         -- Operação de subtração
        ALU_OP_XOR,         -- Operção XOR
        ALU_OP_AND          -- Operação AND
    );

    type acc_action_t   is (
        ACC_NOP,            -- ACC não é atualizado
        ACC_LOAD_ALU       -- ACC atualizado com valor da ALU 
    ); 
    

    -- Sinais ---------------------------------------------------------------------------------------------

    -- Saídas do decodificador de instrução:
    signal pc_action    :   pc_action_t;
    signal load_flags   :   boolean;
    signal alu_source   :   alu_source_t;
    signal alu_action   :   alu_action_t;
    signal acc_action   :   acc_action_t;

    -- Registradores:
    signal pc           :   unsigned(3 downto 0) := "0000";             -- Contador de programa (PC)
    signal acc          :   std_logic_vector(3 downto 0) := "0000";     -- acumulador (ACC)
    signal sr           :   std_logic_vector(1 downto 0) := "00";       -- registrador de estado (status reg.)
    signal ir           :   std_logic_vector(7 downto 0) := "00000000"; -- Registrador de instrução
    signal phase        :   phase_t := FETCH;                           -- Estado atual da máquina de estados
    signal next_phase   :   phase_t := FETCH;
    
    -- Unidade lógica aritmética (ALU):
    signal alu_in       :   std_logic_vector(3 downto 0);
    signal alu_a        :   unsigned(4 downto 0);
    signal alu_b        :   unsigned(4 downto 0);
    signal alu_f        :   unsigned(4 downto 0);   -- Bit 4 é o carry
    
     
    
    -- Alias ----------------------------------------------------------------------------------------------
    alias carry_flag    :   std_logic is sr(1);             -- flag de carry
    alias zero_flag     :   std_logic is sr(0);             -- flag de carry
    alias opcode        :   std_logic_vector(3 downto 0)    -- Código de operação
        is ir(7 downto 4);
    alias operand       :   std_logic_vector(3 downto 0)    -- Operando
        is ir(3 downto 0); 
    

begin

    prog_addr <= std_logic_vector(pc);  -- Endereço de programa é PC
    cpu_mem_addr <= operand;            -- Endereço da memória vem do operando
    cpu_mem_data_out <= acc;            -- Entrada de dados para a RAM

    -- Busca de instrução:
    fetch_process : process(clock, phase, rst)
    begin
        if rst = '1' then
            ir <= "00000000";
        elsif rising_edge(clock) then
            if phase = FETCH then
                ir <= prog_data;
            end if ;
        end if ;
    end process ; -- fetch_process

    -- ALU (combinacional):
    with alu_source select
        alu_in <=   operand         when ALU_IMMEDIATE,
                    cpu_mem_data_in when ALU_MEMORY;
    alu_a <= unsigned('0' & acc);
    alu_b <= unsigned('0' & alu_in);
    with alu_action select
        alu_f <=    alu_b           when ALU_OP_B,
                    alu_a + alu_b   when ALU_OP_ADD,
                    alu_a - alu_b   when ALU_OP_SUB,
                    alu_a xor alu_b when ALU_OP_XOR,
                    alu_a and alu_b when ALU_OP_AND;

    -- Atualização dos registradores
    update_regs : process(clock, rst)
    begin
        if rst = '1' then
            pc <= "0000";
            phase <= FETCH;
        elsif rising_edge(clock) then
            -- Fase:
            phase <= next_phase;

            -- ACC
            case acc_action is            
                when ACC_NOP => null;
                when ACC_LOAD_ALU =>    acc <= std_logic_vector(alu_f(3 downto 0));       
                when others =>   null;            
            end case;

            -- PC
            case pc_action is
                when PC_INCREMENT => pc <= pc + 1;
                when PC_LOAD      => pc <= unsigned(operand);
                when PC_NOP       => null;
             end case;

             -- SR
             if load_flags then
                carry_flag <= alu_f(4);
                zero_flag  <= not (alu_f(3) or alu_f(2) or alu_f(1) or alu_f(0));
             end if;
             
        end if ; 
    end process ; -- update_regs

    -- Decodificador de instruções
    decode : process(ir, phase, carry_flag, zero_flag)
    begin
        -- Valores padrões
        load_flags     <= false;
        pc_action      <= PC_NOP;
        alu_source     <= ALU_MEMORY;
        alu_action     <= ALU_OP_ADD;
        acc_action     <= ACC_NOP;
        cpu_mem_write  <= '0';        

        case phase is
            
            -- Busca
            when FETCH =>
                -- Apenas IR é atualizado
                next_phase <= EXECUTE; 
            
            when EXECUTE =>
                pc_action <= PC_INCREMENT;
                next_phase <= FETCH;
                
                case(opcode) is            
                    when NOP_OP=>  
                        null;

                    when JNZ_OP=>
                        if zero_flag = '0' then
                            pc_action <= PC_LOAD;                 
                        end if ;

                    when JNC_OP=>
                        if carry_flag = '0' then
                            pc_action <= PC_LOAD;                     
                        end if ;

                    when JMP_OP=>
                        pc_action <= PC_LOAD;

                    when LDI_OP=>  
                        alu_source <= ALU_IMMEDIATE;
                        alu_action <= ALU_OP_B;
                        acc_action <= ACC_LOAD_ALU;

                    when LDR_OP=>  
                        alu_source <= ALU_MEMORY;
                        alu_action <= ALU_OP_B;
                        acc_action <= ACC_LOAD_ALU;
                        
                    when STR_OP=>  
                        cpu_mem_write <= '1';                        

                    when XRI_OP=>  
                        alu_source <= ALU_IMMEDIATE;
                        alu_action <= ALU_OP_XOR;
                        acc_action <= ACC_LOAD_ALU;
                        load_flags <= true;

                    when CPM_OP=>  
                        alu_source <= ALU_MEMORY;
                        alu_action <= ALU_OP_SUB;
                        load_flags <= true;

                    when CPI_OP=>  
                        alu_source <= ALU_IMMEDIATE;
                        alu_action <= ALU_OP_SUB;
                        load_flags <= true;

                    when SUB_OP=> 
                        alu_source <= ALU_MEMORY;
                        alu_action <= ALU_OP_SUB;
                        acc_action <= ACC_LOAD_ALU;
                        load_flags <= true;

                    when XOR_OP=>  
                        alu_source <= ALU_MEMORY;
                        alu_action <= ALU_OP_XOR;
                        acc_action <= ACC_LOAD_ALU;
                        load_flags <= true;

                    when ADD_OP=>  
                        alu_source <= ALU_MEMORY;
                        alu_action <= ALU_OP_ADD;
                        acc_action <= ACC_LOAD_ALU;
                        load_flags <= true;

                    when ADI_OP=>  
                        alu_source <= ALU_IMMEDIATE;
                        alu_action <= ALU_OP_ADD;
                        acc_action <= ACC_LOAD_ALU;
                        load_flags <= true;

                    when AND_OP=>  
                        alu_source <= ALU_MEMORY;
                        alu_action <= ALU_OP_AND;
                        acc_action <= ACC_LOAD_ALU;
                        load_flags <= true;

                    when ANI_OP=> 
                        alu_source <= ALU_IMMEDIATE;
                        alu_action <= ALU_OP_AND;
                        acc_action <= ACC_LOAD_ALU;
                        load_flags <= true;                   
                
                    when others => null;
                
                end case ;            
        
            when others =>
                null;
        
        end case ;
        
    end process ; -- decode

end main ; -- main