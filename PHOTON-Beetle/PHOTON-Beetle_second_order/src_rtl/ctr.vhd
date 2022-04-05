----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 12/21/2019 07:01:33 AM
-- Design Name: 
-- Module Name: ctr - Behavioral
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
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity ctr is
    generic ( w : integer := 3);
    Port ( clk : in STD_LOGIC;
           en : in STD_LOGIC;
           ld_en : in STD_LOGIC;
           LD : in STD_LOGIC_VECTOR (w-1 downto 0);
           Q : out STD_LOGIC_VECTOR (w-1 downto 0));
end ctr;

architecture Behavioral of ctr is

signal q_sig : unsigned( w-1 downto 0 );
begin

process (clk)
begin
    if rising_edge(clk) then
        if en = '1' then
            if ld_en = '1' then
			     q_sig <= unsigned(LD);
			else
			     if q_sig = (2**w) - 1 then
			         q_sig <= (others => '0');
			     else
			         q_sig <= q_sig + "1";
			     end if;
			end if;			 
		else
			q_sig <= q_sig;
        end if;
    end if;
end process;

Q <= std_logic_vector(q_sig);

end Behavioral;