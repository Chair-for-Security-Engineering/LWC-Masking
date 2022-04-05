----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 12/16/2019 01:57:37 PM
-- Design Name: 
-- Module Name: 4c_reg - Behavioral
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

entity reg2 is
    generic (w : integer := 32);
    Port ( clk : in STD_LOGIC;
           rst : in STD_LOGIC;
           en : in STD_LOGIC;
           D : in STD_LOGIC_VECTOR( w-1 downto 0 );
           Q : out STD_LOGIC_VECTOR( w-1 downto 0 ));
end reg2;

architecture Behavioral of reg2 is

begin

process (clk)
begin
    if rising_edge(clk) then
        if rst = '1' then
            Q <= (others => '0');
        else
            if en = '1' then
			     Q <= D;
            end if;
        end if;
    end if;
end process;

end Behavioral;
