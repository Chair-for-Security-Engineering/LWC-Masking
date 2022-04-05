----------------------------------------------------------------------------------
-- Company:
-- Engineer:
--
-- Create Date: 12/20/2019 08:44:55 PM
-- Design Name:
-- Module Name: Rho - Behavioral
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
-- Rho is the message encryption/decryption operation.
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

entity Rho is
    Port ( -- Inputs --
            rho_in : in STD_LOGIC_VECTOR (127 downto 0); --state, which is temp
            shuffle : in STD_LOGIC_VECTOR (127 downto 0);
            bdi : in STD_LOGIC_VECTOR (31 downto 0);
            iv_input_sel : in STD_LOGIC_VECTOR (1 downto 0);
            rho_valid : in STD_LOGIC_VECTOR (3 downto 0);
 
            -- Outputs --
            bdo : out STD_LOGIC_VECTOR (31 downto 0);
            bdo_128 : out STD_LOGIC_VECTOR (127 downto 0));
end Rho;

architecture Behavioral of Rho is
signal shuffle_32 : STD_LOGIC_VECTOR(31 downto 0);
signal truncate : STD_LOGIC_VECTOR(31 downto 0);
signal bdo_i : STD_LOGIC_VECTOR(31 downto 0);

begin

--Store a rho bit in a register.
	
with iv_input_sel select shuffle_32 <=
    shuffle(95 downto 64) when "01",
    shuffle(63 downto 32) when "10",
    shuffle(31 downto 0) when "11",
    shuffle(127 downto 96) when others;
   
-- Truncation required at eot/size < 128 bits
truncate <= (shuffle_32(31 downto 24) AND (7 downto 0 => rho_valid(3))) &
			(shuffle_32(23 downto 16) AND (7 downto 0 => rho_valid(2))) &
			(shuffle_32(15 downto 8) AND (7 downto 0 => rho_valid(1))) &
			(shuffle_32(7 downto 0) AND (7 downto 0 => rho_valid(0))); 

bdo_i <= truncate xor bdi;
bdo <= bdo_i;

gen_bdo_128 : for ii in 0 to 3 generate
    bdo_128(127 - 32*ii downto 96 - 32*ii) <= bdo_i when 
		ii = to_integer(unsigned(iv_input_sel))
		else rho_in(127 - 32*ii downto 96 - 32*ii);
end generate gen_bdo_128;

end Behavioral;
