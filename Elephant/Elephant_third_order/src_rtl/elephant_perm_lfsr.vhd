----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 10.03.2022 10:33:52
-- Design Name: 
-- Module Name: elephant_perm_lfsr - Behavioral
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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity elephant_perm_lfsr is
    port(
        clk: in std_logic;
        load_lfsr: in std_logic;
        lfsr_en: in std_logic;
        lfsr: out std_logic_vector(6 downto 0);
        rev_lfsr: out std_logic_vector(6 downto 0)
    );
end elephant_perm_lfsr;

architecture Behavioral of elephant_perm_lfsr is

signal lfsr_i: std_logic_vector(6 downto 0);

begin
    lsfr: process (clk)
    begin
        if rising_edge(clk) then
            if load_lfsr = '1' then
                lfsr_i <= "1110101";
            else
                if lfsr_en = '1' then
                    lfsr_i <= lfsr_i(5 downto 0) & (lfsr_i(6) xor lfsr_i(5)); --LFSR poly
                end if;    
            end if;
        end if;
    end process;
    rev_lfsr <= lfsr_i(0) & lfsr_i(1) & lfsr_i(2) & lfsr_i(3) & lfsr_i(4) & lfsr_i(5) & lfsr_i(6);-- to 6);
    lfsr <= lfsr_i;
end Behavioral;
