----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 12/16/2019 11:55:17 AM
-- Design Name: 
-- Module Name: Datapath - Behavioral
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
use work.NIST_LWAPI_pkg.all;
use work.design_pkg.all;

entity Datapath is
    port (  clk 			: in STD_LOGIC;
			
			bdi 			: in STD_LOGIC_VECTOR(PDI_SHARES * CCW - 1 downto 0 );
			key_in 			: in STD_LOGIC_VECTOR(SDI_SHARES * CCSW - 1 downto 0 );
			decrypt_in 		: in STD_LOGIC;
			
			bdi_valid_bytes : in STD_LOGIC_VECTOR( 3 downto 0 );
			bdi_pad_loc     : in STD_LOGIC_VECTOR( 3 downto 0 );
			
			-- Internal inputs and signals --
            
			iv_we 			: in STD_LOGIC;		
			
            iv_sel          : in STD_LOGIC_VECTOR( 1 downto 0);
            iv_input_sel    : in STD_LOGIC_VECTOR( 1 downto 0);
            iv_xor_sel      : in STD_LOGIC;
            
            iv1_en      : in STD_LOGIC;
            iv1_rst     : in STD_LOGIC;

			c0 				: in STD_LOGIC_VECTOR( 2 downto 0 );
			c1 				: in STD_LOGIC_VECTOR( 2 downto 0 );
			c1_sel          : in STD_LOGIC;
			c0_c1_en        : in STD_LOGIC;
			
            ozs_en          : in STD_LOGIC;
            zero_en         : in STD_LOGIC;
            hash_pad        : in STD_LOGIC;

			bdo_sel 		: in STD_LOGIC;
		    
		    temp_en         : in STD_LOGIC;
		    temp_rst        : in STD_LOGIC;
		    temp_sel        : in STD_LOGIC;
		    rho_reg_en      : in STD_LOGIC;
		    
			key_sel         : in STD_LOGIC;
			key_en          : in STD_LOGIC;
			
			ozs_input_sel 	: in STD_LOGIC;
			
			p256_s          : in STD_LOGIC;
			p256_sel        : in STD_LOGIC;
		    
		    msg_en          : in STD_LOGIC;
			round 			: in STD_LOGIC_VECTOR( 3 downto 0 );
			
			rho_vb          : in STD_LOGIC_VECTOR( 3 downto 0 );
			
			-- Output --
			bdo             : out STD_LOGIC_VECTOR(PDI_SHARES * CCW - 1 downto 0);
          	fresh           : in STD_LOGIC_VECTOR(1119 downto 0)
          	);
end Datapath;

architecture Behavioral of Datapath is

--signal key_next : STD_LOGIC_VECTOR(127 downto 0);
signal key : STD_LOGIC_VECTOR(SDI_SHARES * 128 - 1 downto 0);
signal iv_next : STD_LOGIC_VECTOR(PDI_SHARES * 128 - 1 downto 0);
signal iv : STD_LOGIC_VECTOR(PDI_SHARES * 128 - 1 downto 0);
signal iv1 : STD_LOGIC_VECTOR(PDI_SHARES * 128 - 1 downto 0);
signal p256_iv1_s0 : STD_LOGIC_VECTOR(127 downto 0);
signal p256_iv1_s1 : STD_LOGIC_VECTOR(127 downto 0);

signal iv1_next : STD_LOGIC_VECTOR(PDI_SHARES * 128 - 1 downto 0);

signal iv_32 : STD_LOGIC_VECTOR(PDI_SHARES * CCW - 1 downto 0);
signal temp_32 : STD_LOGIC_VECTOR(PDI_SHARES * CCW - 1 downto 0);

signal iv_en : STD_LOGIC_VECTOR(3 downto 0);

signal p256_s0 : STD_LOGIC_VECTOR(127 downto 0);
signal p256_s1 : STD_LOGIC_VECTOR(127 downto 0);

--signal p256_out : STD_LOGIC_VECTOR(127 downto 0);

