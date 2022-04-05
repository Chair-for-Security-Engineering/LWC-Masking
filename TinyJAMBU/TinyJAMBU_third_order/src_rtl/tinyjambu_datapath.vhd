--------------------------------------------------------------------------------
--! @file       tinyjambu_datapath.vhd
--! @brief      Datapath for TinyJAMBU
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
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.design_pkg.all;
use work.NIST_LWAPI_pkg.all;

entity tinyjambu_datapath is
    port (
        clk                 : in std_logic;
        reset               : in std_logic;
        nlfsr_load          : in std_logic;
        partial             : in std_logic;
        partial_bytes       : in std_logic_vector (1        downto 0);
        partial_bdo_out     : in std_logic_vector (3        downto 0);
        nlfsr_en            : in std_logic;
        nlfsr_reset         : in std_logic;
        decrypt             : in std_logic;
        bdi                 : in std_logic_vector (PDI_SHARES * CCW - 1  downto 0);
        key                 : in std_logic_vector (SDI_SHARES * CCSW - 1 downto 0);
        key_load            : in std_logic;
        key_index           : in std_logic_vector (1        downto 0);
        fbits_sel           : in std_logic_vector (1        downto 0);
        s_sel               : in std_logic_vector (1        downto 0);
        bdo_sel             : in std_logic;
        bdo                 : out std_logic_vector (PDI_SHARES * CCW - 1 downto 0);
        fresh               : in std_logic_vector (191 downto 0)
    );
end entity tinyjambu_datapath;

architecture dataflow of tinyjambu_datapath is
constant REG_SIZE           : integer           := 128;
signal fbits_mux_out        : std_logic_vector (2           downto 0);
signal s_fbits_xor_out      : std_logic_vector (PDI_SHARES * 3 - 1 downto 0);
signal s_left_concat_out    : std_logic_vector (PDI_SHARES * REG_SIZE - 1 downto 0);
signal s_right_concat_out   : std_logic_vector (PDI_SHARES * REG_SIZE - 1 downto 0);
signal s_mux_out            : std_logic_vector (PDI_SHARES * REG_SIZE - 1 downto 0);
signal partial_full_mux_out : std_logic_vector (PDI_SHARES * 96 - 1 downto 0);
signal partial_out          : std_logic_vector (PDI_SHARES * 96 - 1 downto 0);
signal bdo_masked_out       : std_logic_vector (PDI_SHARES * CCW - 1 downto 0);
signal bdo_masked           : std_logic_vector (PDI_SHARES * CCW - 1 downto 0);
signal in_xor_out           : std_logic_vector (PDI_SHARES * CCW - 1 downto 0);
signal m_mux_out            : std_logic_vector (PDI_SHARES * CCW - 1 downto 0);
signal bdo_out              : std_logic_vector (PDI_SHARES * CCW - 1 downto 0);
signal tag_out              : std_logic_vector (PDI_SHARES * CCW - 1 downto 0);
signal bdi_swapped          : std_logic_vector (PDI_SHARES * CCW - 1 downto 0);
signal bdo_swapped          : std_logic_vector (PDI_SHARES * CCW - 1 downto 0);
signal tag_swapped          : std_logic_vector (PDI_SHARES * CCW - 1 downto 0);
signal key_swapped          : std_logic_vector (SDI_SHARES * CCSW - 1 downto 0);
signal bdo_mux_out          : std_logic_vector (PDI_SHARES * CCW - 1 downto 0); -- Select between c/m and tag
signal pad_mux_out          : std_logic_vector (CCW-1       downto 0);
signal tag                  : std_logic_vector (CCW-1       downto 0);
signal full_key             : std_logic_vector (SDI_SHARES * REG_SIZE - 1 downto 0);
signal s_mux_out_unshared   : std_logic_vector (REG_SIZE - 1 downto 0);


--signal for the NLFSR
signal s                    : std_logic_vector (PDI_SHARES*REG_SIZE-1  downto 0);

signal key_array_s0            : t_slv_array(3 downto 0) := (others => (others => '0'));
signal key_array_s1            : t_slv_array(3 downto 0) := (others => (others => '0'));
signal key_array_s2            : t_slv_array(3 downto 0) := (others => (others => '0'));
signal key_array_s3            : t_slv_array(3 downto 0) := (others => (others => '0'));

