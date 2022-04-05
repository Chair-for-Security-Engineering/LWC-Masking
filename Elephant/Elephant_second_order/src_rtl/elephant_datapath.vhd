--------------------------------------------------------------------------------
--! @file       elephant_datapath.vhd
--! @brief      
--! @author     Richard Haeussler
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
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use ieee.math_real.all;
use work.NIST_LWAPI_pkg.all;
use work.elephant_constants.all;
use work.Design_pkg.all;

entity elephant_datapath is
    port(
        --Signals to con
        key: in std_logic_vector(SDI_SHARES * CCW_SIZE-1 downto 0);
        bdi: in std_logic_vector(PDI_SHARES * CCW_SIZE-1 downto 0);
        bdi_size: in std_logic_vector(1 downto 0);
        data_type_sel: std_logic;

        load_data_en: in std_logic;
        load_data_sel: in std_logic_vector(1 downto 0);
        lfsr_mux_sel: in std_logic_vector(1 downto 0);
        
        lfsr_en: in std_logic;
       
        --Signals for key and npub
        key_en: in std_logic;
        npub_en: in std_logic;
        tag_en: in std_logic;
        tag_reset: in std_logic;
        
        ms_en: in std_logic;
        --Signals for permutation
        perm_en: in std_logic;
        load_lfsr: in std_logic;
        
        datap_lfsr_load: in std_logic;
        datap_lfsr_en: in std_logic;
        
        bdo: out std_logic_vector(PDI_SHARES * CCW_SIZE-1 downto 0);
        bdo_sel: in std_logic;
        saving_bdo: in std_logic;
        data_count: in integer range 0 to BLOCK_SIZE+1; --std_logic_vector(2 downto 0);
        perm_count: in integer range 0 to PERM_CYCLES;
        clk: in std_logic;
        fresh: in std_logic_vector(839 downto 0)
    );
end elephant_datapath;

architecture behavioral of elephant_datapath is
    
    signal permout: std_logic_vector(PDI_SHARES*STATE_SIZE-1 downto 0);
    signal perm_input: std_logic_vector(PDI_SHARES*STATE_SIZE-1 downto 0);
    
    signal datap_lfsr_out: std_logic_vector(SDI_SHARES*(STATE_SIZE+16)-1 downto 0);
    signal lfsr_current: std_logic_vector(SDI_SHARES*STATE_SIZE-1 downto 0);
    signal lfsr_next: std_logic_vector(SDI_SHARES*STATE_SIZE-1 downto 0);
    signal lfsr_prev: std_logic_vector(SDI_SHARES*STATE_SIZE-1 downto 0);
    signal cur_ms_xor: std_logic_vector(PDI_SHARES*STATE_SIZE-1 downto 0);
    signal prev_next_ms_xor: std_logic_vector(PDI_SHARES*STATE_SIZE-1 downto 0);
    signal cur_next_ms_xor: std_logic_vector(PDI_SHARES*STATE_SIZE-1 downto 0);
    
    signal bdi_or_key_s0: std_logic_vector(CCW_SIZE-1 downto 0);
    signal bdi_or_key_s1: std_logic_vector(CCW_SIZE-1 downto 0);
    signal bdi_or_key_s2: std_logic_vector(CCW_SIZE-1 downto 0);

    signal bdi_or_key_rev_s0 : std_logic_vector(CCW_SIZE-1 downto 0);
    signal bdi_or_key_rev_s1 : std_logic_vector(CCW_SIZE-1 downto 0);
    signal bdi_or_key_rev_s2 : std_logic_vector(CCW_SIZE-1 downto 0);
   
    signal bdi_or_bdo: std_logic_vector(PDI_SHARES*CCW_SIZE-1 downto 0);
    
    signal padding_bdi: std_logic_vector(PDI_SHARES*CCW_SIZE-1 downto 0);
