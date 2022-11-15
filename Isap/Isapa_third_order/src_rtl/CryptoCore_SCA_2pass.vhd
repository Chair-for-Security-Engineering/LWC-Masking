--------------------------------------------------------------------------------
--   ____                  _           ____                         ___ ____    _    ____  
--  / ___|_ __ _   _ _ __ | |_ ___    / ___|___  _ __ ___          |_ _/ ___|  / \  |  _ \ 
-- | |   | '__| | | | '_ \| __/ _ \  | |   / _ \| '__/ _ \  _____   | |\___ \ / _ \ | |_) |
-- | |___| |  | |_| | |_) | || (_) | | |__| (_) | | |  __/ |_____|  | | ___) / ___ \|  __/ 
--  \____|_|   \__, | .__/ \__\___/   \____\___/|_|  \___|         |___|____/_/   \_\_|    
--	           |___/|_|                                                                    
-- 
--------------------------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE ieee.std_logic_misc.ALL;
USE work.NIST_LWAPI_pkg.ALL;
USE work.isap_pkg.ALL;
USE work.design_pkg.ALL;


ENTITY CryptoCore_SCA_2pass IS
	PORT (
		clk : IN STD_LOGIC;
		rst : IN STD_LOGIC;
		-----------------------------------------------------------------------
		-- Pre-Proecessor
		-----------------------------------------------------------------------
		-- Key
		key : IN STD_LOGIC_VECTOR (SDI_SHARES * CCSW - 1 DOWNTO 0);
		key_valid : IN STD_LOGIC;
		key_ready : OUT STD_LOGIC;
		-- Data
		bdi : IN STD_LOGIC_VECTOR (PDI_SHARES * CCW - 1 DOWNTO 0);
		bdi_valid : IN STD_LOGIC;
		bdi_ready : OUT STD_LOGIC;
		bdi_pad_loc : IN STD_LOGIC_VECTOR (CCWdiv8 - 1 DOWNTO 0);
		bdi_valid_bytes : IN STD_LOGIC_VECTOR (CCWdiv8 - 1 DOWNTO 0);
		bdi_size : IN STD_LOGIC_VECTOR (3 - 1 DOWNTO 0);
		bdi_eot : IN STD_LOGIC;
		bdi_eoi : IN STD_LOGIC;
		bdi_type : IN STD_LOGIC_VECTOR (4 - 1 DOWNTO 0);
		decrypt_in : IN STD_LOGIC;
		key_update : IN STD_LOGIC;
		hash_in : IN std_logic;
		-----------------------------------------------------------------------
		-- Post-Proecessor
		-----------------------------------------------------------------------
		bdo : OUT STD_LOGIC_VECTOR (PDI_SHARES * CCW - 1 DOWNTO 0);
		bdo_valid : OUT STD_LOGIC;
		bdo_ready : IN STD_LOGIC;
		bdo_type : OUT STD_LOGIC_VECTOR (4 - 1 DOWNTO 0);
		bdo_valid_bytes : OUT STD_LOGIC_VECTOR (CCWdiv8 - 1 DOWNTO 0);
		end_of_block : OUT STD_LOGIC;
		-- decrypt_out : OUT STD_LOGIC;
		msg_auth_valid : OUT STD_LOGIC;
		msg_auth_ready : IN STD_LOGIC;
		msg_auth : OUT STD_LOGIC;
		rdi             : in  std_logic_vector(RW - 1 downto 0);
        rdi_valid       : in  std_logic;
        rdi_ready       : out std_logic;
		-----------------------------------------------------------------------
		-- Two-Pass-FIFO
		-----------------------------------------------------------------------
        fdi_data         : in std_logic_vector(PDI_SHARES * CCW - 1 downto 0);
        fdi_valid        : in std_logic;
        fdi_ready        : out std_logic;
        fdo_data         : out std_logic_vector(PDI_SHARES * CCW - 1 downto 0);
        fdo_valid        : out std_logic;
        fdo_ready        : in  std_logic
	);
END CryptoCore_SCA_2pass;

ARCHITECTURE behavioral OF CryptoCore_SCA_2pass IS
    component Asconp_HPC2_ClockGating_d3 is
        port(
            clk : in std_logic;
            state_in_s0 : in std_logic_vector (319 downto 0);
            state_in_s1 : in std_logic_vector (319 downto 0);
            state_in_s2 : in std_logic_vector (319 downto 0);
            state_in_s3 : in std_logic_vector (319 downto 0);
			state_out_s0 : out std_logic_vector (319 downto 0);
            state_out_s1 : out std_logic_vector (319 downto 0);
            state_out_s2 : out std_logic_vector (319 downto 0);
            state_out_s3 : out std_logic_vector (319 downto 0);			
			rcon : in std_logic_vector (3 downto 0);
            fresh : in std_logic_vector (1919 downto 0)
        );
    end component;

    SIGNAL isap_state_cur_word_s_reg : std_logic_vector(PDI_SHARES * CCW - 1 DOWNTO 0);
    SIGNAL isap_state_cur_word_s_reg_unshared : std_logic_vector(CCW - 1 DOWNTO 0);
    SIGNAL bdi_s_reg : std_logic_vector(PDI_SHARES * CCW - 1 DOWNTO 0);
    SIGNAL bdi_s_reg_unshared : std_logic_vector(CCW - 1 DOWNTO 0);    
	---------------------------------------------------------------------------
	--! Constant Values
	---------------------------------------------------------------------------

	-- Number of words the respective blocks contain.
	CONSTANT NPUB_WORDS_C : INTEGER := get_words(p_k, CCW);
	CONSTANT BLOCK_WORDS_C : INTEGER := get_words(p_rH, CCW);
	CONSTANT TAG_WORDS_C : INTEGER := get_words(p_k, CCW);
	CONSTANT KEY_WORDS_C : INTEGER := get_words(p_k, CCW);
    CONSTANT STATE_WORDS_C : INTEGER := get_words(p_n, CCW);

	---------------------------------------------------------------------------
	--! State Signals
	---------------------------------------------------------------------------
    TYPE state_t IS (IDLE,
    STORE_KEY,
    STORE_NONCE,
    WAIT_INPUT_TYPE,
    ISAP_RK_SETUP_STATE,
    ISAP_RK_INITIALIZE,
    ISAP_RK_REKEYING,
    ISAP_RK_SQUEEZE,
    ISAP_ENC_INITIALIZE,
    ISAP_ENC_PERMUTE_PE,
    ISAP_ENC_SEND_CT,
    ISAP_MAC_SETUP_STATE,
    ISAP_MAC_INITIALIZE,
    ISAP_MAC_WAIT_INPUT,
    ISAP_MAC_ABSORB_AD,
    ISAP_MAC_PROCESS_AD,
    ISAP_MAC_ABSORB_AD_PAD,
    ISAP_MAC_DOMAIN_SEPERATION,
    ISAP_MAC_ABSORB_CT,
    ISAP_MAC_PROCESS_CT,
    ISAP_MAC_ABSORB_CT_PAD,
    ISAP_MAC_FINALIZE_AFTER_RK_STATE_SETUP,
    ISAP_MAC_FINALIZE_PERMUTE_PH,
    ISAP_ENC_SQUEEZE_BLOCK,
    EXTRACT_TAG,
    VERIFY_TAG,
    WAIT_ACK,
    HASH_SETUP_STATE,
    EXTRACT_HASH_VALUE);
	SIGNAL n_state_s, state_s : state_t;

	TYPE isap_encmac_t IS (ISAP_ENC, ISAP_MAC);
	SIGNAL isap_encmac_s : isap_encmac_t;

	TYPE isap_auth_t IS (AUTH_ENC, AUTH_DEC);
	SIGNAL isap_auth_encdec_s, n_isap_auth_encdec_s : isap_auth_t;

	---------------------------------------------------------------------------
	--! Internal Signals
	---------------------------------------------------------------------------
	-- Index of current word in the state.
	SIGNAL word_idx_s : INTEGER RANGE 0 TO KEY_WORDS_C;

	-- Internal port signals: Input
	SIGNAL key_s : std_logic_vector(SDI_SHARES * CCSW - 1 DOWNTO 0);

	SIGNAL key_ready_s : std_logic;
	SIGNAL bdi_ready_s : std_logic;
	SIGNAL bdi_s : std_logic_vector(PDI_SHARES * CCW - 1 DOWNTO 0);
	
	SIGNAL bdi_valid_bytes_s : std_logic_vector(CCWdiv8 - 1 DOWNTO 0);

	-- Internal port signals: Output
	SIGNAL bdo_s : std_logic_vector(PDI_SHARES * CCW - 1 DOWNTO 0);
	SIGNAL bdo_valid_bytes_s : std_logic_vector(CCWdiv8 - 1 DOWNTO 0);
	SIGNAL bdo_valid_s : std_logic;
	SIGNAL bdo_type_s : std_logic_vector(3 DOWNTO 0);
	SIGNAL end_of_block_s : std_logic;
	SIGNAL msg_auth_valid_s : std_logic;
    SIGNAL bdi_pad_loc_s : std_logic_vector(CCWdiv8 - 1 DOWNTO 0);
    SIGNAL bdoo_s : std_logic_vector(PDI_SHARES * CCW - 1 DOWNTO 0);

	-- Internal flags
	SIGNAL n_msg_auth_s, msg_auth_s : std_logic;
	SIGNAL n_update_key_s, update_key_s : std_logic;
	SIGNAL n_eoi_s, eoi_s : std_logic;
	SIGNAL n_eot_s, eot_s : std_logic;
	SIGNAL n_fifo_words_s, fifo_words_s : INTEGER RANGE 0 TO 65535;
    SIGNAL n_empty_hash_s, empty_hash_s : std_logic;
    SIGNAL n_hash_s, hash_s : std_logic;
        
	-- ISAP
	SIGNAL isap_state_s : std_logic_vector(PDI_SHARES * p_n - 1 DOWNTO 0);
	SIGNAL isap_state_s_s0, isap_state_s_s1, isap_state_s_s2, isap_state_s_s3 : std_logic_vector(p_k - 1 DOWNTO 0);
    SIGNAL isap_state_n_s : std_logic_vector(PDI_SHARES * p_n - 1 DOWNTO 0);
	SIGNAL isap_cnt_s : std_logic_vector(7 DOWNTO 0); 
	SIGNAL delay_cnt_s : std_logic_vector(1 DOWNTO 0);
	SIGNAL isap_cnt_y_s : integer RANGE 0 TO 127;
	SIGNAL isap_key_s : std_logic_vector(PDI_SHARES * p_k - 1 DOWNTO 0);
	SIGNAL isap_nonce_s : std_logic_vector(PDI_SHARES * p_k - 1 DOWNTO 0);
	SIGNAL isap_y_s : std_logic_vector(PDI_SHARES * p_k - 1 DOWNTO 0);
	SIGNAL isap_buf_s : std_logic_vector(PDI_SHARES * (p_n - p_k) - 1 DOWNTO 0);
	SIGNAL isap_ctrl_s : std_logic_vector(3 DOWNTO 0);

	-- FIFO
	SIGNAL fifo_din_s : std_logic_vector(PDI_SHARES * CCW - 1 DOWNTO 0);
	SIGNAL fifo_din_valid_s : std_logic;
	SIGNAL fifo_din_ready_s : std_logic;
	SIGNAL fifo_dout_s : std_logic_vector(PDI_SHARES * CCW - 1 DOWNTO 0);
	SIGNAL fifo_dout_valid_s : std_logic;
	SIGNAL fifo_dout_ready_s : std_logic;
	SIGNAL fifo_valid_bytes_s : std_logic_vector(CCW/8 - 1 DOWNTO 0);
	SIGNAL fifo_last_word_valid_bytes_s : std_logic_vector(CCW/8 - 1 DOWNTO 0);
    SIGNAL fifo_eoi : std_logic;
    SIGNAL fifo_partial : std_logic;

	-- Utility signals
	SIGNAL perm_in_s : std_logic_vector(PDI_SHARES * p_n - 1 DOWNTO 0);
	SIGNAL perm_out_s : std_logic_vector(PDI_SHARES * p_n - 1 DOWNTO 0);
	SIGNAL pad_added_s : std_logic;
	SIGNAL bit_idx_s : INTEGER RANGE 0 TO 511;
	SIGNAL isap_state_cur_word_s : std_logic_vector(PDI_SHARES * CCW - 1 DOWNTO 0);
	SIGNAL bdi_partial_s : std_logic;
	
	SIGNAL bdi_masked_s : std_logic_vector(PDI_SHARES * CCW - 1 DOWNTO 0);
	
	-- AsconHash signals
    SIGNAL hash_cnt_s : INTEGER RANGE 0 TO 3;
    CONSTANT IV_HASH : std_logic_vector(63 DOWNTO 0) := X"00400c0000000100";

    --! Constant to check for empty hash
    CONSTANT EMPTY_HASH_SIZE_C : std_logic_vector(2 DOWNTO 0) := (OTHERS => '0');