-- temporary signals
begin
full_key(1*REG_SIZE-1 downto 0*REG_SIZE) <= to_slv(key_array_s0);
full_key(2*REG_SIZE-1 downto 1*REG_SIZE) <= to_slv(key_array_s1);
full_key(3*REG_SIZE-1 downto 2*REG_SIZE) <= to_slv(key_array_s2);
full_key(4*REG_SIZE-1 downto 3*REG_SIZE) <= to_slv(key_array_s3);

bdi_swapped(1*CCW-1 downto 0*CCW) <= bdi(0*CCW+7 downto 0*CCW+0) & bdi(0*CCW+15 downto 0*CCW+8) & bdi(0*CCW+23 downto 0*CCW+16) & bdi(0*CCW+31 downto 0*CCW+24);
bdi_swapped(2*CCW-1 downto 1*CCW) <= bdi(1*CCW+7 downto 1*CCW+0) & bdi(1*CCW+15 downto 1*CCW+8) & bdi(1*CCW+23 downto 1*CCW+16) & bdi(1*CCW+31 downto 1*CCW+24);
bdi_swapped(3*CCW-1 downto 2*CCW) <= bdi(2*CCW+7 downto 2*CCW+0) & bdi(2*CCW+15 downto 2*CCW+8) & bdi(2*CCW+23 downto 2*CCW+16) & bdi(2*CCW+31 downto 2*CCW+24);
bdi_swapped(4*CCW-1 downto 3*CCW) <= bdi(3*CCW+7 downto 3*CCW+0) & bdi(3*CCW+15 downto 3*CCW+8) & bdi(3*CCW+23 downto 3*CCW+16) & bdi(3*CCW+31 downto 3*CCW+24);

key_swapped(1*CCSW-1 downto 0*CCSW) <= key(0*CCSW+7 downto 0*CCSW+0) & key(0*CCSW+15 downto 0*CCSW+8) & key(0*CCSW+23 downto 0*CCSW+16) & key(0*CCSW+31 downto 0*CCSW+24);
key_swapped(2*CCSW-1 downto 1*CCSW) <= key(1*CCSW+7 downto 1*CCSW+0) & key(1*CCSW+15 downto 1*CCSW+8) & key(1*CCSW+23 downto 1*CCSW+16) & key(1*CCSW+31 downto 1*CCSW+24);
key_swapped(3*CCSW-1 downto 2*CCSW) <= key(2*CCSW+7 downto 2*CCSW+0) & key(2*CCSW+15 downto 2*CCSW+8) & key(2*CCSW+23 downto 2*CCSW+16) & key(2*CCSW+31 downto 2*CCSW+24);
key_swapped(4*CCSW-1 downto 3*CCSW) <= key(3*CCSW+7 downto 3*CCSW+0) & key(3*CCSW+15 downto 3*CCSW+8) & key(3*CCSW+23 downto 3*CCSW+16) & key(3*CCSW+31 downto 3*CCSW+24);

bdo_out(1*CCW-1 downto 0*CCW) <= s(0*REG_SIZE+95 downto 0*REG_SIZE+64) xor bdi_swapped(1*CCW-1 downto 0*CCW);
bdo_out(2*CCW-1 downto 1*CCW) <= s(1*REG_SIZE+95 downto 1*REG_SIZE+64) xor bdi_swapped(2*CCW-1 downto 1*CCW);
bdo_out(3*CCW-1 downto 2*CCW) <= s(2*REG_SIZE+95 downto 2*REG_SIZE+64) xor bdi_swapped(3*CCW-1 downto 2*CCW);
bdo_out(4*CCW-1 downto 3*CCW) <= s(3*REG_SIZE+95 downto 3*REG_SIZE+64) xor bdi_swapped(4*CCW-1 downto 3*CCW);

bdo_swapped(1*CCW-1 downto 0*CCW) <= bdo_out(0*CCW+7 downto 0*CCW+0) & bdo_out(0*CCW+15 downto 0*CCW+8) & bdo_out(0*CCW+23 downto 0*CCW+16) & bdo_out(0*CCW+31 downto 0*CCW+24);
bdo_swapped(2*CCW-1 downto 1*CCW) <= bdo_out(1*CCW+7 downto 1*CCW+0) & bdo_out(1*CCW+15 downto 1*CCW+8) & bdo_out(1*CCW+23 downto 1*CCW+16) & bdo_out(1*CCW+31 downto 1*CCW+24);
bdo_swapped(3*CCW-1 downto 2*CCW) <= bdo_out(2*CCW+7 downto 2*CCW+0) & bdo_out(2*CCW+15 downto 2*CCW+8) & bdo_out(2*CCW+23 downto 2*CCW+16) & bdo_out(2*CCW+31 downto 2*CCW+24);
bdo_swapped(4*CCW-1 downto 3*CCW) <= bdo_out(3*CCW+7 downto 3*CCW+0) & bdo_out(3*CCW+15 downto 3*CCW+8) & bdo_out(3*CCW+23 downto 3*CCW+16) & bdo_out(3*CCW+31 downto 3*CCW+24);

