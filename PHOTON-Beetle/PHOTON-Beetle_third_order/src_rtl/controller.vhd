library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.NIST_LWAPI_pkg.all;
use work.design_pkg.all;

entity Controller is
    Port ( 	clk             : in   STD_LOGIC;
	        rst             : in   STD_LOGIC;

	        key_valid       : in   STD_LOGIC;
	        key_update      : in   STD_LOGIC;
			bdi 			: in STD_LOGIC_VECTOR(PDI_SHARES * CCW - 1 downto 0 );	
	        bdi_valid       : in   STD_LOGIC;
	        bdi_pad_loc     : in   STD_LOGIC_VECTOR( 3 downto 0 );
	        bdi_valid_bytes : in   STD_LOGIC_VECTOR( 3 downto 0 );
	        bdi_size        : in   STD_LOGIC_VECTOR( 2 downto 0 );
	        bdi_eot         : in   STD_LOGIC;
	        bdi_eoi         : in   STD_LOGIC;
	        bdi_type        : in   STD_LOGIC_VECTOR( 3 downto 0 );
	        decrypt_in      : in   STD_LOGIC;
	        hash_in         : in   STD_LOGIC;
	
	        bdo_ready       : in   STD_LOGIC;
	        msg_auth_ready  : in   STD_LOGIC;
		
	        -- CryptoCore Outputs --
	
	        key_ready       : out  STD_LOGIC;
	        bdi_ready       : out  STD_LOGIC;			
	        bdo 			: in   STD_LOGIC_VECTOR(PDI_SHARES * CCW - 1 downto 0 );	
	        bdo_valid       : out  STD_LOGIC;
	        bdo_valid_bytes : out  STD_LOGIC_VECTOR( 3 downto 0 );
	
	        -- IV / IV_addr --
	
	        iv_we           : out STD_LOGIC;
	        iv1_en          : out STD_LOGIC;
	        iv1_rst         : out STD_LOGIC;

	        -- Select Signals -- 
	
            iv_sel          : out STD_LOGIC_VECTOR( 1 downto 0 );
            iv_input_sel    : out STD_LOGIC_VECTOR( 1 downto 0 );
	        iv_xor_sel		: out STD_LOGIC;
	        c1_sel          : out STD_LOGIC;
	        c0_c1_en        : out STD_LOGIC;
	
	        ozs_en          : out STD_LOGIC;
	        ozs_input_sel   : out STD_LOGIC;
	        zero_en         : out STD_LOGIC;
	        hash_pad        : out STD_LOGIC;
	
            temp_en         : out STD_LOGIC;
            temp_rst        : out STD_LOGIC;
	        key_sel         : out STD_LOGIC;
	        key_en          : out STD_LOGIC;
	        rho_vb          : out STD_LOGIC_VECTOR( 3 downto 0 );
	        msg_en          : out STD_LOGIC;
	
	        p256_s          : out STD_LOGIC;
	        p256_sel        : out STD_LOGIC;
	        bdo_sel         : out STD_LOGIC;
	        temp_sel        : out STD_LOGIC;
	
	        -- Register Signals --
	        c0              : out STD_LOGIC_VECTOR( 2 downto 0 );
	        c1              : out STD_LOGIC_VECTOR( 2 downto 0 );
	
	        bdo_type        : out STD_LOGIC_VECTOR( 3 downto 0 );
	
	        -- Submodule Controller Outputs --
	
	        round           : out STD_LOGIC_VECTOR( 3 downto 0 );
		    rho_reg_en      : out STD_LOGIC;

	        msg_auth        : out STD_LOGIC;
	        msg_auth_valid  : out STD_LOGIC;
	        end_of_block    : out STD_LOGIC;
	        rdi_valid       : in  STD_LOGIC;
	        rdi_ready       : out STD_LOGIC
	        );
	
end Controller;

architecture Behavioral of Controller is

type t_state is 
(s_idle, s_store_k, s_store_r, s_load_k, s_load_n, s_p256_1, s_p256_2,
s_ad_init, s_ad, s_ad_xor, s_msg_init, s_msg, s_msg_xor, s_msg_bdo, s_tag_xor, s_tag, 
s_tag_bdo, s_tag_verify, s_auth, s_hash_zero_init,
s_hash1, s_hash2, s_hash_tag_xor);

signal state_reg, next_state : t_state;

