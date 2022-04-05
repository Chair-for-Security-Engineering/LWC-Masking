----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 05/30/2019 05:17:50 PM
-- Design Name: 
-- Module Name: GIFT-128 - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use work.NIST_LWAPI_pkg.all;
use work.design_pkg.all;

-- Entity
------------------------------------------------------------------------
entity GIFT128 is
    Port (
        clk         : in std_logic;
        rst         : in std_logic;
        start       : in std_logic;
        Key         : in std_logic_vector (SDI_SHARES * 128 - 1 downto 0);
        X_in        : in std_logic_vector (PDI_SHARES * 128 - 1 downto 0);
        Y_out       : out std_logic_vector (PDI_SHARES * 128 - 1 downto 0);
        done        : out std_logic;
        fresh       : in  std_logic_vector(575 downto 0)
    );
end GIFT128;

-- Architecture
-----------------------------------------------------------------------
architecture Behavioral of GIFT128 is

    -- Signals ---------------------------------------------------------
    signal S0, S1, S2, S3                   : std_logic_vector(PDI_SHARES * 32 - 1 downto 0); -- Four 32-bit words of current state
    signal S0_Up, S1_Up, S2_Up, S3_Up       : std_logic_vector(PDI_SHARES * 32 - 1 downto 0); -- Four 32-bit words of updated state 
    signal W0, W1, W2, W3, W4, W5, W6, W7   : std_logic_vector(PDI_SHARES * 16 - 1 downto 0); -- Eight 16-bit segments of key state
    signal U, V                             : std_logic_vector(PDI_SHARES * 32 - 1 downto 0); -- Round key: RK = U || V
    signal SubC_temp                        : std_logic_vector(PDI_SHARES * 128 - 1 downto 0); -- As the input of SubCells (just because in a port map no functions should be used)
    signal state_Sub, state_Permu           : std_logic_vector(PDI_SHARES * 128 - 1 downto 0); -- 128-bit satate after substitusion and permutation layers
    signal state_Up, Kstate_Up              : std_logic_vector(PDI_SHARES * 128 - 1 downto 0); -- 128-bit updated state and key state
    signal round_Num                        : natural range 0 to 39; -- Round number
    signal round_Cons                       : std_logic_vector(5 downto 0); -- 6-bit LFSR round constant
    signal RC_rst                           : std_logic; -- Reset for round constant generator(LFSR)
    
    -- Components ------------------------------------------------------
    component SubCells_HPC2_ClockGating_d2 is
        Port(
            clk            : in std_logic;
            SubC_in_s0     : in std_logic_vector(127 downto 0);
            SubC_in_s1     : in std_logic_vector(127 downto 0);
            SubC_in_s2     : in std_logic_vector(127 downto 0);
			Fresh          : in std_logic_vector(575 downto 0);
            SubC_out_s0    : out std_logic_vector(127 downto 0);
            SubC_out_s1    : out std_logic_vector(127 downto 0);
			SubC_out_s2    : out std_logic_vector(127 downto 0)
        );
    end component SubCells_HPC2_ClockGating_d2;
    
    component PermBits is
        Port(
            P_in    : in std_logic_vector (127 downto 0);
            P_out   : out std_logic_vector (127 downto 0)
        );
    end component PermBits;
    
    component ConsGen is
        Port(
        clk         : in std_logic;
        rst         : in std_logic;
        en          : in std_logic;
        round_Cons  : out std_logic_vector(5 downto 0)
    );
    end component ConsGen;
    