with partial_bdo_out select
    bdo_masked(1*CCW-1 downto 0*CCW) <= x"000000" & bdo_out(0*CCW+7  downto 0*CCW+0) when "1000",
                                        x"0000"   & bdo_out(0*CCW+15 downto 0*CCW+0) when "1100",
                                        x"00"     & bdo_out(0*CCW+23 downto 0*CCW+0) when "1110",
                                                    bdo_out(0*CCW+31 downto 0*CCW+0) when others;
with partial_bdo_out select
    bdo_masked(2*CCW-1 downto 1*CCW) <= x"000000" & bdo_out(1*CCW+7  downto 1*CCW+0) when "1000",
                                        x"0000"   & bdo_out(1*CCW+15 downto 1*CCW+0) when "1100",
                                        x"00"     & bdo_out(1*CCW+23 downto 1*CCW+0) when "1110",
                                                    bdo_out(1*CCW+31 downto 1*CCW+0) when others;                                                                                                
with partial_bdo_out select
    bdo_masked(3*CCW-1 downto 2*CCW) <= x"000000" & bdo_out(2*CCW+7  downto 2*CCW+0) when "1000",
                                        x"0000"   & bdo_out(2*CCW+15 downto 2*CCW+0) when "1100",
                                        x"00"     & bdo_out(2*CCW+23 downto 2*CCW+0) when "1110",
                                                    bdo_out(2*CCW+31 downto 2*CCW+0) when others;   
with partial_bdo_out select
    bdo_masked(4*CCW-1 downto 3*CCW) <= x"000000" & bdo_out(3*CCW+7  downto 3*CCW+0) when "1000",
                                        x"0000"   & bdo_out(3*CCW+15 downto 3*CCW+0) when "1100",
                                        x"00"     & bdo_out(3*CCW+23 downto 3*CCW+0) when "1110",
                                                    bdo_out(3*CCW+31 downto 3*CCW+0) when others;                                                    
with partial_bdo_out select
    bdo_masked_out(1*CCW-1 downto 0*CCW)  <= bdo_mux_out(0*CCW+31 downto 0*CCW+24) & x"000000" when "1000",
                                             bdo_mux_out(0*CCW+31 downto 0*CCW+16) & x"0000" when "1100",
                                             bdo_mux_out(0*CCW+31 downto 0*CCW+8)  & x"00" when "1110",
                                             bdo_mux_out(0*CCW+31 downto 0*CCW+0)  when others;
with partial_bdo_out select
    bdo_masked_out(2*CCW-1 downto 1*CCW)  <= bdo_mux_out(1*CCW+31 downto 1*CCW+24) & x"000000" when "1000",
                                             bdo_mux_out(1*CCW+31 downto 1*CCW+16) & x"0000" when "1100",
                                             bdo_mux_out(1*CCW+31 downto 1*CCW+8)  & x"00" when "1110",
                                             bdo_mux_out(1*CCW+31 downto 1*CCW+0)  when others;
with partial_bdo_out select
    bdo_masked_out(3*CCW-1 downto 2*CCW)  <= bdo_mux_out(2*CCW+31 downto 2*CCW+24) & x"000000" when "1000",
                                             bdo_mux_out(2*CCW+31 downto 2*CCW+16) & x"0000" when "1100",
                                             bdo_mux_out(2*CCW+31 downto 2*CCW+8)  & x"00" when "1110",
                                             bdo_mux_out(2*CCW+31 downto 2*CCW+0)  when others;      
with partial_bdo_out select
    bdo_masked_out(4*CCW-1 downto 3*CCW)  <= bdo_mux_out(3*CCW+31 downto 3*CCW+24) & x"000000" when "1000",
                                             bdo_mux_out(3*CCW+31 downto 3*CCW+16) & x"0000" when "1100",
                                             bdo_mux_out(3*CCW+31 downto 3*CCW+8)  & x"00" when "1110",
                                             bdo_mux_out(3*CCW+31 downto 3*CCW+0)  when others;                                                                                                                             
bdo <= bdo_masked_out;

