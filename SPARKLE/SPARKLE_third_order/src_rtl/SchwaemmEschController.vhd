----------------------------------------------------------------------------------
-- Code based on NIST LWC Schwaemm256128
-- 3/18/2020
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.utility_functions.ALL;
use work.NIST_LWAPI_pkg.ALL;
use work.design_pkg.all;

entity controller is
    Port (
        clk : in std_logic;
        rst : in std_logic;
    
        key : in std_logic_vector(SDI_SHARES * CCSW - 1 downto 0);
        key_valid : in std_logic;
        key_ready : out std_logic;
        
        bdi : in std_logic_vector(PDI_SHARES * CCW - 1 downto 0);
        bdi_valid : in std_logic;
        bdi_ready : out std_logic;
        bdi_pad_loc : in std_logic_vector(3 downto 0);
        bdi_valid_bytes : in std_logic_vector(3 downto 0);
        
        bdi_size : in std_logic_vector(2 downto 0);
        bdi_eot : in std_logic;
        bdi_eoi : in std_logic;
        bdi_type : in std_logic_vector(3 downto 0);
        decrypt : in std_logic;
        hash : in std_logic;
        key_update : in std_logic;
        
        bdo : out std_logic_vector(PDI_SHARES * CCW - 1 downto 0);
        bdo_valid : out std_logic;
        bdo_ready : in std_logic;
        end_of_block : out std_logic;
        bdo_valid_bytes : out std_logic_vector(3 downto 0);
        bdo_type : out std_logic_vector(3 downto 0);
        
        msg_auth : out std_logic;
        msg_auth_valid : out std_logic;
        msg_auth_ready : in std_logic;
        
        rdi             : in  std_logic_vector(RW - 1 downto 0);
        rdi_valid       : in  std_logic;
        rdi_ready       : out std_logic
    );
end controller;

architecture behavioral of controller is

    -- Controller states
    type controller_state is (IDLE, LOAD_KEY, LOAD_NPUB,
                              START_PERM, WAIT_PERM,
                              LOAD_BLK, LOAD_BLK_ZERO,
                              FINALIZE_DAT_OUT, OUTPUT_DAT_BLK, 
                              LOAD_TAG, OUTPUT_TAG, VERIFY_TAG,
                              START_PERM_INIT,
                              LOAD_HASH, LOAD_HASH_ZERO, 
                              FINALIZE_HASH_OUT, OUTPUT_HASH);
    signal current_state : controller_state;
    signal next_state : controller_state;
    
    -- Input/Output word counter
    signal word_cntr_en, word_cntr_init : std_logic;
    signal word_counter : integer;
    
    -- Signals to handle manipulation and storage of input words
    signal bdi_reg_en, key_reg_en : std_logic;
    signal bdi_pad_en, zero_fill : std_logic;

    -- Partial registers for storage of each word
    signal key_s0, key_s1, key_s2, key_s3 : std_logic_vector(CCSW - 1 downto 0);
    signal key_0_s0, key_1_s0, key_2_s0, key_3_s0: std_logic_vector(CCSW - 1 downto 0);
    signal key_0_s1, key_1_s1, key_2_s1, key_3_s1: std_logic_vector(CCSW - 1 downto 0);
    signal key_0_s2, key_1_s2, key_2_s2, key_3_s2: std_logic_vector(CCSW - 1 downto 0);
    signal key_0_s3, key_1_s3, key_2_s3, key_3_s3: std_logic_vector(CCSW - 1 downto 0);

    --signal bdi_p, bdi_z : std_logic_vector(PDI_SHARES * CCW - 1 downto 0);
    
    signal bdi_p_s0, bdi_p_s1, bdi_p_s2, bdi_p_s3 : std_logic_vector(CCW - 1 downto 0);
    signal bdi_z_s0, bdi_z_s1, bdi_z_s2, bdi_z_s3 : std_logic_vector(CCW - 1 downto 0);
    signal bdi_0_s0, bdi_1_s0, bdi_2_s0, bdi_3_s0, bdi_4_s0, bdi_5_s0, bdi_6_s0, bdi_7_s0 : std_logic_vector(CCW - 1 downto 0);
    signal bdi_0_s1, bdi_1_s1, bdi_2_s1, bdi_3_s1, bdi_4_s1, bdi_5_s1, bdi_6_s1, bdi_7_s1 : std_logic_vector(CCW - 1 downto 0);
    signal bdi_0_s2, bdi_1_s2, bdi_2_s2, bdi_3_s2, bdi_4_s2, bdi_5_s2, bdi_6_s2, bdi_7_s2 : std_logic_vector(CCW - 1 downto 0);
    signal bdi_0_s3, bdi_1_s3, bdi_2_s3, bdi_3_s3, bdi_4_s3, bdi_5_s3, bdi_6_s3, bdi_7_s3 : std_logic_vector(CCW - 1 downto 0);
    
    -- Complete data storage registers
    signal bdi_blk : std_logic_vector(PDI_SHARES * 256 - 1 downto 0);
    signal key_reg : std_logic_vector(SDI_SHARES * 128 - 1 downto 0);
    
    -- Signals to handle storage
    signal store_dec, dec_reg : std_logic;
    signal store_lblk, lblk_reg, eoi_reg : std_logic;
    signal bdi_valid_bytes_reg : std_logic_vector(3 downto 0);
    signal bdi_pad_reg, store_pad_en : std_logic;
    signal lword_index : integer;
    
    -- BDO output signals
    signal bdo_out_reg : std_logic_vector(PDI_SHARES * 256 - 1 downto 0);
    
    signal bdo_current_s0 : std_logic_vector(CCW - 1 downto 0);
    signal bdo_current_s1 : std_logic_vector(CCW - 1 downto 0);
    signal bdo_current_s2 : std_logic_vector(CCW - 1 downto 0);
    signal bdo_current_s3 : std_logic_vector(CCW - 1 downto 0);
    
    signal valid_bytes_sel, bdo_en : std_logic;
    signal bdo_out_sel : std_logic_vector(1 downto 0);
    
    -- Datapath signals
    signal feistel_out : std_logic_vector(PDI_SHARES * 384 - 1 downto 0);                     -- Feistel unit
    signal rho_rate_in : std_logic_vector(PDI_SHARES * 256 - 1 downto 0);                     -- Rho 1
    signal rho_out : std_logic_vector(PDI_SHARES * 384 - 1 downto 0);
    signal inv_rho_out : std_logic_vector(PDI_SHARES * 384 - 1 downto 0);                     -- Inv rho 1
    signal rho_ct_out_s0 : std_logic_vector(384 - 1 downto 0);                                -- Rho 2
    signal rho_ct_out_s1 : std_logic_vector(384 - 1 downto 0);                                -- Rho 2
    signal rho_ct_out_s2 : std_logic_vector(384 - 1 downto 0);                                -- Rho 2
    signal rho_ct_out_s3 : std_logic_vector(384 - 1 downto 0);                                -- Rho 2

    signal padded_zero_pt : std_logic_vector(PDI_SHARES * 256 -1 downto 0);                   -- Padded plaintext
    signal pad_const : std_logic_vector(31 downto 0);                                         -- Pad constant
    signal inj_const_in, inj_const_out : std_logic_vector(PDI_SHARES * 384 - 1 downto 0);     -- Inject constant unit 
    signal rate_whiten_in, rate_whiten_out : std_logic_vector(PDI_SHARES * 384 - 1 downto 0);
    signal state_init_input : std_logic_vector(PDI_SHARES * 384 - 1 downto 0);
    signal tag : std_logic_vector(PDI_SHARES * 128 - 1 downto 0);
    
    -- Hash signals
    signal hash_feistel_in, hash_feistel_out, hash_constm, hash_state_in  : std_logic_vector(PDI_SHARES * 384 - 1 downto 0);
    signal hash_pad_const : std_logic_vector(31 downto 0);
    signal hash_pad_const_sel, fin_hash, lblk_in : std_logic;
    signal hash_init, store_hash_init, hash_init_val : std_logic;
    signal hash_value_d0 : std_logic_vector(PDI_SHARES * 128 - 1 downto 0);
    signal hash_value : std_logic_vector(PDI_SHARES * 256 - 1 downto 0);
    signal store_hash_d0, store_hash, hash_reg : std_logic;
    
    -- Datapath signal selects
    signal rho_rate_in_sel, inj_const_in_sel : std_logic;
    signal pad_const_sel : std_logic_vector(1 downto 0);
    signal ad_flag_in, ad_flag, store_ad_flag : std_logic;
    signal comp_tag : std_logic;
    
    -- Sparkle Permutation control signals: 
    signal perm_en, perm_complete : std_logic;
    signal num_steps : integer;
    signal state_sparkle_in, state_sparkle_out : std_logic_vector(PDI_SHARES * 384 - 1 downto 0);
    signal sparkle_in_sel : std_logic_vector(1 downto 0);
       
    signal tag_reg, bdi_blk_reg : std_logic_vector(PDI_SHARES * 128 - 1 downto 0);
    signal tag_reg_unshared, bdi_blk_reg_unshared : std_logic_vector(127 downto 0);
       
