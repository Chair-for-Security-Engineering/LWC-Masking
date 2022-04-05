----------------------------------------------------------------------------------
-- Company:
-- Engineer:
--
-- Create Date: 12/20/2019 07:49:56 PM
-- Design Name:
-- Module Name: Ozs - Behavioral
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

entity Ozs is
    Port ( w0 : in STD_LOGIC_VECTOR(31 downto 0); -- bdi
           w1 : in STD_LOGIC_VECTOR(31 downto 0); -- rho_xor1_out
           pad_loc : in STD_LOGIC_VECTOR(3 downto 0);
		   ozs_sel : in STD_LOGIC;
           ozs_en : in STD_LOGIC;
           hash_pad : in STD_LOGIC;
           zero_en : in STD_LOGIC;
           ozs_out : out STD_LOGIC_VECTOR(31 downto 0));
end Ozs;

architecture Behavioral of Ozs is

signal ozs_in : STD_LOGIC_VECTOR(31 downto 0);
signal ozs : STD_LOGIC_VECTOR(31 downto 0);
signal ozs_mux : STD_LOGIC_VECTOR(31 downto 0);

begin

-- ozs_sel = '1' when padding bdo; otherwise, it's padding bdi input before AD processing
ozs_in <= w1 when ozs_sel = '1' else w0;

-- pad location used to actually pad ozs
gen1: for i in 3 downto 0 generate 
  ozs(8*i+7 downto 8*i) <= ozs_in(8*i+7 downto 8*i+1) & ((ozs_in(8*i) AND pad_loc(i)) XOR ozs_in(8*i) XOR pad_loc(i));
end generate gen1;

-- enable signal only activated when processing eot 
ozs_mux <= ozs when ozs_en = '1' else ozs_in;
ozs_out <= (31 downto 25 => '0') & hash_pad & (23 downto 0 => '0') when zero_en = '1' else ozs_mux;

end Behavioral;