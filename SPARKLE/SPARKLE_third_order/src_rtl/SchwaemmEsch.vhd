----------------------------------------------------------------------------------
-- Code based on NIST LWC Schwaemm256128
-- 2/6/2020
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity regGen is
generic( width: integer );
port(
	d: in std_logic_vector(width - 1 downto 0);
	e, clk: in std_logic;
	q: out std_logic_vector(width - 1 downto 0)
	);
end regGen;

architecture behavioral of regGen is
begin

    process(clk) begin
        if (rising_edge(clk)) then
            if (e = '1') then
                q <= d;
            end if;
        end if;
    end process;

end behavioral;

library ieee;
use ieee.std_logic_1164.all;

entity regOne is
port(
	d: in std_logic;
	e, clk: in std_logic;
	q: out std_logic
	);
end regOne;

architecture behavioral of regOne is
begin

    process(clk) begin
        if (rising_edge(clk)) then
            if (e = '1') then
                q <= d;
            end if;
        end if;
    end process;

end behavioral;

library ieee;
use ieee.std_logic_1164.all;

entity regNum is
port(
	d: in integer;
	e, clk: in std_logic;
	q: out integer
	);
end regNum;

architecture behavioral of regNum is
begin

    process(clk) begin
        if (rising_edge(clk)) then
            if (e = '1') then
                q <= d;
            end if;
        end if;
    end process;

end behavioral;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use work.utility_functions.ALL;

entity arx_round is
Port ( 
    round_constant : in std_logic_vector(31 downto 0);
    round : in integer;
    x_round_in, y_round_in : in std_logic_vector(31 downto 0);
    x_round_out, y_round_out : out std_logic_vector(31 downto 0)
    );
end arx_round;

architecture behavioral of arx_round is
    signal sum : std_logic_vector(31 downto 0);
    signal y_rotated, sum_rotated : std_logic_vector(31 downto 0);
begin
    
    y_rotated <= rot_y_word(y_round_in, round); 
    sum <= x_round_in + y_rotated;

    sum_rotated <= rot_x_word(sum, round);
    y_round_out <= y_round_in xor sum_rotated;
    x_round_out <= sum xor round_constant;

end behavioral;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use work.utility_functions.ALL;

entity linear_layer is
    Port (
        state_in : in std_logic_vector(383 downto 0);
        state_out : out std_logic_vector(383 downto 0)
    );
end linear_layer;

architecture structural of linear_layer is

    -- Function to compute x tmp or y tmp
    function ell ( input_word : in std_logic_vector(31 downto 0))
    return std_logic_vector is variable tmp : std_logic_vector(31 downto 0);
    begin 
        tmp := (input_word(15 downto 0) & input_word(31 downto 16)) xor (x"0000" & input_word(15 downto 0));
        return tmp;
    end ell;
    
    signal xor_result_x, xor_result_y : std_logic_vector(31 downto 0);
    signal x_tmp, y_tmp : std_logic_vector(31 downto 0);

begin

    xor_result_y <= state_in(351 downto 320) xor state_in(287 downto 256) xor state_in(223 downto 192);
    xor_result_x <= state_in(383 downto 352) xor state_in(319 downto 288) xor state_in(255 downto 224);
    y_tmp <= ell(xor_result_y);
    x_tmp <= ell(xor_result_x);

    -- Update "x" words of state
    state_out(383 downto 352) <= state_in(319 downto 288) xor state_in(127 downto 96) xor y_tmp;
    state_out(319 downto 288) <= state_in(255 downto 224) xor state_in(63 downto 32) xor y_tmp;
    state_out(255 downto 224) <= state_in(383 downto 352) xor state_in(191 downto 160) xor y_tmp;
    state_out(191 downto 160) <= state_in(383 downto 352);
    state_out(127 downto 96) <= state_in(319 downto 288);
    state_out(63 downto 32) <= state_in(255 downto 224);

    -- Update "y" words of state
    state_out(351 downto 320) <= state_in(287 downto 256) xor state_in(95 downto 64) xor x_tmp;
    state_out(287 downto 256) <= state_in(223 downto 192) xor state_in(31 downto 0) xor x_tmp;
    state_out(223 downto 192) <= state_in(351 downto 320) xor state_in(159 downto 128) xor x_tmp;
    state_out(159 downto 128) <= state_in(351 downto 320);
    state_out(95 downto 64) <= state_in(287 downto 256);
    state_out(31 downto 0) <= state_in(223 downto 192);