signal temp_next : STD_LOGIC_VECTOR(PDI_SHARES * 128 - 1 downto 0);
signal temp : STD_LOGIC_VECTOR(PDI_SHARES * 128 - 1 downto 0);

signal temp_s0 : STD_LOGIC_VECTOR(127 downto 0);
signal temp_s1 : STD_LOGIC_VECTOR(127 downto 0);

signal temp_s_s0 : STD_LOGIC_VECTOR(127 downto 0);
signal temp_s_s1 : STD_LOGIC_VECTOR(127 downto 0);

signal ozs_out : STD_LOGIC_VECTOR(PDI_SHARES * CCW - 1 downto 0);
signal rho_bdo : STD_LOGIC_VECTOR(PDI_SHARES * CCW - 1 downto 0);

signal vb_in   : STD_LOGIC_VECTOR(3 downto 0);

signal c0_c1 : STD_LOGIC_VECTOR(2 downto 0);
signal c01_128 : STD_LOGIC_VECTOR(SDI_SHARES * 128 - 1 downto 0);
signal iv1_mux : STD_LOGIC_VECTOR(SDI_SHARES * 128 - 1 downto 0);
signal bdo_128 : STD_LOGIC_VECTOR(PDI_SHARES * 128 - 1 downto 0);
--signal temp_mux : STD_LOGIC_VECTOR(127 downto 0);
signal temp_mux_sel : STD_LOGIC_VECTOR(1 downto 0);

signal rho_reg : STD_LOGIC_VECTOR(PDI_SHARES * 128 - 1 downto 0);
signal rho_reg_next : STD_LOGIC_VECTOR(PDI_SHARES * 128 - 1 downto 0);
signal sel_bytes : STD_LOGIC_VECTOR(3 downto 0);
signal key_reg_en : STD_LOGIC_VECTOR(3 downto 0);
signal pad_loc : STD_LOGIC_VECTOR(3 downto 0);
signal iv_rst : STD_LOGIC;

signal ozs_xor : STD_LOGIC_VECTOR(PDI_SHARES * CCW - 1 downto 0);
signal ozs_iv : STD_LOGIC_VECTOR(PDI_SHARES * 128 - 1 downto 0);

signal iv_s0 : STD_LOGIC_VECTOR(128 - 1 downto 0);
signal iv_s1 : STD_LOGIC_VECTOR(128 - 1 downto 0);
signal iv1_s0 : STD_LOGIC_VECTOR(128 - 1 downto 0);
signal iv1_s1 : STD_LOGIC_VECTOR(128 - 1 downto 0);

signal temp_s_u : STD_LOGIC_VECTOR(128 - 1 downto 0);
signal p256_u : STD_LOGIC_VECTOR(128-1 downto 0);
signal p256_iv1_u : STD_LOGIC_VECTOR(128-1 downto 0);