BEGIN      
    isap_state_s_s0 <= isap_state_s(0*p_n+p_k-1 DOWNTO 0*p_n);    
    isap_state_s_s1 <= isap_state_s(1*p_n+p_k-1 DOWNTO 1*p_n);    
    isap_state_s_s2 <= isap_state_s(2*p_n+p_k-1 DOWNTO 2*p_n);    
    isap_state_s_s3 <= isap_state_s(3*p_n+p_k-1 DOWNTO 3*p_n);    

    isap_state_cur_word_s_reg_unshared <= (others => '0'); --isap_state_cur_word_s_reg(1*CCW-1 downto 0*CCW) xor isap_state_cur_word_s_reg(2*CCW-1 downto 1*CCW) xor isap_state_cur_word_s_reg(3*CCW-1 downto 2*CCW) xor isap_state_cur_word_s_reg(4*CCW-1 downto 3*CCW);
    bdi_s_reg_unshared <= (others => '0'); --bdi_s_reg(1*CCW-1 downto 0*CCW) xor bdi_s_reg(2*CCW-1 downto 1*CCW) xor bdi_s_reg(3*CCW-1 downto 2*CCW) xor bdi_s_reg(4*CCW-1 downto 3*CCW);

	----------------------------------------------------------------------------
	--! I/O Mappings
	-- Algorithm is specified in Big Endian. However, this is a Little Endian
	-- implementation so reverse_byte/bit functions are used to reorder affected signals.
	----------------------------------------------------------------------------
	key_s <= reverse_byte(key);
	bdi_s <= reverse_byte(bdi);
	
	bdi_valid_bytes_s <= reverse_bit(bdi_valid_bytes);
    bdi_pad_loc_s <= reverse_bit(bdi_pad_loc);
	key_ready <= key_ready_s;
	bdi_ready <= bdi_ready_s;
	bdo <= reverse_byte(bdo_s);
	bdo_valid_bytes <= reverse_bit(bdo_valid_bytes_s);
	bdo_valid <= bdo_valid_s;
	bdo_type <= bdo_type_s;
	end_of_block <= end_of_block_s;
	msg_auth <= msg_auth_s;
	msg_auth_valid <= msg_auth_valid_s;
	-- decrypt_out <= '1' WHEN isap_auth_encdec_s = AUTH_DEC ELSE '0';
	
	----------------------------------------------------------------------------
	--! Two-pass FIFO Mappings
	----------------------------------------------------------------------------
    fdo_data <= fifo_din_s;
    fdo_valid <= fifo_din_valid_s;
    fifo_din_ready_s <= fdo_ready;
    fifo_dout_s <= fdi_data;
    fifo_dout_valid_s <= fdi_valid;
    fdi_ready <= fifo_dout_ready_s;
    
    ---------------------------------------------------------------------------
	--! Utility Signals
	---------------------------------------------------------------------------
	-- Indicates whether the input word is fully filled or not.
	bdi_partial_s <= NOT and_reduce(bdi_valid_bytes_s);

	-- Word index in state that is currently used for data absorption/extraction.
	isap_state_cur_word_s(1*CCW-1 downto 0*CCW) <= isap_state_s(0*p_n+bit_idx_s+CCW-1 DOWNTO 0*p_n+bit_idx_s);
	isap_state_cur_word_s(2*CCW-1 downto 1*CCW) <= isap_state_s(1*p_n+bit_idx_s+CCW-1 DOWNTO 1*p_n+bit_idx_s);
	isap_state_cur_word_s(3*CCW-1 downto 2*CCW) <= isap_state_s(2*p_n+bit_idx_s+CCW-1 DOWNTO 2*p_n+bit_idx_s);
	isap_state_cur_word_s(4*CCW-1 downto 3*CCW) <= isap_state_s(3*p_n+bit_idx_s+CCW-1 DOWNTO 3*p_n+bit_idx_s);

	-- Lowest bit index in state that is currently used for data absorption/extraction.
    bit_idx_s <= word_idx_s * CCW;

	-- bdi signal where invalid bytes are set to 0.
	bdi_masked_s <= mask_zero(bdi_s, bdi_valid_bytes_s);
		
	---------------------------------------------------------------------------
	--! Ascon-p instantiation
	---------------------------------------------------------------------------
	g_asconp : IF ((ISAP_TYPE = ISAPA128) OR (ISAP_TYPE = ISAPA128A)) GENERATE
	    i_Asconp_HPC2_ClockGating_d1: Asconp_HPC2_ClockGating_d3
            port map (
                clk => clk,
                state_in_s0 => perm_in_s(1*p_n-1 DOWNTO 0*p_n),
                state_in_s1 => perm_in_s(2*p_n-1 DOWNTO 1*p_n),
                state_in_s2 => perm_in_s(3*p_n-1 DOWNTO 2*p_n),
                state_in_s3 => perm_in_s(4*p_n-1 DOWNTO 3*p_n),
				state_out_s0 => perm_out_s(1*p_n-1 DOWNTO 0*p_n),
                state_out_s1 => perm_out_s(2*p_n-1 DOWNTO 1*p_n),  
                state_out_s2 => perm_out_s(3*p_n-1 DOWNTO 2*p_n),  
				state_out_s3 => perm_out_s(4*p_n-1 DOWNTO 3*p_n),  
				rcon => isap_cnt_s(3 downto 0),
                fresh => rdi
            );
	END GENERATE g_asconp;

	---------------------------------------------------------------------------
	--! Keccak-p[400] instantiation
	---------------------------------------------------------------------------