tag_out(1*CCW-1 downto 0*CCW) <= s(0*REG_SIZE+95 downto 0*REG_SIZE+64);
tag_out(2*CCW-1 downto 1*CCW) <= s(1*REG_SIZE+95 downto 1*REG_SIZE+64);
tag_out(3*CCW-1 downto 2*CCW) <= s(2*REG_SIZE+95 downto 2*REG_SIZE+64);
tag_out(4*CCW-1 downto 3*CCW) <= s(3*REG_SIZE+95 downto 3*REG_SIZE+64);

tag_swapped(1*CCW-1 downto 0*CCW) <= tag_out(0*CCW+7 downto 0*CCW+0) & tag_out(0*CCW+15 downto 0*CCW+8) & tag_out(0*CCW+23 downto 0*CCW+16) & tag_out(0*CCW+31 downto 0*CCW+24);
tag_swapped(2*CCW-1 downto 1*CCW) <= tag_out(1*CCW+7 downto 1*CCW+0) & tag_out(1*CCW+15 downto 1*CCW+8) & tag_out(1*CCW+23 downto 1*CCW+16) & tag_out(1*CCW+31 downto 1*CCW+24);
tag_swapped(3*CCW-1 downto 2*CCW) <= tag_out(2*CCW+7 downto 2*CCW+0) & tag_out(2*CCW+15 downto 2*CCW+8) & tag_out(2*CCW+23 downto 2*CCW+16) & tag_out(2*CCW+31 downto 2*CCW+24);
tag_swapped(4*CCW-1 downto 3*CCW) <= tag_out(3*CCW+7 downto 3*CCW+0) & tag_out(3*CCW+15 downto 3*CCW+8) & tag_out(3*CCW+23 downto 3*CCW+16) & tag_out(3*CCW+31 downto 3*CCW+24);

s_fbits_xor_out(1*3-1 downto 0*3) <= fbits_mux_out xor s(0*REG_SIZE+38 downto 0*REG_SIZE+36);
s_fbits_xor_out(2*3-1 downto 1*3) <= s(1*REG_SIZE+38 downto 1*REG_SIZE+36);
s_fbits_xor_out(3*3-1 downto 2*3) <= s(2*REG_SIZE+38 downto 2*REG_SIZE+36);
s_fbits_xor_out(4*3-1 downto 3*3) <= s(3*REG_SIZE+38 downto 3*REG_SIZE+36);

s_left_concat_out(1*REG_SIZE-1 downto 0*REG_SIZE) <= s(0*REG_SIZE+127 downto 0*REG_SIZE+39) & s_fbits_xor_out(1*3-1 downto 0*3) & s(0*REG_SIZE+35 downto 0*REG_SIZE+0);
s_left_concat_out(2*REG_SIZE-1 downto 1*REG_SIZE) <= s(1*REG_SIZE+127 downto 1*REG_SIZE+39) & s_fbits_xor_out(2*3-1 downto 1*3) & s(1*REG_SIZE+35 downto 1*REG_SIZE+0);
s_left_concat_out(3*REG_SIZE-1 downto 2*REG_SIZE) <= s(2*REG_SIZE+127 downto 2*REG_SIZE+39) & s_fbits_xor_out(3*3-1 downto 2*3) & s(2*REG_SIZE+35 downto 2*REG_SIZE+0);
s_left_concat_out(4*REG_SIZE-1 downto 3*REG_SIZE) <= s(3*REG_SIZE+127 downto 3*REG_SIZE+39) & s_fbits_xor_out(4*3-1 downto 3*3) & s(3*REG_SIZE+35 downto 3*REG_SIZE+0);

in_xor_out(1*CCW-1 downto 0*CCW) <= m_mux_out(1*CCW-1 downto 0*CCW) xor s(0*REG_SIZE+127 downto 0*REG_SIZE+96);
in_xor_out(2*CCW-1 downto 1*CCW) <= m_mux_out(2*CCW-1 downto 1*CCW) xor s(1*REG_SIZE+127 downto 1*REG_SIZE+96);
in_xor_out(3*CCW-1 downto 2*CCW) <= m_mux_out(3*CCW-1 downto 2*CCW) xor s(2*REG_SIZE+127 downto 2*REG_SIZE+96);
in_xor_out(4*CCW-1 downto 3*CCW) <= m_mux_out(4*CCW-1 downto 3*CCW) xor s(3*REG_SIZE+127 downto 3*REG_SIZE+96);

