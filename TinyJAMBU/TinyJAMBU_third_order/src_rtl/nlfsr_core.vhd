--------------------------------------------------------------------------------
--! @file       nlfsr.vhd
--! @brief      Implementation of a non-linear shift register used for TinyJAMBU
--! @author     Sammy Lin
--! @copyright  Copyright (c) 2020 Cryptographic Engineering Research Group
--!             ECE Department, George Mason University Fairfax, VA, U.S.A.
--!             All rights Reserved.
--! @license    This project is released under the GNU Public License.
--!             The license and distribution terms for this file may be
--!             found in the file LICENSE in this distribution or at
--!             http://www.gnu.org/licenses/gpl-3.0.txt
--! @note       This is publicly available encryption source code that falls
--!             under the License Exception TSU (Technology and software-
--!             unrestricted)
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.ALL;
use ieee.numeric_std.all;

entity nlfsr_core is
    port (
        x : in std_logic_vector (127 downto 0);
        y : out std_logic_vector (31 downto 0)
    );
end entity nlfsr_core;

architecture behavioral of nlfsr_core is

begin
y <= x(101 downto 70) nand x(116 downto 85);
end architecture behavioral;