function rev_by_4bits(x : STD_LOGIC_VECTOR) return STD_LOGIC_VECTOR is
        variable y : STD_LOGIC_VECTOR(x'length - 1 downto 0);
        
    begin
        for ii in x'length/8 - 1 downto 0 loop
            y(8*ii+7 downto 8*ii+4) := x(8*ii+3 downto 8*ii);
            y(8*ii+3 downto 8*ii) := x(8*ii+7 downto 8*ii+4);
        end loop;

        return y;
end function rev_by_4bits;


component Photon_256_HPC2_ClockGating_d1 is
    Port ( clk : in STD_LOGIC;
           w0_s0 : in STD_LOGIC_VECTOR(127 downto 0);
           w0_s1 : in STD_LOGIC_VECTOR(127 downto 0); 
           w1_s0 : in STD_LOGIC_VECTOR(127 downto 0);
           w1_s1 : in STD_LOGIC_VECTOR(127 downto 0);
           temp_s0 : in STD_LOGIC_VECTOR(127 downto 0);
           temp_s1 : in STD_LOGIC_VECTOR(127 downto 0);
           Fresh : in STD_LOGIC_VECTOR(1119 downto 0);
           k   : in STD_LOGIC_VECTOR(3 downto 0); -- Round/iteration
           p256_sel : in STD_LOGIC; -- Indicates cycle # of iteration
           y0_s0 : out STD_LOGIC_VECTOR(127 downto 0);
           y0_s1 : out STD_LOGIC_VECTOR(127 downto 0); 
           y1_s0 : out STD_LOGIC_VECTOR(127 downto 0);
           y1_s1 : out STD_LOGIC_VECTOR(127 downto 0);   
           temp_next_s0 : out STD_LOGIC_VECTOR(127 downto 0);   
           temp_next_s1 : out STD_LOGIC_VECTOR(127 downto 0)   
);
end component;

begin	

-- Dictates which input is written to the state ram --
ozs_xor <= ozs_out XOR iv_32 when iv_xor_sel = '1' else ozs_out;

gen_ozs_128 : for ii in 0 to 3 generate
	ozs_iv(0*128+127 - 32*ii downto 0*128+96 - 32*ii) <= ozs_xor(1*CCW-1 downto 0*CCW);
	ozs_iv(1*128+127 - 32*ii downto 1*128+96 - 32*ii) <= ozs_xor(2*CCW-1 downto 1*CCW);
end generate gen_ozs_128;

with iv_sel(1) select iv_next(1*128-1 downto 0*128) <=
	rev_by_4bits(p256_s0)    when '0',
    ozs_iv(1*128-1 downto 0*128) when others;

with iv_sel(1) select iv_next(2*128-1 downto 1*128) <=
	rev_by_4bits(p256_s1)    when '0',
    ozs_iv(2*128-1 downto 1*128) when others;
		
with iv_input_sel select sel_bytes <=
    "0001" when "00",
    "0010" when "01",
    "0100" when "10",
    "1000" when others;
    
key_reg_en <= sel_bytes AND (key_en & key_en & key_en & key_en);
    
-- add_sub/shiftr = straightforward transformation
gen_key_reg: for ii in 0 to 3 generate 
    key_reg0: entity work.reg2(Behavioral)
        generic map (w => CCW)
        port map (  clk => clk,
                    rst => '0',
                    en => key_reg_en(ii),
                    D => key_in(1*CCW-1 downto 0*CCW),
                    Q => key(1*128-1 - 32*ii downto 0*128+96 - 32*ii));
    
    key_reg1: entity work.reg2(Behavioral)
        generic map (w => CCW)
        port map (  clk => clk,
                    rst => '0',
                    en => key_reg_en(ii),
                    D => key_in(2*CCW-1 downto 1*CCW),
                    Q => key(2*128-1 - 32*ii downto 1*128+96 - 32*ii));                    
end generate gen_key_reg;

iv_en <= (sel_bytes AND (iv_we & iv_we & iv_we & iv_we)) OR (p256_s & p256_s & p256_s & p256_s);

-- pad location used to actually pad ozs
gen_iv_reg: for ii in 0 to 3 generate 
    iv_reg0: entity work.reg2(Behavioral)
        generic map (w => 32)
        port map (  clk => clk,
                    rst => iv_sel(0),
                    en => iv_en(ii),
                    D => iv_next(1*128-1-32*ii downto 0*128+96-32*ii),
                    Q => iv(1*128-1-32*ii downto 0*128+96-32*ii));
    
    iv_reg1: entity work.reg2(Behavioral)
        generic map (w => 32)
        port map (  clk => clk,
                    rst => iv_sel(0),
                    en => iv_en(ii),
                    D => iv_next(2*128-1-32*ii downto 1*128+96-32*ii),
                    Q => iv(2*128-1-32*ii downto 1*128+96-32*ii));                
end generate gen_iv_reg;

c0_c1 <= c1 when c1_sel = '1' else c0;

c01_128(1*128-1 downto 0*128) <= iv1(1*128-1 downto 0*128+8) & (c0_c1 xor iv1(0*128+7 downto 0*128+5)) & iv1(0*128+4 downto 0*128);
c01_128(2*128-1 downto 1*128) <= iv1(2*128-1 downto 1*128+8) & ("000" xor iv1(1*128+7 downto 1*128+5)) & iv1(1*128+4 downto 1*128);

iv1_mux(1*128-1 downto 0*128) <= c01_128(1*128-1 downto 0*128) when c0_c1_en = '1' else rev_by_4bits(p256_iv1_s0);
iv1_mux(2*128-1 downto 1*128) <= c01_128(2*128-1 downto 1*128) when c0_c1_en = '1' else rev_by_4bits(p256_iv1_s1);

iv1_next <= iv1_mux when key_sel = '0' else key;

iv_reg1: entity work.reg2(Behavioral)
    generic map (w => PDI_SHARES * 128)
    port map (  clk => clk,
                rst => iv1_rst,
                en => iv1_en,
                D => iv1_next,
                Q => iv1 );

iv_s0 <= iv(1*128-1 downto 0*128);
iv_s1 <= iv(2*128-1 downto 1*128);
iv1_s0 <= iv1(1*128-1 downto 0*128);
iv1_s1 <= iv1(2*128-1 downto 1*128);
temp_s0 <= temp(1*128-1 downto 0*128);
temp_s1 <= temp(2*128-1 downto 1*128);

-- Actual permutation
photon_256a: Photon_256_HPC2_ClockGating_d1
    Port map (
        clk => clk,
		w0_s0 => rev_by_4bits(iv_s0),
		w0_s1 => rev_by_4bits(iv_s1),
        w1_s0 => rev_by_4bits(iv1_s0),
        w1_s1 => rev_by_4bits(iv1_s1),	
		temp_s0 => rev_by_4bits(temp_s0),
		temp_s1 => rev_by_4bits(temp_s1),
		Fresh => fresh,
		k   => round,
    	p256_sel => p256_sel,	
		y0_s0 => p256_s0,
		y0_s1 => p256_s1,
		y1_s0 => p256_iv1_s0,
		y1_s1 => p256_iv1_s1,
		temp_next_s0 => temp_s_s0,
		temp_next_s1 => temp_s_s1
    );

temp_mux_sel <= temp_sel & msg_en;

with temp_mux_sel select temp_next(1*128-1 downto 0*128) <=
    iv(1*128-1 downto 0*128) when "00",
    bdo_128(1*128-1 downto 0*128) when "01",
    rev_by_4bits(temp_s_s0) when others;

with temp_mux_sel select temp_next(2*128-1 downto 1*128) <=
    iv(2*128-1 downto 1*128) when "00",
    bdo_128(2*128-1 downto 1*128) when "01",
    rev_by_4bits(temp_s_s1) when others;

-- Register to store photon-256 intermediate multiplication value
temp1: entity work.reg2(Behavioral)
	generic map(w => PDI_SHARES * 128)
		Port map (	clk => clk,
		            rst => temp_rst,
					en => temp_en,
					D => temp_next,
					Q => temp);		
-- Padding
ozs0: entity work.Ozs(Behavioral)
    port map ( w0 => bdi(1*CCW-1 downto 0*CCW),
               w1 => rho_bdo(1*CCW-1 downto 0*CCW),
               pad_loc => bdi_pad_loc,
			   ozs_sel => ozs_input_sel,
               ozs_en => ozs_en,
               zero_en => zero_en,
               hash_pad => hash_pad,
               ozs_out => ozs_out(1*CCW-1 downto 0*CCW)
     );

ozs1: entity work.Ozs2(Behavioral)
    port map ( w0 => bdi(2*CCW-1 downto 1*CCW),
               w1 => rho_bdo(2*CCW-1 downto 1*CCW),
               pad_loc => bdi_pad_loc,
			   ozs_sel => ozs_input_sel,
               ozs_en => ozs_en,
               zero_en => zero_en,
               ozs_out => ozs_out(2*CCW-1 downto 1*CCW)
     );

rho_reg_next(1*128-1 downto 0*128) <= iv(0*128+63 downto 0*128) & iv(0*128+112) & iv(1*128-1 downto 0*128+121) & iv(0*128+104)
& iv(0*128+119 downto 0*128+113) & iv(0*128+96) & iv(0*128+111 downto 0*128+105) & iv(0*128+88) 
& iv(0*128+103 downto 0*128+97) & iv(0*128+80) & iv(0*128+95 downto 0*128+89) & iv(0*128+72) 
& iv(0*128+87 downto 0*128+81) & iv(0*128+64) & iv(0*128+79 downto 0*128+73) & iv(0*128+120) & iv(0*128+71 downto 0*128+65);

rho_reg_next(2*128-1 downto 1*128) <= iv(1*128+63 downto 1*128) & iv(1*128+112) & iv(2*128-1 downto 1*128+121) & iv(1*128+104)
& iv(1*128+119 downto 1*128+113) & iv(1*128+96) & iv(1*128+111 downto 1*128+105) & iv(1*128+88) 
& iv(1*128+103 downto 1*128+97) & iv(1*128+80) & iv(1*128+95 downto 1*128+89) & iv(1*128+72) 
& iv(1*128+87 downto 1*128+81) & iv(1*128+64) & iv(1*128+79 downto 1*128+73) & iv(1*128+120) & iv(1*128+71 downto 1*128+65);

--What it is in the software implementation.
rho_reg1: entity work.reg2(Behavioral)
	generic map(w => PDI_SHARES * 128)
		Port map (	clk => clk,
		            rst => '0',
					en => rho_reg_en,
					D => rho_reg_next,
					Q => rho_reg);		

-- Encryption/decryption operation
rho1: entity work.Rho(Behavioral)
    port map ( rho_in => temp(1*128-1 downto 0*128),
               shuffle => rho_reg(1*128-1 downto 0*128),
               bdi => bdi(1*CCW-1 downto 0*CCW),
               iv_input_sel => iv_input_sel,
               rho_valid => rho_vb,
               bdo => rho_bdo(1*CCW-1 downto 0*CCW),
               bdo_128 => bdo_128(1*128-1 downto 0*128));

rho2: entity work.Rho(Behavioral)
    port map ( rho_in => temp(2*128-1 downto 1*128),
               shuffle => rho_reg(2*128-1 downto 1*128),
               bdi => bdi(2*CCW-1 downto 1*CCW),
               iv_input_sel => iv_input_sel,
               rho_valid => rho_vb,
               bdo => rho_bdo(2*CCW-1 downto 1*CCW),
               bdo_128 => bdo_128(2*128-1 downto 1*128));
 
-- bdo is a 32-bit output
with iv_input_sel select iv_32(1*CCW-1 downto 0*CCW) <=
    iv(0*128+95 downto 0*128+64) when "01",
    iv(0*128+63 downto 0*128+32) when "10",
    iv(0*128+31 downto 0*128+0) when "11",
    iv(0*128+127 downto 0*128+96) when others;

with iv_input_sel select iv_32(2*CCW-1 downto 1*CCW) <=
    iv(1*128+95 downto 1*128+64) when "01",
    iv(1*128+63 downto 1*128+32) when "10",
    iv(1*128+31 downto 1*128+0) when "11",
    iv(1*128+127 downto 1*128+96) when others;

with iv_input_sel select temp_32(1*CCW-1 downto 0*CCW) <=
    temp(0*128+95 downto 0*128+64) when "01",
    temp(0*128+63 downto 0*128+32) when "10",
    temp(0*128+31 downto 0*128+0) when "11",
    temp(0*128+127 downto 0*128+96) when others;

with iv_input_sel select temp_32(2*CCW-1 downto 1*CCW) <=
    temp(1*128+95 downto 1*128+64) when "01",
    temp(1*128+63 downto 1*128+32) when "10",
    temp(1*128+31 downto 1*128+0) when "11",
    temp(1*128+127 downto 1*128+96) when others;
    
bdo <= temp_32; 
					
end Behavioral;
