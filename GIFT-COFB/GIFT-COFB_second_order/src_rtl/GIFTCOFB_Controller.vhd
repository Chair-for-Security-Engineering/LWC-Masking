------------------------------------------------------------------------
-- Company: SAL-Virginia Tech
-- Engineer: Behnaz Rezvani
-- 
-- Create Date: 02/05/2020
-- Module Name: GIFTCOFB_Controller - Behavioral
-- Tool Versions: Vivado 2019.1
-- Description: Version 1
-- 
----------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
USE IEEE.NUMERIC_STD.ALL;
use work.NIST_LWAPI_pkg.all;
use work.design_pkg.all;

-- Entity
----------------------------------------------------------------------
entity GIFTCOFB_Controller is
    Port(
        clk             : in std_logic;
        rst             : in std_logic;
        -- GIFT
        GIFT_start      : out std_logic;
        GIFT_rst        : out std_logic;
        GIFT_done       : in std_logic;
        X_in_mux_sel    : out std_logic;
        -- Key Control
        key             : in std_logic_vector(SDI_SHARES * CCSW - 1 downto 0); -- SW = 32
        key_valid       : in std_logic;
        key_ready       : out std_logic;
        key_update      : in std_logic;
        -- BDI Control
        bdi             : in std_logic_vector(PDI_SHARES * CCW - 1 downto 0); -- W = 32
        bdi_valid       : in std_logic;
        bdi_ready       : out std_logic;
        bdi_valid_bytes : in std_logic_vector(3 downto 0); -- W/8 = 4
        bdi_size        : in std_logic_vector(2 downto 0); -- W/(8+1) = 3
        bdi_eot         : in std_logic;
        bdi_eoi         : in std_logic;
        bdi_type        : in std_logic_vector(3 downto 0);
        decrypt_in      : in std_logic;
        -- BDO Control
        bdo             : in std_logic_vector(PDI_SHARES * CCW - 1 downto 0);
        bdo_valid       : out std_logic;
        bdo_ready       : in std_logic;
        bdo_valid_bytes : out std_logic_vector(3 downto 0); -- W/8 = 4
        end_of_block    : out std_logic;
        -- Tag Verification
        msg_auth        : out std_logic;
        msg_auth_valid  : out std_logic;
        msg_auth_ready  : in std_logic;
        -- Control
        ctr_words       : inout std_logic_vector(2 downto 0);
        ctr_bytes       : inout std_logic_vector(4 downto 0);
        KeyReg128_rst   : out std_logic;
        KeyReg128_en    : out std_logic;
        DstateReg_rst   : out std_logic;
        DstateReg_en    : out std_logic;
        Dstate_mux_sel  : out std_logic_vector(1 downto 0);
        iDataReg_rst    : out std_logic;
        iDataReg_en     : out std_logic;
        iData_mux_sel   : out std_logic_vector(1 downto 0);
        bdo_t_mux_sel   : out std_logic;
        rdi_valid       : in  std_logic;
        rdi_ready       : out std_logic
    );
end GIFTCOFB_Controller;