--    signal bdi_or_reset: std_logic_vector(CCW_SIZE-1 downto 0);
    signal load_data_input_mux: std_logic_vector(PDI_SHARES*CCW_SIZE-1 downto 0);
    signal load_data_output: std_logic_vector(PDI_SHARES*STATE_SIZE-1 downto 0);
    signal lfsr_xor_mux: std_logic_vector(PDI_SHARES*STATE_SIZE-1 downto 0);
    
    signal key_out: std_logic_vector(SDI_SHARES*STATE_SIZE-1 downto 0);
    signal npub_out: std_logic_vector(PDI_SHARES*NPUB_SIZE_BITS-1 downto 0);
    signal tag_out: std_logic_vector(PDI_SHARES*TAG_SIZE_BITS-1 downto 0);
    signal tag_input: std_logic_vector(PDI_SHARES*TAG_SIZE_BITS-1 downto 0);
    
    -- Verifiy this size
    signal ms_reg_input_mux: std_logic_vector(PDI_SHARES*STATE_SIZE-1 downto 0);
    signal ms_reg_out: std_logic_vector(PDI_SHARES*STATE_SIZE-1 downto 0);
    signal ms_out_mux1: std_logic_vector(CCW_SIZE-1 downto 0);
    signal ms_out_mux2: std_logic_vector(PDI_SHARES*CCW_SIZE-1 downto 0);
    
    signal data_out_mux_s0: std_logic_vector(CCW_SIZE-1 downto 0);
    signal data_out_mux_s1: std_logic_vector(CCW_SIZE-1 downto 0);
    signal data_out_mux_s2: std_logic_vector(CCW_SIZE-1 downto 0);
    
    signal data_bdo: std_logic_vector(PDI_SHARES*CCW_SIZE-1 downto 0);
    signal tag_mux: std_logic_vector(PDI_SHARES*CCW_SIZE-1 downto 0);
    
    signal lfsr, rev_lfsr: std_logic_vector(6 downto 0);

component elephant_perm_lfsr is
    port(
        clk: in std_logic;
        load_lfsr: in std_logic;
        lfsr_en: in std_logic;
        lfsr: out std_logic_vector(6 downto 0);
        rev_lfsr: out std_logic_vector(6 downto 0)
    );
end component;

component elephant_perm_HPC2_ClockGating_d2 is
    port(
        clk: in std_logic;
        input0_s0: in std_logic_vector(159 downto 0);
        input0_s1: in std_logic_vector(159 downto 0);
        input0_s2: in std_logic_vector(159 downto 0);
        lfsr: in std_logic_vector(6 downto 0);
        rev_lfsr: in std_logic_vector(6 downto 0);
        Fresh: in std_logic_vector(839 downto 0);
        output0_s0: out std_logic_vector(159 downto 0);
        output0_s1: out std_logic_vector(159 downto 0);
        output0_s2: out std_logic_vector(159 downto 0)
    );
end component;    
    