-- Maintains which state to enter after completing p256
signal p256_state : STD_LOGIC_VECTOR( 1 downto 0 );
signal p256_state_next : STD_LOGIC_VECTOR( 1 downto 0 );
signal p256_state_en : STD_LOGIC;

signal iv_input_en : STD_LOGIC;
signal liv : STD_LOGIC;
signal iv_input_next : STD_LOGIC_VECTOR( 1 downto 0 );

signal c0_en : STD_LOGIC;
signal c0_in : STD_LOGIC_VECTOR( 2 downto 0 );
            
signal c1_en : STD_LOGIC;
signal c1_in : STD_LOGIC_VECTOR( 2 downto 0 );

signal round_en : STD_LOGIC;
signal round_next : STD_LOGIC_VECTOR( 3 downto 0 );
signal ldr : STD_LOGIC;

signal flag : STD_LOGIC_VECTOR( 1 downto 0 );
signal flag_en : STD_LOGIC;
signal flag_next : STD_LOGIC_VECTOR(1 downto 0);

signal ad_flag : STD_LOGIC;
signal ad_flag_en: STD_LOGIC;
signal ad_flag_next : STD_LOGIC;

signal bdo_type_en : STD_LOGIC;
signal bdo_type_next : STD_LOGIC_VECTOR( 3 downto 0 );

signal msg_auth_en : STD_LOGIC;
signal msg_auth_next : STD_LOGIC;

signal bdo_vb_en : STD_LOGIC;
signal bdo_vb_next : STD_LOGIC_VECTOR( 3 downto 0 );

signal p256_state_s : STD_LOGIC_VECTOR( 1 downto 0 );
signal c0_s : STD_LOGIC_VECTOR( 2 downto 0 );
signal c1_s : STD_LOGIC_VECTOR( 2 downto 0 );
signal bdo_type_s: STD_LOGIC_VECTOR( 3 downto 0 );
signal end_of_block_s: STD_LOGIC;
signal msg_auth_valid_s: STD_LOGIC;
signal msg_auth_s: STD_LOGIC;
signal eot_input : STD_LOGIC_VECTOR(1 downto 0);
signal eot_input_en : STD_LOGIC;
signal bdo_vb_s : STD_LOGIC_VECTOR(3 downto 0);

signal counter_reset, counter_enable : std_logic;
signal counter                       : std_logic_vector(7 downto 0);

signal bdi_reg, bdo_reg : STD_LOGIC_VECTOR(PDI_SHARES * CCW - 1 downto 0 );	
signal bdi_reg_unshared, bdo_reg_unshared : STD_LOGIC_VECTOR(CCW - 1 downto 0 );	