end structural;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use work.utility_functions.ALL;

entity feistel_function is
    Port (
        state_in : in std_logic_vector(383 downto 0);
        state_out : out std_logic_vector(383 downto 0)
    );
end feistel_function;

architecture structural of feistel_function is

    -- Function to compute x tmp or y tmp
    function ell ( input_word : in std_logic_vector(31 downto 0))
    return std_logic_vector is variable tmp : std_logic_vector(31 downto 0);
    begin 
        tmp := (input_word(15 downto 0) & input_word(31 downto 16)) xor (x"0000" & input_word(15 downto 0));
        return tmp;
    end ell;
    
    signal xor_result_x, xor_result_y : std_logic_vector(31 downto 0);
    signal x_tmp, y_tmp : std_logic_vector(31 downto 0);

begin
    xor_result_y <= state_in(351 downto 320) xor state_in(287 downto 256) xor state_in(223 downto 192);
    xor_result_x <= state_in(383 downto 352) xor state_in(319 downto 288) xor state_in(255 downto 224);
    y_tmp <= ell(xor_result_y);
    x_tmp <= ell(xor_result_x);
    
    -- Update "x" words of state
    state_out(383 downto 352) <= state_in(383 downto 352) xor y_tmp;
    state_out(319 downto 288) <= state_in(319 downto 288) xor y_tmp;
    state_out(255 downto 224) <= state_in(255 downto 224) xor y_tmp;
    state_out(191 downto 160) <= state_in(191 downto 160);
    state_out(127 downto 96) <= state_in(127 downto 96);
    state_out(63 downto 32) <= state_in(63 downto 32);

    -- Update "y" words of state
    state_out(351 downto 320) <= state_in(351 downto 320) xor x_tmp;
    state_out(287 downto 256) <= state_in(287 downto 256) xor x_tmp;
    state_out(223 downto 192) <= state_in(223 downto 192) xor x_tmp;
    state_out(159 downto 128) <= state_in(159 downto 128);
    state_out(95 downto 64) <= state_in(95 downto 64);
    state_out(31 downto 0) <= state_in(31 downto 0);
end structural;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.utility_functions.ALL;
use work.NIST_LWAPI_pkg.ALL;
use work.design_pkg.all;

entity sparkle_permutation_fsm is
    Port ( 
        clk : in std_logic;
        rst : in std_logic;
        perm_start : in std_logic;
        num_steps : in integer;
        state_in : in std_logic_vector(PDI_SHARES * 384 - 1 downto 0);
        state_out : out std_logic_vector(PDI_SHARES * 384 - 1 downto 0);
        perm_complete : out std_logic;
        rdi             : in  std_logic_vector(RW - 1 downto 0);
        rdi_valid       : in  std_logic;
        rdi_ready       : out std_logic
        );
end sparkle_permutation_fsm;