begin
    tag_reg_unshared <= (others => '0'); --tag_reg(1*128-1 downto 0*128) xor tag_reg(2*128-1 downto 1*128) xor tag_reg(3*128-1 downto 2*128) xor tag_reg(4*128-1 downto 3*128);
    bdi_blk_reg_unshared <= (others => '0'); --bdi_blk_reg(1*128-1 downto 0*128) xor bdi_blk_reg(2*128-1 downto 1*128) xor bdi_blk_reg(3*128-1 downto 2*128) xor bdi_blk_reg(4*128-1 downto 3*128);
    
    key_s0 <= key(1*CCSW-1 downto 0*CCSW);
    key_s1 <= key(2*CCSW-1 downto 1*CCSW);
    key_s2 <= key(3*CCSW-1 downto 2*CCSW);
    key_s3 <= key(4*CCSW-1 downto 3*CCSW);
   
    -- Registers:     
    bdi_valid_reg_unit: entity work.regGen(behavioral)
    generic map (width => 4)
    port map(
        d => bdi_valid_bytes,
	    e => store_lblk,
	    clk => clk,
	    q => bdi_valid_bytes_reg
    );
        
    ad_flag_reg_unit: entity work.regOne(behavioral)
    port map(
        d => ad_flag_in,
	    e => store_ad_flag,
	    clk => clk,
	    q => ad_flag
    );
    
    dec_flag_reg_unit: entity work.regOne(behavioral)
    port map(
        d => decrypt,
	    e => store_dec,
	    clk => clk,
	    q => dec_reg
    );
    
    eoi_reg_unit: entity work.regOne(behavioral)
    port map(
        d => bdi_eoi,
	    e => store_lblk,
	    clk => clk,
	    q => eoi_reg
    );
    
    bdi_pad_reg_unit: entity work.regOne(behavioral)
    port map(
        d => bdi_pad_en,
	    e => store_pad_en,
	    clk => clk,
	    q => bdi_pad_reg
    );
    
    eot_reg_unit: entity work.regOne(behavioral)
    port map(
        d => lblk_in,
	    e => store_lblk,
	    clk => clk,
	    q => lblk_reg
    );
    
    lw_num_reg_unit: entity work.regNum(behavioral)
    port map(
        d => word_counter,
	    e => store_lblk,
	    clk => clk,
	    q => lword_index
    );
    
    h0_reg: entity work.regGen(behavioral)
    generic map (width => 128)
    port map(
        d => state_sparkle_out(1*384-1 downto 0*384+256),
	    e => store_hash_d0,
	    clk => clk,
	    q => hash_value_d0(1*128-1 downto 0*128)
    );
    
    h1_reg: entity work.regGen(behavioral)
    generic map (width => 128)
    port map(
        d => state_sparkle_out(2*384-1 downto 1*384+256),
	    e => store_hash_d0,
	    clk => clk,
	    q => hash_value_d0(2*128-1 downto 1*128)
    );    

    h2_reg: entity work.regGen(behavioral)
    generic map (width => 128)
    port map(
        d => state_sparkle_out(3*384-1 downto 2*384+256),
	    e => store_hash_d0,
	    clk => clk,
	    q => hash_value_d0(3*128-1 downto 2*128)
    ); 

    h3_reg: entity work.regGen(behavioral)
    generic map (width => 128)
    port map(
        d => state_sparkle_out(4*384-1 downto 3*384+256),
	    e => store_hash_d0,
	    clk => clk,
	    q => hash_value_d0(4*128-1 downto 3*128)
    ); 

    hash_reg_unit: entity work.regOne(behavioral)
    port map(
        d => hash,
	    e => store_hash,
	    clk => clk,
	    q => hash_reg
    );
    
    hash_init_reg_unit: entity work.regOne(behavioral)
    port map(
        d => hash_init_val,
	    e => store_hash_init,
	    clk => clk,
	    q => hash_init
    );
        
    -- Datapath units: 

    fesitel_unit1: entity work.feistel_swap(structural) -- linear
    port map(
        state_in => state_sparkle_out(1*384-1 downto 0*384),
        state_out => feistel_out(1*384-1 downto 0*384)
    ); 

    fesitel_unit2: entity work.feistel_swap(structural)
    port map(
        state_in => state_sparkle_out(2*384-1 downto 1*384),
        state_out => feistel_out(2*384-1 downto 1*384)
    ); 

    fesitel_unit3: entity work.feistel_swap(structural)
    port map(
        state_in => state_sparkle_out(3*384-1 downto 2*384),
        state_out => feistel_out(3*384-1 downto 2*384)
    ); 

    fesitel_unit4: entity work.feistel_swap(structural)
    port map(
        state_in => state_sparkle_out(4*384-1 downto 3*384),
        state_out => feistel_out(4*384-1 downto 3*384)
    ); 

    rho_state_unit1: entity work.rho(structural) -- linear
    port map(
        state_in => feistel_out(1*384-1 downto 0*384),      
        input_rate => rho_rate_in(1*256-1 downto 0*256),
        state_out => rho_out(1*384-1 downto 0*384)
    ); 

    rho_state_unit2: entity work.rho(structural)
    port map(
        state_in => feistel_out(2*384-1 downto 1*384),      
        input_rate => rho_rate_in(2*256-1 downto 1*256),
        state_out => rho_out(2*384-1 downto 1*384)
    ); 

    rho_state_unit3: entity work.rho(structural)
    port map(
        state_in => feistel_out(3*384-1 downto 2*384),      
        input_rate => rho_rate_in(3*256-1 downto 2*256),
        state_out => rho_out(3*384-1 downto 2*384)
    ); 

    rho_state_unit4: entity work.rho(structural)
    port map(
        state_in => feistel_out(4*384-1 downto 3*384),      
        input_rate => rho_rate_in(4*256-1 downto 3*256),
        state_out => rho_out(4*384-1 downto 3*384)
    ); 

    rho_ct_unit1: entity work.rho(structural)
    port map(
        state_in => state_sparkle_out(1*384-1 downto 0*384),      
        input_rate => bdi_blk(1*256-1 downto 0*256),
        state_out => rho_ct_out_s0
    );

    rho_ct_unit2: entity work.rho(structural)
    port map(
        state_in => state_sparkle_out(2*384-1 downto 1*384),      
        input_rate => bdi_blk(2*256-1 downto 1*256),
        state_out => rho_ct_out_s1
    );

    rho_ct_unit3: entity work.rho(structural)
    port map(
        state_in => state_sparkle_out(3*384-1 downto 2*384),      
        input_rate => bdi_blk(3*256-1 downto 2*256),
        state_out => rho_ct_out_s2
    );

    rho_ct_unit4: entity work.rho(structural)
    port map(
        state_in => state_sparkle_out(4*384-1 downto 3*384),      
        input_rate => bdi_blk(4*256-1 downto 3*256),
        state_out => rho_ct_out_s3
    );

    inv_rho_unit1: entity work.inv_rho(structural) -- linear
    port map(
        state_in_pre_feistel => state_sparkle_out(1*384-1 downto 0*384+128),      
        state_in_post_feistel => feistel_out(1*384-1 downto 0*384),      
        input_rate => bdi_blk(1*256-1 downto 0*256),
        state_out => inv_rho_out(1*384-1 downto 0*384)
    );

    inv_rho_unit2: entity work.inv_rho(structural)
    port map(
        state_in_pre_feistel => state_sparkle_out(2*384-1 downto 1*384+128),      
        state_in_post_feistel => feistel_out(2*384-1 downto 1*384),      
        input_rate => bdi_blk(2*256-1 downto 1*256),
        state_out => inv_rho_out(2*384-1 downto 1*384)
    );

    inv_rho_unit3: entity work.inv_rho(structural)
    port map(
        state_in_pre_feistel => state_sparkle_out(3*384-1 downto 2*384+128),      
        state_in_post_feistel => feistel_out(3*384-1 downto 2*384),      
        input_rate => bdi_blk(3*256-1 downto 2*256),
        state_out => inv_rho_out(3*384-1 downto 2*384)
    );

    inv_rho_unit4: entity work.inv_rho(structural)
    port map(
        state_in_pre_feistel => state_sparkle_out(4*384-1 downto 3*384+128),      
        state_in_post_feistel => feistel_out(4*384-1 downto 3*384),      
        input_rate => bdi_blk(4*256-1 downto 3*256),
        state_out => inv_rho_out(4*384-1 downto 3*384)
    );

    inject_const1: entity work.inject_constant(structural) -- linear but constant unshared?
    port map(
        state_in => inj_const_in(1*384-1 downto 0*384),
        constant_value => pad_const,
        state_out => inj_const_out(1*384-1 downto 0*384)
    );

    inject_const2: entity work.inject_constant(structural)
    port map(
        state_in => inj_const_in(2*384-1 downto 1*384),
        constant_value => x"00000000",
        state_out => inj_const_out(2*384-1 downto 1*384)
    );

    inject_const3: entity work.inject_constant(structural)
    port map(
        state_in => inj_const_in(3*384-1 downto 2*384),
        constant_value => x"00000000",
        state_out => inj_const_out(3*384-1 downto 2*384)
    );

    inject_const4: entity work.inject_constant(structural)
    port map(
        state_in => inj_const_in(4*384-1 downto 3*384),
        constant_value => x"00000000",
        state_out => inj_const_out(4*384-1 downto 3*384)
    );

    rate_white_unit1: entity work.rate_whitening(structural) -- linear
    port map(
        state_in => rate_whiten_in(1*384-1 downto 0*384),
        state_out => rate_whiten_out(1*384-1 downto 0*384)
    ); 

    rate_white_unit2: entity work.rate_whitening(structural)
    port map(
        state_in => rate_whiten_in(2*384-1 downto 1*384),
        state_out => rate_whiten_out(2*384-1 downto 1*384)
    ); 

    rate_white_unit3: entity work.rate_whitening(structural)
    port map(
        state_in => rate_whiten_in(3*384-1 downto 2*384),
        state_out => rate_whiten_out(3*384-1 downto 2*384)
    ); 

    rate_white_unit4: entity work.rate_whitening(structural)
    port map(
        state_in => rate_whiten_in(4*384-1 downto 3*384),
        state_out => rate_whiten_out(4*384-1 downto 3*384)
    ); 

    perm_fsm: entity work.sparkle_permutation_fsm(behavioral)
    port map (
        clk => clk,
        rst => rst,
        perm_start => perm_en,
        num_steps => num_steps,
        state_in => state_sparkle_in,
        state_out => state_sparkle_out,
        perm_complete => perm_complete,
        rdi           => rdi,
        rdi_valid     => rdi_valid,
        rdi_ready     => rdi_ready
    );

    hash_feistel_function1: entity work.feistel_function(structural)
        port map(
        state_in => hash_feistel_in(1*384-1 downto 0*384),
        state_out => hash_feistel_out(1*384-1 downto 0*384)
        ); 

    hash_feistel_function2: entity work.feistel_function(structural)
        port map(
        state_in => hash_feistel_in(2*384-1 downto 1*384),
        state_out => hash_feistel_out(2*384-1 downto 1*384)
        ); 

    hash_feistel_function3: entity work.feistel_function(structural)
	port map(
        state_in => hash_feistel_in(3*384-1 downto 2*384),
        state_out => hash_feistel_out(3*384-1 downto 2*384)
        ); 

    hash_feistel_function4: entity work.feistel_function(structural)
	port map(
        state_in => hash_feistel_in(4*384-1 downto 3*384),
        state_out => hash_feistel_out(4*384-1 downto 3*384)
        ); 