-------------------------------------------------------------------------   
begin

    done  <= '1' when (round_Num = 40) else '0';
    Y_out <= state_Up;

    -- Load 128-bit plaintext or updated state
    S0(1*32-1 downto 0*32) <= X_in(0*128+127 downto 0*128+96) when (round_Num = 0) else state_Up(0*128+127 downto 0*128+96);
    S0(2*32-1 downto 1*32) <= X_in(1*128+127 downto 1*128+96) when (round_Num = 0) else state_Up(1*128+127 downto 1*128+96);
    S0(3*32-1 downto 2*32) <= X_in(2*128+127 downto 2*128+96) when (round_Num = 0) else state_Up(2*128+127 downto 2*128+96);
   
    S1(1*32-1 downto 0*32) <= X_in(0*128+95 downto 0*128+64)  when (round_Num = 0) else state_Up(0*128+95 downto 0*128+64);
    S1(2*32-1 downto 1*32) <= X_in(1*128+95 downto 1*128+64)  when (round_Num = 0) else state_Up(1*128+95 downto 1*128+64);
    S1(3*32-1 downto 2*32) <= X_in(2*128+95 downto 2*128+64)  when (round_Num = 0) else state_Up(2*128+95 downto 2*128+64);
    
    S2(1*32-1 downto 0*32) <= X_in(0*128+63 downto 0*128+32)  when (round_Num = 0) else state_Up(0*128+63 downto 0*128+32);
    S2(2*32-1 downto 1*32) <= X_in(1*128+63 downto 1*128+32)  when (round_Num = 0) else state_Up(1*128+63 downto 1*128+32);    
    S2(3*32-1 downto 2*32) <= X_in(2*128+63 downto 2*128+32)  when (round_Num = 0) else state_Up(2*128+63 downto 2*128+32);    

    S3(1*32-1 downto 0*32) <= X_in(0*128+31 downto 0*128+0)   when (round_Num = 0) else state_Up(0*128+31 downto 0*128+0);
    S3(2*32-1 downto 1*32) <= X_in(1*128+31 downto 1*128+0)   when (round_Num = 0) else state_Up(1*128+31 downto 1*128+0);
    S3(3*32-1 downto 2*32) <= X_in(2*128+31 downto 2*128+0)   when (round_Num = 0) else state_Up(2*128+31 downto 2*128+0);
    
    -- Key schedule: Load 128-bit secret key or updated key state
    W0(1*16-1 downto 0*16) <= Key(0*128+127 downto 0*128+112) when (round_Num = 0) else Kstate_Up(0*128+17 downto 0*128+16) & Kstate_Up(0*128+31 downto 0*128+18);
    W0(2*16-1 downto 1*16) <= Key(1*128+127 downto 1*128+112) when (round_Num = 0) else Kstate_Up(1*128+17 downto 1*128+16) & Kstate_Up(1*128+31 downto 1*128+18);   
    W0(3*16-1 downto 2*16) <= Key(2*128+127 downto 2*128+112) when (round_Num = 0) else Kstate_Up(2*128+17 downto 2*128+16) & Kstate_Up(2*128+31 downto 2*128+18);   
    
    W1(1*16-1 downto 0*16) <= Key(0*128+111 downto 0*128+96)  when (round_Num = 0) else Kstate_Up(0*128+11 downto 0*128+0) & Kstate_Up(0*128+15 downto 0*128+12);
    W1(2*16-1 downto 1*16) <= Key(1*128+111 downto 1*128+96)  when (round_Num = 0) else Kstate_Up(1*128+11 downto 1*128+0) & Kstate_Up(1*128+15 downto 1*128+12);  
    W1(3*16-1 downto 2*16) <= Key(2*128+111 downto 2*128+96)  when (round_Num = 0) else Kstate_Up(2*128+11 downto 2*128+0) & Kstate_Up(2*128+15 downto 2*128+12);  
    
    W2(1*16-1 downto 0*16) <= Key(0*128+95 downto 0*128+80)   when (round_Num = 0) else Kstate_Up(0*128+127 downto 0*128+112);
    W2(2*16-1 downto 1*16) <= Key(1*128+95 downto 1*128+80)   when (round_Num = 0) else Kstate_Up(1*128+127 downto 1*128+112);
    W2(3*16-1 downto 2*16) <= Key(2*128+95 downto 2*128+80)   when (round_Num = 0) else Kstate_Up(2*128+127 downto 2*128+112);

    W3(1*16-1 downto 0*16) <= Key(0*128+79 downto 0*128+64)   when (round_Num = 0) else Kstate_Up(0*128+111 downto 0*128+96);
    W3(2*16-1 downto 1*16) <= Key(1*128+79 downto 1*128+64)   when (round_Num = 0) else Kstate_Up(1*128+111 downto 1*128+96);
    W3(3*16-1 downto 2*16) <= Key(2*128+79 downto 2*128+64)   when (round_Num = 0) else Kstate_Up(2*128+111 downto 2*128+96);
    
    W4(1*16-1 downto 0*16) <= Key(0*128+63 downto 0*128+48)   when (round_Num = 0) else Kstate_Up(0*128+95 downto 0*128+80);
    W4(2*16-1 downto 1*16) <= Key(1*128+63 downto 1*128+48)   when (round_Num = 0) else Kstate_Up(1*128+95 downto 1*128+80);
    W4(3*16-1 downto 2*16) <= Key(2*128+63 downto 2*128+48)   when (round_Num = 0) else Kstate_Up(2*128+95 downto 2*128+80);

    W5(1*16-1 downto 0*16) <= Key(0*128+47 downto 0*128+32)   when (round_Num = 0) else Kstate_Up(0*128+79 downto 0*128+64);
    W5(2*16-1 downto 1*16) <= Key(1*128+47 downto 1*128+32)   when (round_Num = 0) else Kstate_Up(1*128+79 downto 1*128+64);
    W5(3*16-1 downto 2*16) <= Key(2*128+47 downto 2*128+32)   when (round_Num = 0) else Kstate_Up(2*128+79 downto 2*128+64);

    W6(1*16-1 downto 0*16) <= Key(0*128+31 downto 0*128+16)   when (round_Num = 0) else Kstate_Up(0*128+63 downto 0*128+48);
    W6(2*16-1 downto 1*16) <= Key(1*128+31 downto 1*128+16)   when (round_Num = 0) else Kstate_Up(1*128+63 downto 1*128+48);
    W6(3*16-1 downto 2*16) <= Key(2*128+31 downto 2*128+16)   when (round_Num = 0) else Kstate_Up(2*128+63 downto 2*128+48);

    W7(1*16-1 downto 0*16) <= Key(0*128+15 downto 0*128+0)    when (round_Num = 0) else Kstate_Up(0*128+47 downto 0*128+32);
    W7(2*16-1 downto 1*16) <= Key(1*128+15 downto 1*128+0)    when (round_Num = 0) else Kstate_Up(1*128+47 downto 1*128+32);
    W7(3*16-1 downto 2*16) <= Key(2*128+15 downto 2*128+0)    when (round_Num = 0) else Kstate_Up(2*128+47 downto 2*128+32);

    -- Round function --------------------------------------------------
    -- SubCells
    SubC_temp(1*128-1 downto 0*128) <= (S0(1*32-1 downto 0*32) & S1(1*32-1 downto 0*32) & S2(1*32-1 downto 0*32) & S3(1*32-1 downto 0*32));
    SubC_temp(2*128-1 downto 1*128) <= (S0(2*32-1 downto 1*32) & S1(2*32-1 downto 1*32) & S2(2*32-1 downto 1*32) & S3(2*32-1 downto 1*32));
    SubC_temp(3*128-1 downto 2*128) <= (S0(3*32-1 downto 2*32) & S1(3*32-1 downto 2*32) & S2(3*32-1 downto 2*32) & S3(3*32-1 downto 2*32));

    SC: SubCells_HPC2_ClockGating_d2
    Port map(
        clk => clk,
        SubC_in_s0  => SubC_temp(1*128-1 downto 0*128),
        SubC_in_s1  => SubC_temp(2*128-1 downto 1*128),
        SubC_in_s2  => SubC_temp(3*128-1 downto 2*128),
		Fresh => fresh,
        SubC_out_s0 => state_Sub(1*128 -1 downto 0*128),
        SubC_out_s1 => state_Sub(2*128 -1 downto 1*128),
		SubC_out_s2 => state_Sub(3*128 -1 downto 2*128)
    );
            
    --PermBits
    PB_s0: PermBits 
    Port map(
        P_in  => state_Sub(1*128 -1 downto 0*128),
        P_out => state_Permu(1*128 -1 downto 0*128)
    );

    PB_s1: PermBits 
    Port map(
        P_in  => state_Sub(2*128 -1 downto 1*128),
        P_out => state_Permu(2*128 -1 downto 1*128)
    );

    PB_s2: PermBits 
    Port map(
        P_in  => state_Sub(3*128 -1 downto 2*128),
        P_out => state_Permu(3*128 -1 downto 2*128)
    );
	
    -- Add round key and add round constant
    RC_rst <= '1' when (rst = '1' or (round_Num = 39 and start = '1')) else '0';
    
    RC: ConsGen
    Port map(
        clk         => clk,
        rst         => RC_rst,
        en          => start,
        round_Cons  => round_Cons
    );
            
    U(1*32-1 downto 0*32) <= W2(1*16-1 downto 0*16) & W3(1*16-1 downto 0*16);
    U(2*32-1 downto 1*32) <= W2(2*16-1 downto 1*16) & W3(2*16-1 downto 1*16);
    U(3*32-1 downto 2*32) <= W2(3*16-1 downto 2*16) & W3(3*16-1 downto 2*16);

    V(1*32-1 downto 0*32) <= W6(1*16-1 downto 0*16) & W7(1*16-1 downto 0*16);
    V(2*32-1 downto 1*32) <= W6(2*16-1 downto 1*16) & W7(2*16-1 downto 1*16);
    V(3*32-1 downto 2*32) <= W6(3*16-1 downto 2*16) & W7(3*16-1 downto 2*16);

    S0_Up(1*32-1 downto 0*32) <= state_Permu(0*128+127 downto 0*128+96);
    S0_Up(2*32-1 downto 1*32) <= state_Permu(1*128+127 downto 1*128+96);
    S0_Up(3*32-1 downto 2*32) <= state_Permu(2*128+127 downto 2*128+96);

    S2_Up(1*32-1 downto 0*32) <= state_Permu(0*128+63 downto 0*128+32) xor U(1*32-1 downto 0*32); -- S2 xor U
    S2_Up(2*32-1 downto 1*32) <= state_Permu(1*128+63 downto 1*128+32) xor U(2*32-1 downto 1*32); -- S2 xor U  
    S2_Up(3*32-1 downto 2*32) <= state_Permu(2*128+63 downto 2*128+32) xor U(3*32-1 downto 2*32); -- S2 xor U  
    
    S1_Up(1*32-1 downto 0*32) <= state_Permu(0*128+95 downto 0*128+64) xor V(1*32-1 downto 0*32); -- S1 xor V
    S1_Up(2*32-1 downto 1*32) <= state_Permu(1*128+95 downto 1*128+64) xor V(2*32-1 downto 1*32); -- S1 xor V
    S1_Up(3*32-1 downto 2*32) <= state_Permu(2*128+95 downto 2*128+64) xor V(3*32-1 downto 2*32); -- S1 xor V
    
    S3_Up(1*32-1 downto 0*32) <= state_Permu(0*128+31 downto 0*128+0)  xor (x"800000" & "00" & round_Cons); -- S3 xor constant
    S3_Up(2*32-1 downto 1*32) <= state_Permu(1*128+31 downto 1*128+0)  xor (x"000000" & "00" & "000000"); -- S3 xor constant
    S3_Up(3*32-1 downto 2*32) <= state_Permu(2*128+31 downto 2*128+0)  xor (x"000000" & "00" & "000000"); -- S3 xor constant
   
   -- Process (one round per clock cycle)
    RF: process(clk)
    begin
        if rising_edge(clk) then
            if (rst = '1') then
                round_Num   <= 0;
            else 
                if (start = '1') then
                    round_Num   <= round_Num + 1;
                    state_Up(1*128-1 downto 0*128) <= S0_Up(1*32-1 downto 0*32) & S1_Up(1*32-1 downto 0*32) & S2_Up(1*32-1 downto 0*32) & S3_Up(1*32-1 downto 0*32);
                    state_Up(2*128-1 downto 1*128) <= S0_Up(2*32-1 downto 1*32) & S1_Up(2*32-1 downto 1*32) & S2_Up(2*32-1 downto 1*32) & S3_Up(2*32-1 downto 1*32);
                    state_Up(3*128-1 downto 2*128) <= S0_Up(3*32-1 downto 2*32) & S1_Up(3*32-1 downto 2*32) & S2_Up(3*32-1 downto 2*32) & S3_Up(3*32-1 downto 2*32);

                    Kstate_Up(1*128-1 downto 0*128)   <= W0(1*16-1 downto 0*16) &  W1(1*16-1 downto 0*16) &  W2(1*16-1 downto 0*16) &  W3(1*16-1 downto 0*16) &  W4(1*16-1 downto 0*16) &  W5(1*16-1 downto 0*16) &  W6(1*16-1 downto 0*16) &  W7(1*16-1 downto 0*16); 
                    Kstate_Up(2*128-1 downto 1*128)   <= W0(2*16-1 downto 1*16) &  W1(2*16-1 downto 1*16) &  W2(2*16-1 downto 1*16) &  W3(2*16-1 downto 1*16) &  W4(2*16-1 downto 1*16) &  W5(2*16-1 downto 1*16) &  W6(2*16-1 downto 1*16) &  W7(2*16-1 downto 1*16); 
                    Kstate_Up(3*128-1 downto 2*128)   <= W0(3*16-1 downto 2*16) &  W1(3*16-1 downto 2*16) &  W2(3*16-1 downto 2*16) &  W3(3*16-1 downto 2*16) &  W4(3*16-1 downto 2*16) &  W5(3*16-1 downto 2*16) &  W6(3*16-1 downto 2*16) &  W7(3*16-1 downto 2*16); 
				end if;    
            end if;
        end if;
    end process RF;
end Behavioral;
