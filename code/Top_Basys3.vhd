--=============================================================================
-- Integrating entity for the EPM CPU with a Basys3 card
--=============================================================================
-- Code for the manuscript:
-- The Post's Machine Reloaded
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
library ieee; -- declaramos la libreria 'ieee'
  use ieee.std_logic_1164.all; -- usaremos el modulo '1164'

-------------------------------------------------------------------------------
-- Entity declaration
-------------------------------------------------------------------------------
entity Basys3_system is -- declaramos la entidad con nombre 'Basys3_system'
port ( -- declaramos sus puertos

  --Basys3 Resources
  btnC          : in std_logic; -- sys_rst 
  btnU          : in std_logic; -- manm_clk 
  btnR          : in std_logic; -- run_sig 
  sysclk        : in std_logic; -- reloj del sistema
  led           : out std_logic_vector(15 downto 0); -- indicador de estado de switch
  sw            : in std_logic_vector(15 downto 0); -- ingresador de direccion de mem. RAM
  seg           : out std_logic_vector(6 downto 0); -- 7 segmentos del display
  an            : out std_logic_vector(3 downto 0) -- 4 anodos, de cada display 

);
end Basys3_system; -- finalizamos la entidad

architecture my_arch of Basys3_system is -- declaramos la arquiectura 'my_arch' del modulo 'Basys3_system' 

-------------------------------------------------------------------------------
-- Components declaration
-------------------------------------------------------------------------------
-- declaramos las entidades externas que se emplearan
component doublepulse_generator --del codigo 'double_pulse'
   port(
      clk       : in std_logic; -- reloj
      reset     : in std_logic; -- reinicio
      trigger   : in std_logic; -- disparador
      p         : out std_logic -- pulso final
   );
end component;

component deboucing_3tics -- del codigo 'debouncing_mod'
   port(
      clk   : in std_logic; -- reloj
      rst   : in std_logic; -- reinicio
      x     : in std_logic; -- entrada
      y     : out std_logic -- salida final
   );
end component;

component Bin_Counter -- del bloque IP 'Bin_Counter'
  port (
    clk     : in std_logic; -- reloj
    q       : out std_logic_vector(23 DOWNTO 0) -- divisor de freq.
  );
end component;

component hex2led -- del codigo 'behavioral_hex2led'
    Port ( 
      hex   : in std_logic_vector(3 downto 0); -- los 4 disp. de la FPGA
      led   : out std_logic_vector(6 downto 0 ) -- Los 7 seg de cada disp.
  );
end component;

component RAM_4096x1 -- del bloque IP 'RAM_4096x1'
  Port (
    clka    : in std_logic; -- el reloj
    ena     : in std_logic; -- la habilitacion 0 OFF, 1 ON
    wea     : in std_logic_vector(0 downto 0); -- escritura 1 o lectura 0
    addra   : in std_logic_vector(11 downto 0); -- direccion 0 a 4095
    dina    : in std_logic_vector(0 downto 0); -- el valor de escritura
    douta   : out std_logic_vector(0 downto 0) --  el valor de esa direccion
  );
end component;

component ROM_4096x4 -- del bloque IP 'ROM_4096x4'
  Port (
    clka    : in std_logic; -- su reloj
    ena     : in std_logic; -- habilitacion
    addra   : in std_logic_vector(11 downto 0); -- direccion 0 a 4096
    douta   : out std_logic_vector(3 downto 0) -- valor de esa direccion en nibbles
  );
end component;

component Post_cpu -- del codigo 'MPM_cpu'
   port(
      clk, reset : in std_logic; -- reloj, reinicio(btnC)
      run        : in std_logic; -- corrida de la cpu (btnR)
      state      : out std_logic_vector(7 downto 0); -- estado actual de la maquina 
      code_add   : out std_logic_vector(11 downto 0); -- direccion del codigo ROM a 4096
      code       : in std_logic_vector(3 downto 0); -- nibble
      code_mem   : out std_logic; -- señal de habilitacion de la memoria del codigo
      data_add   : out std_logic_vector(11 downto 0); -- direccion de la RAM a 4096
      din        : in std_logic; -- La entrada de escritura
      dout       : out std_logic; -- La salida de lectura
      data_mem   : out std_logic; -- señal de habilitacion de la memoria de datos
      data_we    : out std_logic -- señal de habilitacion de la escritura
  );
end component;

-------------------------------------------------------------------------------
-- Signal declaration
-------------------------------------------------------------------------------
-- las señales/alias que usaremos en este codigo
signal sys_rst       : std_logic; -- btnC, los reset de todos los componentes
signal refresh       : std_logic; -- btnU, entrada 'x' del debouncing
signal exec_mode     : std_logic; -- sw15, modo ejecucion o manual
signal one_pulse     : std_logic; -- salida 'y' del debouncing
signal run_sig       : std_logic; -- btnR, run de 'Post_cpu'
signal usrclk        : std_logic_vector(23 downto 0); -- Divided clock signals  
signal disp_driver   : std_logic_vector(6 downto 0); -- 7 segments LED Disp.   
signal ram2cpu_data  : std_logic; -- din de 'Post_cpu'
signal cpu2ram_data  : std_logic; -- dout de 'Post_cpu'
signal manm_din      : std_logic; -- sw12
signal muxed_din     : std_logic; -- dina(0) de 'RAM_256x1'
signal data_add_bus  : std_logic_vector(11 downto 0); -- data_add de 'Post_cpu' RAM
signal manm_add      : std_logic_vector(11 downto 0); --
signal muxed_add     : std_logic_vector(11 downto 0); -- addra de 'RAM_256x1'
signal code_add_bus  : std_logic_vector(11 downto 0); -- code_add de 'Post_cpu' ROM
signal code_bus      : std_logic_vector(3 downto 0);
signal RAM_en        : std_logic; -- datamem de 'Post_cpu'
signal manm_en       : std_logic; -- sw14
signal muxed_en      : std_logic; -- ena de 'RAM_256x1'
signal RAM_we        : std_logic; -- datawe de 'Post_cpu'
signal manm_we       : std_logic; -- sw13
signal muxed_we      : std_logic; -- wea(0) de 'RAM_256x1'
signal ROM_en        : std_logic; -- codemem de 'Post_cpu'
signal mem_clk       : std_logic; -- clka de 'ROM_256x4' reloj bloques de memoria
signal manm_clk      : std_logic; -- p de 'doblepulsegenerator'
signal muxed_clk     : std_logic; -- clka de 'RAM_256x1'
signal cpu_clk       : std_logic; -- clk de 'Post_cpu' reloj del sistema
signal disp_ref_clk  : std_logic; -- clk de 'doblepulsegenerator'
signal disp_bus      : std_logic_vector(3 downto 0); -- HEX de 'hex2led'
signal state_byte    : std_logic_vector(7 downto 0); -- state de 'Post_cpu'
signal state_nible   : std_logic_vector(3 downto 0);
signal data_byte     : std_logic_vector(7 downto 0);
signal data_nible    : std_logic_vector(3 downto 0);