architecture behavioral of sparkle_permutation_fsm is

    type word_constants is array(0 to 7) of std_logic_vector (31 downto 0);
       constant round_constant_array : word_constants := (x"B7E15162", x"BF715880", x"38B4DA56", x"324E7738",
                                                          x"BB1185EB", x"4F7C7B57", x"CFBFA1C8", x"C2B3293D");
                               
    type perm_state is (IDLE, RUN);
        signal current_state : perm_state;
        signal next_state : perm_state;
        
	signal state_in_mod : std_logic_vector(PDI_SHARES * 384 - 1 downto 0);
	signal arx_state_in, arx_state_out : std_logic_vector(PDI_SHARES * 384 - 1 downto 0);
	signal arx_step_in, perm_reg_in, perm_reg_out : std_logic_vector(PDI_SHARES * 384 - 1 downto 0);
	
	signal linear_state_in, linear_state_out : std_logic_vector(PDI_SHARES * 384 - 1 downto 0);
	
	signal round_counter : integer := 0;
	signal delay_counter : integer := 0;
	signal step_counter : integer := 0;
    signal latency : integer := 10;

	signal round_counter_std : std_logic_vector(1 downto 0);
	signal arx_cntr_en, arx_cntr_init, perm_cntr_en, perm_cntr_init, delay_cntr_en, delay_cntr_init : std_logic;

    component arx_round_HPC2_ClockGating_d3 is
        port(
           clk            : in std_logic;
           round_constant : in std_logic_vector(31 downto 0); 
           round          : in std_logic_vector(1 downto 0);
           x_round_in_s0  : in std_logic_vector(31 downto 0); 
           x_round_in_s1  : in std_logic_vector(31 downto 0); 
           x_round_in_s2  : in std_logic_vector(31 downto 0); 
           x_round_in_s3  : in std_logic_vector(31 downto 0); 
		   y_round_in_s0  : in std_logic_vector(31 downto 0); 
           y_round_in_s1  : in std_logic_vector(31 downto 0);  
		   y_round_in_s2  : in std_logic_vector(31 downto 0);  
		   y_round_in_s3  : in std_logic_vector(31 downto 0);  
		   Fresh          : in std_logic_vector(1535 downto 0);         
           x_round_out_s0  : out std_logic_vector(31 downto 0); 
           x_round_out_s1  : out std_logic_vector(31 downto 0); 
           x_round_out_s2  : out std_logic_vector(31 downto 0); 
           x_round_out_s3  : out std_logic_vector(31 downto 0); 
		   y_round_out_s0  : out std_logic_vector(31 downto 0); 
           y_round_out_s1  : out std_logic_vector(31 downto 0);
		   y_round_out_s2  : out std_logic_vector(31 downto 0);
		   y_round_out_s3  : out std_logic_vector(31 downto 0)
		);
    end component;