-- Handle BDI
bdi_z_s0 <= ZERO_W when (zero_fill = '1') else bdi(1*CCW-1 downto 0*CCW); -- Zero fill bdi word if needed
bdi_z_s1 <= ZERO_W when (zero_fill = '1') else bdi(2*CCW-1 downto 1*CCW); 
bdi_z_s2 <= ZERO_W when (zero_fill = '1') else bdi(3*CCW-1 downto 2*CCW);
bdi_z_s3 <= ZERO_W when (zero_fill = '1') else bdi(4*CCW-1 downto 3*CCW);

bdi_p_s0 <= padWordLoc(bdi_z_s0, bdi_pad_loc) when (bdi_pad_en = '1') else bdi_z_s0; -- Pad bdi word if needed
bdi_p_s1 <= padWordLoc2(bdi_z_s1, bdi_pad_loc) when (bdi_pad_en = '1') else bdi_z_s1;   
bdi_p_s2 <= padWordLoc2(bdi_z_s2, bdi_pad_loc) when (bdi_pad_en = '1') else bdi_z_s2;   
bdi_p_s3 <= padWordLoc2(bdi_z_s3, bdi_pad_loc) when (bdi_pad_en = '1') else bdi_z_s3;   

-- Assign input key, nonce, tag, ad, and dat registers
key_reg(1*128-1 downto 0*128) <= key_0_s0 & key_1_s0 & key_2_s0 & key_3_s0;
key_reg(2*128-1 downto 1*128) <= key_0_s1 & key_1_s1 & key_2_s1 & key_3_s1;
key_reg(3*128-1 downto 2*128) <= key_0_s2 & key_1_s2 & key_2_s2 & key_3_s2;
key_reg(4*128-1 downto 3*128) <= key_0_s3 & key_1_s3 & key_2_s3 & key_3_s3;