-- Architecture
----------------------------------------------------------------------
architecture Behavioral of GIFTCOFB_Controller is

    -- Constants -----------------------------------------------------
    --bdi_type and bdo_type encoding
    constant HDR_AD         : std_logic_vector(3 downto 0) := "0001";
    constant HDR_MSG        : std_logic_vector(3 downto 0) := "0100";
    constant HDR_CT         : std_logic_vector(3 downto 0) := "0101";
    constant HDR_TAG        : std_logic_vector(3 downto 0) := "1000";
    constant HDR_KEY        : std_logic_vector(3 downto 0) := "1100";
    constant HDR_NPUB       : std_logic_vector(3 downto 0) := "1101";
    
    constant zero64         : std_logic_vector(63 downto 0) := (others => '0');
    
    -- Types ---------------------------------------------------------
    type fsm is (idle, load_rnd, load_key, wait_Npub, load_Npub, process_Npub,
                 load_AD, process_AD, load_data, process_data, output_tag,
                 load_tag, verify_tag, AD_delta1, AD_delta2, AD_delta3, AD_delta4,
                 M_delta1, M_delta2);

    -- Signals -------------------------------------------------------
    signal decrypt_rst      : std_logic;
    signal decrypt_set      : std_logic;
    signal decrypt_reg      : std_logic;
    
    signal last_AD_reg      : std_logic;
    signal last_AD_rst      : std_logic;
    signal last_AD_set      : std_logic;
    
    signal half_AD_reg      : std_logic;
    signal half_AD_rst      : std_logic;
    signal half_AD_set      : std_logic;
    
    signal no_AD_reg        : std_logic;
    signal no_AD_rst        : std_logic;
    signal no_AD_set        : std_logic;
    
    signal last_M_reg       : std_logic;
    signal last_M_rst       : std_logic;
    signal last_M_set       : std_logic;
    
    signal half_M_reg       : std_logic;
    signal half_M_rst       : std_logic;
    signal half_M_set       : std_logic;
    
    signal no_M_reg         : std_logic;
    signal no_M_rst         : std_logic;
    signal no_M_set         : std_logic;

    -- Counter signals
    signal ctr_words_rst    : std_logic;
    signal ctr_words_inc    : std_logic;
    
    signal ctr_bytes_rst    : std_logic;
    signal ctr_bytes_inc    : std_logic;
    
    signal ctr_time_rst     : std_logic;
    signal ctr_time_inc     : std_logic;
    
    signal GIFT_reset       : std_logic;
    signal ctr_time         : std_logic_vector(7 downto 0);

    signal msg_auth_s          : std_logic;
    signal n_msg_auth_s        : std_logic;
    signal bdi_reg             : std_logic_vector(PDI_SHARES * CCW - 1 downto 0);
    signal bdo_reg             : std_logic_vector(PDI_SHARES * CCW - 1 downto 0);
    signal bdi_reg_unshared    : std_logic_vector(CCW - 1 downto 0);
    signal bdo_reg_unshared    : std_logic_vector(CCW - 1 downto 0);
    
    -- State machine signals
    signal state            : fsm;
    signal next_state       : fsm;