--	 g_keccakpp400 : IF ((ISAP_TYPE = ISAPK128) OR (ISAP_TYPE = ISAPK128A)) GENERATE
--	 	i_keccakpp400 : ENTITY work.keccakp400
--	 		PORT MAP(
--	 			state_in => perm_in_s,
--	 			rcon => isap_cnt_s(4 DOWNTO 0),
--	 			state_out => perm_out_s
--	 		);
--	 END GENERATE;

	----------------------------------------------------------------------------
	--! Permutation input multiplexer
	----------------------------------------------------------------------------
	p_asconp_mux : PROCESS (isap_ctrl_s, isap_state_s, isap_y_s, isap_cnt_y_s)
	BEGIN
		CASE isap_ctrl_s IS
		
			WHEN X"0" =>
				-- Permutation input => state.
				perm_in_s <= isap_state_s;

			WHEN X"1" =>
				-- Permutation input => state xor 1 bit from Y (that is cyclically shifted).
                perm_in_s(1*p_n-1 downto 0*p_n) <= isap_state_s(1*p_n - 1 DOWNTO 0*p_n+8) & (isap_state_s(0*p_n+7) XOR isap_y_s(0*p_k+127)) & isap_state_s(0*p_n+6 DOWNTO 0*p_n);
                perm_in_s(2*p_n-1 downto 1*p_n) <= isap_state_s(2*p_n - 1 DOWNTO 1*p_n+8) & (isap_state_s(1*p_n+7) XOR isap_y_s(1*p_k+127)) & isap_state_s(1*p_n+6 DOWNTO 1*p_n);
                perm_in_s(3*p_n-1 downto 2*p_n) <= isap_state_s(3*p_n - 1 DOWNTO 2*p_n+8) & (isap_state_s(2*p_n+7) XOR isap_y_s(2*p_k+127)) & isap_state_s(2*p_n+6 DOWNTO 2*p_n);
                perm_in_s(4*p_n-1 downto 3*p_n) <= isap_state_s(4*p_n - 1 DOWNTO 3*p_n+8) & (isap_state_s(3*p_n+7) XOR isap_y_s(3*p_k+127)) & isap_state_s(3*p_n+6 DOWNTO 3*p_n);

			WHEN X"2" =>
				-- Permutation input => state xor emtpy lane with padding.
				perm_in_s(1*p_n-1 downto 0*p_n) <= isap_state_s(1*p_n - 1 DOWNTO 0*p_n+8) & (isap_state_s(0*p_n+7 DOWNTO 0*p_n) XOR X"80");
				perm_in_s(2*p_n-1 downto 1*p_n) <= isap_state_s(2*p_n - 1 DOWNTO 1*p_n+8) & (isap_state_s(1*p_n+7 DOWNTO 1*p_n) XOR X"00");
				perm_in_s(3*p_n-1 downto 2*p_n) <= isap_state_s(3*p_n - 1 DOWNTO 2*p_n+8) & (isap_state_s(2*p_n+7 DOWNTO 2*p_n) XOR X"00");
				perm_in_s(4*p_n-1 downto 3*p_n) <= isap_state_s(4*p_n - 1 DOWNTO 3*p_n+8) & (isap_state_s(3*p_n+7 DOWNTO 3*p_n) XOR X"00");
			WHEN OTHERS =>
				perm_in_s <= isap_state_s;
				
		END CASE;
	END PROCESS p_asconp_mux;

    -- bdo dynamic slicing
    p_dynslice_bdo : process (word_idx_s,isap_state_s)
    begin
        if word_idx_s < BLOCK_WORDS_C then
            bdoo_s(1*CCW-1 downto 0*CCW) <= isap_state_s(0*p_n+CCW-1+CCW*word_idx_s DOWNTO 0*p_n+CCW*word_idx_s);
            bdoo_s(2*CCW-1 downto 1*CCW) <= isap_state_s(1*p_n+CCW-1+CCW*word_idx_s DOWNTO 1*p_n+CCW*word_idx_s);
            bdoo_s(3*CCW-1 downto 2*CCW) <= isap_state_s(2*p_n+CCW-1+CCW*word_idx_s DOWNTO 2*p_n+CCW*word_idx_s);
            bdoo_s(4*CCW-1 downto 3*CCW) <= isap_state_s(3*p_n+CCW-1+CCW*word_idx_s DOWNTO 3*p_n+CCW*word_idx_s);
		else
            bdoo_s <= (OTHERS => '0');
        end if;
    end process;
    
	----------------------------------------------------------------------------
	--! fifo out valid bytes
	----------------------------------------------------------------------------
	p_fifo_val_bytes : PROCESS (fifo_last_word_valid_bytes_s,fifo_dout_valid_s, fifo_words_s,fifo_valid_bytes_s)
	BEGIN
		CASE fifo_words_s IS
		
			WHEN 1 =>
				fifo_valid_bytes_s <= fifo_last_word_valid_bytes_s;
                fifo_eoi <= '1';
                fifo_partial <= not and_reduce(fifo_valid_bytes_s);
                
			WHEN 0 =>
				fifo_valid_bytes_s <= (OTHERS => '0');
			    fifo_eoi <= '0';
			    fifo_partial <= '0';
			    
			WHEN OTHERS =>
			    fifo_eoi <= '0';
			    fifo_partial <= '0';
			    if(fifo_dout_valid_s = '1') then
				    fifo_valid_bytes_s <= (OTHERS => '1');
				else
				    fifo_valid_bytes_s <= (OTHERS => '0');
				end if;
				
		END CASE;
	END PROCESS p_fifo_val_bytes;
    
    -- Quick fix for dynamic slicing 2
    p_CASE2 : process (word_idx_s,isap_state_s,state_s,bdi_valid,bdi_s,isap_auth_encdec_s,bdi_valid_bytes_s,bdi_pad_loc_s,bdoo_s,bdi_eot,bdi_partial_s,fifo_dout_s,fifo_words_s,fifo_eoi,fifo_partial,fifo_valid_bytes_s)
        variable pad1 : STD_LOGIC_VECTOR(PDI_SHARES*CCW-1 DOWNTO 0);
        variable pad2 : STD_LOGIC_VECTOR(PDI_SHARES*CCW-1 DOWNTO 0);
    begin
        pad1 := pad_bdi(bdi_s, bdi_valid_bytes_s, bdoo_s, '0');
        pad2 := pad_bdi((fifo_dout_s), reverse_bit(fifo_valid_bytes_s), bdoo_s, '0'); -- dec_in ok?
        isap_state_n_s <= (others => '0');
        
    case state_s is
        when ISAP_MAC_ABSORB_AD =>
            if word_idx_s < BLOCK_WORDS_C then
                isap_state_n_s <= dyn_slice(pad1,bdi_eot,bdi_partial_s,isap_state_s,word_idx_s);
            end if;
        when ISAP_MAC_ABSORB_CT =>
            case isap_auth_encdec_s is
                when AUTH_DEC =>
					if word_idx_s < BLOCK_WORDS_C then
						isap_state_n_s <= dyn_slice(pad1,bdi_eot,bdi_partial_s,isap_state_s,word_idx_s);
					end if;
                when AUTH_ENC =>
					if word_idx_s < BLOCK_WORDS_C then
						isap_state_n_s <= dyn_slice(pad2,fifo_eoi,fifo_partial,isap_state_s,word_idx_s);
					end if;
            end case;
        when others =>
            isap_state_n_s <= isap_state_s;
    end case;
    end process;

	----------------------------------------------------------------------------
	--! FIFO multiplexer
	----------------------------------------------------------------------------
	p_fifo_mux : PROCESS (state_s, bdi_s, bdi_masked_s, bdi_ready_s, bdi_valid, isap_auth_encdec_s, bdo_ready, isap_state_cur_word_s)
	BEGIN
		CASE state_s IS
			WHEN ISAP_ENC_SQUEEZE_BLOCK =>
				IF (isap_auth_encdec_s = AUTH_DEC) THEN
					fifo_din_s <= (OTHERS => '0');
					fifo_din_valid_s <= '0';
					fifo_dout_ready_s <= bdo_ready;
				ELSE
					fifo_din_s <= bdi_masked_s XOR isap_state_cur_word_s;
					fifo_din_valid_s <= bdi_valid AND bdi_ready_s;
					fifo_dout_ready_s <= '0';
				END IF;

			WHEN ISAP_MAC_ABSORB_CT =>
				IF (isap_auth_encdec_s = AUTH_DEC) THEN
					fifo_din_s <= bdi_s;
					fifo_din_valid_s <= bdi_valid;
					fifo_dout_ready_s <= '0';
				ELSE
					fifo_din_s <= (OTHERS => '0');
					fifo_din_valid_s <= '0';
					fifo_dout_ready_s <= '1';
				END IF;

			WHEN EXTRACT_TAG =>
				fifo_din_s <= (OTHERS => '0');
				fifo_din_valid_s <= '0';
				fifo_dout_ready_s <= '0';

			WHEN OTHERS =>
				fifo_din_s <= (OTHERS => '0');
				fifo_din_valid_s <= '0';
				fifo_dout_ready_s <= '0';

		END CASE;
	END PROCESS p_fifo_mux;

	----------------------------------------------------------------------------
	--! Bdo multiplexer
	----------------------------------------------------------------------------
	p_bdo_mux : PROCESS (state_s, bdi_masked_s, word_idx_s, bdi_valid_bytes_s, bdi_valid, bdi_eot, isap_auth_encdec_s, fifo_words_s,
		fifo_dout_s, fifo_last_word_valid_bytes_s, isap_state_cur_word_s, hash_cnt_s)
	BEGIN
		CASE state_s IS
			WHEN ISAP_ENC_SQUEEZE_BLOCK =>
				-- Directly connect bdi and bdo signals when en/decrypting data.
				IF (isap_auth_encdec_s = AUTH_DEC) THEN
					bdo_s <= fifo_dout_s XOR isap_state_cur_word_s;
					-- Only in the last block bytes can be invalid
					IF (fifo_words_s = 1) THEN
						bdo_valid_bytes_s <= reverse_bit(fifo_last_word_valid_bytes_s);
						end_of_block_s <= '1';
					ELSE
						bdo_valid_bytes_s <= fifo_last_word_valid_bytes_s OR (NOT fifo_last_word_valid_bytes_s);
						end_of_block_s <= '0';
					END IF;
					bdo_valid_s <= '1';
					bdo_type_s <= HDR_PT;
				ELSE
					bdo_s <= bdi_masked_s XOR isap_state_cur_word_s;
					bdo_valid_bytes_s <= bdi_valid_bytes_s;
					bdo_valid_s <= bdi_valid;
					end_of_block_s <= bdi_eot;
					bdo_type_s <= HDR_CT;
				END IF;

			WHEN EXTRACT_TAG =>
				bdo_s <= isap_state_cur_word_s;
				bdo_valid_bytes_s <= (OTHERS => '1');
				bdo_valid_s <= '1';
				bdo_type_s <= HDR_TAG;
				IF (word_idx_s = TAG_WORDS_C - 1) THEN
					end_of_block_s <= '1';
				ELSE
					end_of_block_s <= '0';
				END IF;
				
            WHEN EXTRACT_HASH_VALUE =>
                bdo_s <= isap_state_cur_word_s;
                bdo_valid_bytes_s <= (OTHERS => '1');
                bdo_valid_s <= '1';
                bdo_type_s <= HDR_HASH_VALUE;
                IF (word_idx_s >= BLOCK_WORDS_C - 1 AND hash_cnt_s = 3) THEN
                    end_of_block_s <= '1';
                ELSE
                    end_of_block_s <= '0';
                END IF;

			WHEN OTHERS =>
				bdo_s <= (OTHERS => '0');
				bdo_valid_bytes_s <= (0 => '1', OTHERS => '0');
				bdo_valid_s <= '0';
				end_of_block_s <= '0';
				bdo_type_s <= "0000"; -- todo HDR_TAG;

		END CASE;
	END PROCESS p_bdo_mux;

	----------------------------------------------------------------------------
	--! Next_state FSM
	----------------------------------------------------------------------------
	p_next_state : PROCESS (state_s, key_valid, key_ready_s, key_update, bdi_valid, fifo_din_ready_s, pad_added_s, hash_in, hash_cnt_s,
		bdi_ready_s, bdi_eot, bdi_eoi, bdi_type, eoi_s, eot_s, word_idx_s, isap_auth_encdec_s, bdo_valid_s, bdo_ready, msg_auth_s,
		msg_auth_valid_s, msg_auth_ready, bdi_partial_s, isap_cnt_s, delay_cnt_s, isap_cnt_y_s, isap_encmac_s, fifo_dout_valid_s, fifo_dout_ready_s, fifo_words_s,hash_s,empty_hash_s)
	BEGIN

		-- Default values preventing latches
		n_state_s <= state_s;

		CASE state_s IS
			WHEN IDLE =>
				-- Wakeup as soon as valid bdi or key is signaled.
				IF (key_valid = '1' OR bdi_valid = '1') THEN
                    n_state_s <= STORE_KEY;
				END IF;
				
			WHEN HASH_SETUP_STATE => -- hash specific
                n_state_s <= ISAP_MAC_INITIALIZE;

			WHEN STORE_KEY =>
				IF (((key_valid = '1' AND key_ready_s = '1') OR key_update = '0') AND word_idx_s >= KEY_WORDS_C - 1) THEN
					IF (hash_in = '1') THEN
                        n_state_s <= HASH_SETUP_STATE;
                    ELSE
                        n_state_s <= STORE_NONCE;
                    END IF;
				END IF;

			WHEN STORE_NONCE =>
				-- After nonce is received for encryption/decryption:
				-- When message length is 0 bytes then extract/verify the tag,
				-- otherwise continue with isap_enc/isap_mac.
				IF (bdi_valid = '1' AND bdi_ready_s = '1' AND word_idx_s >= NPUB_WORDS_C - 1) THEN
					IF (bdi_eoi = '1') THEN
						n_state_s <= ISAP_MAC_SETUP_STATE;
					ELSE
						IF (isap_auth_encdec_s = AUTH_DEC) THEN
							n_state_s <= ISAP_MAC_SETUP_STATE;
						ELSE
							n_state_s <= WAIT_INPUT_TYPE;
						END IF;
					END IF;
				END IF;

			WHEN WAIT_INPUT_TYPE =>
				-- Only entered during encryption. Wait until the input type is valid so we
				-- know if we need to do encryption.
				IF (bdi_valid = '1') THEN
					IF (bdi_type = HDR_AD) THEN
						n_state_s <= ISAP_MAC_SETUP_STATE;
					ELSIF (bdi_type = HDR_PT) THEN
						n_state_s <= ISAP_RK_SETUP_STATE;
					END IF;
				END IF;

			WHEN ISAP_RK_SETUP_STATE =>
				-- Fill state with key and iv.
				n_state_s <= ISAP_RK_INITIALIZE;

			WHEN ISAP_RK_INITIALIZE =>
				-- Perform sK permutation rounds.
				IF (isap_cnt_s = X"01" and delay_cnt_s = B"01") THEN
					n_state_s <= ISAP_RK_REKEYING;
				END IF;

			WHEN ISAP_RK_REKEYING =>
				-- Absorb Y bit by by, after each absorption perform sB permutation rounds.
				IF (isap_cnt_y_s = 1 AND isap_cnt_s = X"01" and delay_cnt_s = B"01") THEN
					n_state_s <= ISAP_RK_SQUEEZE;
				END IF;

			WHEN ISAP_RK_SQUEEZE =>
				-- Perform sK permutation rounds.
				IF (isap_cnt_s = X"01" and delay_cnt_s = B"01") THEN
					IF (isap_encmac_s = ISAP_ENC) THEN
						n_state_s <= ISAP_ENC_INITIALIZE;
					ELSE
						n_state_s <= ISAP_MAC_FINALIZE_AFTER_RK_STATE_SETUP;
					END IF;
				END IF;

			WHEN ISAP_ENC_INITIALIZE =>
				-- Overwrite parts of state with previouly buffered part of the state.
				n_state_s <= ISAP_ENC_PERMUTE_PE;

			WHEN ISAP_ENC_PERMUTE_PE =>
				-- Perform sE permutation rounds.
				IF (isap_cnt_s = X"01" and delay_cnt_s = B"01") THEN
					n_state_s <= ISAP_ENC_SQUEEZE_BLOCK;
				END IF;

			WHEN ISAP_ENC_SQUEEZE_BLOCK =>
				-- Read in either plaintext or ciphertext until end of type is detected.
				IF (isap_auth_encdec_s = AUTH_DEC) THEN
					IF (fifo_dout_valid_s = '1' AND fifo_dout_ready_s = '1' AND bdo_ready = '1') THEN
						IF (fifo_words_s = 1) THEN
							n_state_s <= IDLE;
						ELSIF (word_idx_s >= BLOCK_WORDS_C - 1) THEN
							n_state_s <= ISAP_ENC_PERMUTE_PE;
						END IF;
					END IF;
				ELSE -- AUTH_ENC
					IF (bdi_valid = '1' AND bdi_ready_s = '1' AND fifo_din_ready_s = '1') THEN
						IF (bdi_eot = '1') THEN
							n_state_s <= ISAP_MAC_SETUP_STATE;
						ELSE
							IF (word_idx_s = BLOCK_WORDS_C - 1) THEN
								n_state_s <= ISAP_ENC_PERMUTE_PE;
							END IF;
						END IF;
					END IF;
				END IF;

			WHEN ISAP_MAC_SETUP_STATE =>
				-- Fill state with nonce and iv.
				n_state_s <= ISAP_MAC_INITIALIZE;

			WHEN ISAP_MAC_INITIALIZE =>
				-- Perform sH permutation rounds, then absorb ad or only padding if ad length is zero.
				IF (isap_cnt_s = X"01" and delay_cnt_s = B"01") THEN
                    IF (hash_s = '1') then
                        if (empty_hash_s = '1') THEN
						    n_state_s <= ISAP_MAC_ABSORB_AD_PAD;
						else
							n_state_s <= ISAP_MAC_ABSORB_AD;
                        end if;
					ELSE
                        n_state_s <= ISAP_MAC_WAIT_INPUT;
                    end if;
				END IF;

			WHEN ISAP_MAC_WAIT_INPUT =>
				-- Wait until we know if ad needs to be absorbed.
				IF (bdi_valid = '1') THEN
					IF (bdi_type = HDR_AD) THEN
						n_state_s <= ISAP_MAC_ABSORB_AD;
					ELSE
						n_state_s <= ISAP_MAC_ABSORB_AD_PAD;
					END IF;
				END IF;

			WHEN ISAP_MAC_ABSORB_AD =>
				-- Wait until last word of AD is signaled.
				IF (bdi_valid = '1' AND bdi_ready_s = '1') THEN
					IF (bdi_eot = '1') THEN
						n_state_s <= ISAP_MAC_PROCESS_AD;
					ELSE
						IF (word_idx_s = BLOCK_WORDS_C - 1) THEN
							n_state_s <= ISAP_MAC_PROCESS_AD;
						END IF;
					END IF;
				END IF;

			WHEN ISAP_MAC_PROCESS_AD =>
				-- Perform sH permutation rounds, then absorb padding if it was not already absorbed in the last block.
				IF (isap_cnt_s = X"01" and delay_cnt_s = B"01") THEN
				    -- hash specific
				    if (hash_s = '1') then
                        IF (eoi_s = '1') THEN
							IF (pad_added_s = '1') THEN
								n_state_s <= EXTRACT_HASH_VALUE;
							ELSE
								n_state_s <= ISAP_MAC_ABSORB_AD_PAD;
							END IF;
					    else
					    	n_state_s <= ISAP_MAC_ABSORB_AD;
						END IF;
					ELSIF (isap_auth_encdec_s = AUTH_ENC) THEN
						IF (eoi_s = '1') THEN
							IF (pad_added_s = '1') THEN
								n_state_s <= ISAP_MAC_DOMAIN_SEPERATION;
							ELSE
								n_state_s <= ISAP_MAC_ABSORB_AD_PAD;
							END IF;
						ELSE
							n_state_s <= ISAP_MAC_ABSORB_AD;
						END IF;
					ELSE -- AUTH_DEC
						IF (eot_s = '1') THEN
							IF (pad_added_s = '1') THEN
								n_state_s <= ISAP_MAC_DOMAIN_SEPERATION;
							ELSE
								n_state_s <= ISAP_MAC_ABSORB_AD_PAD;
							END IF;
						ELSE
							n_state_s <= ISAP_MAC_ABSORB_AD;
						END IF;
					END IF;
				END IF;

			WHEN ISAP_MAC_ABSORB_AD_PAD =>
				-- Absorb block that only contains padding.
				IF (isap_cnt_s = X"01" and delay_cnt_s = B"01") THEN
				    -- hash specific
				    if (hash_s = '1') then
				        n_state_s <= EXTRACT_HASH_VALUE;
                    else
					   n_state_s <= ISAP_MAC_DOMAIN_SEPERATION;
                    end if;
				END IF;

			WHEN ISAP_MAC_DOMAIN_SEPERATION =>
				-- Flip the highest bit in the state.
				IF (isap_auth_encdec_s = AUTH_DEC) THEN
					IF (eoi_s = '1') THEN
						n_state_s <= ISAP_MAC_ABSORB_CT_PAD;
					ELSE
						n_state_s <= ISAP_MAC_ABSORB_CT;
					END IF;
				ELSE
					-- eoi is always '1' here, we need to rely on 'fifo_words'.
					IF (fifo_words_s > 0) THEN
						n_state_s <= ISAP_MAC_ABSORB_CT;
					ELSE
						n_state_s <= ISAP_MAC_ABSORB_CT_PAD;
					END IF;
				END IF;

			WHEN ISAP_MAC_ABSORB_CT =>
				IF (isap_auth_encdec_s = AUTH_DEC) THEN
					-- AUTH_DEC: Absorb CT words from bdi until a block is full or the last CT word was absorbed, then process it.
					IF (bdi_valid = '1' AND bdi_ready_s = '1' AND bdi_type = HDR_CT) THEN
						IF (word_idx_s = BLOCK_WORDS_C - 1 OR bdi_eot = '1') THEN
							n_state_s <= ISAP_MAC_PROCESS_CT;
						END IF;
					END IF;
				ELSE
					-- AUTH_ENC: Absorb CT words from fifo until a block is full or the last CT word was absorbed, then process it.
					IF ((word_idx_s = BLOCK_WORDS_C - 1 OR fifo_words_s = 1) AND fifo_dout_valid_s = '1' AND fifo_dout_ready_s = '1') THEN
						n_state_s <= ISAP_MAC_PROCESS_CT;
					END IF;
				END IF;

			WHEN ISAP_MAC_PROCESS_CT =>
				-- Perform sH permutation rounds, then absorb padding nor not depending on if it was already inserted into the last block.
				IF (isap_cnt_s = X"01" and delay_cnt_s = B"01") THEN
					IF (isap_auth_encdec_s = AUTH_DEC) THEN
						IF (eoi_s = '0') THEN
							n_state_s <= ISAP_MAC_ABSORB_CT;
						ELSE
							IF (pad_added_s = '1') THEN
								n_state_s <= ISAP_RK_SETUP_STATE;
							ELSE
								n_state_s <= ISAP_MAC_ABSORB_CT_PAD;
							END IF;
						END IF;
					ELSE -- AUTH_ENC
						IF (fifo_words_s > 0) THEN
							n_state_s <= ISAP_MAC_ABSORB_CT;
						ELSE
							IF (pad_added_s = '1') THEN
								n_state_s <= ISAP_RK_SETUP_STATE;
							ELSE
								n_state_s <= ISAP_MAC_ABSORB_CT_PAD;
							END IF;
						END IF;
					END IF;
				END IF;

			WHEN ISAP_MAC_ABSORB_CT_PAD =>
				-- Absorb block that only contains padding.
				IF (isap_cnt_s = X"01" and delay_cnt_s = B"01") THEN
					n_state_s <= ISAP_RK_SETUP_STATE;
				END IF;

			WHEN ISAP_MAC_FINALIZE_AFTER_RK_STATE_SETUP =>
				-- Overwrite parts of state with previouly buffered part of the state.
				n_state_s <= ISAP_MAC_FINALIZE_PERMUTE_PH;

			WHEN ISAP_MAC_FINALIZE_PERMUTE_PH =>
				IF (isap_cnt_s = X"01" and delay_cnt_s = B"01") THEN
					IF (isap_auth_encdec_s = AUTH_DEC) THEN
						n_state_s <= VERIFY_TAG;
					ELSE
						n_state_s <= EXTRACT_TAG;
					END IF;
				END IF;

			WHEN EXTRACT_TAG =>
				-- Wait until the whole tag block is transferred, then go back to IDLE.
				IF (bdo_valid_s = '1' AND bdo_ready = '1' AND word_idx_s >= TAG_WORDS_C - 1) THEN
					n_state_s <= IDLE;
				END IF;

			WHEN VERIFY_TAG =>
				-- Wait until the tag being verified is received, continue
				-- with waiting for acknowledgement on msg_auth_valis.
				IF (bdi_valid = '1' AND bdi_ready_s = '1' AND bdi_type = HDR_TAG) THEN
					IF (word_idx_s >= TAG_WORDS_C - 1) THEN
						n_state_s <= WAIT_ACK;
					END IF;
				END IF;

			WHEN WAIT_ACK =>
				-- Wait until message authentication is acknowledged.
				IF (msg_auth_valid_s = '1' AND msg_auth_ready = '1') THEN
					IF (msg_auth_s = '1' AND fifo_words_s > 0) THEN
						n_state_s <= ISAP_RK_SETUP_STATE;
					ELSE
						n_state_s <= IDLE;
					END IF;
				END IF;
				
            WHEN EXTRACT_HASH_VALUE =>
                -- Wait until the whole hash is transferred, then go back to IDLE.
                IF (bdo_valid_s = '1' AND bdo_ready = '1' AND word_idx_s >= BLOCK_WORDS_C - 1) THEN
                    IF (hash_cnt_s < 3) THEN
                        n_state_s <= ISAP_MAC_PROCESS_AD;
                    ELSE
                        n_state_s <= IDLE;
                    END IF;
                END IF;

			WHEN OTHERS =>
				n_state_s <= IDLE;

		END CASE;
	END PROCESS p_next_state;

	----------------------------------------------------------------------------
	--! Registers for state and internal signals
	----------------------------------------------------------------------------
	p_reg : PROCESS (clk)
	BEGIN
		IF rising_edge(clk) THEN
			IF (rst = '1') THEN
				msg_auth_s <= '1';
				update_key_s <= '0';
				isap_auth_encdec_s <= AUTH_ENC;
				state_s <= IDLE;
				fifo_words_s <= 0;
				eoi_s <= '0';
				eot_s <= '0';
				empty_hash_s <= '0';
				hash_s <= '0';
			ELSE
				msg_auth_s <= n_msg_auth_s;
				update_key_s <= n_update_key_s;
				isap_auth_encdec_s <= n_isap_auth_encdec_s;
				state_s <= n_state_s;
				eoi_s <= n_eoi_s;
				eot_s <= n_eot_s;
				fifo_words_s <= n_fifo_words_s;
                empty_hash_s <= n_empty_hash_s;
                hash_s <= n_hash_s;
            END IF;
		END IF;
	END PROCESS p_reg;

	----------------------------------------------------------------------------
	--! Decoder process for control logic
	----------------------------------------------------------------------------
	p_decoder : PROCESS (state_s, key_valid, key_update, update_key_s, eoi_s, eot_s, bdi_eot, hash_in, bdi_size, bdi_s_reg_unshared,
		bdi_s, bdi_eoi, bdi_valid, bdi_type, decrypt_in, isap_auth_encdec_s, bdi_ready_s, isap_state_cur_word_s, isap_state_cur_word_s_reg_unshared,
		bdo_ready, word_idx_s, msg_auth_s, isap_cnt_s, fifo_words_s, fifo_dout_valid_s, fifo_dout_ready_s, fifo_din_ready_s,empty_hash_s,hash_s)
	BEGIN
		-- Default values preventing latches
		key_ready_s <= '0';
		bdi_ready_s <= '0';
		msg_auth_valid_s <= '0';
		n_msg_auth_s <= msg_auth_s;
		n_update_key_s <= update_key_s;
		n_isap_auth_encdec_s <= isap_auth_encdec_s;
		n_fifo_words_s <= fifo_words_s;
		n_eoi_s <= eoi_s;
		n_eot_s <= eot_s;
		isap_ctrl_s <= X"0";
        n_empty_hash_s <= empty_hash_s;
        n_hash_s <= hash_s;
        isap_state_cur_word_s_reg <= (others => '0');
        bdi_s_reg <= (others => '0');

		CASE state_s IS

			WHEN IDLE =>
				-- Default values. If valid input is detected, set internal flags
				-- depending on input and mode.
				n_msg_auth_s <= '1';
				n_update_key_s <= '0';
				n_isap_auth_encdec_s <= AUTH_ENC;
				n_eoi_s <= '0';
				n_eot_s <= '0';
				n_fifo_words_s <= 0;
                n_empty_hash_s <= '0';
                n_hash_s <= '0';
				IF (key_valid = '1' AND key_update = '1') THEN
					n_update_key_s <= '1';
				END IF;
                IF (bdi_valid = '1' AND hash_in = '1') THEN
                    n_hash_s <= '1';
                    IF (bdi_size = EMPTY_HASH_SIZE_C) THEN
                        n_empty_hash_s <= '1';
                        n_eoi_s <= '1';
                        n_eot_s <= '1';
                    END IF;
                END IF;
				
		    when HASH_SETUP_STATE =>
				IF (bdi_valid = '1' AND bdi_type = HDR_HASH_MSG AND bdi_eoi = '1') THEN
					n_eoi_s <= '1';
				END IF;
				-- If empty hash is detected, acknowledge with one cycle bdi_ready.
                -- Afterwards empty_hash_s flag can be deasserted, it's not needed anymore.
                IF (empty_hash_s = '1') THEN
                    bdi_ready_s <= '1';
                END IF;

			WHEN STORE_KEY =>
				-- Ready for key.
				IF (update_key_s = '1') THEN
					key_ready_s <= '1';
				END IF;

			WHEN STORE_NONCE =>
				-- Ready for nonce, remember whether we should do enc or dec. Remember if we will receive more input.
				bdi_ready_s <= '1';
				IF (decrypt_in = '1') THEN
					n_isap_auth_encdec_s <= AUTH_DEC;
				ELSE
					n_isap_auth_encdec_s <= AUTH_ENC;
				END IF;
				IF (bdi_valid = '1' AND bdi_type = HDR_NPUB AND bdi_eoi = '1') THEN
					n_eoi_s <= '1';
				END IF;

			WHEN ISAP_RK_REKEYING =>
				-- Absorb one bit of Y then perform sB permutation rounds.
				IF (isap_cnt_s = p_sB) THEN
					isap_ctrl_s <= X"1";
				END IF;

			WHEN ISAP_RK_SQUEEZE =>
				-- Perform sK permutation rounds, absorb last bit of Y before first permutation call.
				IF (isap_cnt_s = p_sK) THEN
					isap_ctrl_s <= X"1";
				END IF;

			WHEN ISAP_MAC_ABSORB_AD =>
				-- If pt or ct is detected, don't assert bdi_ready, otherwise first word
				-- gets lost.
				IF (bdi_valid = '1' AND NOT (bdi_type = HDR_PT OR bdi_type = HDR_CT)) THEN
					bdi_ready_s <= '1';
				END IF;
				IF (bdi_valid = '1' AND (bdi_type = HDR_AD OR bdi_type = HDR_HASH_MSG)) THEN
					IF (bdi_eoi = '1') THEN
						n_eoi_s <= '1';
					END IF;
					IF (bdi_eot = '1') THEN
						n_eot_s <= '1';
					END IF;
				END IF;

			WHEN ISAP_MAC_ABSORB_AD_PAD =>
				-- Perform sH permutation rounds, absorb padding block before first permutation call.  
				IF (isap_cnt_s = p_sH) THEN
					isap_ctrl_s <= X"2";
				END IF;
				n_eot_s <= '0';

			WHEN ISAP_MAC_ABSORB_CT =>
				-- During decryption we are ready for inputs once it is valid and the type is correct
				IF (isap_auth_encdec_s = AUTH_DEC) THEN
					IF (bdi_valid = '1' AND bdi_type = HDR_CT AND fifo_din_ready_s = '1') THEN
						bdi_ready_s <= '1';
						IF (bdi_eoi = '1') THEN
							n_eoi_s <= '1';
						END IF;
						n_fifo_words_s <= fifo_words_s + 1;
					END IF;
				ELSE
					IF (fifo_dout_valid_s = '1' AND fifo_dout_ready_s = '1') THEN
						n_fifo_words_s <= fifo_words_s - 1;
					END IF;
				END IF;

			WHEN ISAP_MAC_ABSORB_CT_PAD =>
				-- Perform sH permutation rounds, absorb padding block before first permutation call.  
				IF (isap_cnt_s = p_sH) THEN
					isap_ctrl_s <= X"2";
				END IF;

			WHEN ISAP_ENC_SQUEEZE_BLOCK =>
				-- We are only ready for input if bdo is also ready. Remember if we will receive more input.
				IF (isap_auth_encdec_s = AUTH_ENC) THEN
					bdi_ready_s <= bdo_ready;
					IF (bdi_valid = '1' AND bdi_ready_s = '1' AND bdi_type = HDR_PT AND fifo_din_ready_s = '1') THEN
						IF (bdi_eoi = '1') THEN
							n_eoi_s <= '1';
						END IF;
						n_fifo_words_s <= fifo_words_s + 1;
					END IF;
				ELSE
					IF (fifo_dout_valid_s = '1' AND fifo_dout_ready_s = '1') THEN
						n_fifo_words_s <= fifo_words_s - 1;
					END IF;
				END IF;

			WHEN VERIFY_TAG =>
				-- As soon as bdi input doesn't match with tag, reset msg_auth.
				bdi_ready_s <= '1';
				isap_state_cur_word_s_reg <= isap_state_cur_word_s;
				bdi_s_reg <= bdi_s;
				
				IF (bdi_valid = '1' AND bdi_type = HDR_TAG AND (isap_state_cur_word_s_reg_unshared /= bdi_s_reg_unshared)) THEN
					n_msg_auth_s <= '0';
				END IF;

			WHEN WAIT_ACK =>
				-- Authentication check is done, "msg_auth_s" is valid
				msg_auth_valid_s <= '1';

			WHEN OTHERS =>
				NULL;

		END CASE;
	END PROCESS p_decoder;

	----------------------------------------------------------------------------
	--! Word Counter
	----------------------------------------------------------------------------
	p_isap : PROCESS (clk)
	BEGIN
		IF rising_edge(clk) THEN
			IF (rst = '1') THEN
				word_idx_s <= 0;
			ELSE
				CASE state_s IS

					WHEN IDLE =>
						word_idx_s <= 0;

					WHEN STORE_KEY =>
						IF (key_update = '1') THEN
							IF (key_valid = '1' AND key_ready_s = '1') THEN
								IF (word_idx_s >= KEY_WORDS_C - 1) THEN
									word_idx_s <= 0;
								ELSE
									word_idx_s <= word_idx_s + 1;
								END IF;
							END IF;
						ELSE
							IF (word_idx_s >= KEY_WORDS_C - 1) THEN
								word_idx_s <= 0;
							ELSE
								word_idx_s <= word_idx_s + 1;
							END IF;
						END IF;

					WHEN STORE_NONCE =>
						IF (bdi_valid = '1' AND bdi_ready_s = '1') THEN
							IF (word_idx_s >= NPUB_WORDS_C - 1) THEN
								word_idx_s <= 0;
							ELSE
								word_idx_s <= word_idx_s + 1;
							END IF;
						END IF;

					WHEN ISAP_ENC_SQUEEZE_BLOCK =>
						IF (isap_auth_encdec_s = AUTH_DEC) THEN
							IF (fifo_dout_valid_s = '1' AND fifo_dout_ready_s = '1' AND bdo_ready = '1') THEN
								IF (word_idx_s >= BLOCK_WORDS_C - 1) THEN
									word_idx_s <= 0;
								ELSE
									word_idx_s <= word_idx_s + 1;
								END IF;
							END IF;
						ELSE
							IF (bdi_valid = '1' AND bdi_ready_s = '1' AND fifo_din_ready_s = '1') THEN
								IF (word_idx_s >= BLOCK_WORDS_C - 1 AND bdi_eot = '0') THEN
									word_idx_s <= 0;
								ELSIF (bdi_eot = '1') THEN
									word_idx_s <= 0;
								ELSE
									word_idx_s <= word_idx_s + 1;
								END IF;
							END IF;
						END IF;

					WHEN ISAP_MAC_SETUP_STATE =>
						word_idx_s <= 0;

					WHEN ISAP_MAC_ABSORB_AD =>
						IF (bdi_valid = '1' AND bdi_ready_s = '1' AND (bdi_type = HDR_AD OR bdi_type = HDR_HASH_MSG)) THEN
							IF (word_idx_s >= BLOCK_WORDS_C - 1) THEN
								word_idx_s <= 0;
							ELSIF (bdi_eot = '1') THEN
								word_idx_s <= 0;
							ELSE
								word_idx_s <= word_idx_s + 1;
							END IF;
						END IF;

					WHEN ISAP_MAC_DOMAIN_SEPERATION =>
						word_idx_s <= 0;

					WHEN EXTRACT_TAG =>
						IF (bdo_valid_s = '1' AND bdo_ready = '1') THEN
							IF (word_idx_s >= TAG_WORDS_C - 1) THEN
								word_idx_s <= 0;
							ELSE
								word_idx_s <= word_idx_s + 1;
							END IF;
						END IF;

					WHEN ISAP_MAC_ABSORB_CT =>
						IF (isap_auth_encdec_s = AUTH_DEC) THEN
							IF (bdi_valid = '1' AND bdi_ready_s = '1' AND bdi_type = HDR_CT) THEN
								IF (word_idx_s >= BLOCK_WORDS_C - 1 AND bdi_eot = '0') THEN
									word_idx_s <= 0;
								ELSIF (bdi_eot = '1') THEN
									word_idx_s <= 0;
								ELSE
									word_idx_s <= word_idx_s + 1;
								END IF;
							END IF;
						ELSE
							IF (fifo_dout_valid_s = '1' AND fifo_dout_ready_s = '1') THEN
								IF (word_idx_s >= BLOCK_WORDS_C - 1 OR fifo_words_s = 1) THEN
									word_idx_s <= 0;
								ELSE
									word_idx_s <= word_idx_s + 1;
								END IF;
							END IF;
						END IF;

					WHEN VERIFY_TAG =>
						IF (bdi_valid = '1' AND bdi_ready_s = '1' AND bdi_type = HDR_TAG) THEN
							IF (word_idx_s >= TAG_WORDS_C - 1) THEN
								word_idx_s <= 0;
							ELSE
								word_idx_s <= word_idx_s + 1;
							END IF;
						END IF;

					WHEN EXTRACT_HASH_VALUE =>
						IF (bdo_valid_s = '1' AND bdo_ready = '1') THEN
							IF (word_idx_s >= BLOCK_WORDS_C - 1) THEN
								word_idx_s <= 0;
							ELSE
								word_idx_s <= word_idx_s + 1;
							END IF;
						END IF;

					WHEN OTHERS =>
						NULL;

				END CASE;
			END IF;
		END IF;
	END PROCESS p_isap;

	----------------------------------------------------------------------------
	--! ISAP Calculations
	----------------------------------------------------------------------------
	p_counters : PROCESS (clk)
	BEGIN

		IF rising_edge(clk) THEN
			IF (rst = '1') THEN
				isap_encmac_s <= ISAP_ENC;
			ELSE
				rdi_ready <= '1';

				CASE state_s IS
					WHEN IDLE =>
						-- Nothing to do here, reset counters
						pad_added_s <= '0'; -- todo move down
						fifo_last_word_valid_bytes_s <= (OTHERS => '0');

					WHEN STORE_KEY =>
						-- If key is to be updated, increase counter on every successful
						-- data transfer (valid and ready), else just count cycles
						IF (key_update = '1') THEN
							IF (key_valid = '1' AND key_ready_s = '1') THEN
								isap_key_s(0*p_k+CCW*word_idx_s+CCW-1 DOWNTO 0*p_k+CCW*word_idx_s) <= key_s(1*CCSW-1 downto 0*CCSW);
								isap_key_s(1*p_k+CCW*word_idx_s+CCW-1 DOWNTO 1*p_k+CCW*word_idx_s) <= key_s(2*CCSW-1 downto 1*CCSW);
								isap_key_s(2*p_k+CCW*word_idx_s+CCW-1 DOWNTO 2*p_k+CCW*word_idx_s) <= key_s(3*CCSW-1 downto 2*CCSW);							
								isap_key_s(3*p_k+CCW*word_idx_s+CCW-1 DOWNTO 3*p_k+CCW*word_idx_s) <= key_s(4*CCSW-1 downto 3*CCSW);							
							END IF;
						END IF;

					WHEN STORE_NONCE =>
						-- Every time a word is transferred, increase counter
						-- up to NPUB_WORDS_C
						IF (bdi_valid = '1' AND bdi_ready_s = '1') THEN
							isap_nonce_s(0*p_k+CCW*word_idx_s+CCW-1 DOWNTO 0*p_k+CCW*word_idx_s) <= bdi_s(1*CCW-1 downto 0*CCW);
							isap_nonce_s(1*p_k+CCW*word_idx_s+CCW-1 DOWNTO 1*p_k+CCW*word_idx_s) <= bdi_s(2*CCW-1 downto 1*CCW);
							isap_nonce_s(2*p_k+CCW*word_idx_s+CCW-1 DOWNTO 2*p_k+CCW*word_idx_s) <= bdi_s(3*CCW-1 downto 2*CCW);
							isap_nonce_s(3*p_k+CCW*word_idx_s+CCW-1 DOWNTO 3*p_k+CCW*word_idx_s) <= bdi_s(4*CCW-1 downto 3*CCW);
							
							IF (word_idx_s >= NPUB_WORDS_C - 1) THEN
								IF (isap_auth_encdec_s = AUTH_DEC) THEN
									isap_encmac_s <= ISAP_MAC;
								ELSE
									isap_encmac_s <= ISAP_ENC;
								END IF;
							END IF;
						END IF;

                    WHEN HASH_SETUP_STATE =>
                        -- Setup state with IV||0*.
                        isap_state_s(0*p_n+64-1 DOWNTO 0*p_n) <= reverse_byte(IV_HASH);
                        isap_state_s(1*p_n+64-1 DOWNTO 1*p_n) <= (others => '0'); 
                        isap_state_s(2*p_n+64-1 DOWNTO 2*p_n) <= (others => '0'); 
                        isap_state_s(3*p_n+64-1 DOWNTO 3*p_n) <= (others => '0'); 
						
                        isap_state_s(1*p_n - 1 DOWNTO 0*p_n+64) <= (OTHERS => '0');
                        isap_state_s(2*p_n - 1 DOWNTO 1*p_n+64) <= (OTHERS => '0');
                        isap_state_s(3*p_n - 1 DOWNTO 2*p_n+64) <= (OTHERS => '0');
                        isap_state_s(4*p_n - 1 DOWNTO 3*p_n+64) <= (OTHERS => '0');
                        
                        isap_cnt_s <= p_sH;
                        delay_cnt_s <= LATENCY;
                        pad_added_s <= '0';
                        hash_cnt_s <= 0;
                        isap_encmac_s <= ISAP_MAC;

					WHEN ISAP_RK_SETUP_STATE =>
						-- Fill state with key and IV.
						isap_state_s(0*p_n+p_k-1 DOWNTO 0*p_n) <= isap_key_s(1*p_k-1 downto 0*p_k);
						isap_state_s(1*p_n+p_k-1 DOWNTO 1*p_n) <= isap_key_s(2*p_k-1 downto 1*p_k);		
						isap_state_s(2*p_n+p_k-1 DOWNTO 2*p_n) <= isap_key_s(3*p_k-1 downto 2*p_k);		
						isap_state_s(3*p_n+p_k-1 DOWNTO 3*p_n) <= isap_key_s(4*p_k-1 downto 3*p_k);		
						
						isap_state_s(1*p_n-1 DOWNTO 0*p_n+p_k+64) <= (OTHERS => '0');
						isap_state_s(2*p_n-1 DOWNTO 1*p_n+p_k+64) <= (OTHERS => '0');
						isap_state_s(3*p_n-1 DOWNTO 2*p_n+p_k+64) <= (OTHERS => '0');
						isap_state_s(4*p_n-1 DOWNTO 3*p_n+p_k+64) <= (OTHERS => '0');
						
						isap_cnt_s <= p_sK;
						delay_cnt_s <= LATENCY;

						IF (isap_encmac_s = ISAP_ENC) THEN
							isap_state_s(0*p_n+p_k + 63 DOWNTO 0*p_n+p_k) <= reverse_byte(p_iv_ke);
							isap_state_s(1*p_n+p_k + 63 DOWNTO 1*p_n+p_k) <= (OTHERS => '0');
							isap_state_s(2*p_n+p_k + 63 DOWNTO 2*p_n+p_k) <= (OTHERS => '0');
							isap_state_s(3*p_n+p_k + 63 DOWNTO 3*p_n+p_k) <= (OTHERS => '0');
							
							isap_y_s <= reverse_byte(isap_nonce_s);
						ELSE
							isap_state_s(0*p_n+p_k+63 DOWNTO 0*p_n+p_k) <= reverse_byte(p_iv_ka);
							isap_state_s(1*p_n+p_k+63 DOWNTO 1*p_n+p_k) <= (OTHERS => '0');
							isap_state_s(2*p_n+p_k+63 DOWNTO 2*p_n+p_k) <= (OTHERS => '0');
							isap_state_s(3*p_n+p_k+63 DOWNTO 3*p_n+p_k) <= (OTHERS => '0');
							
							isap_y_s(1*p_k-1 downto 0*p_k) <= reverse_byte(isap_state_s_s0);
							isap_y_s(2*p_k-1 downto 1*p_k) <= reverse_byte(isap_state_s_s1);
							isap_y_s(3*p_k-1 downto 2*p_k) <= reverse_byte(isap_state_s_s2);
							isap_y_s(4*p_k-1 downto 3*p_k) <= reverse_byte(isap_state_s_s3);
							
							isap_buf_s(1*(p_n-p_k) - 1 DOWNTO 0*(p_n-p_k)) <= isap_state_s(1*p_n-1 DOWNTO 0*p_n+p_k);
							isap_buf_s(2*(p_n-p_k) - 1 DOWNTO 1*(p_n-p_k)) <= isap_state_s(2*p_n-1 DOWNTO 1*p_n+p_k);
							isap_buf_s(3*(p_n-p_k) - 1 DOWNTO 2*(p_n-p_k)) <= isap_state_s(3*p_n-1 DOWNTO 2*p_n+p_k);
							isap_buf_s(4*(p_n-p_k) - 1 DOWNTO 3*(p_n-p_k)) <= isap_state_s(4*p_n-1 DOWNTO 3*p_n+p_k);							
						END IF;

					WHEN ISAP_RK_INITIALIZE =>
						-- Perform sK permutation rounds.
						IF (rdi_valid = '1') THEN
						    IF (isap_cnt_s = X"01" and delay_cnt_s = B"01") THEN
							    isap_cnt_s <= p_sB;
							    delay_cnt_s <= LATENCY;
							    isap_cnt_y_s <= 127;
							    isap_state_s <= perm_out_s;
						    ELSE
						        IF (delay_cnt_s = B"01") THEN
						            delay_cnt_s <= LATENCY;
							        isap_cnt_s <= std_logic_vector(unsigned(isap_cnt_s) - 1);
							        isap_state_s <= perm_out_s;
							    ELSE
							        delay_cnt_s <= std_logic_vector(unsigned(delay_cnt_s) - 1);
							    END IF;    
						    END IF;
						END IF;

					WHEN ISAP_RK_REKEYING =>
						-- Absorb Y bit by bit. After absorption of 1 bit do sB permutation rounds.
						IF (rdi_valid = '1') THEN
						    IF (delay_cnt_s = B"01") THEN
						        IF (isap_cnt_y_s = 1 AND isap_cnt_s = X"01") THEN
							        isap_cnt_s <= p_sK;
						        ELSIF (isap_cnt_s = X"01") THEN
							        isap_cnt_s <= p_sB;
						        END IF;
                            
                                isap_cnt_y_s <= isap_cnt_y_s - 1;
                                isap_y_s(1*p_k-1 downto 0*p_k) <= isap_y_s(0*p_k+126 downto 0*p_k) & isap_y_s(0*p_k+127);
                                isap_y_s(2*p_k-1 downto 1*p_k) <= isap_y_s(1*p_k+126 downto 1*p_k) & isap_y_s(1*p_k+127);                        
                                isap_y_s(3*p_k-1 downto 2*p_k) <= isap_y_s(2*p_k+126 downto 2*p_k) & isap_y_s(2*p_k+127);                                                        
								isap_y_s(4*p_k-1 downto 3*p_k) <= isap_y_s(3*p_k+126 downto 3*p_k) & isap_y_s(3*p_k+127);                                                        
								delay_cnt_s <= LATENCY;
						        isap_state_s <= perm_out_s;
						    ELSE
							    delay_cnt_s <= std_logic_vector(unsigned(delay_cnt_s) - 1);
						    END IF; 
						END IF;
					WHEN ISAP_RK_SQUEEZE =>
						-- Perform sK permutation rounds.
						IF (rdi_valid = '1') THEN
						    IF (delay_cnt_s = B"01") THEN
                                delay_cnt_s <= LATENCY;
						        isap_cnt_s <= std_logic_vector(unsigned(isap_cnt_s) - 1);
						        isap_state_s <= perm_out_s;
						    ELSE
							    delay_cnt_s <= std_logic_vector(unsigned(delay_cnt_s) - 1);
						    END IF;    
                        END IF;
					WHEN ISAP_ENC_INITIALIZE =>
						-- Overwrite part of state with nonce.
						isap_cnt_s <= p_sE;
						isap_state_s(1*p_n-1 DOWNTO 1*p_n-p_k) <= isap_nonce_s(1*p_k-1 DOWNTO 0*p_k);
						isap_state_s(2*p_n-1 DOWNTO 2*p_n-p_k) <= isap_nonce_s(2*p_k-1 DOWNTO 1*p_k);						
						isap_state_s(3*p_n-1 DOWNTO 3*p_n-p_k) <= isap_nonce_s(3*p_k-1 DOWNTO 2*p_k);						
						isap_state_s(4*p_n-1 DOWNTO 4*p_n-p_k) <= isap_nonce_s(4*p_k-1 DOWNTO 3*p_k);						

					WHEN ISAP_ENC_PERMUTE_PE =>
						-- Perform sE permutation rounds.
						IF (rdi_valid = '1') THEN
						    IF (delay_cnt_s = B"01") THEN
                                delay_cnt_s <= LATENCY;
						        isap_cnt_s <= std_logic_vector(unsigned(isap_cnt_s) - 1);
						        isap_state_s <= perm_out_s;
						    ELSE
							    delay_cnt_s <= std_logic_vector(unsigned(delay_cnt_s) - 1);
						    END IF;    
                        END IF;
					WHEN ISAP_ENC_SQUEEZE_BLOCK =>
						-- Read from bdi/fifo during en/decryption.
						IF (isap_auth_encdec_s = AUTH_DEC) THEN
							IF (n_state_s = ISAP_ENC_PERMUTE_PE) THEN
								isap_cnt_s <= p_sE;
							END IF;
						ELSE
							IF (bdi_valid = '1' AND bdi_ready_s = '1' AND fifo_din_ready_s = '1') THEN
								IF (bdi_eot = '1') THEN
									-- Remember how many byte of last pt word are valid.
									fifo_last_word_valid_bytes_s <= bdi_valid_bytes;
								END IF;
							END IF;
							IF (n_state_s = ISAP_ENC_PERMUTE_PE) THEN
								isap_cnt_s <= p_sE;
							END IF;
						END IF;

					WHEN ISAP_MAC_SETUP_STATE =>
						-- Fill state with nonce and IV.
						isap_state_s(0*p_n+p_k-1 DOWNTO 0*p_n) <= isap_nonce_s(1*p_k-1 downto 0*p_k);
						isap_state_s(1*p_n+p_k-1 DOWNTO 1*p_n) <= isap_nonce_s(2*p_k-1 downto 1*p_k);			
						isap_state_s(2*p_n+p_k-1 DOWNTO 2*p_n) <= isap_nonce_s(3*p_k-1 downto 2*p_k);			
						isap_state_s(3*p_n+p_k-1 DOWNTO 3*p_n) <= isap_nonce_s(4*p_k-1 downto 3*p_k);			
						
						isap_state_s(0*p_n+p_k+63 DOWNTO 0*p_n+p_k) <= reverse_byte(p_iv_a);
						isap_state_s(1*p_n+p_k+63 DOWNTO 1*p_n+p_k) <= (OTHERS => '0');
						isap_state_s(2*p_n+p_k+63 DOWNTO 2*p_n+p_k) <= (OTHERS => '0');
						isap_state_s(3*p_n+p_k+63 DOWNTO 3*p_n+p_k) <= (OTHERS => '0');
						
						isap_state_s(1*p_n-1 DOWNTO 0*p_n+p_k+64) <= (OTHERS => '0');
						isap_state_s(2*p_n-1 DOWNTO 1*p_n+p_k+64) <= (OTHERS => '0');
						isap_state_s(3*p_n-1 DOWNTO 2*p_n+p_k+64) <= (OTHERS => '0');
						isap_state_s(4*p_n-1 DOWNTO 3*p_n+p_k+64) <= (OTHERS => '0');
						
						isap_cnt_s <= p_sH;
						delay_cnt_s <= LATENCY;
						isap_encmac_s <= ISAP_MAC;

					WHEN ISAP_MAC_INITIALIZE =>
						-- Perform sH permutation rounds.
						IF (rdi_valid = '1') THEN
						    IF (delay_cnt_s = B"01") THEN
						        isap_state_s <= perm_out_s;
							    delay_cnt_s <= LATENCY;

						        IF (n_state_s = ISAP_MAC_ABSORB_AD_PAD) THEN
					                isap_cnt_s <= p_sH;
						        ELSE
							        isap_cnt_s <= std_logic_vector(unsigned(isap_cnt_s) - 1);
						        END IF;
						    ELSE
							    delay_cnt_s <= std_logic_vector(unsigned(delay_cnt_s) - 1);
						    END IF; 
						END IF;  
					WHEN ISAP_MAC_WAIT_INPUT =>
						-- Wait until we know the type of the next input.
						IF (n_state_s /= ISAP_MAC_WAIT_INPUT) THEN
							isap_cnt_s <= p_sH;
							delay_cnt_s <= LATENCY;
						END IF;

					WHEN ISAP_MAC_ABSORB_AD =>
						-- Absorption of AD during ISAP-MAC.
						-- When the last word is processed add padding if there is space for it.
						-- Otherwise remember (pad_added_s) that we need to absorb another block with only padding.
						IF (bdi_valid = '1' AND bdi_ready_s = '1' AND (bdi_type = HDR_AD or bdi_type = HDR_HASH_MSG)) THEN -- hash specific
							isap_state_s <= isap_state_n_s; -- todo new
							IF (bdi_eot = '1' AND bdi_partial_s = '1') THEN
								pad_added_s <= '1';
							ELSIF (bdi_eot = '1' AND bdi_partial_s = '0') THEN
								IF (word_idx_s < BLOCK_WORDS_C - 1) THEN
									pad_added_s <= '1';
								ELSE
									pad_added_s <= '0';
								END IF;
							END IF;
						END IF;
						IF (n_state_s = ISAP_MAC_PROCESS_AD) THEN
							isap_cnt_s <= p_sH;
							delay_cnt_s <= LATENCY;
						END IF;

					WHEN ISAP_MAC_PROCESS_AD =>
						-- Perform sH permutation rounds.
						IF (rdi_valid = '1') THEN
						    IF (delay_cnt_s = B"01") THEN
						        isap_cnt_s <= std_logic_vector(unsigned(isap_cnt_s) - 1);
							    delay_cnt_s <= LATENCY;
						        isap_state_s <= perm_out_s;
						        IF (n_state_s = ISAP_MAC_ABSORB_AD_PAD) THEN
							        isap_cnt_s <= p_sH;
						        END IF;
						    ELSE
							    delay_cnt_s <= std_logic_vector(unsigned(delay_cnt_s) - 1);
						    END IF; 
						END IF; 
					WHEN ISAP_MAC_ABSORB_AD_PAD =>
						-- Absorb block that only contains padding.
						IF (rdi_valid = '1') THEN
						    IF (delay_cnt_s = B"01") THEN
						        isap_cnt_s <= std_logic_vector(unsigned(isap_cnt_s) - 1);
						        delay_cnt_s <= LATENCY;
						        isap_state_s <= perm_out_s;
                                pad_added_s <= '1';
						    ELSE
							    delay_cnt_s <= std_logic_vector(unsigned(delay_cnt_s) - 1);
						    END IF; 
						END IF; 
					WHEN ISAP_MAC_DOMAIN_SEPERATION =>
						-- Flip the highest bit in the state.
						pad_added_s <= '0';
						isap_state_s(1*p_n - 8) <= isap_state_s(1*p_n - 8) XOR '1';
											
						IF (n_state_s = ISAP_MAC_ABSORB_CT_PAD) THEN
							isap_cnt_s <= p_sH;
							delay_cnt_s <= LATENCY;
						END IF;

					WHEN ISAP_MAC_ABSORB_CT =>
						-- Absorption of CT during ISAP-MAC.
						IF (n_state_s = ISAP_MAC_PROCESS_CT) THEN
							isap_cnt_s <= p_sH;
							delay_cnt_s <= LATENCY;
						END IF;
						IF (isap_auth_encdec_s = AUTH_DEC) THEN
							-- Read ct from bdi during decryption.
							IF (bdi_valid = '1' AND bdi_ready_s = '1' AND bdi_type = HDR_CT) THEN
								IF (bdi_eot = '1') THEN
									fifo_last_word_valid_bytes_s <= bdi_valid_bytes;
								END IF;
								-- When the last word is processed add padding if there is space for it.
								-- Otherwise remember (pad_added_s) that we need to absorb another block with only padding.
                                isap_state_s <= isap_state_n_s; -- todo new
								IF (bdi_eot = '1') THEN
									IF (and_reduce(bdi_valid_bytes) = '1') THEN
										IF (word_idx_s < BLOCK_WORDS_C - 1) THEN
											pad_added_s <= '1';
										ELSE
											pad_added_s <= '0';
										END IF;
									ELSE
										pad_added_s <= '1';
									END IF;
								END IF;
							END IF;
						ELSE
							-- Read ct from fifo during encryption.
							IF (fifo_dout_valid_s = '1' AND fifo_dout_ready_s = '1') THEN
								-- When the last word is processed add padding if there is space for it.
								-- Otherwise remember (pad_added_s) that we need to absorb another block with only padding.
								isap_state_s <= isap_state_n_s; -- todo new
								IF (fifo_words_s = 1) THEN
									IF (and_reduce(fifo_last_word_valid_bytes_s) = '1') THEN
										IF (word_idx_s < BLOCK_WORDS_C - 1) THEN
											pad_added_s <= '1';
										ELSE
											pad_added_s <= '0';
										END IF;
									ELSE
										pad_added_s <= '1';
									END IF;
								END IF;
							END IF;
						END IF;

					WHEN ISAP_MAC_PROCESS_CT =>
						-- Perform sH permutation rounds.
						IF (rdi_valid = '1') THEN
						    IF (delay_cnt_s = B"01") THEN
						        isap_cnt_s <= std_logic_vector(unsigned(isap_cnt_s) - 1);
						        delay_cnt_s <= LATENCY;
						        isap_state_s <= perm_out_s;
						        IF (n_state_s = ISAP_MAC_ABSORB_CT_PAD) THEN
							        isap_cnt_s <= p_sH;
						        END IF;
						    ELSE
							    delay_cnt_s <= std_logic_vector(unsigned(delay_cnt_s) - 1);
						    END IF;
						END IF;  
					WHEN ISAP_MAC_ABSORB_CT_PAD =>
						-- Absorb block that only contains padding
						IF (rdi_valid = '1') THEN
					        IF (delay_cnt_s = B"01") THEN
						        isap_cnt_s <= std_logic_vector(unsigned(isap_cnt_s) - 1);
						        delay_cnt_s <= LATENCY;
						        isap_state_s <= perm_out_s;
						    ELSE
							    delay_cnt_s <= std_logic_vector(unsigned(delay_cnt_s) - 1);
						    END IF; 
						END IF;
						
					WHEN ISAP_MAC_FINALIZE_AFTER_RK_STATE_SETUP =>
						-- Overwrite parts of state by the previously saved state after the absorption of ct.
						isap_state_s(1*p_n-1 DOWNTO 0*p_n+p_k) <= isap_buf_s(1*(p_n-p_k)-1 DOWNTO 0*(p_n-p_k));
						isap_state_s(2*p_n-1 DOWNTO 1*p_n+p_k) <= isap_buf_s(2*(p_n-p_k)-1 DOWNTO 1*(p_n-p_k));						
						isap_state_s(3*p_n-1 DOWNTO 2*p_n+p_k) <= isap_buf_s(3*(p_n-p_k)-1 DOWNTO 2*(p_n-p_k));						
						isap_state_s(4*p_n-1 DOWNTO 3*p_n+p_k) <= isap_buf_s(4*(p_n-p_k)-1 DOWNTO 3*(p_n-p_k));						
						
						isap_cnt_s <= p_sH;
                        delay_cnt_s <= LATENCY;

					WHEN ISAP_MAC_FINALIZE_PERMUTE_PH =>
						-- Perform sH permutation rounds.
						IF (rdi_valid = '1') THEN
					        IF (delay_cnt_s = B"01") THEN
						        isap_cnt_s <= std_logic_vector(unsigned(isap_cnt_s) - 1);
						        delay_cnt_s <= LATENCY;
						        isap_state_s <= perm_out_s;
						    ELSE
							    delay_cnt_s <= std_logic_vector(unsigned(delay_cnt_s) - 1);
						    END IF; 
                        END IF;
					WHEN WAIT_ACK =>
						-- Only entered during decryption. After tag verification start decryption.
						IF (n_state_s = ISAP_RK_SETUP_STATE) THEN
							isap_encmac_s <= ISAP_ENC;
						END IF;
						
					when EXTRACT_HASH_VALUE =>
						IF (n_state_s = ISAP_MAC_PROCESS_AD) THEN
							isap_cnt_s <= p_sH;
							delay_cnt_s <= LATENCY;
                            hash_cnt_s <= hash_cnt_s + 1;
						END IF;

					WHEN OTHERS =>
						NULL;

				END CASE;
			END IF;
		END IF;
	END PROCESS p_counters;

END behavioral;