bdi_blk(1*256-1 downto 0*256) <= bdi_0_s0 & bdi_1_s0 & bdi_2_s0 & bdi_3_s0 & bdi_4_s0 & bdi_5_s0 & bdi_6_s0 & bdi_7_s0;
bdi_blk(2*256-1 downto 1*256) <= bdi_0_s1 & bdi_1_s1 & bdi_2_s1 & bdi_3_s1 & bdi_4_s1 & bdi_5_s1 & bdi_6_s1 & bdi_7_s1;
bdi_blk(3*256-1 downto 2*256) <= bdi_0_s2 & bdi_1_s2 & bdi_2_s2 & bdi_3_s2 & bdi_4_s2 & bdi_5_s2 & bdi_6_s2 & bdi_7_s2;
bdi_blk(4*256-1 downto 3*256) <= bdi_0_s3 & bdi_1_s3 & bdi_2_s3 & bdi_3_s3 & bdi_4_s3 & bdi_5_s3 & bdi_6_s3 & bdi_7_s3;

-- Assign the intialization state input
state_init_input(1*384-1 downto 0*384) <= bdi_blk(1*256-1 downto 0*256) & key_reg(1*128-1 downto 0*128);
state_init_input(2*384-1 downto 1*384) <= bdi_blk(2*256-1 downto 1*256) & key_reg(2*128-1 downto 1*128);
state_init_input(3*384-1 downto 2*384) <= bdi_blk(3*256-1 downto 2*256) & key_reg(3*128-1 downto 2*128);
state_init_input(4*384-1 downto 3*384) <= bdi_blk(4*256-1 downto 3*256) & key_reg(4*128-1 downto 3*128);
                             
-- Pad the computed plaintext to feed back into rho
padded_zero_pt(1*256-1 downto 0*256) <= zeroFillPt(rho_ct_out_s0(383 downto 128), lword_index, bdi_valid_bytes_reg);
padded_zero_pt(2*256-1 downto 1*256) <= zeroFillPt2(rho_ct_out_s1(383 downto 128), lword_index, bdi_valid_bytes_reg);
padded_zero_pt(3*256-1 downto 2*256) <= zeroFillPt2(rho_ct_out_s2(383 downto 128), lword_index, bdi_valid_bytes_reg);
padded_zero_pt(4*256-1 downto 3*256) <= zeroFillPt2(rho_ct_out_s3(383 downto 128), lword_index, bdi_valid_bytes_reg);

-- Calculate tag
tag(1*128-1 downto 0*128) <= state_sparkle_out(0*384+127 downto 0*384) xor key_reg(1*128-1 downto 0*128);
tag(2*128-1 downto 1*128) <= state_sparkle_out(1*384+127 downto 1*384) xor key_reg(2*128-1 downto 1*128);
tag(3*128-1 downto 2*128) <= state_sparkle_out(2*384+127 downto 2*384) xor key_reg(3*128-1 downto 2*128);
tag(4*128-1 downto 3*128) <= state_sparkle_out(3*384+127 downto 3*384) xor key_reg(4*128-1 downto 3*128);

hash_feistel_in(1*384-1 downto 0*384) <= bdi_blk(0*256+127 downto 0*256) & x"0000000000000000000000000000000000000000000000000000000000000000";
hash_feistel_in(2*384-1 downto 1*384) <= bdi_blk(1*256+127 downto 1*256) & x"0000000000000000000000000000000000000000000000000000000000000000";
hash_feistel_in(3*384-1 downto 2*384) <= bdi_blk(2*256+127 downto 2*256) & x"0000000000000000000000000000000000000000000000000000000000000000";
hash_feistel_in(4*384-1 downto 3*384) <= bdi_blk(3*256+127 downto 3*256) & x"0000000000000000000000000000000000000000000000000000000000000000";

hash_constm(1*384-1 downto 0*384) <= (hash_feistel_out(1*384-1 downto 0*384+224) & (hash_feistel_out(0*384+223 downto 0*384+192) xor hash_pad_const) & hash_feistel_out(0*384+191 downto 0*384)) when (lblk_reg = '1') else hash_feistel_out(1*384-1 downto 0*384);
hash_constm(2*384-1 downto 1*384) <= (hash_feistel_out(2*384-1 downto 1*384+224) & (hash_feistel_out(1*384+223 downto 1*384+192)                   ) & hash_feistel_out(1*384+191 downto 1*384)) when (lblk_reg = '1') else hash_feistel_out(2*384-1 downto 1*384);
hash_constm(3*384-1 downto 2*384) <= (hash_feistel_out(3*384-1 downto 2*384+224) & (hash_feistel_out(2*384+223 downto 2*384+192)                   ) & hash_feistel_out(2*384+191 downto 2*384)) when (lblk_reg = '1') else hash_feistel_out(3*384-1 downto 2*384);
hash_constm(4*384-1 downto 3*384) <= (hash_feistel_out(4*384-1 downto 3*384+224) & (hash_feistel_out(3*384+223 downto 3*384+192)                   ) & hash_feistel_out(3*384+191 downto 3*384)) when (lblk_reg = '1') else hash_feistel_out(4*384-1 downto 3*384);

hash_state_in(1*384-1 downto 0*384) <= hash_constm(1*384-1 downto 0*384) when (hash_init = '1') else (hash_constm(1*384-1 downto 0*384) xor state_sparkle_out(1*384-1 downto 0*384));
hash_state_in(2*384-1 downto 1*384) <= hash_constm(2*384-1 downto 1*384) when (hash_init = '1') else (hash_constm(2*384-1 downto 1*384) xor state_sparkle_out(2*384-1 downto 1*384));
hash_state_in(3*384-1 downto 2*384) <= hash_constm(3*384-1 downto 2*384) when (hash_init = '1') else (hash_constm(3*384-1 downto 2*384) xor state_sparkle_out(3*384-1 downto 2*384));
hash_state_in(4*384-1 downto 3*384) <= hash_constm(4*384-1 downto 3*384) when (hash_init = '1') else (hash_constm(4*384-1 downto 3*384) xor state_sparkle_out(4*384-1 downto 3*384));

lblk_in <= bdi_eot and fin_hash;

-- Assign hash value
hash_value(1*256-1 downto 0*256) <= hash_value_d0(1*128-1 downto 0*128) & state_sparkle_out(1*384-1 downto 0*384+256); 
hash_value(2*256-1 downto 1*256) <= hash_value_d0(2*128-1 downto 1*128) & state_sparkle_out(2*384-1 downto 1*384+256); 
hash_value(3*256-1 downto 2*256) <= hash_value_d0(3*128-1 downto 2*128) & state_sparkle_out(3*384-1 downto 2*384+256); 
hash_value(4*256-1 downto 3*256) <= hash_value_d0(4*128-1 downto 3*128) & state_sparkle_out(4*384-1 downto 3*384+256); 

