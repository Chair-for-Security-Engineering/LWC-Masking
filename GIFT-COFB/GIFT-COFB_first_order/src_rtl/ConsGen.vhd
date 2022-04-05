----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 06/05/2019 10:12:49 PM
-- Design Name: 
-- Module Name: ConsGen - Behavioral
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

-- Entity
--------------------------------------------------------------
entity ConsGen is
    Port(
        clk         : in std_logic;
        rst         : in std_logic;
        en          : in std_logic;
        round_Cons  : out std_logic_vector(5 downto 0)
    );
end ConsGen;

-- Architecture
--------------------------------------------------------------
architecture Behavioral of ConsGen is

    -- Signal ------------------------------------------------
    signal temp  : std_logic_vector(5 downto 0) := (others => '0');

--------------------------------------------------------------    
begin
    
    round_Cons <= temp;
    lfsr: process(clk)
    begin
        if rising_edge(clk) then
            if (rst = '1') then
                temp <= "000001";
            else
                if (en = '1') then
                    temp <= temp(4 downto 0) & (temp(5) xor temp(4) xor '1');
                end if;
            end if;
        end if;
    end process lfsr;

end Behavioral;
