--=============================================================================
-- My Post Machine Entity (EPM CPU) 
--=============================================================================
-- Code for the manuscript:
-- The Post’s Machine Reloaded
-- Design, Implementation and Programming of 
-- a Small and Functional CPU Prototype
--=============================================================================
-- Author: Gerardo A. Laguna-Sanchez
-- Universidad Autonoma Metropolitana
-- Unidad Lerma
-- may.08.2020
--=============================================================================
-- Modified by: Victor D. Lopez-Munguia
-- Universidad Autonoma Metropolitana
-- Unidad Lerma
-- dic.03.2024
-- RAM & ROM up to 4096
--=============================================================================

-------------------------------------------------------------------------------
-- Library declarations
-------------------------------------------------------------------------------
library ieee; -- declaracion de libreria 'ieee'
use ieee.std_logic_1164.all; -- se usara el modulo '1164'
use ieee.numeric_std.all; -- se usara el modulo 'numeric'

-------------------------------------------------------------------------------
-- Entity declaration
-------------------------------------------------------------------------------
entity Post_cpu is -- declaramos la entidad con nombre 'Post_cpu'
   port( -- declaramos los puertos
      clk, reset : in std_logic; -- reloj y reinicio, como entradas
      run        : in std_logic; -- run como entrada
      state      : out std_logic_vector(7 downto 0); -- estado como vector de salida de 8 elementos
      code_add   : out std_logic_vector(11 downto 0); -- direccion de codigo como salida de 12 elementos
      code       : in std_logic_vector(3 downto 0); -- codigo como entrada de 4 elementos
      code_mem   : out std_logic; -- salida
      data_add   : out std_logic_vector(11 downto 0); -- direccion de la RAM como salida de 12 elementos
      din        : in std_logic; -- data in, en caso de escritura
      dout       : out std_logic; -- data out, en caso de lectura
      data_mem   : out std_logic; -- salida
      data_we    : out std_logic -- salida
  );
end Post_cpu; -- finalizamos entidad

architecture my_arch of Post_cpu is -- declaramos arquitectura 'my_arch' de la entidad
-------------------------------------------------------------------------------
-- Constant declaration
-------------------------------------------------------------------------------
-- declaracion de constantes, siendo estas una serie de secuencia binaria
   constant stop             :  std_logic_vector(7 downto 0):= "00000000"; --0
   constant start            :  std_logic_vector(7 downto 0):= "00000001"; --1
   constant fetch            :  std_logic_vector(7 downto 0):= "00000010"; --2
   constant decode           :  std_logic_vector(7 downto 0):= "00000011"; --3
   constant point_ha_jmp     :  std_logic_vector(7 downto 0):= "00000100"; --4
   constant load_ha_jmp      :  std_logic_vector(7 downto 0):= "00000101"; --5
   constant point_ma_jmp     :  std_logic_vector(7 downto 0):= "00000110"; --6 AGREGAMOS EL NUEVO NIBBLE
   constant load_ma_jmp      :  std_logic_vector(7 downto 0):= "00000111"; --7
   constant point_la_jmp     :  std_logic_vector(7 downto 0):= "00001000"; --8
   constant load_la_jmp      :  std_logic_vector(7 downto 0):= "00001001"; --9
   constant jmp              :  std_logic_vector(7 downto 0):= "00001010"; --10
   constant point_ha_jz      :  std_logic_vector(7 downto 0):= "00001011"; --11
   constant load_ha_jz       :  std_logic_vector(7 downto 0):= "00001100"; --12
   constant point_ma_jz      :  std_logic_vector(7 downto 0):= "00001101"; --13 AGREGAMOS EL NUEVO NIBBLE
   constant load_ma_jz       :  std_logic_vector(7 downto 0):= "00001110"; --14  
   constant point_la_jz      :  std_logic_vector(7 downto 0):= "00001111"; --15
   constant load_la_jz       :  std_logic_vector(7 downto 0):= "00010000"; --16
   constant point_data_jz    :  std_logic_vector(7 downto 0):= "00010001"; --17
   constant loadntst_data_jz :  std_logic_vector(7 downto 0):= "00010010"; --18
   constant jz               :  std_logic_vector(7 downto 0):= "00010011"; --19
   constant incdp            :  std_logic_vector(7 downto 0):= "00010100"; --20
   constant decdp            :  std_logic_vector(7 downto 0):= "00010101"; --21
   constant set              :  std_logic_vector(7 downto 0):= "00010110"; --22
   constant clr              :  std_logic_vector(7 downto 0):= "00010111"; --23
   constant nop_code         :  std_logic_vector(3 downto 0):= "0000"; --0 No operacion
   constant incdp_code       :  std_logic_vector(3 downto 0):= "0001"; --1 Incremento del DP
   constant decdp_code       :  std_logic_vector(3 downto 0):= "0010"; --2 Decremento del DP
   constant set_code         :  std_logic_vector(3 downto 0):= "0011"; --3 Escritura de '1'
   constant clr_code         :  std_logic_vector(3 downto 0):= "0100"; --4 Escritura de '0'
   constant jmp_code         :  std_logic_vector(3 downto 0):= "0101"; --5 Salto
   constant jz_code          :  std_logic_vector(3 downto 0):= "0110"; --6 Salto condicional
   constant stoop_code       :  std_logic_vector(3 downto 0):= "0111"; --7 Parada