-- Flag to determine whether AD or DAT blocks are being processed 
ad_flag_in <= '1' when (bdi_type = HDR_AD) else '0';

-- MUX for sparkle input
with sparkle_in_sel select
state_sparkle_in(1*384-1 downto 0*384) <= state_init_input(1*384-1 downto 0*384)  when b"00", 
                                          rate_whiten_out(1*384-1 downto 0*384) when b"01", 
                                          hash_state_in(1*384-1 downto 0*384) when b"10", 
                                          state_sparkle_out(1*384-1 downto 0*384) when b"11", 
                                          state_init_input(1*384-1 downto 0*384) when others;
with sparkle_in_sel select
state_sparkle_in(2*384-1 downto 1*384) <= state_init_input(2*384-1 downto 1*384)  when b"00", 
                                          rate_whiten_out(2*384-1 downto 1*384) when b"01", 
                                          hash_state_in(2*384-1 downto 1*384) when b"10", 
                                          state_sparkle_out(2*384-1 downto 1*384) when b"11", 
                                          state_init_input(2*384-1 downto 1*384) when others;                 
with sparkle_in_sel select
state_sparkle_in(3*384-1 downto 2*384) <= state_init_input(3*384-1 downto 2*384)  when b"00", 
                                          rate_whiten_out(3*384-1 downto 2*384) when b"01", 
                                          hash_state_in(3*384-1 downto 2*384) when b"10", 
                                          state_sparkle_out(3*384-1 downto 2*384) when b"11", 
                                          state_init_input(3*384-1 downto 2*384) when others; 
with sparkle_in_sel select
state_sparkle_in(4*384-1 downto 3*384) <= state_init_input(4*384-1 downto 3*384)  when b"00", 
                                          rate_whiten_out(4*384-1 downto 3*384) when b"01", 
                                          hash_state_in(4*384-1 downto 3*384) when b"10", 
                                          state_sparkle_out(4*384-1 downto 3*384) when b"11", 
                                          state_init_input(4*384-1 downto 3*384) when others; 
										  
-- MUX for rho state input
with rho_rate_in_sel select
rho_rate_in(1*256-1 downto 0*256) <= bdi_blk(1*256-1 downto 0*256) when '0',
                              padded_zero_pt(1*256-1 downto 0*256) when '1',
                                     bdi_blk(1*256-1 downto 0*256) when others;
with rho_rate_in_sel select
rho_rate_in(2*256-1 downto 1*256) <= bdi_blk(2*256-1 downto 1*256) when '0',
                              padded_zero_pt(2*256-1 downto 1*256) when '1',
                                     bdi_blk(2*256-1 downto 1*256) when others;
with rho_rate_in_sel select
rho_rate_in(3*256-1 downto 2*256) <= bdi_blk(3*256-1 downto 2*256) when '0',
                              padded_zero_pt(3*256-1 downto 2*256) when '1',
                                     bdi_blk(3*256-1 downto 2*256) when others;
with rho_rate_in_sel select
rho_rate_in(4*256-1 downto 3*256) <= bdi_blk(4*256-1 downto 3*256) when '0',
                              padded_zero_pt(4*256-1 downto 3*256) when '1',
                                     bdi_blk(4*256-1 downto 3*256) when others;									 
-- MUX for inject constant input       
with inj_const_in_sel select
inj_const_in(1*384-1 downto 0*384) <= rho_out(1*384-1 downto 0*384) when '0',
                                  inv_rho_out(1*384-1 downto 0*384) when '1',
                                      rho_out(1*384-1 downto 0*384) when others;
with inj_const_in_sel select
inj_const_in(2*384-1 downto 1*384) <= rho_out(2*384-1 downto 1*384) when '0',
                                  inv_rho_out(2*384-1 downto 1*384) when '1',
                                      rho_out(2*384-1 downto 1*384) when others;
with inj_const_in_sel select
inj_const_in(3*384-1 downto 2*384) <= rho_out(3*384-1 downto 2*384) when '0',
                                  inv_rho_out(3*384-1 downto 2*384) when '1',
                                      rho_out(3*384-1 downto 2*384) when others;  
with inj_const_in_sel select
inj_const_in(4*384-1 downto 3*384) <= rho_out(4*384-1 downto 3*384) when '0',
                                  inv_rho_out(4*384-1 downto 3*384) when '1',
                                      rho_out(4*384-1 downto 3*384) when others;  									  
-- MUX for Sparkle number of steps
with lblk_reg select
num_steps <= STEPS_BIG when '1',
             STEPS_SMALL when '0',
             0 when others;

-- MUX for rate whiten input selection
with lblk_reg select
rate_whiten_in(1*384-1 downto 0*384) <= inj_const_in(1*384-1 downto 0*384) when '0', 
                                        inj_const_out(1*384-1 downto 0*384) when '1', 
                                        inj_const_in(1*384-1 downto 0*384) when others;
with lblk_reg select
rate_whiten_in(2*384-1 downto 1*384) <= inj_const_in(2*384-1 downto 1*384) when '0', 
                                        inj_const_out(2*384-1 downto 1*384) when '1', 
                                        inj_const_in(2*384-1 downto 1*384) when others;
with lblk_reg select
rate_whiten_in(3*384-1 downto 2*384) <= inj_const_in(3*384-1 downto 2*384) when '0', 
                                        inj_const_out(3*384-1 downto 2*384) when '1', 
                                        inj_const_in(3*384-1 downto 2*384) when others; 
with lblk_reg select
rate_whiten_in(4*384-1 downto 3*384) <= inj_const_in(4*384-1 downto 3*384) when '0', 
                                        inj_const_out(4*384-1 downto 3*384) when '1', 
                                        inj_const_in(4*384-1 downto 3*384) when others; 										
-- MUX for pad constant select
with pad_const_sel select
pad_const <= PAD_AD_CONST when b"00", 
             NO_PAD_AD_CONST when b"01", 
             PAD_PT_CONST when b"10", 
             NO_PAD_PT_CONST when b"11", 
             ZERO_W when others;

-- MUX for hash constant select
with hash_pad_const_sel select
hash_pad_const <= NO_PAD_HASH_CONST when '0', 
                  PAD_HASH_CONST when '1',
                  ZERO_W when others;

-- MUX for bdo output (dat, tag, or hash)
with bdo_out_sel select
bdo_out_reg(1*256-1 downto 0*256) <= rho_ct_out_s0(383 downto 128) when b"00", 
                                     (tag(1*128-1 downto 0*128) & x"00000000000000000000000000000000") when b"01",
                                     hash_value(1*256-1 downto 0*256) when b"10",
                                     hash_value(1*256-1 downto 0*256) when others;
with bdo_out_sel select
bdo_out_reg(2*256-1 downto 1*256) <= rho_ct_out_s1(383 downto 128) when b"00", 
                                     (tag(2*128-1 downto 1*128) & x"00000000000000000000000000000000") when b"01",
                                     hash_value(2*256-1 downto 1*256) when b"10",
                                     hash_value(2*256-1 downto 1*256) when others;
