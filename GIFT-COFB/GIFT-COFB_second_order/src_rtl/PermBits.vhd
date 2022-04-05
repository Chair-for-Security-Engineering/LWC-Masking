----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 05/31/2019 04:04:35 PM
-- Design Name: 
-- Module Name: PermBits - Behavioral
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

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

-- Entity
-----------------------------------------------------------------------
entity PermBits is
Port (
    P_in    : in std_logic_vector (127 downto 0);
    P_out   : out std_logic_vector (127 downto 0)
);
end PermBits;

-- Architecture
-----------------------------------------------------------------------
architecture Behavioral of PermBits is
    
    -- Signals --------------------------------------------------------
    signal S0, S1, S2, S3               : std_logic_vector (31 downto 0);
    signal S0_up, S1_up, S2_Up, S3_up   : std_logic_vector (31 downto 0);
    
    -- Constants ------------------------------------------------------
    type BitPosCon is array (0 to 3) of integer range 0 to 3;
    constant BP0 : BitPosCon := (0, 3, 2, 1);
    constant BP1 : BitPosCon := (1, 0, 3, 2);
    constant BP2 : BitPosCon := (2, 1, 0, 3);
    constant BP3 : BitPosCon := (3, 2, 1, 0);
  
-----------------------------------------------------------------------
begin
    S0 <= P_in(127 downto 96);
    S1 <= P_in(95 downto 64);
    S2 <= P_in(63 downto 32);
    S3 <= P_in(31 downto 0);
    
    Row0: for b in 0 to 7 generate
        S0_up(b + 8*BP0(0)) <= S0(4*b);
        S0_up(b + 8*BP0(1)) <= S0(4*b + 1);
        S0_up(b + 8*BP0(2)) <= S0(4*b + 2);
        S0_up(b + 8*BP0(3)) <= S0(4*b + 3);
    end generate Row0;
    
    Row1: for b in 0 to 7 generate
        S1_up(b + 8*BP1(0)) <= S1(4*b);
        S1_up(b + 8*BP1(1)) <= S1(4*b + 1);
        S1_up(b + 8*BP1(2)) <= S1(4*b + 2);
        S1_up(b + 8*BP1(3)) <= S1(4*b + 3);
    end generate Row1;
    
    Row2: for b in 0 to 7 generate
        S2_up(b + 8*BP2(0)) <= S2(4*b);
        S2_up(b + 8*BP2(1)) <= S2(4*b + 1);
        S2_up(b + 8*BP2(2)) <= S2(4*b + 2);
        S2_up(b + 8*BP2(3)) <= S2(4*b + 3);
    end generate Row2;
    
    Row3: for b in 0 to 7 generate
        S3_up(b + 8*BP3(0)) <= S3(4*b);
        S3_up(b + 8*BP3(1)) <= S3(4*b + 1);
        S3_up(b + 8*BP3(2)) <= S3(4*b + 2);
        S3_up(b + 8*BP3(3)) <= S3(4*b + 3);
    end generate Row3;

    P_out <= S0_up & S1_up & S2_up & S3_up;
    
end Behavioral;