-------------------------------------------------------------------------------
-- Begin
-------------------------------------------------------------------------------
begin -- comienza

   my_Post_Machine : Post_cpu -- asignacion de señales
   port map( -- Mapeo
      clk => cpu_clk, 
      reset => sys_rst,
      run  => run_sig,
      state => state_byte,
      code_add => code_add_bus,
      code => code_bus,
      code_mem => ROM_en,
      data_add => data_add_bus,
      din => ram2cpu_data,
      dout => cpu2ram_data,
      data_mem => RAM_en,
      data_we => RAM_we
  );

    my_Pulse_gen : doublepulse_generator -- asignacion de señales
    port map ( -- Mapeo
        clk => disp_ref_clk,
        reset => sys_rst,
        trigger => one_pulse,
        p => manm_clk   
    );

    my_Deboucing : deboucing_3tics -- asignacion de señales
    port map (-- Mapeo
        clk => disp_ref_clk,
        rst => sys_rst,
        x => refresh,
        y => one_pulse   
    );

    my_Counter : Bin_Counter -- asignacion de señales
    port map ( -- Mapeo
        clk => sysclk,
        q => usrclk
    );

    my_RAM  : RAM_4096x1 -- asignacion de señales
    port map( -- Mapeo
        clka => muxed_clk,
        ena => muxed_en,
        wea(0) => muxed_we,
        addra => muxed_add,
        dina(0) => muxed_din,
        douta(0) => ram2cpu_data  
    );
  
    my_ROM  : ROM_4096x4 -- asignacion de señales
    port map( -- Mapeo
      clka => mem_clk,
      ena => ROM_en,
      addra => code_add_bus,
      douta => code_bus  
    );

 -- Binary coded Hexa to 7 segments display:

    my_Display7seg : hex2led -- asignacion de señales
    port map ( -- Mapeo
          hex => disp_bus,
          led => disp_driver 
      );
             
    state_nible <= state_byte(7 downto 4) when (disp_ref_clk = '1') else
                    state_byte(3 downto 0);

    data_nible <= data_byte(7 downto 4) when (disp_ref_clk = '1') else
                    data_byte(3 downto 0);

    an <=  "0111" when (disp_ref_clk = '1') else
            "1011";         

    seg <= disp_driver;

    data_byte <= "00000001" when (ram2cpu_data = '1') else
                "00000000";

    disp_bus <= state_nible when (exec_mode = '1') else
                data_nible;

-- RAM's multiplexed control:
    muxed_add <= data_add_bus when (exec_mode = '1') else
                  manm_add;

    muxed_din <= cpu2ram_data when (exec_mode = '1') else
                  manm_din;

    muxed_en <= RAM_en when (exec_mode = '1') else
                  manm_en;

    muxed_we <= RAM_we when (exec_mode = '1') else 
                  manm_we;

    muxed_clk <= mem_clk when (exec_mode = '1') else 
                  manm_clk;

-- Conections:
-- asignacion de señales a puertos fisicos de la FPGA
    disp_ref_clk <= usrclk(20); 
    mem_clk <= usrclk(22); -- division de freq.
    cpu_clk <= usrclk(23);
    
    sys_rst <= btnC;
    refresh <= btnU;
    run_sig <= btnR;
    exec_mode <= sw(15);
    manm_en <= sw(14);
    manm_we <= sw(13);
    manm_din <= sw(12);
    manm_add <= sw(11 downto 0);
    
    led(0)<= sw(0);   -- manm_add0 & LED
    led(1)<= sw(1);   -- manm_add1 & LED
    led(2)<= sw(2);   -- manm_add2 & LED
    led(3)<= sw(3);   -- manm_add3 & LED
    led(4)<= sw(4);   -- manm_add4 & LED
    led(5)<= sw(5);   -- manm_add5 & LED
    led(6)<= sw(6);   -- manm_add6 & LED
    led(7)<= sw(7);   -- manm_add7 & LED
    led(8)<= sw(8);     -- manm_add8 & LED
    led(9)<= sw(9);     -- manm_add9 & LED
    led(10)<= sw(10);   -- manm_add10 & LED
    led(11)<= sw(11);   -- manm_add11 & LED
    
    led(12)<= sw(12);   -- manm_din & LED
    led(13)<= sw(13);   -- manm_we & LED
    led(14)<= sw(14);   -- manm_en & LED
    led(15)<= sw(15);   -- exec_mode & LED

end my_arch;