begin
    bdi_reg_unshared <= (others => '0'); --bdi_reg(1*CCW-1 downto 0*CCW) xor bdi_reg(2*CCW-1 downto 1*CCW) xor bdi_reg(3*CCW-1 downto 2*CCW) xor bdi_reg(4*CCW-1 downto 3*CCW);
    bdo_reg_unshared <= (others => '0'); --bdo_reg(1*CCW-1 downto 0*CCW) xor bdo_reg(2*CCW-1 downto 1*CCW) xor bdo_reg(3*CCW-1 downto 2*CCW) xor bdo_reg(4*CCW-1 downto 3*CCW);

    process(clk, rst)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state_reg <= s_idle;
            else
                state_reg <= next_state;
            end if;
        end if;
    end process;

    round_ctr : entity work.ctr(Behavioral)
        generic map (w => 4)
        port map (
                clk => clk,
                en => round_en,
                ld_en => ldr,
                LD => round_next,
                Q => round);

    iv_input_ctr : entity work.ctr(Behavioral)
        generic map (w => 2)
        port map (
                clk => clk,
                en => iv_input_en,
                ld_en => liv,
                LD => iv_input_next,
                Q => iv_input_sel);
               
    -- Controller Registers -- 
    process(all)
    begin
      
    if rising_edge(clk) then

        -- Tracks state prior to entering p256 --
        -- 0: Hash
        -- 1: Msg
        -- 2: Tag-128
        -- 3: Tag-256 (Goes to 128 after first iteration)
        if p256_state_en = '1' then
            p256_state <= p256_state_next;
        end if;
        
        if (counter_reset = '1') then
            counter <= x"00";
        else
            if (counter_enable = '1') then
                counter <= counter + 1;
            end if;
        end if;    
        
        
        -- XOR value #1 --
        if c0_en = '1' then
            c0 <= c0_in;
        end if;
        
        -- XOR value #2 --
        if c1_en = '1' then
            c1 <= c1_in;
        end if;

        -- Signals controlling padding/truncation--
        if flag_en = '1' then
            flag <= flag_next;
        end if;
        
        -- If repeating AD, ad_flag = '1' --
        if ad_flag_en = '1' then
            ad_flag <= ad_flag_next;
        end if;

        -- Bdo Type (Msg/Tag)
        if bdo_type_en = '1' then
            bdo_type <= bdo_type_next;
        end if;
                    
        if msg_auth_en = '1' then
            msg_auth <= msg_auth_next;
        end if;
        
        -- 
        if bdo_vb_en = '1' then
            bdo_vb_s <= bdo_vb_next;
        end if;
        
        -- Used to c
        if eot_input_en = '1' then
            eot_input <= iv_input_sel;
        end if;
        
    end if;
    
    end process;

    process(all) --Input signals change state
    begin
        key_ready <= '0';
        bdi_ready <= '0';
        rdi_ready <= '1';			
        bdo_valid <= '0';
        
        iv_we <= '0';
        
        iv_sel <= "00";
        iv_xor_sel <= '0';
        c1_sel <= '0';
        c0_c1_en <= '0';
        
        ozs_en <= '0';
        ozs_input_sel <= '0';
        zero_en <= '0';
        hash_pad <= '0';
        
        temp_en <= '0';
        temp_rst <= '0';
        key_sel <= '0';
        key_en <= '0';
        
        p256_s <= '0';
        p256_sel <= '0';
        bdo_sel <= '0';
        
        bdo_type_en <= '0';
        bdo_type_next <= "0000";
        
        bdo_vb_en <= '0';
        bdo_vb_next <= "0000";
            
        p256_state_next <= "00";
        p256_state_en <= '0';
        
        iv_input_en <= '0';
        liv <= '0';
        iv_input_next <= "00";
        
        iv1_en <= '0';
        iv1_rst <= '0';
        
        c0_en <= '0';
        c0_in <= "000";
                
        c1_en <= '0';
        c1_in <= "000";
        
        rho_reg_en <= '0';
        
        round_en <= '0';
        ldr <= '0';
        round_next <= "0000";
        
        flag_en <= '0';
        flag_next <= "00";
        
        ad_flag_en <= '0';
        ad_flag_next <= '0';
        
        rho_vb <= bdi_valid_bytes;
        
        end_of_block <= '0';
        
        msg_auth_en <= '0';
        msg_auth_next <= '0';
        
        temp_sel <= '0';
        
        msg_en <= '0';
        eot_input_en <= '0';
        
        bdo_valid_bytes <= "1111";
        msg_auth_valid <= '0';
        
        counter_enable <= '0';
        counter_reset <= '0';
        bdi_reg <= (others => '0');
        bdo_reg <= (others => '0');
        next_state <= state_reg;
        
        case state_reg is
            -- Reset counters and other objects
            when s_idle => 	
              
                bdo_type_en <= '1';
                bdo_type_next <= "0000";
                
                bdo_vb_en <= '1';
                bdo_vb_next <= "0000";
                
                round_en <= '1';
                ldr <= '1';
                round_next <= "0000";
        
                iv_input_en <= '1';
                liv <= '1';
                iv_input_next <= "00";
                
                temp_rst <= '1';
                counter_reset <= '1';
    
                p256_state_next <= "10";
                p256_state_en <= '1';
            
                msg_auth_en <= '1';
                msg_auth_next <= '1';
                
                flag_en <= '1';
                flag_next <= "00";
                
                ad_flag_en <= '1';
                ad_flag_next <= '0';
                
                end_of_block <= '0';
                eot_input_en <= '1';
                
                temp_en <= '1';
                temp_rst <= '1';
                -- Default values for c0 and c1
                c0_en <= '1';
                c0_in <= "100";
                
                c1_en <= '1';
                c1_in <= "110";
                next_state <= s_store_r;
            
            when s_store_r =>   
                if(rdi_valid = '1') then                         
                    if hash_in = '1' then
                        -- Starts by initializing state as all zeroes
                        next_state <= s_hash_zero_init;
                    elsif key_update = '1' and key_valid = '1' then
                        next_state <= s_store_k; -- Load key to addr1 before continuing                
                    elsif bdi_valid = '1' then
                        next_state <= s_load_k;     
                    else
                        bdi_ready <= '1';
                        next_state <= s_idle;
                    end if;
                end if;
            when s_store_k => --4 cycles
                key_ready <= '1';
                
                if key_valid = '1' then
                    key_en <= '1';
                    iv_input_en <= '1';
        
                    if iv_input_sel = "11" then --4th key already loaded
                        next_state <= s_load_k;
        
                    else
                        next_state <= s_store_k;
                    end if;
                else
                    next_state <= s_store_k;
                end if;
           
            when s_load_k => --1 cycle
                key_sel <= '1'; -- Writes key to iv1
                iv1_en <= '1';
                
                next_state <= s_load_n;
                
            when s_load_n =>
                iv_sel <= "10"; --ozs (inactive)
                
                if bdi_valid = '1' then
                    if iv_input_sel = "11" then --4th npub already loaded
                        iv_we <= '1';
                        
                        temp_en <= '1'; -- For p256 initialization
                        temp_rst <= '1';
                        
                        -- Go straight to tag
                        if bdi_eoi = '1' then
                            c1_en <= '1';
                            c1_in <= "001"; -- Auto XOR with c1 = 1
                            
                            next_state <= s_tag_xor;
                            
                        else
                            p256_state_en <= '1';
                            p256_state_next <= "00";
                            
                            next_state <= s_p256_1;
                        end if;
                        
                    else
                        bdi_ready <= '1';
                        
                        iv_we <= '1'; --Write npub to iv, then increment iv input addr
                        iv_input_en <= '1';
                        
                        next_state <= s_load_n;
                    end if;
                else
                    bdi_ready <= '1';
                    
                    next_state <= s_load_n;
                end if;
            
           when s_p256_1 =>
               if(rdi_valid = '1') then          
                   counter_enable <= '1';
                   iv_sel <= "00"; -- for p256
                   temp_sel <= '1';
                                
                   if (counter >= 6) then
                       counter_reset <= '1';
                       temp_en <= '1';
                       iv_we <= '1';
                       p256_s <= '1';
                       next_state <= s_p256_2;
                   end if;       
               end if;
           when s_p256_2 =>
               if(rdi_valid = '1') then  
                   counter_enable <= '1';
                   p256_sel <= '1';
                   temp_sel <= '1';
                
                   iv_sel <= "00"; -- for p256
                          
                   if (counter >= 6) then
                       counter_reset <= '1';
                       round_en <= '1';
                       p256_s <= '1';
                       iv_we <= '1';
                       iv1_en <= '1';

                
                       if round = "1011" then -- When round 12 is reached, exit
                           round_en <= '1';
                           ldr <= '1';
                           round_next <= "0000";
                
                           iv_input_en <= '1'; -- to reset iv_input_sel back to zero
                           liv <= '1';
                           iv_input_next <= "00";
                    
                           temp_en <= '1';
    
                           if p256_state <= "00" then
                               if hash_in = '1' then
                                   next_state <= s_hash2;
                            
                               elsif ad_flag = '0' then
                                   bdi_ready <= '1';
                            
                               next_state <= s_ad_init;
                            
                           else
                               next_state <= s_ad;
                           end if;                        
                       elsif p256_state <= "01" then
                           if ad_flag = '0' then
                               next_state <= s_msg_init;                          
                           else
                               bdi_ready <= '1';
                               next_state <= s_msg;
                           end if;
                           next_state <= s_msg_init;
                       else
                           next_state <= s_tag;  
                       end if;
                   else
                       next_state <= s_p256_1;
                   end if;
               end if;
           end if;    
           when s_ad_init =>
                if bdi_valid = '1' then
                    if bdi_type = HDR_AD then				
                        c1_en <= '1'; -- Set c1 to 2 (first condition met)
                        c1_in <= "010";
                            
                        ad_flag_en <= '1';
                        ad_flag_next <= '1';
                    
                        next_state <= s_ad;
                    else
                        next_state <= s_msg_init;
                    end if;
                else
                    bdi_ready <= '1';
                    next_state <= s_ad_init;
                end if;
           
           when s_ad =>
                iv_sel <= "10"; -- ozs
                    
                if bdi_valid = '1' then
                    iv_we <= '1'; -- Write to addr 0
                    iv_xor_sel <= '1'; --Tells iv to input ozs(bdi) XOR iv
                    
                    if bdi_eot = '1' then
                        ozs_en <= '1';
                        
                        if iv_input_sel = "11" then
                            iv_input_en <= '0'; -- Freeze at 3
                            flag_en <= '1';
                            flag_next <= "00";
                            
                            if flag(1) = '1' then
                                zero_en <= '1';
                                if flag(0) = '0' then
                                    hash_pad <= '1';
                                end if;
                            end if;
                            
                            if (bdi_pad_loc = "0000" and flag = "00") or bdi_eoi = '0' then -- |AD| % 128 == 0
                                c0_en <= '1'; 
                                
                                if bdi_eoi = '0' and (bdi_pad_loc = "0000" and flag = "00") then
                                    c0_in <= "001";
                                elsif bdi_eoi = '0' then
                                    c0_in <= "010";
                                else
                                    c0_in <= "011";
                                end if;
                            
                                next_state <= s_ad_xor; -- Needs extra cycle for iv XOR c0
                            else
                                next_state <= s_ad_xor; 
                            end if;
                        else
                            if flag = "00" then
                                flag_en <= '1';
                                if bdi_valid_bytes = "1111" then
                                    flag_next <= "10";
                                else
                                    flag_next <= "11";
                                end if;
                            elsif flag = "10" then -- Already padded
                                zero_en <= '1';
                                hash_pad <= '1';
                                flag_en <= '1';
                                flag_next <= "11";
                            elsif flag = "11" then
                                zero_en <= '1';
                            end if;
                            
                            iv_input_en <= '1';
                            
                            next_state <= s_ad;
                        end if;
                    
                    else
                        bdi_ready <= '1';
                        iv_input_en <= '1';
                        
                        if iv_input_sel /= "11" then
                            next_state <= s_ad;
                        else
                            next_state <= s_p256_1;
                        end if;					
                    end if;
                else
                    bdi_ready <= '1';
                    
                    next_state <= s_ad;
            end if;
    
           when s_ad_xor =>
                ad_flag_en <= '1';
                ad_flag_next <= '0'; -- To reset flag after ad
                
                iv_input_en <= '1';
                c0_c1_en <= '1';
                iv1_en <= '1';
    
                if bdi_eoi = '1' then --No msg data
                    bdo_type_en <= '1';
                    bdo_type_next <= HDR_TAG;
                    c1_en <= '1'; -- Condition 2 for c1 met
                    c1_in <= c1(2) & "01";
                    
                    p256_state_en <= '1';
                    p256_state_next <= "10"; -- When finished, return to tag
                    
                    next_state <= s_p256_1;
                    
                else -- Set p256 return state to s_msg			
                    p256_state_en <= '1';
                    p256_state_next <= "01"; -- When finished, return to message
                    --bdi_ready <= '1';
            
                    if decrypt_in = '1' then
                        bdo_type_en <= '1';
                        bdo_type_next <= HDR_PT;
                        
                        next_state <= s_p256_1; -- Temp reset handled at end of p256
                    else
                        bdo_type_en <= '1';
                        bdo_type_next <= HDR_CT;
                        
                        next_state <= s_p256_1;
                    end if;
                end if;
    
            when s_msg_init =>
                p256_state_en <= '1';
                p256_state_next <= "01";
                if bdi_type = HDR_PT or bdi_type = HDR_CT then
                    rho_reg_en <= '1'; --store shuffled iv in rho_reg
                    temp_en <= '1';
                    ad_flag_en <= '1';
                    ad_flag_next <= '1';
                    next_state <= s_msg;
                else
                    bdi_ready <= '1';
                    next_state <= s_msg_init;
                end if;
                
            when s_msg =>
                if bdi_valid = '1' then
                    msg_en <= '1';
                    
                    iv_input_en <= '1';
                    iv_we <= '1'; -- Write to addr 0
                    iv_sel <= "10"; -- ozs
                    iv_xor_sel <= '1'; -- bdi xor iv
                    ozs_input_sel <= decrypt_in; -- To select ozs(rho) xor iv
                    
                    if bdi_eot = '1' then
                        ozs_en <= '1';
                        
                        if flag = "10" and bdi_valid_bytes = "1111" then
                            if iv_input_sel /= "11" then
                                flag_en <= '1';
                                flag_next <= "11";
                            end if;
                            hash_pad <= '1';
                            temp_en <= '0';
                            zero_en <= '1';
                        elsif flag(1) = '1' then -- Already padded
                            temp_en <= '0';
                            zero_en <= '1';
                        else
                            if iv_input_sel /= "11" and bdi_valid_bytes = "1111" then
                                flag_en <= '1';
                                flag_next <= "10";
                            elsif iv_input_sel /= "11" then
                                flag_en <= '1';
                                flag_next <= "11";
                            end if;
                            
                            rho_vb <= bdi_valid_bytes;
                            bdo_vb_en <= '1';
                            bdo_vb_next <= bdi_valid_bytes;
                            temp_en <= '1';
                            eot_input_en <= '1';
                        end if;
                        
                        if iv_input_sel = "11" then
                            iv_input_en <= '0'; -- Freeze at 3
    
                            flag_en <= '1';
                            flag_next <= "00";
                            
                            if bdi_pad_loc = "0000" and flag = "00" then -- |PT/CT| % 32 == 0
                                c1_en <= '1'; -- Condition 2 for c1 met
                                c1_in <= c1(2) & "01";
                            
                                next_state <= s_msg_xor; -- Needs extra cycle for iv XOR c0
                            else
                                next_state <= s_msg_xor; -- Needs extra cycle for iv XOR c0
                            end if;
                        else
                            next_state <= s_msg;
                        end if;
                        
                    else
                        temp_en <= '1';
                        rho_vb <= bdi_valid_bytes;
                        
                        if iv_input_sel /= "11" then
                            bdi_ready <= '1';
                            next_state <= s_msg;
                        else
                            eot_input_en <= '1';
                            next_state <= s_msg_bdo;
                        end if;					
                    end if;
                
                else
                    bdi_ready <= '1';
                    
                    next_state <= s_msg;
                
                end if;
                                
            when s_msg_xor =>
                iv_input_en <= '1';
                iv1_en <= '1'; -- Writes iv XOR c1 to iv
                c0_c1_en <= '1';
                iv_xor_sel <= '1';
                c1_sel <= '1';
                
                p256_state_en <= '1';
                p256_state_next <= "10"; -- When finished, return to tag
                
                next_state <= s_msg_bdo;
                
            when s_msg_bdo =>
                if bdo_ready = '1' then
                    bdo_valid <= '1';
                    iv_input_en <= '1';
                    
                    if eot_input = iv_input_sel or iv_input_sel = "11" then
                        flag_en <= '1';
                        flag_next <= "00";
                        temp_rst <= '1';
                        liv <= '1';
                        iv_input_next <= "00";
                        end_of_block <= '1';
                        
                        next_state <= s_p256_1;
                        
                    else
                        next_state <= s_msg_bdo;
                    end if;
                else
                    bdo_valid <= '1';
                                        
                    next_state <= s_msg_bdo;
                end if;
                
            when s_tag_xor =>        
                c0_c1_en <= '1';
                iv1_en <= '1';
                c1_sel <= '1';
                temp_rst <= '1';
                
                next_state <= s_p256_1;
                
            when s_tag =>
                iv_input_en <= '1';
                liv <= '1';
                iv_input_next <= "00";
                bdo_type_en <= '1';
                bdo_type_next <= HDR_TAG;
                temp_en <= '1';
                if hash_in /= '1' or p256_state /= "10" then
                    bdi_ready <= '1'; --The simulation doesn't move on unless I do this...
                end if;
                bdo_sel <= '1'; -- Selects iv as output (for tag)   
                    if decrypt_in = '1' and hash_in = '0' then
                        next_state <= s_tag_verify;
                    else
                        next_state <= s_tag_bdo;
                end if;
                    
            when s_tag_bdo =>
                bdo_valid <= '1';
                if bdo_ready = '1' then
                    iv_input_en <= '1';
                    if iv_input_sel = "11" then -- Already set 4 bdo
                        if p256_state = "11" then
                            
                            bdo_valid <= '1';
                            
                            p256_state_en <= '1';
                            p256_state_next <= "10"; -- One more iteration of tag
                            
                            next_state <= s_p256_1;
                            
                        else  
                            end_of_block <= '1';
                            bdo_valid <= '1';
                            next_state <= s_idle;
    
                        end if;
                        
                    else
                        next_state <= s_tag_bdo;
                    end if;
                else
                    next_state <= s_tag_bdo;
                end if;
    
            when s_tag_verify =>
                bdi_ready <= '1';
                
                if bdi_valid = '1' then
                    iv_input_en <= '1';
                    
                    if iv_input_sel = "11" then
                        
                        if p256_state = "11" then
                            p256_state_en <= '1';
                            p256_state_next <= "10"; --Sends back to tag for one more iteration
                        
                            next_state <= s_p256_1;
                        else
                            bdi_reg <= bdi;
                            bdo_reg <= bdo;
                            if bdi_reg_unshared /= bdo_reg_unshared then
                                msg_auth_en <= '1';
                                msg_auth_next <= '0';
                                next_state <= s_auth;
                            else
                                next_state <= s_auth;
                            end if;
                            
                        end if;
                    else
                        bdi_reg <= bdi;
                        bdo_reg <= bdo;
                        if bdi_reg_unshared /= bdo_reg_unshared then
                            msg_auth_en <= '1';
                            msg_auth_next <= '0';
                            
                            next_state <= s_tag_verify;
                        else
                            next_state <= s_tag_verify;
                        end if;
                    end if;
                else
                    next_state <= s_tag_verify;
                end if;
                
            when s_auth =>
                msg_auth_valid <= '1';
                
                if msg_auth_ready = '1' then
                    next_state <= s_idle;
                else
                    next_state <= s_auth;
                end if;
                   
    
           -- Initializes hash algorithm
           when s_hash_zero_init =>
                iv_sel <= "01"; -- Sets registers to zero
                iv_we <= '1';
                iv1_rst <= '1';
                temp_rst <= '1';
                
                c0_en <= '1';
                c0_in <= "001";
    
                next_state <= s_hash1;
    
            when s_hash1 =>
                if bdi_eot = '0' then
                    bdi_ready <= '1';
                end if;
                
                if bdi_valid = '1' then
                    if bdi_size /= "000" then
                        iv_we <= '1';
                        iv_sel <= "10"; --ozs
                        
                        iv_input_en <= '1';
                        
                        if bdi_eoi = '1' then
                            ozs_en <= '1';
                            
                            if flag(1) = '1' and bdi_pad_loc = "0000" then
                                zero_en <= '1';
                                hash_pad <= '1';
                                
                                next_state <= s_hash_tag_xor;
                            elsif iv_input_sel = "11" then
                                if bdi_pad_loc = "0000" then
                                    c0_en <= '1';
                                    c0_in <= "010";
                                end if;
                                
                                next_state <= s_hash_tag_xor;
                                
                            else
                                if bdi_pad_loc = "0000" then
                                    flag_en <= '1';
                                    flag_next <= "10";
                                
                                    next_state <= s_hash1;
                                else
                                    next_state <= s_hash_tag_xor;
                                end if;
                            end if;
                            
                        elsif iv_input_sel = "11" then
                            p256_state_en <= '1';
                            p256_state_next <= "00";
                            
                            next_state <= s_p256_1;
                            
                        else
                            next_state <= s_hash1;
                            
                        end if;
                    else
                        next_state <= s_hash_tag_xor;
                    end if;
                else
                    next_state <= s_hash1;
                    
                end if;
                
            -- After first 128 bits, rest of tag's hash processed here	
            when s_hash2 =>
                
                if bdi_valid = '1' then
                    iv_we <= '1';
                    iv_sel <= "10"; --ozs
                    iv_xor_sel <= '1'; --Tells iv to input ozs(bdi) XOR iv
                    iv_input_en <= '1';
                    
                    if bdi_eot = '1' then
                        ozs_en <= '1';
                        if bdi_pad_loc /= "0000" then
                            c0_en <= '1'; -- Condition 2 for c0 met
                            c0_in <= "010";
                    
                            next_state <= s_hash_tag_xor; -- Needs extra cycle for iv XOR c0
                        else
                            next_state <= s_hash_tag_xor; -- Needs extra cycle for iv XOR c0
                        end if;
                        
                    else					
                        bdi_ready <= '1';
                        iv_input_en <= '1';
                
                        next_state <= s_p256_1;
                        
                    end if;
                else
                    bdi_ready <= '1';
                    
                    next_state <= s_hash2;
                end if;
                
            when s_hash_tag_xor =>
                bdo_type_en <= '1';
                bdo_type_next <= HDR_TAG;
                
                iv1_en <= '1';
                c0_c1_en <= '1'; -- c0
                iv_xor_sel <= '1';
    
                p256_state_en <= '1';
                p256_state_next <= "11"; -- Tag-256
                
                iv_input_en <= '1';
                liv <= '1';
                iv_input_next <= "00";
                
                next_state <= s_p256_1;
        end case;
    end process;

end Behavioral;