with bdo_out_sel select
bdo_out_reg(3*256-1 downto 2*256) <= rho_ct_out_s2(383 downto 128) when b"00", 
                                     (tag(3*128-1 downto 2*128) & x"00000000000000000000000000000000") when b"01",
                                     hash_value(3*256-1 downto 2*256) when b"10",
                                     hash_value(3*256-1 downto 2*256) when others; 
with bdo_out_sel select
bdo_out_reg(4*256-1 downto 3*256) <= rho_ct_out_s3(383 downto 128) when b"00", 
                                     (tag(4*128-1 downto 3*128) & x"00000000000000000000000000000000") when b"01",
                                     hash_value(4*256-1 downto 3*256) when b"10",
                                     hash_value(4*256-1 downto 3*256) when others; 
									 
-- MUX for bdo output (which word)
with word_counter select
bdo_current_s0 <= bdo_out_reg(0*256+255 downto 0*256+224) when 0, 
                  bdo_out_reg(0*256+223 downto 0*256+192) when 1,
                  bdo_out_reg(0*256+191 downto 0*256+160) when 2,
                  bdo_out_reg(0*256+159 downto 0*256+128) when 3,
                  bdo_out_reg(0*256+127 downto 0*256+96) when 4,
                  bdo_out_reg(0*256+95 downto 0*256+64) when 5,
                  bdo_out_reg(0*256+63 downto 0*256+32) when 6,
                  bdo_out_reg(0*256+31 downto 0*256+0) when 7,
                  ZERO_W when others;
 
with word_counter select
bdo_current_s1 <= bdo_out_reg(1*256+255 downto 1*256+224) when 0, 
                  bdo_out_reg(1*256+223 downto 1*256+192) when 1,
                  bdo_out_reg(1*256+191 downto 1*256+160) when 2,
                  bdo_out_reg(1*256+159 downto 1*256+128) when 3,
                  bdo_out_reg(1*256+127 downto 1*256+96) when 4,
                  bdo_out_reg(1*256+95 downto 1*256+64) when 5,
                  bdo_out_reg(1*256+63 downto 1*256+32) when 6,
                  bdo_out_reg(1*256+31 downto 1*256+0) when 7,
                  ZERO_W when others; 

with word_counter select
bdo_current_s2 <= bdo_out_reg(2*256+255 downto 2*256+224) when 0, 
                  bdo_out_reg(2*256+223 downto 2*256+192) when 1,
                  bdo_out_reg(2*256+191 downto 2*256+160) when 2,
                  bdo_out_reg(2*256+159 downto 2*256+128) when 3,
                  bdo_out_reg(2*256+127 downto 2*256+96) when 4,
                  bdo_out_reg(2*256+95 downto 2*256+64) when 5,
                  bdo_out_reg(2*256+63 downto 2*256+32) when 6,
                  bdo_out_reg(2*256+31 downto 2*256+0) when 7,
                  ZERO_W when others;   

with word_counter select
bdo_current_s3 <= bdo_out_reg(3*256+255 downto 3*256+224) when 0, 
                  bdo_out_reg(3*256+223 downto 3*256+192) when 1,
                  bdo_out_reg(3*256+191 downto 3*256+160) when 2,
                  bdo_out_reg(3*256+159 downto 3*256+128) when 3,
                  bdo_out_reg(3*256+127 downto 3*256+96) when 4,
                  bdo_out_reg(3*256+95 downto 3*256+64) when 5,
                  bdo_out_reg(3*256+63 downto 3*256+32) when 6,
                  bdo_out_reg(3*256+31 downto 3*256+0) when 7,
                  ZERO_W when others; 
				  
-- MUX for bdo output valid bytes (all valid or bdi valid reg)
with valid_bytes_sel select
bdo_valid_bytes <= VALID_WORD when '0', 
                   bdi_valid_bytes_reg when '1',
                   VALID_WORD when others;

register_input: process(clk, key_reg_en, bdi_reg_en, bdo_en, key_s0, key_s1, key_s2, bdi_p_s0, bdi_p_s1, bdi_p_s2, bdo_current_s0, bdo_current_s1, bdo_current_s2)
begin
	if (rising_edge(clk)) then
        if (key_reg_en = '1') then       
            key_3_s0 <= littleEndianWord(key_s0);
            key_2_s0 <= key_3_s0;
            key_1_s0 <= key_2_s0;
            key_0_s0 <= key_1_s0;

            key_3_s1 <= littleEndianWord(key_s1);
            key_2_s1 <= key_3_s1;
            key_1_s1 <= key_2_s1;
            key_0_s1 <= key_1_s1;
			
			key_3_s2 <= littleEndianWord(key_s2);
            key_2_s2 <= key_3_s2;
            key_1_s2 <= key_2_s2;
            key_0_s2 <= key_1_s2;
			
			key_3_s3 <= littleEndianWord(key_s3);
            key_2_s3 <= key_3_s3;
            key_1_s3 <= key_2_s3;
            key_0_s3 <= key_1_s3;			
        end if;
        if (bdi_reg_en = '1') then
            bdi_7_s0 <= littleEndianWord(bdi_p_s0);
            bdi_6_s0 <= bdi_7_s0;
            bdi_5_s0 <= bdi_6_s0;
            bdi_4_s0 <= bdi_5_s0;
            bdi_3_s0 <= bdi_4_s0;
            bdi_2_s0 <= bdi_3_s0;
            bdi_1_s0 <= bdi_2_s0;
            bdi_0_s0 <= bdi_1_s0;
            
            bdi_7_s1 <= littleEndianWord(bdi_p_s1);
            bdi_6_s1 <= bdi_7_s1;
            bdi_5_s1 <= bdi_6_s1;
            bdi_4_s1 <= bdi_5_s1;
            bdi_3_s1 <= bdi_4_s1;
            bdi_2_s1 <= bdi_3_s1;
            bdi_1_s1 <= bdi_2_s1;
            bdi_0_s1 <= bdi_1_s1;            

            bdi_7_s2 <= littleEndianWord(bdi_p_s2);
            bdi_6_s2 <= bdi_7_s2;
            bdi_5_s2 <= bdi_6_s2;
            bdi_4_s2 <= bdi_5_s2;
            bdi_3_s2 <= bdi_4_s2;
            bdi_2_s2 <= bdi_3_s2;
            bdi_1_s2 <= bdi_2_s2;
            bdi_0_s2 <= bdi_1_s2;

            bdi_7_s3 <= littleEndianWord(bdi_p_s3);
            bdi_6_s3 <= bdi_7_s3;
            bdi_5_s3 <= bdi_6_s3;
            bdi_4_s3 <= bdi_5_s3;
            bdi_3_s3 <= bdi_4_s3;
            bdi_2_s3 <= bdi_3_s3;
            bdi_1_s3 <= bdi_2_s3;
            bdi_0_s3 <= bdi_1_s3;
		end if;
		
        if (bdo_en = '1') then
            bdo(1*CCW-1 downto 0*CCW) <= littleEndianWord(bdo_current_s0);
            bdo(2*CCW-1 downto 1*CCW) <= littleEndianWord(bdo_current_s1);
            bdo(3*CCW-1 downto 2*CCW) <= littleEndianWord(bdo_current_s2);
            bdo(4*CCW-1 downto 3*CCW) <= littleEndianWord(bdo_current_s3);
		end if;
    end if;
end process;

