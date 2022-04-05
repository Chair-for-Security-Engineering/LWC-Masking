library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity Photon_256 is
    Port (  w0  : in  STD_LOGIC_VECTOR(127 downto 0);
            w1  : in  STD_LOGIC_VECTOR(127 downto 0);
            temp : in STD_LOGIC_VECTOR(127 downto 0);
    
            k   : in STD_LOGIC_VECTOR(3 downto 0); -- Round/iteration
            p256_sel : in STD_LOGIC; -- Indicates cycle # of iteration
            
            y0  : out STD_LOGIC_VECTOR(127 downto 0); -- Output
            y1 : out STD_LOGIC_VECTOR(127 downto 0);
            temp_next : out STD_LOGIC_VECTOR(127 downto 0)); -- temp for bottom half

end Photon_256;

architecture STRUCTURE of Photon_256 is

signal addc_in : STD_LOGIC_VECTOR(127 downto 0);
signal subc_out : STD_LOGIC_VECTOR(127 downto 0);
signal shiftr_out : STD_LOGIC_VECTOR(127 downto 0);
signal mcs_out : STD_LOGIC_VECTOR(255 downto 0);
signal mcs_sig : STD_LOGIC_VECTOR(127 downto 0);
signal ic_in : STD_LOGIC_VECTOR (11 downto 0);

begin
    
    addc_in <= w0 when p256_sel = '0' else w1;
    ic_in(2 downto 0) <= p256_sel & std_logic_vector(to_unsigned(0, 2));
    ic_in(5 downto 3) <= p256_sel & std_logic_vector(to_unsigned(1, 2));
    ic_in(8 downto 6) <= p256_sel & std_logic_vector(to_unsigned(2, 2));
    ic_in(11 downto 9) <= p256_sel & std_logic_vector(to_unsigned(3, 2));
    
    -- add_sub/shiftr = straightforward transformation
    gen_add_sub: for ii in 0 to 3 generate 

		add_sub1: entity work.Add_and_Sub(addc_subc)
			port map (
                rc_in => k,
                ic_in => ic_in(3*ii+2 downto 3*ii),
                addc_in => addc_in(32*(3-ii)+31 downto 32*(3-ii)),
                subc_out => subc_out(32*(3-ii)+31 downto 32*(3-ii)));
    end generate gen_add_sub;
	
    gen_shiftr: for ii in 0 to 3 generate 
		shiftr1: entity work.Shift_Row(shiftr)
		    generic map ( i => ii )
			port map (
                w => subc_out(32*(3-ii)+31 downto 32*(3-ii)),
                p256_sel => p256_sel,
                y => shiftr_out(32*(3-ii)+31 downto 32*(3-ii)));
    end generate gen_shiftr;
        
    mcs1: entity work.mcs(Behavioral)
        Port map ( w0 => shiftr_out,
                   p256_sel => p256_sel,
                   y0 => mcs_out
        );
           
    -- Output
    y0 <= w0 XOR mcs_out(255 downto 128) when p256_sel = '1' else 
          mcs_out(255 downto 128);
    y1 <= mcs_out(127 downto 0) xor temp;
    -- Stores other half of matrix multiplication        
    temp_next <= mcs_out(127 downto 0);
   
end STRUCTURE;
