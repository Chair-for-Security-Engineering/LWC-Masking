--------------------------------------------------------------------------------
--! @file       xoodoo_n_rounds.vhd
--! @brief      Xoodoo rounds: n per cycle.
--!
--! @author     Guido Bertoni
--! @license    To the extent possible under law, the implementer has waived all copyright
--!             and related or neighboring rights to the source code in this file.
--!             http://creativecommons.org/publicdomain/zero/1.0/
--------------------------------------------------------------------------------

library work;
    use work.xoodoo_globals.all;
    use work.design_pkg.all;
    use work.NIST_LWAPI_pkg.all;

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.std_logic_arith.all;


entity xoodoo_n_rounds is
    generic( roundPerCycle : integer  := roundsPerCycle);
    port (
        clk          : in std_logic;
        state_in     : in std_logic_vector(2*384-1 downto 0);
        state_out    : out std_logic_vector(2*384-1 downto 0);
        rnd          : in std_logic_vector(383 downto 0);
        rc_state_in  : in std_logic_vector(5 downto 0);
        rc_state_out : out std_logic_vector(5 downto 0)
    );
end xoodoo_n_rounds;

architecture behavioral of xoodoo_n_rounds is

component xoodoo_round_HPC2_ClockGating_d1
    port (
        clk          : in std_logic;
        state_in_s0  : in std_logic_vector(383 downto 0);
        state_in_s1  : in std_logic_vector(383 downto 0);
        rc           : in std_logic_vector(31 downto 0);
        Fresh        : in std_logic_vector(383 downto 0);
        state_out_s0 : out std_logic_vector(383 downto 0);
        state_out_s1 : out std_logic_vector(383 downto 0)    
    );
end component;

component xoodoo_round
    port (
        state_in     : in  x_state_type;
        rc           : in std_logic_vector(31 downto 0);
        state_out    : out x_state_type
    );
end component;

component xoodoo_rc
    port (
        state_in  : in  std_logic_vector(5 downto 0);
        state_out : out std_logic_vector(5 downto 0);
        rc : out std_logic_vector(31 downto 0)
    );
end component;

signal xoodoo_rc_value : std_logic_vector(31 downto 0);
signal xoodoo_state_out : std_logic_vector(2*384-1 downto 0);
signal xoodoo_rc_state_out : std_logic_vector(5 downto 0);
signal state_in_x, state_out_x : x_state_type;

begin

rd_I : xoodoo_round_HPC2_ClockGating_d1
    port map(
        clk => clk, 
        state_in_s0 => state_in(1*384-1 downto 0*384),
        state_in_s1 => state_in(2*384-1 downto 1*384),
        rc => xoodoo_rc_value,
        Fresh => rnd,
        state_out_s0 => xoodoo_state_out(1*384-1 downto 0*384),
        state_out_s1 => xoodoo_state_out(2*384-1 downto 1*384)
    );

rc_I : xoodoo_rc
    port map(
        state_in => rc_state_in,
        rc => xoodoo_rc_value,
        state_out => xoodoo_rc_state_out
    );
    
state_out <= xoodoo_state_out;
rc_state_out <= xoodoo_rc_state_out;

end behavioral;