begin
    
    PERM_LFSR: elephant_perm_lfsr
        port map(
            clk => clk,
            load_lfsr => load_lfsr,
            lfsr_en => lfsr_en,
            lfsr => lfsr,
            rev_lfsr => rev_lfsr
        );
        
    PERM: elephant_perm_HPC2_ClockGating_d2
        port map(
            clk => clk,
            input0_s0 => perm_input(1*STATE_SIZE-1 downto 0*STATE_SIZE),
            input0_s1 => perm_input(2*STATE_SIZE-1 downto 1*STATE_SIZE),
            input0_s2 => perm_input(3*STATE_SIZE-1 downto 2*STATE_SIZE),
            Fresh => fresh,
            lfsr => lfsr,
            rev_lfsr => rev_lfsr, 
            output0_s0 => permout(1*STATE_SIZE-1 downto 0*STATE_SIZE),
            output0_s1 => permout(2*STATE_SIZE-1 downto 1*STATE_SIZE),
            output0_s2 => permout(3*STATE_SIZE-1 downto 2*STATE_SIZE)
        );

    DATAP_LFSR0: entity work.elephant_datapath_lfsr
        port map(
            load_key    => datap_lfsr_load,
            clk         => clk,
            key_in      => key_out(1*STATE_SIZE-1 downto 0*STATE_SIZE),
            en          => datap_lfsr_en,
            ele_lfsr_output => datap_lfsr_out(1*(STATE_SIZE+16)-1 downto 0*(STATE_SIZE+16))
        );
        
    DATAP_LFSR1: entity work.elephant_datapath_lfsr
        port map(
            load_key    => datap_lfsr_load,
            clk         => clk,
            key_in      => key_out(2*STATE_SIZE-1 downto 1*STATE_SIZE),
            en          => datap_lfsr_en,
            ele_lfsr_output => datap_lfsr_out(2*(STATE_SIZE+16)-1 downto 1*(STATE_SIZE+16))
        );

    DATAP_LFSR2: entity work.elephant_datapath_lfsr
        port map(
            load_key    => datap_lfsr_load,
            clk         => clk,
            key_in      => key_out(3*STATE_SIZE-1 downto 2*STATE_SIZE),
            en          => datap_lfsr_en,
            ele_lfsr_output => datap_lfsr_out(3*(STATE_SIZE+16)-1 downto 2*(STATE_SIZE+16))
        );
                
    p_ms_reg: process(clk, ms_en)
    begin
        if rising_edge(clk) and ms_en = '1' then
            ms_reg_out <= ms_reg_input_mux;
        end if;
    end process;
    p_key_reg: process(clk, key_en)
    begin
        if rising_edge(clk) and key_en = '1' then
            key_out <= ms_reg_input_mux;
        end if;
    end process;

    p_npub_reg: process(clk, npub_en)
    begin
        if rising_edge(clk) and npub_en = '1' then
            npub_out(1*NPUB_SIZE_BITS-1 downto 0*NPUB_SIZE_BITS) <= load_data_output(0*STATE_SIZE+STATE_SIZE-1 downto 0*STATE_SIZE+STATE_SIZE-NPUB_SIZE_BITS);
            npub_out(2*NPUB_SIZE_BITS-1 downto 1*NPUB_SIZE_BITS) <= load_data_output(1*STATE_SIZE+STATE_SIZE-1 downto 1*STATE_SIZE+STATE_SIZE-NPUB_SIZE_BITS);
            npub_out(3*NPUB_SIZE_BITS-1 downto 2*NPUB_SIZE_BITS) <= load_data_output(2*STATE_SIZE+STATE_SIZE-1 downto 2*STATE_SIZE+STATE_SIZE-NPUB_SIZE_BITS);
        end if;
    end process;

    p_tag_reg: process(clk, tag_en)
    begin
        if rising_edge(clk) and tag_en = '1' then
            tag_out <= tag_input;
        end if;
    end process;

    p_load_data: process(clk, load_data_en)
    begin
        if rising_edge(clk) and load_data_en = '1' then
            if load_data_sel = "11" then
                load_data_output(1*STATE_SIZE-1 downto 0*STATE_SIZE) <= x"0000000000000000" & npub_out(1*NPUB_SIZE_BITS-1 downto 0*NPUB_SIZE_BITS);
                load_data_output(2*STATE_SIZE-1 downto 1*STATE_SIZE) <= x"0000000000000000" & npub_out(2*NPUB_SIZE_BITS-1 downto 1*NPUB_SIZE_BITS);
                load_data_output(3*STATE_SIZE-1 downto 2*STATE_SIZE) <= x"0000000000000000" & npub_out(3*NPUB_SIZE_BITS-1 downto 2*NPUB_SIZE_BITS);
            else
                load_data_output(1*STATE_SIZE-1 downto 0*STATE_SIZE) <= load_data_input_mux(1*CCW_SIZE-1 downto 0*CCW_SIZE) & load_data_output(0*STATE_SIZE+STATE_SIZE-1 downto 0*STATE_SIZE+CCW_SIZE);
                load_data_output(2*STATE_SIZE-1 downto 1*STATE_SIZE) <= load_data_input_mux(2*CCW_SIZE-1 downto 1*CCW_SIZE) & load_data_output(1*STATE_SIZE+STATE_SIZE-1 downto 1*STATE_SIZE+CCW_SIZE);
                load_data_output(3*STATE_SIZE-1 downto 2*STATE_SIZE) <= load_data_input_mux(3*CCW_SIZE-1 downto 2*CCW_SIZE) & load_data_output(2*STATE_SIZE+STATE_SIZE-1 downto 2*STATE_SIZE+CCW_SIZE);
            end if;
        end if;
    end process;

    --Select between process key or bdi
    bdi_or_key_s0 <= bdi(1*CCW_SIZE-1 downto 0*CCW_SIZE) when data_type_sel = '0' else  key(1*CCW_SIZE-1 downto 0*CCW_SIZE);
    bdi_or_key_s1 <= bdi(2*CCW_SIZE-1 downto 1*CCW_SIZE) when data_type_sel = '0' else  key(2*CCW_SIZE-1 downto 1*CCW_SIZE);
    bdi_or_key_s2 <= bdi(3*CCW_SIZE-1 downto 2*CCW_SIZE) when data_type_sel = '0' else  key(3*CCW_SIZE-1 downto 2*CCW_SIZE);
    
    bdi_or_key_rev_s0 <= reverse_byte(bdi_or_key_s0);
    bdi_or_key_rev_s1 <= reverse_byte(bdi_or_key_s1);
    bdi_or_key_rev_s2 <= reverse_byte(bdi_or_key_s2);

    bdi_or_bdo(1*CCW_SIZE-1 downto 0*CCW_SIZE) <= bdi_or_key_rev_s0 when saving_bdo = '0' else data_bdo(1*CCW_SIZE-1 downto 0*CCW_SIZE);
    bdi_or_bdo(2*CCW_SIZE-1 downto 1*CCW_SIZE) <= bdi_or_key_rev_s1 when saving_bdo = '0' else data_bdo(2*CCW_SIZE-1 downto 1*CCW_SIZE);  
    bdi_or_bdo(3*CCW_SIZE-1 downto 2*CCW_SIZE) <= bdi_or_key_rev_s2 when saving_bdo = '0' else data_bdo(3*CCW_SIZE-1 downto 2*CCW_SIZE);  
    
   --Logic for how padding works
    with bdi_size select
        padding_bdi(1*CCW_SIZE-1 downto 0*CCW_SIZE) <= x"00000001" when "00",
                                                       x"000001" & bdi_or_bdo(0*CCW_SIZE+7 downto 0*CCW_SIZE+0) when "01",
                                                       x"0001" & bdi_or_bdo(0*CCW_SIZE+15 downto 0*CCW_SIZE+0) when "10",
                                                       x"01" & bdi_or_bdo(0*CCW_SIZE+23 downto 0*CCW_SIZE+0) when others;
    
    with bdi_size select
        padding_bdi(2*CCW_SIZE-1 downto 1*CCW_SIZE) <= x"00000000" when "00",
                                                       x"000000" & bdi_or_bdo(1*CCW_SIZE+7 downto 1*CCW_SIZE+0) when "01",
                                                       x"0000" & bdi_or_bdo(1*CCW_SIZE+15 downto 1*CCW_SIZE+0) when "10",
                                                       x"00" & bdi_or_bdo(1*CCW_SIZE+23 downto 1*CCW_SIZE+0) when others;
    with bdi_size select
        padding_bdi(3*CCW_SIZE-1 downto 2*CCW_SIZE) <= x"00000000" when "00",
                                                       x"000000" & bdi_or_bdo(2*CCW_SIZE+7 downto 2*CCW_SIZE+0) when "01",
                                                       x"0000" & bdi_or_bdo(2*CCW_SIZE+15 downto 2*CCW_SIZE+0) when "10",
                                                       x"00" & bdi_or_bdo(2*CCW_SIZE+23 downto 2*CCW_SIZE+0) when others;
                       
    --Also mux is very large at the momment might be able to reduce to CCW size
    --mux to reset load_data and shift data input
    with load_data_sel select
        load_data_input_mux <= x"000000000000000000000000"  when "00",
                                       bdi_or_bdo   when "01",
                                       padding_bdi  when others;

    --Above and beyond logic see if there is a way to not include ms_reg_out in xor.
    --Would likely required this to happen after mux and => ms_reg would be zero prior
    --to the loading the state.
    lfsr_current(1*STATE_SIZE-1 downto 0*STATE_SIZE) <= datap_lfsr_out(0*(STATE_SIZE+16)+STATE_SIZE+8-1 downto 0*(STATE_SIZE+16)+8);
    lfsr_current(2*STATE_SIZE-1 downto 1*STATE_SIZE) <= datap_lfsr_out(1*(STATE_SIZE+16)+STATE_SIZE+8-1 downto 1*(STATE_SIZE+16)+8);
    lfsr_current(3*STATE_SIZE-1 downto 2*STATE_SIZE) <= datap_lfsr_out(2*(STATE_SIZE+16)+STATE_SIZE+8-1 downto 2*(STATE_SIZE+16)+8);
    
    lfsr_next(1*STATE_SIZE-1 downto 0*STATE_SIZE) <= datap_lfsr_out(0*(STATE_SIZE+16)+STATE_SIZE+16-1 downto 0*(STATE_SIZE+16)+16);
    lfsr_next(2*STATE_SIZE-1 downto 1*STATE_SIZE) <= datap_lfsr_out(1*(STATE_SIZE+16)+STATE_SIZE+16-1 downto 1*(STATE_SIZE+16)+16);
    lfsr_next(3*STATE_SIZE-1 downto 2*STATE_SIZE) <= datap_lfsr_out(2*(STATE_SIZE+16)+STATE_SIZE+16-1 downto 2*(STATE_SIZE+16)+16);
    
    lfsr_prev(1*STATE_SIZE-1 downto 0*STATE_SIZE) <= datap_lfsr_out(0*(STATE_SIZE+16)+STATE_SIZE-1 downto 0*(STATE_SIZE+16)+0);
    lfsr_prev(2*STATE_SIZE-1 downto 1*STATE_SIZE) <= datap_lfsr_out(1*(STATE_SIZE+16)+STATE_SIZE-1 downto 1*(STATE_SIZE+16)+0);
    lfsr_prev(3*STATE_SIZE-1 downto 2*STATE_SIZE) <= datap_lfsr_out(2*(STATE_SIZE+16)+STATE_SIZE-1 downto 2*(STATE_SIZE+16)+0);
    
    cur_ms_xor <= lfsr_current xor ms_reg_out;
    prev_next_ms_xor <= lfsr_prev xor lfsr_next xor ms_reg_out;
    cur_next_ms_xor <= lfsr_next xor cur_ms_xor;
    
    with lfsr_mux_sel select
        lfsr_xor_mux <= load_data_output when "00",
                        cur_ms_xor when "01",     
                        prev_next_ms_xor when "10",
                        cur_next_ms_xor when others;
    --Update Tag
