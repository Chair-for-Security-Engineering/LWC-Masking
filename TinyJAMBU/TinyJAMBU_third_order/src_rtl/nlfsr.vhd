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

entity nlfsr is
    port (
        clk         : in std_logic;
        reset       : in std_logic;
        enable      : in std_logic;
        key         : in std_logic_vector (4*128-1 downto 0);
        load        : in std_logic;
        input       : in std_logic_vector (4*128-1 downto 0);
        output      : out std_logic_vector (4*128-1 downto 0);
        fresh       : in std_logic_vector (191 downto 0)
    );
end entity nlfsr;

architecture behavioral of nlfsr is

component nlfsr_core_HPC2_ClockGating_d3 is
    port (
        clk: in std_logic;
        x_s0 : in std_logic_vector (116 downto 70);
        x_s1 : in std_logic_vector (116 downto 70);
        x_s2 : in std_logic_vector (116 downto 70);
        x_s3 : in std_logic_vector (116 downto 70);
        Fresh : in std_logic_vector (191 downto 0);
        y_s0 : out std_logic_vector (31 downto 0);
        y_s1 : out std_logic_vector (31 downto 0);
        y_s2 : out std_logic_vector (31 downto 0);
        y_s3 : out std_logic_vector (31 downto 0)
    );
end component;

signal reg      : std_logic_vector (4*128-1 downto 0);
signal feedback : std_logic_vector (4*32-1 downto 0);
signal nand_out : std_logic_vector (4*32-1 downto 0);
signal counter  : unsigned (6 downto 0);

begin

    Inst_nlfsr : nlfsr_core_HPC2_ClockGating_d3
        port map(
            clk => clk,
            x_s0 => reg(0*128+116 downto 0*128+70),
            x_s1 => reg(1*128+116 downto 1*128+70),
            x_s2 => reg(2*128+116 downto 2*128+70),
            x_s3 => reg(3*128+116 downto 3*128+70),
            Fresh => fresh,
            y_s0 => nand_out(1*32-1 downto 0*32),
            y_s1 => nand_out(2*32-1 downto 1*32),
            y_s2 => nand_out(3*32-1 downto 2*32),
            y_s3 => nand_out(4*32-1 downto 3*32)            
        );
        
output <= reg;
feedback(1*32-1 downto 0*32) <= reg(0*128+122 downto 0*128+91) xor nand_out(1*32-1 downto 0*32) xor reg(0*128+78 downto 0*128+47) xor reg(0*128+31 downto 0*128+0) xor key((0*128+to_integer(counter) + 32) - 1 downto (0*128+to_integer(counter)));
feedback(2*32-1 downto 1*32) <= reg(1*128+122 downto 1*128+91) xor nand_out(2*32-1 downto 1*32) xor reg(1*128+78 downto 1*128+47) xor reg(1*128+31 downto 1*128+0) xor key((1*128+to_integer(counter) + 32) - 1 downto (1*128+to_integer(counter)));
feedback(3*32-1 downto 2*32) <= reg(2*128+122 downto 2*128+91) xor nand_out(3*32-1 downto 2*32) xor reg(2*128+78 downto 2*128+47) xor reg(2*128+31 downto 2*128+0) xor key((2*128+to_integer(counter) + 32) - 1 downto (2*128+to_integer(counter)));
feedback(4*32-1 downto 3*32) <= reg(3*128+122 downto 3*128+91) xor nand_out(4*32-1 downto 3*32) xor reg(3*128+78 downto 3*128+47) xor reg(3*128+31 downto 3*128+0) xor key((3*128+to_integer(counter) + 32) - 1 downto (3*128+to_integer(counter)));

    shift_reg : process(clk)
    begin
        if rising_edge(clk) then
            if (reset = '1') then
                reg <= (others => '0');
                counter <= (others => '0');
            elsif (load = '1') then
                reg <= input;
                counter <= (others => '0');
            elsif (enable = '1') then
                counter <= counter + 32;

                reg(1*128-1 downto 1*128-32) <= feedback(1*32-1 downto 0*32);
                reg(2*128-1 downto 2*128-32) <= feedback(2*32-1 downto 1*32);
                reg(3*128-1 downto 3*128-32) <= feedback(3*32-1 downto 2*32);
                reg(4*128-1 downto 4*128-32) <= feedback(4*32-1 downto 3*32);

                reg(1*128-32-1 downto 0*128) <= reg(1*128-1 downto 0*128+32);
                reg(2*128-32-1 downto 1*128) <= reg(2*128-1 downto 1*128+32);     
                reg(3*128-32-1 downto 2*128) <= reg(3*128-1 downto 2*128+32);     
                reg(4*128-32-1 downto 3*128) <= reg(4*128-1 downto 3*128+32);     
            end if;
        end if;

    end process shift_reg;
end architecture behavioral;