begin
    round_counter_std <= std_logic_vector(to_unsigned(round_counter, round_counter_std'length));

    -- MUX to select ARX STEP input (state input vs. linear layer output)
    with perm_start select
    arx_step_in(1*384-1 downto 0*384) <= linear_state_out(1*384-1 downto 0*384) when '0', 
                                                 state_in(1*384-1 downto 0*384) when '1',
                                                 state_in(1*384-1 downto 0*384) when others;
    with perm_start select
    arx_step_in(2*384-1 downto 1*384) <= linear_state_out(2*384-1 downto 1*384) when '0', 
                                                 state_in(2*384-1 downto 1*384) when '1',
                                                 state_in(2*384-1 downto 1*384) when others;                   
    with perm_start select
    arx_step_in(3*384-1 downto 2*384) <= linear_state_out(3*384-1 downto 2*384) when '0', 
                                                 state_in(3*384-1 downto 2*384) when '1',
                                                 state_in(3*384-1 downto 2*384) when others;  
    with perm_start select
    arx_step_in(4*384-1 downto 3*384) <= linear_state_out(4*384-1 downto 3*384) when '0', 
                                                 state_in(4*384-1 downto 3*384) when '1',
                                                 state_in(4*384-1 downto 3*384) when others;  
												 
    -- MUX to select ARX ROUND input (step input vs. arx output)
    with perm_cntr_en select
    perm_reg_in(1*384-1 downto 0*384) <= arx_state_out(1*384-1 downto 0*384) when '0',
                                           arx_step_in(1*384-1 downto 0*384) when '1', 
                                           arx_step_in(1*384-1 downto 0*384) when others;
    with perm_cntr_en select
    perm_reg_in(2*384-1 downto 1*384) <= arx_state_out(2*384-1 downto 1*384) when '0',
                                           arx_step_in(2*384-1 downto 1*384) when '1', 
                                           arx_step_in(2*384-1 downto 1*384) when others;   
    with perm_cntr_en select
    perm_reg_in(3*384-1 downto 2*384) <= arx_state_out(3*384-1 downto 2*384) when '0',
                                           arx_step_in(3*384-1 downto 2*384) when '1', 
                                           arx_step_in(3*384-1 downto 2*384) when others;  
    with perm_cntr_en select
    perm_reg_in(4*384-1 downto 3*384) <= arx_state_out(4*384-1 downto 3*384) when '0',
                                           arx_step_in(4*384-1 downto 3*384) when '1', 
                                           arx_step_in(4*384-1 downto 3*384) when others; 
										   
    -- Permutation state register
    state_reg: entity work.regGen(behavioral)
    generic map (width => PDI_SHARES * 384)
    port map(
       d => perm_reg_in,
	   e => arx_cntr_en,
	   clk => clk,
	   q => perm_reg_out
    );
    
    -- Update words Y0 and Y1 at the start of each step (rc = 0)
    arx_state_in(0*384+383 downto 0*384+352) <= perm_reg_out(0*384+383 downto 0*384+352);
    arx_state_in(1*384+383 downto 1*384+352) <= perm_reg_out(1*384+383 downto 1*384+352);    
    arx_state_in(2*384+383 downto 2*384+352) <= perm_reg_out(2*384+383 downto 2*384+352);    
    arx_state_in(3*384+383 downto 3*384+352) <= perm_reg_out(3*384+383 downto 3*384+352);    
    
    arx_state_in(0*384+351 downto 0*384+320) <= perm_reg_out(0*384+351 downto 0*384+320) xor round_constant_array(step_counter mod 8) when (round_counter = 0) else perm_reg_out(0*384+351 downto 0*384+320);
    arx_state_in(1*384+351 downto 1*384+320) <= perm_reg_out(1*384+351 downto 1*384+320)                                              when (round_counter = 0) else perm_reg_out(1*384+351 downto 1*384+320);
    arx_state_in(2*384+351 downto 2*384+320) <= perm_reg_out(2*384+351 downto 2*384+320)                                              when (round_counter = 0) else perm_reg_out(2*384+351 downto 2*384+320);
    arx_state_in(3*384+351 downto 3*384+320) <= perm_reg_out(3*384+351 downto 3*384+320)                                              when (round_counter = 0) else perm_reg_out(3*384+351 downto 3*384+320);

    arx_state_in(0*384+319 downto 0*384+288) <= perm_reg_out(0*384+319 downto 0*384+288);
    arx_state_in(1*384+319 downto 1*384+288) <= perm_reg_out(1*384+319 downto 1*384+288);    
    arx_state_in(2*384+319 downto 2*384+288) <= perm_reg_out(2*384+319 downto 2*384+288);    
    arx_state_in(3*384+319 downto 3*384+288) <= perm_reg_out(3*384+319 downto 3*384+288);    
    
    arx_state_in(0*384+287 downto 0*384+256) <= perm_reg_out(0*384+287 downto 0*384+256) xor std_logic_vector(to_unsigned(step_counter, 32)) when (round_counter = 0) else perm_reg_out(0*384+287 downto 0*384+256);
    arx_state_in(1*384+287 downto 1*384+256) <= perm_reg_out(1*384+287 downto 1*384+256)                                                     when (round_counter = 0) else perm_reg_out(1*384+287 downto 1*384+256);
    arx_state_in(2*384+287 downto 2*384+256) <= perm_reg_out(2*384+287 downto 2*384+256)                                                     when (round_counter = 0) else perm_reg_out(2*384+287 downto 2*384+256);
    arx_state_in(3*384+287 downto 3*384+256) <= perm_reg_out(3*384+287 downto 3*384+256)                                                     when (round_counter = 0) else perm_reg_out(3*384+287 downto 3*384+256);
    
    arx_state_in(0*384+255 downto 0*384+0) <= perm_reg_out(0*384+255 downto 0*384+0);
    arx_state_in(1*384+255 downto 1*384+0) <= perm_reg_out(1*384+255 downto 1*384+0);
    arx_state_in(2*384+255 downto 2*384+0) <= perm_reg_out(2*384+255 downto 2*384+0);
    arx_state_in(3*384+255 downto 3*384+0) <= perm_reg_out(3*384+255 downto 3*384+0);

    -- Map linear layer input
    linear_state_in <= arx_state_out;

    perm_done_process: process(clk) begin
    if(rising_edge(clk)) then
        perm_complete <= '0';
        if (step_counter = num_steps -1) and (round_counter = 3) and (delay_counter = latency) then
            perm_complete <= '1';
            state_out <= linear_state_out;
        end if;
    end if;
    end process;    
    
    arx_round_unit_0: arx_round_HPC2_ClockGating_d3
        port map(
            clk => clk,
            round_constant => round_constant_array(0),
            round => round_counter_std,
            x_round_in_s0 => arx_state_in(0*384+383 downto 0*384+352),
            x_round_in_s1 => arx_state_in(1*384+383 downto 1*384+352),
            x_round_in_s2 => arx_state_in(2*384+383 downto 2*384+352),
            x_round_in_s3 => arx_state_in(3*384+383 downto 3*384+352),
			y_round_in_s0 => arx_state_in(0*384+351 downto 0*384+320),
            y_round_in_s1 => arx_state_in(1*384+351 downto 1*384+320),
            y_round_in_s2 => arx_state_in(2*384+351 downto 2*384+320),
            y_round_in_s3 => arx_state_in(3*384+351 downto 3*384+320),
			Fresh => rdi(1*1536-1 downto 0*1536),
            x_round_out_s0 => arx_state_out(0*384+383 downto 0*384+352),
            x_round_out_s1 => arx_state_out(1*384+383 downto 1*384+352),
            x_round_out_s2 => arx_state_out(2*384+383 downto 2*384+352),
            x_round_out_s3 => arx_state_out(3*384+383 downto 3*384+352),
			y_round_out_s0 => arx_state_out(0*384+351 downto 0*384+320),
            y_round_out_s1 => arx_state_out(1*384+351 downto 1*384+320),
            y_round_out_s2 => arx_state_out(2*384+351 downto 2*384+320),
			y_round_out_s3 => arx_state_out(3*384+351 downto 3*384+320)           			
        );

    arx_round_unit_1: arx_round_HPC2_ClockGating_d3
        port map(
            clk => clk,
            round_constant => round_constant_array(1),
            round => round_counter_std,
            x_round_in_s0 => arx_state_in(0*384+319 downto 0*384+288),
            x_round_in_s1 => arx_state_in(1*384+319 downto 1*384+288),
            x_round_in_s2 => arx_state_in(2*384+319 downto 2*384+288),
            x_round_in_s3 => arx_state_in(3*384+319 downto 3*384+288),
			y_round_in_s0 => arx_state_in(0*384+287 downto 0*384+256),
            y_round_in_s1 => arx_state_in(1*384+287 downto 1*384+256),
            y_round_in_s2 => arx_state_in(2*384+287 downto 2*384+256),
            y_round_in_s3 => arx_state_in(3*384+287 downto 3*384+256),
			Fresh => rdi(2*1536-1 downto 1*1536),
            x_round_out_s0 => arx_state_out(0*384+319 downto 0*384+288),
            x_round_out_s1 => arx_state_out(1*384+319 downto 1*384+288),
            x_round_out_s2 => arx_state_out(2*384+319 downto 2*384+288),
            x_round_out_s3 => arx_state_out(3*384+319 downto 3*384+288),
			y_round_out_s0 => arx_state_out(0*384+287 downto 0*384+256),
            y_round_out_s1 => arx_state_out(1*384+287 downto 1*384+256),
			y_round_out_s2 => arx_state_out(2*384+287 downto 2*384+256),
			y_round_out_s3 => arx_state_out(3*384+287 downto 3*384+256)           
        );

    arx_round_unit_2: arx_round_HPC2_ClockGating_d3
        port map(
            clk => clk,
            round_constant => round_constant_array(2),
            round => round_counter_std,
            x_round_in_s0 => arx_state_in(0*384+255 downto 0*384+224),
            x_round_in_s1 => arx_state_in(1*384+255 downto 1*384+224),
            x_round_in_s2 => arx_state_in(2*384+255 downto 2*384+224),
            x_round_in_s3 => arx_state_in(3*384+255 downto 3*384+224),
			y_round_in_s0 => arx_state_in(0*384+223 downto 0*384+192),
            y_round_in_s1 => arx_state_in(1*384+223 downto 1*384+192),
            y_round_in_s2 => arx_state_in(2*384+223 downto 2*384+192),
            y_round_in_s3 => arx_state_in(3*384+223 downto 3*384+192),
			Fresh => rdi(3*1536-1 downto 2*1536),
            x_round_out_s0 => arx_state_out(0*384+255 downto 0*384+224),
            x_round_out_s1 => arx_state_out(1*384+255 downto 1*384+224),
            x_round_out_s2 => arx_state_out(2*384+255 downto 2*384+224),
            x_round_out_s3 => arx_state_out(3*384+255 downto 3*384+224),
			y_round_out_s0 => arx_state_out(0*384+223 downto 0*384+192),
            y_round_out_s1 => arx_state_out(1*384+223 downto 1*384+192),
			y_round_out_s2 => arx_state_out(2*384+223 downto 2*384+192),           
			y_round_out_s3 => arx_state_out(3*384+223 downto 3*384+192)           
		);

    arx_round_unit_3: arx_round_HPC2_ClockGating_d3
        port map(
            clk => clk,
            round_constant => round_constant_array(3),
            round => round_counter_std,
            x_round_in_s0 => arx_state_in(0*384+191 downto 0*384+160),
            x_round_in_s1 => arx_state_in(1*384+191 downto 1*384+160),
            x_round_in_s2 => arx_state_in(2*384+191 downto 2*384+160),
            x_round_in_s3 => arx_state_in(3*384+191 downto 3*384+160),
			y_round_in_s0 => arx_state_in(0*384+159 downto 0*384+128),
            y_round_in_s1 => arx_state_in(1*384+159 downto 1*384+128),
            y_round_in_s2 => arx_state_in(2*384+159 downto 2*384+128),
            y_round_in_s3 => arx_state_in(3*384+159 downto 3*384+128),
			Fresh => rdi(4*1536-1 downto 3*1536),
            x_round_out_s0 => arx_state_out(0*384+191 downto 0*384+160),
            x_round_out_s1 => arx_state_out(1*384+191 downto 1*384+160),
            x_round_out_s2 => arx_state_out(2*384+191 downto 2*384+160),
            x_round_out_s3 => arx_state_out(3*384+191 downto 3*384+160),
			y_round_out_s0 => arx_state_out(0*384+159 downto 0*384+128),
            y_round_out_s1 => arx_state_out(1*384+159 downto 1*384+128),
			y_round_out_s2 => arx_state_out(2*384+159 downto 2*384+128),
			y_round_out_s3 => arx_state_out(3*384+159 downto 3*384+128)           
        );

    arx_round_unit_4: arx_round_HPC2_ClockGating_d3
        port map(
            clk => clk,
            round_constant => round_constant_array(4),
            round => round_counter_std,
            x_round_in_s0 => arx_state_in(0*384+127 downto 0*384+96),
            x_round_in_s1 => arx_state_in(1*384+127 downto 1*384+96),
            x_round_in_s2 => arx_state_in(2*384+127 downto 2*384+96),
            x_round_in_s3 => arx_state_in(3*384+127 downto 3*384+96),
			y_round_in_s0 => arx_state_in(0*384+95 downto 0*384+64),
            y_round_in_s1 => arx_state_in(1*384+95 downto 1*384+64),
            y_round_in_s2 => arx_state_in(2*384+95 downto 2*384+64),
            y_round_in_s3 => arx_state_in(3*384+95 downto 3*384+64),
			Fresh => rdi(5*1536-1 downto 4*1536),
            x_round_out_s0 => arx_state_out(0*384+127 downto 0*384+96),
            x_round_out_s1 => arx_state_out(1*384+127 downto 1*384+96),
            x_round_out_s2 => arx_state_out(2*384+127 downto 2*384+96),
            x_round_out_s3 => arx_state_out(3*384+127 downto 3*384+96),
			y_round_out_s0 => arx_state_out(0*384+95 downto 0*384+64),
            y_round_out_s1 => arx_state_out(1*384+95 downto 1*384+64),
			y_round_out_s2 => arx_state_out(2*384+95 downto 2*384+64),
			y_round_out_s3 => arx_state_out(3*384+95 downto 3*384+64)           
        );

    arx_round_unit_5: arx_round_HPC2_ClockGating_d3
        port map(
            clk => clk,
            round_constant => round_constant_array(5),
            round => round_counter_std,
            x_round_in_s0 => arx_state_in(0*384+63 downto 0*384+32),
            x_round_in_s1 => arx_state_in(1*384+63 downto 1*384+32),
            x_round_in_s2 => arx_state_in(2*384+63 downto 2*384+32),
            x_round_in_s3 => arx_state_in(3*384+63 downto 3*384+32),
			y_round_in_s0 => arx_state_in(0*384+31 downto 0*384+0),
            y_round_in_s1 => arx_state_in(1*384+31 downto 1*384+0),
            y_round_in_s2 => arx_state_in(2*384+31 downto 2*384+0),
            y_round_in_s3 => arx_state_in(3*384+31 downto 3*384+0),
			Fresh => rdi(6*1536-1 downto 5*1536),
            x_round_out_s0 => arx_state_out(0*384+63 downto 0*384+32),
            x_round_out_s1 => arx_state_out(1*384+63 downto 1*384+32),
            x_round_out_s2 => arx_state_out(2*384+63 downto 2*384+32),
            x_round_out_s3 => arx_state_out(3*384+63 downto 3*384+32),
			y_round_out_s0 => arx_state_out(0*384+31 downto 0*384+0),
            y_round_out_s1 => arx_state_out(1*384+31 downto 1*384+0),
			y_round_out_s2 => arx_state_out(2*384+31 downto 2*384+0),
			y_round_out_s3 => arx_state_out(3*384+31 downto 3*384+0)           
        );

    linear_layer_unit1: entity work.linear_layer(structural)
	port map(
	    state_in => linear_state_in(1*384-1 downto 0*384),
        state_out => linear_state_out(1*384-1 downto 0*384)
		);

    linear_layer_unit2: entity work.linear_layer(structural)
	port map(
	    state_in => linear_state_in(2*384-1 downto 1*384),
        state_out => linear_state_out(2*384-1 downto 1*384)
		);

    linear_layer_unit3: entity work.linear_layer(structural)
	port map(
	    state_in => linear_state_in(3*384-1 downto 2*384),
        state_out => linear_state_out(3*384-1 downto 2*384)
		);

    linear_layer_unit4: entity work.linear_layer(structural)
	port map(
	    state_in => linear_state_in(4*384-1 downto 3*384),
        state_out => linear_state_out(4*384-1 downto 3*384)
		);

counter_process: process(clk) begin
	if (rising_edge(clk)) then	
		if (arx_cntr_en = '1') then
			if (arx_cntr_init = '1') then
				round_counter <= 0;
			else
			    round_counter <= round_counter + 1;
		    end if;
		end if;
		
		if (perm_cntr_en = '1') then
			if (perm_cntr_init = '1') then
				step_counter <= 0;
			else
				step_counter <= step_counter + 1;
            end if;
		end if;

		if (delay_cntr_en = '1') then
			if (delay_cntr_init = '1') then
				delay_counter <= 0;
			else
				delay_counter <= delay_counter + 1;
            end if;
		end if;		
	end if;
end process;
	
sync_process: process(clk) begin
if (rising_edge(clk)) then
	if (rst = '1') then
	   current_state <= IDLE;
	else
	   current_state <= next_state;
	end if;
end if;
end process;

public_process: process(latency, rdi_valid, current_state, perm_start, round_counter, delay_counter, step_counter, num_steps)
begin
 
-- Defaults
rdi_ready <= '1';
arx_cntr_init <= '0';
arx_cntr_en <= '0';
perm_cntr_init <= '0';
perm_cntr_en <= '0';
delay_cntr_init <= '0';
delay_cntr_en <= '0'; 
            
case current_state is
		 		 
	when IDLE => 
        next_state <= IDLE; 
		if (perm_start = '1') then		  
            -- Start counters and reset to 0
            arx_cntr_en <= '1';
            arx_cntr_init <= '1';
            perm_cntr_init <= '1';
            perm_cntr_en <= '1';
            delay_cntr_init <= '1';
            delay_cntr_en <= '1';  
            
            if (rdi_valid = '1') then          
			    next_state <= RUN;
			end if;
		end if;
	    
    when RUN => 
        
        next_state <= RUN;
        
        if (rdi_valid = '1') then          
            delay_cntr_en <= '1';
        
            if (delay_counter = latency) then
                arx_cntr_en <= '1';                             -- Enable round counter
        
                if (round_counter = 3) then
                    perm_cntr_en <= '1';                        -- Enable the step counter
                    if (step_counter = (num_steps - 1)) then
                        perm_cntr_init <= '1';                  -- Reset the permutation step counter
				        next_state <= IDLE;
                    end if;
                    arx_cntr_init <= '1';                       -- Reset the arx round counter
		        end if;
		    
		        delay_cntr_init <= '1';
            end if;
        end if;
    when others =>
		next_state <= IDLE;
			  
end case; 

end process;
end behavioral;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.utility_functions.ALL;

entity rate_whitening is
    Port (
        state_in : in std_logic_vector(383 downto 0);
        state_out : out std_logic_vector(383 downto 0)
    );
end rate_whitening;

architecture structural of rate_whitening is
begin

    -- Update rate portion of state
    state_out(383 downto 256) <= state_in(383 downto 256) xor state_in(127 downto 0);
    state_out(255 downto 128) <= state_in(255 downto 128) xor state_in(127 downto 0);
    
    -- Capacity portion of state not modified
    state_out(127 downto 0) <= state_in(127 downto 0);

end structural;


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.utility_functions.ALL;

entity inject_constant is
    Port (
        state_in : in std_logic_vector(383 downto 0);
        constant_value : in std_logic_vector(31 downto 0);
        state_out : out std_logic_vector(383 downto 0)
    );
end inject_constant;

architecture structural of inject_constant is
begin

    -- Map state in to state out
    state_out(383 downto 32) <= state_in(383 downto 32);
    
    -- Update last word of state with constant
    state_out(31 downto 0) <= state_in(31 downto 0) xor constant_value;

end structural;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.utility_functions.ALL;

entity feistel_swap is
    Port (
        state_in : in std_logic_vector(383 downto 0);
        state_out : out std_logic_vector(383 downto 0)
    );
end feistel_swap;

architecture structural of feistel_swap is
begin

    -- Update rate part of state
    state_out(383 downto 256) <= state_in(255 downto 128);
    state_out(255 downto 128) <= state_in(255 downto 128) xor state_in(383 downto 256);
    
    -- Capacity not affected
    state_out(127 downto 0) <= state_in(127 downto 0);
end structural;


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.utility_functions.ALL;

entity rho is
    Port (
        state_in : in std_logic_vector(383 downto 0);
        input_rate : in std_logic_vector(255 downto 0);
        state_out : out std_logic_vector(383 downto 0)
    );
end rho;

architecture structural of rho is
begin
    -- Update rate part of state
    state_out(383 downto 128) <= state_in(383 downto 128) xor input_rate(255 downto 0);
    
    -- Capacity not affected
    state_out(127 downto 0) <= state_in(127 downto 0);  
end structural;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.utility_functions.ALL;

entity inv_rho is
    Port (
        state_in_pre_feistel : in std_logic_vector(255 downto 0);
        state_in_post_feistel : in std_logic_vector(383 downto 0);
        input_rate : in std_logic_vector(255 downto 0);
        state_out : out std_logic_vector(383 downto 0)
    );
end inv_rho;

architecture structural of inv_rho is
begin

    -- Update rate part of state
    state_out(383 downto 128) <= state_in_post_feistel(383 downto 128) xor (state_in_pre_feistel(255 downto 0) xor input_rate(255 downto 0));
    
    -- Capacity not affected
    state_out(127 downto 0) <= state_in_post_feistel(127 downto 0);
end structural;