--    tag_input <= reverse_byte(lfsr_xor_mux(TAG_SIZE_BITS-1 downto 0)) xor tag_out when tag_reset = '0' else (others => '0');
    tag_input(1*TAG_SIZE_BITS-1 downto 0*TAG_SIZE_BITS) <= lfsr_xor_mux(0*STATE_SIZE+TAG_SIZE_BITS-1 downto 0*STATE_SIZE+0) xor tag_out(1*TAG_SIZE_BITS-1 downto 0*TAG_SIZE_BITS) when tag_reset = '0' else (others => '0');
    tag_input(2*TAG_SIZE_BITS-1 downto 1*TAG_SIZE_BITS) <= lfsr_xor_mux(1*STATE_SIZE+TAG_SIZE_BITS-1 downto 1*STATE_SIZE+0) xor tag_out(2*TAG_SIZE_BITS-1 downto 1*TAG_SIZE_BITS) when tag_reset = '0' else (others => '0');
    tag_input(3*TAG_SIZE_BITS-1 downto 2*TAG_SIZE_BITS) <= lfsr_xor_mux(2*STATE_SIZE+TAG_SIZE_BITS-1 downto 2*STATE_SIZE+0) xor tag_out(3*TAG_SIZE_BITS-1 downto 2*TAG_SIZE_BITS) when tag_reset = '0' else (others => '0');

    --Logic for ms_reg_mux and perm
    ms_reg_input_mux <= permout when perm_en = '1' else lfsr_xor_mux;
    
    perm_input <= ms_reg_out;

    with data_count select
        ms_out_mux2(1*CCW_SIZE-1 downto 0*CCW_SIZE) <= ms_reg_out(0*STATE_SIZE+(1*CCW)-1 downto 0*STATE_SIZE+0*CCW) when 0,
                                                       ms_reg_out(0*STATE_SIZE+(2*CCW)-1 downto 0*STATE_SIZE+1*CCW) when 1,
                                                       ms_reg_out(0*STATE_SIZE+(3*CCW)-1 downto 0*STATE_SIZE+2*CCW) when 2,
                                                       ms_reg_out(0*STATE_SIZE+(4*CCW)-1 downto 0*STATE_SIZE+3*CCW) when 3,
                                                       ms_reg_out(0*STATE_SIZE+(5*CCW)-1 downto 0*STATE_SIZE+4*CCW) when others;
    with data_count select
        ms_out_mux2(2*CCW_SIZE-1 downto 1*CCW_SIZE) <= ms_reg_out(1*STATE_SIZE+(1*CCW)-1 downto 1*STATE_SIZE+0*CCW) when 0,
                                                       ms_reg_out(1*STATE_SIZE+(2*CCW)-1 downto 1*STATE_SIZE+1*CCW) when 1,
                                                       ms_reg_out(1*STATE_SIZE+(3*CCW)-1 downto 1*STATE_SIZE+2*CCW) when 2,
                                                       ms_reg_out(1*STATE_SIZE+(4*CCW)-1 downto 1*STATE_SIZE+3*CCW) when 3,
                                                       ms_reg_out(1*STATE_SIZE+(5*CCW)-1 downto 1*STATE_SIZE+4*CCW) when others;                       
    with data_count select
        ms_out_mux2(3*CCW_SIZE-1 downto 2*CCW_SIZE) <= ms_reg_out(2*STATE_SIZE+(1*CCW)-1 downto 2*STATE_SIZE+0*CCW) when 0,
                                                       ms_reg_out(2*STATE_SIZE+(2*CCW)-1 downto 2*STATE_SIZE+1*CCW) when 1,
                                                       ms_reg_out(2*STATE_SIZE+(3*CCW)-1 downto 2*STATE_SIZE+2*CCW) when 2,
                                                       ms_reg_out(2*STATE_SIZE+(4*CCW)-1 downto 2*STATE_SIZE+3*CCW) when 3,
                                                       ms_reg_out(2*STATE_SIZE+(5*CCW)-1 downto 2*STATE_SIZE+4*CCW) when others;                        
                     
                       
    --ms_out_mux2 <= ms_out_mux1 when data_count /= 4 else ms_reg_out(STATE_SIZE-1 downto 4*CCW);
    data_bdo(1*CCW_SIZE-1 downto 0*CCW_SIZE) <= bdi_or_key_rev_s0 xor ms_out_mux2(1*CCW_SIZE-1 downto 0*CCW_SIZE);
    data_bdo(2*CCW_SIZE-1 downto 1*CCW_SIZE) <= bdi_or_key_rev_s1 xor ms_out_mux2(2*CCW_SIZE-1 downto 1*CCW_SIZE);
    data_bdo(3*CCW_SIZE-1 downto 2*CCW_SIZE) <= bdi_or_key_rev_s2 xor ms_out_mux2(3*CCW_SIZE-1 downto 2*CCW_SIZE);
    
    bdo(1*CCW_SIZE-1 downto 0*CCW_SIZE) <= reverse_byte(data_out_mux_s0);
    bdo(2*CCW_SIZE-1 downto 1*CCW_SIZE) <= reverse_byte(data_out_mux_s1);
    bdo(3*CCW_SIZE-1 downto 2*CCW_SIZE) <= reverse_byte(data_out_mux_s2);
    
    tag_mux(1*CCW_SIZE-1 downto 0*CCW_SIZE) <= tag_out(0*TAG_SIZE_BITS+TAG_SIZE_BITS-1 downto 0*TAG_SIZE_BITS+32) when data_count = 1 else tag_out(0*TAG_SIZE_BITS+31 downto 0*TAG_SIZE_BITS+0);
    tag_mux(2*CCW_SIZE-1 downto 1*CCW_SIZE) <= tag_out(1*TAG_SIZE_BITS+TAG_SIZE_BITS-1 downto 1*TAG_SIZE_BITS+32) when data_count = 1 else tag_out(1*TAG_SIZE_BITS+31 downto 1*TAG_SIZE_BITS+0);
    tag_mux(3*CCW_SIZE-1 downto 2*CCW_SIZE) <= tag_out(2*TAG_SIZE_BITS+TAG_SIZE_BITS-1 downto 2*TAG_SIZE_BITS+32) when data_count = 1 else tag_out(2*TAG_SIZE_BITS+31 downto 2*TAG_SIZE_BITS+0);

    data_out_mux_s0 <= data_bdo(1*CCW_SIZE-1 downto 0*CCW_SIZE) when bdo_sel ='0' else tag_mux(1*CCW_SIZE-1 downto 0*CCW_SIZE);
    data_out_mux_s1 <= data_bdo(2*CCW_SIZE-1 downto 1*CCW_SIZE) when bdo_sel ='0' else tag_mux(2*CCW_SIZE-1 downto 1*CCW_SIZE);
    data_out_mux_s2 <= data_bdo(3*CCW_SIZE-1 downto 2*CCW_SIZE) when bdo_sel ='0' else tag_mux(3*CCW_SIZE-1 downto 2*CCW_SIZE);
end behavioral;