compare_tag: process(comp_tag, tag, tag_reg_unshared, bdi_blk, bdi_blk_reg_unshared)
begin
    tag_reg <= (others => '0');
    bdi_blk_reg <= (others => '0');
    msg_auth <= '0';                    -- Default
    if (comp_tag = '1') then            -- Perform tag comparison
        tag_reg <= tag(1*128-1 downto 0*128) & tag(2*128-1 downto 1*128) & tag(3*128-1 downto 2*128) & tag(4*128-1 downto 3*128);
        bdi_blk_reg <= bdi_blk(0*256+127 downto 0*256) & bdi_blk(1*256+127 downto 1*256) & bdi_blk(2*256+127 downto 2*256) & bdi_blk(3*256+127 downto 3*256);
        
        if (tag_reg_unshared = bdi_blk_reg_unshared) then
            msg_auth <= '1';
        end if;
	end if;
end process;

counter_process: process(clk, word_cntr_en, word_cntr_init, word_counter)
begin
    if (rising_edge(clk)) then
        if (word_cntr_en = '1') then
            if (word_cntr_init = '1') then
                word_counter <= 0;
            else
                word_counter <= word_counter + 1;
            end if;
        else 
            word_counter <= 0;
		end if;
	end if;
end process;
	
sync_process: process(clk, rst, next_state)
begin
    if (rising_edge(clk)) then
        if (rst = '1') then
           current_state <= IDLE;
        else
           current_state <= next_state;
        end if;
    end if;
end process;

