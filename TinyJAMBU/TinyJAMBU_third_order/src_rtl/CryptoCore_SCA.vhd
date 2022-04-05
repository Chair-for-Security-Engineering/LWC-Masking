--------------------------------------------------------------------------------
--! @file       CryptoCore.vhd
--! @brief      Template for CryptoCore implementations
--!
--! @author     Patrick Karl <patrick.karl@tum.de>
--! @copyright  Copyright (c) 2019 Chair of Security in Information Technology     
--!             ECE Department, Technical University of Munich, GERMANY
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
use ieee.std_logic_misc.all;
use work.NIST_LWAPI_pkg.all;
use work.design_pkg.all;

entity CryptoCore_SCA is
    Port (
        clk             : in   STD_LOGIC;
        rst             : in   STD_LOGIC;
        --PreProcessor===============================================
        ----!key----------------------------------------------------
        key             : in   STD_LOGIC_VECTOR (SDI_SHARES * CCSW -1  downto 0);
        key_valid       : in   STD_LOGIC;
        key_ready       : out  STD_LOGIC;
        ----!Data----------------------------------------------------
        bdi             : in   STD_LOGIC_VECTOR (PDI_SHARES * CCW - 1 downto 0);
        bdi_valid       : in   STD_LOGIC;
        bdi_ready       : out  STD_LOGIC;
        bdi_pad_loc     : in   STD_LOGIC_VECTOR (CCWdiv8 -1 downto 0);
        bdi_valid_bytes : in   STD_LOGIC_VECTOR (CCWdiv8 -1 downto 0);
        bdi_size        : in   STD_LOGIC_VECTOR (3       -1 downto 0);
        bdi_eot         : in   STD_LOGIC;
        bdi_eoi         : in   STD_LOGIC;
        bdi_type        : in   STD_LOGIC_VECTOR (4       -1 downto 0);
        decrypt_in      : in   STD_LOGIC;
        key_update      : in   STD_LOGIC;
        hash_in         : in   std_logic;
        --!Post Processor=========================================
        bdo             : out  STD_LOGIC_VECTOR (PDI_SHARES * CCW - 1 downto 0);
        bdo_valid       : out  STD_LOGIC;
        bdo_ready       : in   STD_LOGIC;
        bdo_type        : out  STD_LOGIC_VECTOR (4       -1 downto 0);
        bdo_valid_bytes : out  STD_LOGIC_VECTOR (CCWdiv8 -1 downto 0);
        end_of_block    : out  STD_LOGIC;
        msg_auth_valid  : out  STD_LOGIC;
        msg_auth_ready  : in   STD_LOGIC;
        msg_auth        : out  STD_LOGIC;
		rdi             : in  std_logic_vector(RW - 1 downto 0);
        rdi_valid       : in  std_logic;
        rdi_ready       : out std_logic
    );
end CryptoCore_SCA;

architecture behavioral of CryptoCore_SCA is

signal bdo_sel, nlfsr_load, nlfsr_en, nlfsr_reset, ctrl_decrypt : std_logic;
signal key_load, partial : std_logic;
signal fbits_sel, s_sel, key_index, partial_bytes : std_logic_vector (1 downto 0);
signal bdo_sig          : std_logic_vector (PDI_SHARES * CCW - 1 downto 0);

begin
bdo     <= bdo_sig;

datapath : entity work.tinyjambu_datapath
            port map (
                clk             => clk,
                reset           => rst,
                nlfsr_load      => nlfsr_load,
                partial         => partial,
                partial_bytes   => partial_bytes,
                key_load        => key_load,
                key_index       => key_index,
                nlfsr_en        => nlfsr_en,
                nlfsr_reset     => nlfsr_reset,
                decrypt         => ctrl_decrypt,
                bdi             => bdi,
                fbits_sel       => fbits_sel,
                partial_bdo_out => bdi_valid_bytes,
                s_sel           => s_sel,
                key             => key,
                bdo_sel         => bdo_sel,
                bdo             => bdo_sig,
                fresh           => rdi  
            );

control : entity work.tinyjambu_control
            port map (
                clk             => clk,
                reset           => rst,
                decrypt_in      => decrypt_in,
                decrypt_out     => ctrl_decrypt,
                nlfsr_reset     => nlfsr_reset,
                nlfsr_en        => nlfsr_en,
                nlfsr_load      => nlfsr_load,
                key_load        => key_load,
                key_index       => key_index,
                key_ready       => key_ready,
                key             => key,
                key_valid       => key_valid,
                key_update      => key_update,
                bdo_valid       => bdo_valid,
                bdo_ready       => bdo_ready,
                bdo_type        => bdo_type,
                partial         => partial,
                partial_bytes   => partial_bytes,
                bdi             => bdi,
                bdi_valid       => bdi_valid,
                bdi_ready       => bdi_ready,
                bdi_pad_loc     => bdi_pad_loc,
                bdi_size        => bdi_size,
                bdi_eoi         => bdi_eoi,
                bdi_eot         => bdi_eot,
                bdi_valid_bytes => bdi_valid_bytes,
                bdo_valid_bytes => bdo_valid_bytes,
                end_of_block    => end_of_block,
                bdi_type        => bdi_type,
                fbits_sel       => fbits_sel,
                bdo_sel         => bdo_sel,
                bdo             => bdo_sig,
                hash_in         => hash_in,
                s_sel           => s_sel,
                msg_auth_valid  => msg_auth_valid,
                msg_auth_ready  => msg_auth_ready,
                msg_auth        => msg_auth,
                rdi_valid       => rdi_valid,
                rdi_ready       => rdi_ready
            );
end architecture behavioral;