s_right_concat_out(1*REG_SIZE-1 downto 0*REG_SIZE) <= in_xor_out(1*CCW-1 downto 0*CCW) & partial_full_mux_out(1*96-1 downto 0*96);
s_right_concat_out(2*REG_SIZE-1 downto 1*REG_SIZE) <= in_xor_out(2*CCW-1 downto 1*CCW) & partial_full_mux_out(2*96-1 downto 1*96);
s_right_concat_out(3*REG_SIZE-1 downto 2*REG_SIZE) <= in_xor_out(3*CCW-1 downto 2*CCW) & partial_full_mux_out(3*96-1 downto 2*96);
s_right_concat_out(4*REG_SIZE-1 downto 3*REG_SIZE) <= in_xor_out(4*CCW-1 downto 3*CCW) & partial_full_mux_out(4*96-1 downto 3*96);

partial_out(1*96-1 downto 0*96) <= s(0*REG_SIZE+95 downto 0*REG_SIZE+34) & (s(0*REG_SIZE+33 downto 0*REG_SIZE+32) xor partial_bytes) & s(0*REG_SIZE+31 downto 0*REG_SIZE+0);
partial_out(2*96-1 downto 1*96) <= s(1*REG_SIZE+95 downto 1*REG_SIZE+34) & s(1*REG_SIZE+33 downto 1*REG_SIZE+32) & s(1*REG_SIZE+31 downto 1*REG_SIZE+0);
partial_out(3*96-1 downto 2*96) <= s(2*REG_SIZE+95 downto 2*REG_SIZE+34) & s(2*REG_SIZE+33 downto 2*REG_SIZE+32) & s(2*REG_SIZE+31 downto 2*REG_SIZE+0);
partial_out(4*96-1 downto 3*96) <= s(3*REG_SIZE+95 downto 3*REG_SIZE+34) & s(3*REG_SIZE+33 downto 3*REG_SIZE+32) & s(3*REG_SIZE+31 downto 3*REG_SIZE+0);

-- Multiplexer to select which input we want to XOR with the state
with decrypt select
    m_mux_out <= bdo_masked when '1', bdi_swapped when others;

with bdo_sel select
    bdo_mux_out     <= tag_swapped when '1',
                       bdo_swapped when others;

-- Multiplexer to select which constant for FrameBits
with fbits_sel select
    fbits_mux_out   <= b"001" when "00",
                       b"011" when "01",
                       b"101" when "10",
                       b"111" when others;

-- Multiplexer to select the input of the NLFSR
with s_sel select
    s_mux_out       <= s_left_concat_out   when b"00",
                       s_right_concat_out  when others;

-- Handle partial blocks
with partial select
    partial_full_mux_out(1*96-1 downto 0*96) <= partial_out(1*96-1 downto 0*96) when '1', s(0*REG_SIZE+95 downto 0*REG_SIZE+0) when others;

with partial select
    partial_full_mux_out(2*96-1 downto 1*96) <= partial_out(2*96-1 downto 1*96) when '1', s(1*REG_SIZE+95 downto 1*REG_SIZE+0) when others;

with partial select
    partial_full_mux_out(3*96-1 downto 2*96) <= partial_out(3*96-1 downto 2*96) when '1', s(2*REG_SIZE+95 downto 2*REG_SIZE+0) when others;

with partial select
    partial_full_mux_out(4*96-1 downto 3*96) <= partial_out(4*96-1 downto 3*96) when '1', s(3*REG_SIZE+95 downto 3*REG_SIZE+0) when others;
    
-- Load the key into a local array
key_load_proc : process(clk)
begin
    if rising_edge(clk) then
        if (key_load = '1') then
            key_array_s0(to_integer(unsigned(key_index))) <= key_swapped(1*CCSW-1 downto 0*CCSW);
            key_array_s1(to_integer(unsigned(key_index))) <= key_swapped(2*CCSW-1 downto 1*CCSW);
            key_array_s2(to_integer(unsigned(key_index))) <= key_swapped(3*CCSW-1 downto 2*CCSW);
            key_array_s3(to_integer(unsigned(key_index))) <= key_swapped(4*CCSW-1 downto 3*CCSW);
        end if;
    end if;
end process key_load_proc;

state : entity work.nlfsr 
        port map (
            clk     => clk,
            reset   => nlfsr_reset,
            enable  => nlfsr_en,
            key     => full_key,
            load    => nlfsr_load,
            input   => s_mux_out,
            output  => s,
            fresh   => fresh
        );
end architecture dataflow;