fsm_process: process(ad_flag, current_state, key_update, key_valid, bdi_valid, bdi_type, bdi_size, bdi_pad_reg, lblk_reg, perm_complete, num_steps, word_counter, bdi_eot, hash_reg, eoi_reg, dec_reg, lword_index)
begin
 
    -- DEFAULTS:
    next_state <= current_state;            -- Default return to current state 
    perm_en <= '0';                         -- Sparkle permutation start flag
    comp_tag <= '0';                        -- Signal to enable tag comparison
    
    bdo_en <= '0';                          -- Output to postprocessor
    msg_auth_valid <= '0';
    end_of_block <= '0';
    bdo_valid <= '0';
    
    key_ready <= '0';                       -- Output to preprocessor
    bdi_ready <= '0';
    
    bdi_pad_en <= '0';                      -- BDI/SDI signals
    zero_fill <= '0';
    bdi_reg_en <= '0';
    key_reg_en <= '0';
    
    word_cntr_init <= '0';                  -- Word counter
    word_cntr_en <= '0';
    
    store_lblk <= '0';                      -- Signals to enable storage
    store_dec <= '0';
    store_ad_flag <= '0';
    store_pad_en <= '0';
    
    rho_rate_in_sel <= '0';                 -- MUX select signals
    inj_const_in_sel <= '0';
    pad_const_sel <= b"00";
    sparkle_in_sel <= b"00";
    bdo_out_sel <= b"00";
    valid_bytes_sel <= '0';
    
    store_hash <= '0';                      -- Hash signals
    store_hash_d0 <= '0';
    store_hash_init <= '0';
    hash_init_val <= '0';
    hash_pad_const_sel <= '0';
    fin_hash <= '1';
        
    case current_state is
                     
        when IDLE => 
            store_pad_en <= '1';
            if (key_update = '1') then
                if (key_valid = '1') then
                    next_state <= LOAD_KEY;
                end if;
            elsif (bdi_valid = '1') then
                if (bdi_type = HDR_NPUB) then
                    next_state <= LOAD_NPUB;
                elsif (bdi_type = HDR_HASH_MSG) then
                    store_hash_init <= '1';
                    hash_init_val <= '1';
                    store_hash <= '1';                          -- Store hash signal
                    next_state <= LOAD_HASH;
                end if;
            end if;
        
        when LOAD_KEY => 
            key_ready <= '1';                           -- Set output key ready signal
            key_reg_en <= '1';                          -- Enable storage of each word
            word_cntr_en <= '1';                        -- Keep word counter enabled while loading key
            
            if (word_counter = KEY_SIZE - 1) then
                word_cntr_init <= '1';                  -- Reset counter value to 0
                next_state <= IDLE;                     -- Return to IDLE to wait for NPUB
            end if;
        
        when LOAD_NPUB => 
            bdi_ready <= '1';                           -- Set output bdi ready signal
            bdi_reg_en <= '1';                          -- Enable storage of each word
            word_cntr_en <= '1';                        -- Keep word counter enabled while loading NPUB
            store_lblk <= '1';                          -- Enable storage of last block
            
            if (word_counter = BLK_SIZE - 1) then
                word_cntr_init <= '1';                  -- Reset counter value to 0
                store_dec <= '1';                       -- Enable storage of decrypt flag
                next_state <= START_PERM_INIT;
            end if;
        
        when START_PERM_INIT =>                         -- Handle starting permutation for initialization
            perm_en <= '1';                             -- Start permutation            
            next_state <= WAIT_PERM;                    -- Update state to wait for completion
            
        when WAIT_PERM => 
            if (perm_complete = '1') then               -- Wait for completion
                if (hash_reg = '1') then
                    if (bdi_valid = '1') and (bdi_size /= b"000") and (lblk_reg /= '1') then
                        next_state <= LOAD_HASH;
                    else
                        next_state <= FINALIZE_HASH_OUT;
                        sparkle_in_sel <= b"11";
                        fin_hash <= '0';
                        perm_en <= '1';
                        store_hash_d0 <= '1';           -- Store the state for use in finalization
                        store_lblk <= '1';              -- Enable last block to reset to STEPS_SMALL for finalization
                    end if;
                elsif (eoi_reg = '1') then              -- If end of input, handle tag based on enc or dec
                    if (dec_reg = '1') then
                        next_state <= LOAD_TAG;         -- If dec, then load tag from input
                    else
                        next_state <= OUTPUT_TAG;       -- If enc, then transition to outputting calculated tag
                        bdo_out_sel <= b"01";             -- Select TAG for BDO output
                        word_cntr_en <= '1';            -- Enable word counter
                        bdo_en <= '1';                  -- Enable bdo output
                    end if;
                else                                    -- If NOT end of input, transition to loading AD or DAT
                    if (bdi_valid = '1') then
                        next_state <= LOAD_BLK;
                        store_ad_flag <= '1';           -- Store whether input is AD or DAT
                        store_pad_en <= '1';            -- Reset padding
                    end if;
                end if;
            end if;
              
        when LOAD_BLK => 
            bdi_ready <= '1';                           -- Set output bdi ready signal
            bdi_reg_en <= '1';                          -- Enable storage of each word
            word_cntr_en <= '1';                        -- Keep word counter enabled while loading blk
            store_lblk <= '1';                          -- Enable storage of last block
            
            -- Handle padding of current word
            if (bdi_valid_bytes /= VALID_WORD) then
                bdi_pad_en <= '1';                      -- If the current block is not all valid, enable padding
                store_pad_en <= '1';
            end if;
            
            -- Handle end of input block
            if (word_counter = BLK_SIZE - 1) then       -- Full block loaded
                word_cntr_init <= '1';                  -- Reset counter value to 0
                if (ad_flag = '1') then                 -- If handling AD, start permutation
                    next_state <= START_PERM;
                else
                    next_state <= FINALIZE_DAT_OUT;     -- If handling DAT, finalize output
                end if;
            elsif (bdi_eot = '1') then                  -- Block still loading, handle incomplete last input block
                next_state <= LOAD_BLK_ZERO;            -- Update state to zero fill
            end if;
        
        when LOAD_BLK_ZERO => 
            bdi_reg_en <= '1';                          -- Enable storage of each word
            word_cntr_en <= '1';                        -- Keep word counter enabled while loading ad
            zero_fill <= '1';                           -- Enable zero fill for the rest of block
            
            -- Check previous word validity
            if (bdi_valid_bytes = VALID_WORD) then
                bdi_pad_en <= '1';                      -- Enable padding of zero-filled word
                store_pad_en <= '1';                    -- Store the padding flag
            end if;

            if (word_counter = BLK_SIZE - 1) then       -- Full block loaded
                word_cntr_init <= '1';                  -- Reset counter value to 0
                if (ad_flag = '1') then                 -- If handling AD, start permutation
                    next_state <= START_PERM;
                else
                    next_state <= FINALIZE_DAT_OUT;     -- If handling DAT, finalize output
                end if;
            end if;
                    
        when START_PERM =>
            store_hash_init <= '1';
            if (hash_reg = '1') then
                sparkle_in_sel <= b"10";
            else
                sparkle_in_sel <= b"01";                -- Select rate whitening output as state input
            end if;
            perm_en <= '1';                             -- Start permutation
            next_state <= WAIT_PERM;                    -- Update state to wait for completion

            -- Select the correct pad constant
            if (ad_flag = '1') then
                if (bdi_pad_reg = '1') then
                    pad_const_sel <= b"00";             -- Update pad constant select: PAD AD
                else
                    pad_const_sel <= b"01";             -- Update pad constant select: NO PAD AD
                end if;
            else
                if (bdi_pad_reg = '1') then
                    pad_const_sel <= b"10";             -- Update pad constant select: PAD DAT
                else
                    pad_const_sel <= b"11";             -- Update pad constant select: NO PAD DAT
                end if;
            end if;
            
            if (bdi_pad_reg = '1') then
                hash_pad_const_sel <= '1';             -- Update pad constant select: PAD HASH
            end if;
            
            -- If decrypting completely valid full block use inv rho, else use rho with padded PT input
            -- Must be handling DAT blocks
            if (dec_reg = '1') then
                if (ad_flag /= '1') then
                    if (bdi_pad_reg = '0') then
                        inj_const_in_sel <= '1';
                    else
                        rho_rate_in_sel <= '1';
                    end if;
                end if;
            end if;
            
        when FINALIZE_DAT_OUT => 
            bdo_en <= '1';                              -- Enable output
            word_cntr_en <= '1';                        -- Enable word counter
            next_state <= OUTPUT_DAT_BLK;
            
        when OUTPUT_DAT_BLK => 
            bdo_en <= '1';                              -- Enable output
            word_cntr_en <= '1';                        -- Keep word counter enabled while outputting data
            bdo_valid <= '1';
   
            if (word_counter = lword_index + 1) then    -- End of block
                bdo_en <= '0';                          -- Enable output
                valid_bytes_sel <= '1';                 -- Select bdi valid bytes reg for last word 
                end_of_block <= '1';                    -- Indicate end of output block
                word_cntr_init <= '1';                  -- Reset counter value to 0
                next_state <= START_PERM;
            end if;
            
        when LOAD_TAG => 
            bdi_ready <= '1';                           -- Set output bdi ready signal
            bdi_reg_en <= '1';                          -- Enable storage of each word
            word_cntr_en <= '1';                        -- Keep word counter enabled while loading tag
            
            if (word_counter = TAG_SIZE2 - 1) then
                word_cntr_init <= '1';                  -- Reset counter value to 0
                next_state <= VERIFY_TAG;
            end if;
                      
        when OUTPUT_TAG =>            
            bdo_out_sel <= b"01";                         -- Select TAG for BDO output
            bdo_en <= '1';                              -- Enable output
            word_cntr_en <= '1';                        -- Keep word counter enabled while outputting data
            bdo_valid <= '1';
                        
            if (word_counter = TAG_SIZE2) then          
                end_of_block <= '1';                    -- Indicate end of output tag block
                word_cntr_init <= '1';                  -- Reset counter value to 0
                next_state <= IDLE;
            end if;
        
        when VERIFY_TAG => 
            msg_auth_valid <= '1';                      -- Indicate msg auth output is valid
            comp_tag <= '1';                            -- Enable tag comparison
            next_state <= IDLE;                         -- Return to IDLE state
            
        when LOAD_HASH => 
            bdi_ready <= '1';                           -- Set output bdi ready signal
            bdi_reg_en <= '1';                          -- Enable storage of each word
            word_cntr_en <= '1';                        -- Keep word counter enabled while loading blk
            store_lblk <= '1';                          -- Enable storage of last block
            
            -- Handle padding of current word
            if (bdi_valid_bytes /= VALID_WORD) then
                bdi_pad_en <= '1';                      -- If the current block is not all valid, enable padding
                store_pad_en <= '1';
            end if;
            
            -- Handle end of input block
            if (word_counter = HASH_BLK_SIZE - 1) then  -- Full block loaded
                word_cntr_init <= '1';                  -- Reset counter value to 0
                next_state <= START_PERM;
            elsif (bdi_eot = '1') then                  -- Block still loading, handle incomplete last input block
                next_state <= LOAD_HASH_ZERO;            -- Update state to zero fill
            end if;
        
        when LOAD_HASH_ZERO => 
            bdi_reg_en <= '1';                          -- Enable storage of each word
            word_cntr_en <= '1';                        -- Keep word counter enabled while loading ad
            zero_fill <= '1';                           -- Enable zero fill for the rest of block
            
            -- Check previous word validity
            if (bdi_valid_bytes = VALID_WORD) then
                bdi_pad_en <= '1';                      -- Enable padding of zero-filled word
                store_pad_en <= '1';                    -- Store the padding flag
            end if;

            if (word_counter = HASH_BLK_SIZE - 1) then       -- Full block loaded
                word_cntr_init <= '1';                  -- Reset counter value to 0
                next_state <= START_PERM;
            end if;
        
        when FINALIZE_HASH_OUT => 
            fin_hash <= '0';
            sparkle_in_sel <= b"11";                    -- Select state output for sparkle input
            if (perm_complete = '1') and (num_steps = 7) then     
                bdo_out_sel <= b"10";                   -- Select hash for BDO output
                bdo_en <= '1';                          -- Enable output
                word_cntr_en <= '1';                    -- Enable word counter
                next_state <= OUTPUT_HASH;
            end if;
        
        when OUTPUT_HASH =>       
            bdo_out_sel <= b"10";                       -- Select hash for BDO output
            bdo_en <= '1';                              -- Enable output
            bdo_valid <= '1';                           -- Set bdo valid flag
            word_cntr_en <= '1';                        -- Keep word counter enabled while outputting hash
            store_hash <= '1';
            
            if (word_counter = HASH_SIZE) then
                end_of_block <= '1';                    -- Indicate end of output tag block
                word_cntr_init <= '1';                  -- Reset counter value to 0
                next_state <= IDLE;
            end if;
            
        when others =>
            next_state <= IDLE;
            
    end case; 

end process;
end behavioral;