-------------------------------------------------------------------------------
begin
    msg_auth <= msg_auth_s;
    bdi_reg_unshared <= (others => '0'); --bdi_reg(1*CCW-1 downto 0*CCW) xor bdi_reg(2*CCW-1 downto 1*CCW);
    bdo_reg_unshared <= (others => '0'); --bdo_reg(1*CCW-1 downto 0*CCW) xor bdo_reg(2*CCW-1 downto 1*CCW);
    
    GIFT_rst <= rst or GIFT_reset; 
                
    bdo_valid_bytes <=  bdi_valid_bytes when (bdi_type = HDR_MSG or bdi_type = HDR_CT) else -- PT or CT extraction
                        "1111";                                                             -- Tag extraction
                        
    end_of_block    <=  bdi_eot when (bdi_type = HDR_MSG or bdi_type = HDR_CT) else -- PT or CT extraction
                        '1'     when (ctr_words = 3) else                           -- Tag extraction 
                        '0';                      
                                          
    -- Clock process ----------------------------------------------------------
    Sync: process(clk)
    begin
        if rising_edge(clk) then
            if (rst = '1') then
                state   <= idle;                
                msg_auth_s <= '1';
            else
                state   <= next_state;
                msg_auth_s <= n_msg_auth_s;

                if (ctr_words_rst = '1') then
                    ctr_words   <= "000";
                elsif (ctr_words_inc = '1') then
                    ctr_words   <= ctr_words + 1;
                end if;
                
                if (ctr_bytes_rst = '1') then
                    ctr_bytes   <= "00000";
                elsif (ctr_bytes_inc = '1') then
                    ctr_bytes   <= ctr_bytes + bdi_size;
                end if;

                if (ctr_time_rst = '1') then
                    ctr_time   <= x"00";
                elsif (ctr_time_inc = '1') then
                    ctr_time   <= ctr_time + 1;
                end if;
                
                if (decrypt_rst = '1') then
                    decrypt_reg <= '0';
                elsif (decrypt_set = '1') then
                    decrypt_reg <= '1';
                end if;
                
                if (last_AD_rst = '1') then
                    last_AD_reg <= '0';
                elsif (last_AD_set = '1') then
                    last_AD_reg <= '1';
                end if;
                
                if (half_AD_rst = '1') then
                    half_AD_reg <= '0';
                elsif (half_AD_set = '1') then
                    half_AD_reg <= '1';
                end if;
                
                if (no_AD_rst = '1') then
                    no_AD_reg   <= '0';
                elsif (no_AD_set = '1') then
                    no_AD_reg   <= '1';
                end if;
                
                if (last_M_rst = '1') then
                    last_M_reg  <= '0';
                elsif (last_M_set = '1') then
                    last_M_reg  <= '1';
                end if;
                
                if (half_M_rst = '1') then
                    half_M_reg  <= '0';
                elsif (half_M_set = '1') then
                    half_M_reg  <= '1';
                end if;
                
                if (no_M_rst = '1') then
                    no_M_reg   <= '0';
                elsif (no_M_set = '1') then
                    no_M_reg   <= '1';
                end if;
                    
            end if;
        end if;
    end process;
    
    -- Controller process -------------------------------------------------------
    Controller: process(state, key, bdi, bdo, key_valid, key_update, bdi_valid, bdi_eot, last_M_reg, half_M_reg, no_M_reg,
                        bdi_eoi, bdi_type, ctr_words, GIFT_done, bdo_ready, rdi_valid, bdi_reg_unshared, bdo_reg_unshared, 
                        msg_auth_ready, ctr_time, decrypt_in, bdi_size, last_AD_reg, no_AD_reg, half_AD_reg, decrypt_reg)
    begin
        next_state          <= idle;
        key_ready           <= '0';
        bdi_ready           <= '0';
        rdi_ready           <= '1';
        bdo_valid           <= '0';
        msg_auth_valid      <= '0';  
        GIFT_start          <= '0';    
        ctr_words_rst       <= '0';
        ctr_words_inc       <= '0';
        ctr_bytes_rst       <= '0';
        ctr_bytes_inc       <= '0';
        ctr_time_rst        <= '0';
        ctr_time_inc        <= '0';
        KeyReg128_rst       <= '0';
        KeyReg128_en        <= '0';
        iDataReg_rst        <= '0';
        iDataReg_en         <= '0';
        DstateReg_rst       <= '0';
        DstateReg_en        <= '0';
        decrypt_rst         <= '0';
        decrypt_set         <= '0';
        last_AD_rst         <= '0';
        last_AD_set         <= '0';
        half_AD_rst         <= '0';
        half_AD_set         <= '0';
        no_AD_rst           <= '0';
        no_AD_set           <= '0';
        last_M_rst          <= '0';
        last_M_set          <= '0';
        half_M_rst          <= '0';
        half_M_set          <= '0';
        no_M_rst            <= '0';
        no_M_set            <= '0';        
        X_in_mux_sel        <= '1';
        Dstate_mux_sel      <= "11";
        iData_mux_sel       <= "11";     
        bdo_t_mux_sel       <= '0';
        GIFT_reset          <= '0';     
        n_msg_auth_s        <= '1';
        bdi_reg             <= (others => '0');
        bdo_reg             <= (others => '0');
        
        case state is
            when idle =>
                GIFT_reset          <= '1';      
                ctr_words_rst       <= '1';
                ctr_bytes_rst       <= '1';
                ctr_time_rst        <= '1';
                iDataReg_rst        <= '1';
                DstateReg_rst       <= '1'; 
                decrypt_rst         <= '1';
                last_AD_rst         <= '1';
                half_AD_rst         <= '1';
                no_AD_rst           <= '1';
                last_M_rst          <= '1';
                half_M_rst          <= '1';
                no_M_rst            <= '1';
                next_state          <= load_rnd;
           
            when load_rnd =>   
                if(rdi_valid = '1') then
                    if (key_valid = '1' and key_update = '1') then -- Get a new key
                        KeyReg128_rst   <= '1'; -- No need to keep the previous key
                        next_state      <= load_key;
                    elsif (bdi_valid = '1') then -- In decryption, skip getting the key and get the nonce
                        next_state      <= load_Npub;
                    else
                        next_state      <= idle;
                    end if; 
                end if;
            when load_key =>
                key_ready           <= '1';
                KeyReg128_en        <= '1';
                ctr_words_inc       <= '1';
                if (ctr_words = 3) then
                    ctr_words_rst   <= '1';
                    next_state      <= wait_Npub;
                else
                    next_state      <= load_key;
                end if;
                
            when wait_Npub =>
                if (bdi_valid = '1') then
                    next_state      <= load_Npub;
                else
                    next_state      <= wait_Npub;
                end if;
                
            when load_Npub =>              
                bdi_ready           <= '1';   
                ctr_words_inc       <= '1';
                iDataReg_en         <= '1';
                iData_mux_sel       <= "00";
                if (decrypt_in = '1') then -- Decryption
                    decrypt_set     <= '1';
                else                       -- Encryption
                    decrypt_rst     <= '1';
                end if;
                if (bdi_eoi = '1') then -- No AD and no data
                    no_AD_set       <= '1';
                    no_M_set        <= '1';
                end if;
                if (ctr_words = 3) then 
                    ctr_words_rst   <= '1';
                    next_state      <= process_Npub;
                else
                    next_state      <= load_Npub;
                end if;
                
            when process_Npub =>
                if(rdi_valid = '1') then
                    X_in_mux_sel        <= '0';
                    if (ctr_time >= 4) then
                        ctr_time_rst <= '1';

                        GIFT_start          <= '1';
                        if (GIFT_done = '1') then 
                            GIFT_reset      <= '1';      
                            GIFT_start      <= '0';
                            DstateReg_en    <= '1';
                            Dstate_mux_sel  <= "00";
                            iDataReg_rst    <= '1';
                            if (bdi_type /= HDR_AD) then -- No AD
                                no_AD_set   <= '1';
                                next_state  <= AD_delta1; 
                            else                       
                                next_state  <= load_AD;
                            end if;
                        else
                            next_state      <= process_Npub;
                        end if; 
                    else
                        ctr_time_inc <= '1';
                        next_state      <= process_Npub;
                    end if;
                end if;
            when load_AD =>
                bdi_ready           <= '1';
                ctr_words_inc       <= '1';
                ctr_bytes_inc       <= '1';
                iDataReg_en         <= '1';
                if (bdi_eoi = '1') then -- No data
                    no_M_set        <= '1';
                end if;
                if (bdi_eot = '1') then -- Last block of AD
                    last_AD_set     <= '1';
                    if (bdi_size /= 4 or ctr_words /= 3) then -- Partial block of AD
                        half_AD_set <= '1';
                    end if;                  
                end if; 
                if (bdi_eot = '1' or ctr_words = 3) then
                    ctr_words_rst   <= '1';
                    next_state      <= AD_delta1;
                else
                    next_state      <= load_AD;
                end if;                   
                
            when AD_delta1 =>
                DstateReg_en        <= '1';
                if (last_AD_reg = '1' or no_AD_reg = '1') then -- Last block of AD or no AD   
                    Dstate_mux_sel  <= "01"; -- Tripling
                end if;
                next_state          <= AD_delta2;
                
            when AD_delta2 =>
                if (half_AD_reg = '1' or no_AD_reg = '1') then -- Partial or empty block of AD
                    DstateReg_en    <= '1';
                    Dstate_mux_sel  <= "01"; -- Tripling
                end if;
                next_state          <= AD_delta3;
            
            when AD_delta3 =>
                if (no_M_reg = '1') then -- No data, so delta state needs two triples. This is the first one
                    DstateReg_en    <= '1';
                    Dstate_mux_sel  <= "01";
                end if;
                 next_state         <= AD_delta4;
                
            when AD_delta4 =>
                if (no_M_reg = '1') then -- No data, so delta state needs two triples. This is the second one
                    DstateReg_en    <= '1';
                    Dstate_mux_sel  <= "01";
                end if;
                next_state          <= process_AD;
            
            when process_AD =>
                if(rdi_valid = '1') then                            
                    if (ctr_time >= 4) then
                        ctr_time_rst <= '1';
    
                        GIFT_start          <= '1';
                        if (GIFT_done = '1') then
                            GIFT_reset      <= '1';      
                            GIFT_start      <= '0';
                            ctr_bytes_rst   <= '1';
                            iDataReg_rst    <= '1'; 
                            if (last_AD_reg = '0' and no_AD_reg = '0') then -- Still loading AD, if we have any
                                next_state  <= load_AD;
                            elsif (no_M_reg = '0') then -- No AD, start loading data
                                next_state  <= load_data;
                            elsif (decrypt_reg = '0') then  -- No more data (Enc), extract tag
                                next_state  <= output_tag;  
                            else                            -- No more data (Dec), verify tag
                                next_state  <= load_tag; 
                            end if;
                        else
                            next_state      <= process_AD;
                        end if;
                    else
                        ctr_time_inc <= '1';
                        next_state      <= process_AD;
                    end if;
                end if;
            when load_data =>
                bdi_ready           <= '1';            
                ctr_words_inc       <= '1';
                ctr_bytes_inc       <= '1';
                iDataReg_en         <= '1';         
                if (bdi_eot = '1') then -- Last block of data
                    last_M_set      <= '1';
                    if (bdi_size /= 4 or ctr_words /= 3) then -- Partial block of data
                        half_M_set  <= '1';
                    end if;
                end if; 
                if (decrypt_reg = '1') then -- Decryption
                    iData_mux_sel   <= "10";
                end if;
                if (bdo_ready = '1') then
                    bdo_valid       <= '1';              
                end if;    
                if (bdi_eot = '1' or ctr_words = 3) then
                    ctr_words_rst   <= '1';
                    next_state      <= M_delta1;
                else
                    next_state      <= load_data;
                end if;    
                    
            when M_delta1 =>
                DstateReg_en        <= '1';
                if (last_M_reg = '1') then -- Last block of data
                    Dstate_mux_sel  <= "01";
                end if;
                next_state          <= M_delta2;
                
            when M_delta2 =>
                if (half_M_reg = '1') then -- Partial block of data
                    DstateReg_en    <= '1';
                    Dstate_mux_sel  <= "01";
                end if;
                next_state          <= process_data;
            
            when process_data => 
                if(rdi_valid = '1') then
                    if (ctr_time >= 4) then
                        ctr_time_rst <= '1';

                        GIFT_start          <= '1'; 
                        if (GIFT_done = '1') then -- End of data
                            GIFT_reset      <= '1';      
                            GIFT_start      <= '0';
                            ctr_bytes_rst   <= '1';
                            iDataReg_rst    <= '1'; 
                            if (last_M_reg = '1' and decrypt_reg = '0') then -- End of data and encryption
                                next_state  <= output_tag;
                            elsif (last_M_reg = '1') then -- End of data and decryption 
                                next_state  <= load_tag;
                            else
                                next_state  <= load_data;
                            end if;
                        else
                            next_state      <= process_data;
                        end if;
                    else
                        ctr_time_inc <= '1';
                        next_state      <= process_data;
                    end if;
                end if;    
            when output_tag =>
                bdo_t_mux_sel       <= '1';
                bdo_valid           <= '1';
                ctr_words_inc       <= '1';
                if (ctr_words = 3) then
                    ctr_words_rst   <= '1';
                    next_state      <= idle;
                else
                    next_state      <= output_tag;
                end if; 
             
            when load_tag =>
                bdi_ready           <= '1';
                ctr_words_inc       <= '1';
                iDataReg_en         <= '1';
                iData_mux_sel       <= "00"; 
                if (ctr_words = 3) then
                    ctr_words_rst   <= '1';
                    next_state      <= verify_tag;
                else
                    next_state      <= load_tag;
                end if;   
            
            when verify_tag =>
                if (msg_auth_ready = '1') then
                    bdi_reg <= bdi;
                    bdo_reg <= bdo;      
                    msg_auth_valid  <= '1';
                    next_state      <= idle; 
                    if (bdi_reg_unshared /= bdo_reg_unshared) then
                        n_msg_auth_s <= '0';
                    end if;
                else
                    next_state      <= verify_tag;
                end if;
 
            when others =>
                next_state  <= idle;            
        end case;
    end process;
end Behavioral;

