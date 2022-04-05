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
        key             : in   STD_LOGIC_VECTOR (SDI_SHARES * CCSW - 1  downto 0);
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

-- Internal inputs and signals --		

signal iv_we 			: STD_LOGIC;		
signal iv1_en           : STD_LOGIC;
signal iv1_rst          : STD_LOGIC;

signal iv_sel       	: STD_LOGIC_VECTOR( 1 downto 0 );
signal iv_input_sel 	: STD_LOGIC_VECTOR( 1 downto 0 );
signal iv_xor_sel      	: STD_LOGIC;
signal c1_sel           : STD_LOGIC;

signal c0 				: STD_LOGIC_VECTOR( 2 downto 0 );
signal c1 				: STD_LOGIC_VECTOR( 2 downto 0 );
signal c0_c1_en         : STD_LOGIC;

signal ozs_en          	: STD_LOGIC;
signal zero_en          : STD_LOGIC;
signal hash_pad         : STD_LOGIC;

signal p256_s           : STD_LOGIC;
signal bdo_sel 			: STD_LOGIC;

signal temp_en         	: STD_LOGIC;
signal temp_rst        : STD_LOGIC;
signal temp_sel         : STD_LOGIC;

signal key_sel          : STD_LOGIC;
signal key_en           : STD_LOGIC;

signal ozs_input_sel 	: STD_LOGIC;

signal p256_sel        	: STD_LOGIC;

signal round 			: STD_LOGIC_VECTOR( 3 downto 0 );
signal rho_vb           : STD_LOGIC_VECTOR( 3 downto 0 );
signal msg_en           : STD_LOGIC;
signal rho_reg_en       : STD_LOGIC;
signal bdo_sig          : STD_LOGIC_VECTOR (PDI_SHARES * CCW - 1 downto 0);

begin
bdo <= bdo_sig;

datapath1: entity work.Datapath(Behavioral)
    Port map ( 
			clk => clk,
			bdi => bdi,
			key_in => key,
			decrypt_in => decrypt_in,
			
			bdi_valid_bytes => bdi_valid_bytes,
			bdi_pad_loc => bdi_pad_loc,		

			iv_we => iv_we,
			
			iv1_en => iv1_en,
			iv1_rst => iv1_rst,
			
            iv_sel => iv_sel,
            iv_input_sel => iv_input_sel,
            iv_xor_sel => iv_xor_sel,
            c1_sel => c1_sel,

			c0 => c0,
			c1 => c1,
			c0_c1_en => c0_c1_en,
			
            ozs_en => ozs_en,
            zero_en => zero_en,
            hash_pad => hash_pad,

			bdo_sel => bdo_sel,
		    
		    temp_en => temp_en,
		    temp_rst => temp_rst,
		    temp_sel => temp_sel,
		    rho_reg_en => rho_reg_en,
		    
			key_sel => key_sel,
			key_en => key_en,
			
			ozs_input_sel => ozs_input_sel,

            p256_s => p256_s,
			p256_sel => p256_sel,
			rho_vb => rho_vb,
			msg_en => msg_en,
		    
			round => round,
			
			-- Output --
			bdo => bdo_sig,
			fresh => rdi
			);

controller1: entity work.Controller(Behavioral)
    port map (
            clk => clk,
	        rst => rst,

	        key_valid => key_valid,
	        key_update => key_update,
	        
	        bdi       => bdi,
	        bdi_valid => bdi_valid,
	        bdi_pad_loc => bdi_pad_loc,
	        bdi_valid_bytes => bdi_valid_bytes,
	        bdi_size => bdi_size,
	        bdi_eot => bdi_eot,
	        bdi_eoi => bdi_eoi,
	        bdi_type => bdi_type,
	        decrypt_in => decrypt_in,
	        hash_in => hash_in,
	
	        bdo_ready => bdo_ready,
	        msg_auth_ready => msg_auth_ready,
		
	        -- CryptoCore Outputs --
	
	        key_ready => key_ready,
	        bdi_ready => bdi_ready,
	        bdo       => bdo_sig,			
	        bdo_valid => bdo_valid,
	        bdo_valid_bytes => bdo_valid_bytes,
	
	        -- IV / IV_addr --
	
	        iv_we => iv_we,
			iv1_en => iv1_en,
			iv1_rst => iv1_rst,
			
	        -- Select Signals -- 
	
            iv_sel => iv_sel,
            iv_input_sel => iv_input_sel,
	        iv_xor_sel => iv_xor_sel,
            c1_sel => c1_sel,
	
	        ozs_en => ozs_en,
	        ozs_input_sel => ozs_input_sel,
	        zero_en => zero_en,
            hash_pad => hash_pad,
	
            temp_en => temp_en,
            temp_rst => temp_rst,
		    rho_reg_en => rho_reg_en,
	        key_sel => key_sel,
	        key_en => key_en,
	
	        p256_s => p256_s,
	        p256_sel => p256_sel,
	        bdo_sel => bdo_sel,
	        temp_sel => temp_sel,
	        rho_vb => rho_vb,
	        msg_en => msg_en,
	
	        -- Register Signals --
	        c0 => c0,
	        c1 => c1,
			c0_c1_en => c0_c1_en,
	
	        bdo_type => bdo_type,
	
	        -- Submodule Controller Outputs --
	
	        round => round,

	        msg_auth => msg_auth,
	        msg_auth_valid => msg_auth_valid,
	        end_of_block => end_of_block,
	        rdi_valid => rdi_valid,
	        rdi_ready => rdi_ready
	        );
end behavioral;