-------------------------------------------------------------------------------
-- Signal declaration
-------------------------------------------------------------------------------
   signal state_reg, state_next            : std_logic_vector(7 downto 0); --8
   signal IP_reg, IP_next                  : unsigned(11 downto 0); -- 0 a 4095 de ROM
   signal DP_reg, DP_next                  : unsigned(11 downto 0); -- 0 a 4095 de RAM
   signal instruction_reg, instruction_next: std_logic_vector(3 downto 0); -- code 0 a 7
   signal hadd_reg, hadd_next              : unsigned(3 downto 0); -- primer nibble MSB
   signal madd_reg, madd_next              : unsigned(3 downto 0); -- segundo nibble middle (EL NUEVO)
   signal ladd_reg, ladd_next              : unsigned(3 downto 0); -- tercer nibbble LSB
   signal bit_reg, bit_next                : std_logic; 
   signal rome_next, rame_next, we_next    : std_logic;
   signal rome_reg, rame_reg, we_reg       : std_logic;

-------------------------------------------------------------------------------
-- Begin
-------------------------------------------------------------------------------
begin -- comenzamos
   -- state & data registers
   process(clk,reset) -- declaramos proceso para reloj y reinicio
   begin -- iniciamos
      if (reset='1') then -- si reset es '1' entonces, todos los registros en '0'
         state_reg <= stop; -- a la señal 'state_reg' se le asigna la constante 'stop'
         IP_reg <= (others=>'0'); -- todos los bits de 'IP_reg' en '0'
         DP_reg <= (others=>'0'); -- todos los bits de 'DP_reg' en '0'
         instruction_reg <= (others=>'0'); -- todos los bits de 'instruction_reg' en '0'
         hadd_reg <= (others=>'0'); -- todos los bits de 'hadd_reg' en '0'
         madd_reg <= (others=>'0'); -- todos los bits de 'madd_reg' en '0'
         ladd_reg <= (others=>'0'); -- todos los bits de 'ladd_reg' en '0'
         bit_reg <= '0'; -- a '0'
         rome_reg <= '0'; -- a '0'
         rame_reg <= '0'; -- a '0'
         we_reg <= '0'; --'0'
      elsif (clk'event and clk='1') then -- si no, y hay un cambio en el reloj y este vale '1', entonces
         state_reg <= state_next; -- state_reg tomara el valor de state_next
         IP_reg <= IP_next; -- IP_state tomara el valor de IP_next
         DP_reg <= DP_next; -- DP_reg tomara el valor de DP_next
         instruction_reg <= instruction_next; --instruction_reg tomara el valor de instruction_next
         hadd_reg <= hadd_next; -- hadd_reg tomara el valor de hadd_next
         madd_reg <= madd_next; -- madd_reg tomara el valor de madd_next
         ladd_reg <= ladd_next; -- ladd_reg tomara el valor de ladd_next
         bit_reg <= bit_next; -- bit_reg tomara el valor de bit_next
         rome_reg <= rome_next; -- rome_reg toamra el valor de rome_next
         rame_reg <= rame_next; -- tomara el valor de rame_next
         we_reg <= we_next; -- we_reg tomara el valor de we_next 
      end if; -- terminamos if
   end process; -- terminamos proceso
   -- En pocas palabras, el proceso anterior consistio en que si reset es '1', todos los registros se ponen en '0's
   -- Si no ocurre eso y hay flanco de subida '1' en el reloj, todos los registros tomaran el valor next

   -- next-state logic & data path functional units/routing
   process(state_reg,run,code,din, 
           IP_reg,DP_reg,instruction_reg,hadd_reg,madd_reg,ladd_reg)
   begin
      IP_next <= IP_reg;
      DP_next <= DP_reg;
      instruction_next <= instruction_reg;
      hadd_next <= hadd_reg;
      madd_next <= madd_reg;
      ladd_next <= ladd_reg;

      case state_reg is
         when stop =>
            if run='1' then
               state_next <= start;
            else
               state_next <= stop;
            end if;
         when start =>
            IP_next <= (others=>'0');
            DP_next <= (others=>'0');
            state_next <= fetch;
         when fetch =>
            state_next <= decode;
         when decode =>
            instruction_next <= code;
            IP_next <= IP_reg + 1;
            if code = nop_code then --If nop
               state_next <= fetch;
            else
               if code = incdp_code then --If incdp
                  state_next <= incdp;
               else
                  if code = decdp_code then --If decdp
                     state_next <= decdp;
                  else
                     if code = set_code then --If set
                        state_next <= set;
                     else
                        if code = clr_code then --If clr
                           state_next <= clr;
                        else
                           if code = jmp_code then --If jmp
                              state_next <= point_ha_jmp;
                           else
                              if code = jz_code then --If jz
                                 state_next <= point_ha_jz;
                              else
                                 --If stop
                                 state_next <= stop;
                              end if; 
                           end if; 
                        end if; 
                     end if; 
                  end if; 
               end if; 
            end if;
         when point_ha_jmp =>
            state_next <= load_ha_jmp;
         when load_ha_jmp => 
            IP_next <= IP_reg + 1;
            hadd_next <= unsigned(code);
            state_next <= point_ma_jmp;           
         when point_ma_jmp =>     ---------- incluimos el nuevo nibble
            state_next <= load_ma_jmp;   
         when load_ma_jmp =>
            madd_next <= unsigned(code);
            state_next <= point_la_jmp; --------------------   
         when point_la_jmp =>
            state_next <= load_la_jmp;
         when load_la_jmp =>
            ladd_next <= unsigned(code);
            state_next <= jmp;  
         when jmp =>
            IP_next <= hadd_reg & madd_reg & ladd_reg; --- agregamos el nuevo nibble
            state_next <= fetch;
         when point_ha_jz =>
            state_next <= load_ha_jz;
         when load_ha_jz =>
            IP_next <= IP_reg + 1;
            hadd_next <= unsigned(code);
            state_next <= point_ma_jz;  
         when point_ma_jz =>   ------------------- agregamos el nuevo nibble
            state_next <= load_ma_jz;
         when load_ma_jz =>
            IP_next <= IP_reg + 1;
            madd_next <= unsigned(code);
            state_next <= point_la_jz; ----------------------------------------
         when point_la_jz =>
            state_next <= load_la_jz;
         when load_la_jz =>
            IP_next <= IP_reg + 1;
            ladd_next <= unsigned(code);
            state_next <= point_data_jz;
         when point_data_jz =>
            state_next <= loadntst_data_jz;
         when loadntst_data_jz =>
            if din='0' then
               state_next <= jz;
            else
               state_next <= fetch;
            end if;
         when jz =>
            IP_next <= hadd_reg & madd_reg & ladd_reg;
            state_next <= fetch;
         when incdp =>
            DP_next <= DP_reg + 1;
            state_next <=fetch;
         when decdp =>
            DP_next <= DP_reg - 1;
            state_next <=fetch;
         when set =>
            state_next <=fetch;
         when clr =>
            state_next <=fetch;
         when others =>
            state_next <=stop;
      end case;
   end process;

   -- look-ahead output logic
   process(state_next)
   begin
      rome_next <= '0';
      rame_next <= '0';
      we_next <= '0';
      bit_next <= '0';
      
      case state_next is
         when stop =>
         when start =>
         when fetch =>
            rome_next <= '1';
         when decode =>
            rome_next <= '1';  
         when point_ha_jmp =>
            rome_next <= '1';
         when load_ha_jmp =>
            rome_next <= '1';  
         when point_ma_jmp =>     ------------------- agregamos el nuevo nibble
            rome_next <= '1';
         when load_ma_jmp =>
            rome_next <= '1';  ------------------------------  
         when point_la_jmp =>
            rome_next <= '1';
         when load_la_jmp =>
            rome_next <= '1';
            
         when jmp =>     
         when point_ha_jz =>
            rome_next <= '1';
         when load_ha_jz =>
            rome_next <= '1';   
         when point_ma_jz => --------------- agregamos el nuevo nibble
            rome_next <= '1';
         when load_ma_jz =>
            rome_next <= '1';  -----------------------          
         when point_la_jz =>
            rome_next <= '1';
         when load_la_jz =>
            rome_next <= '1';
            
         when point_data_jz =>
            rame_next <= '1';
         when loadntst_data_jz =>
            rame_next <= '1';
         when jz =>
         when incdp=>
         when decdp=>
         when set =>
            bit_next <= '1';
            rame_next <= '1';
            we_next <= '1';
         when clr =>
            bit_next <= '0';
            rame_next <= '1';
            we_next <= '1';
         when others =>
         
      end case;
   end process;

   --  outputs
   state <= state_reg;
   code_add <= std_logic_vector(IP_reg);
   code_mem <= rome_reg;
   data_add <= std_logic_vector(DP_reg);
   dout <= bit_reg;
   data_mem <= rame_reg;
   data_we <= we_reg;

end my_arch;
