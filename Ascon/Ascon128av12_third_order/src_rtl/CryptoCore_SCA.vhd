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
use work.ascon_pkg.all;


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
	
    ---------------------------------------------------------------------------
    --! Constant Values: Ascon
    ---------------------------------------------------------------------------
    constant tag_size : integer := 128;
    constant state_size : integer := 320;
    constant iv_size : integer := 64;
    constant rnd_size : integer := 320;
    constant npub_size : integer := 128;
    constant dblk_hash_size : integer := 64;
    constant key_size : integer := 128;
    constant iv_hash : std_logic_vector(63 downto 0) := X"00400c0000000100";	

    --! Constant to check for empty hash
    constant empty_hash_size_c : std_logic_vector(2 downto 0) := (others => '0');
	
    -- Number of words the respective blocks contain.
    constant npub_words_c : integer := get_words(npub_size, CCW);
    constant hash_words_c : integer := get_words(hash_value_size, CCW);
    constant block_words_c : integer := get_words(dblk_size, CCW);
    constant block_hash_words_c : integer := get_words(dblk_hash_size, CCW);
    constant key_words_c : integer := get_words(key_size, CCW);
    constant tag_words_c : integer := get_words(tag_size, CCW);	

    signal n_state_s, state_s : state_t;

    -- Word counter for address generation. Increases every time a word is transferred.
    signal word_idx_s : integer range 0 to hash_words_c - 1;
    signal word_idx_offset_s : integer range 0 to hash_words_c - 1;

    -- Internal Port signals
    signal key_s : std_logic_vector(SDI_SHARES * CCSW - 1 downto 0);
    signal rdi_ready_s : std_logic;
    signal key_ready_s : std_logic;
    signal bdi_ready_s : std_logic;
    signal bdi_s : std_logic_vector(PDI_SHARES * CCW - 1 downto 0);
    signal bdi_s_reg : std_logic_vector(PDI_SHARES * CCW - 1 downto 0);
    signal bdi_valid_bytes_s : std_logic_vector(CCWdiv8 - 1 downto 0);
    signal bdi_pad_loc_s : std_logic_vector(CCWdiv8 - 1 downto 0);

    signal bdo_s : std_logic_vector(PDI_SHARES * CCW - 1 downto 0);
    signal bdo_valid_bytes_s : std_logic_vector(CCWdiv8 - 1 downto 0);
    signal bdo_valid_s : std_logic;
    signal bdo_type_s : std_logic_vector(3 downto 0);
    signal end_of_block_s : std_logic;
    signal msg_auth_valid_s : std_logic;
    signal bdoo_s : std_logic_vector(PDI_SHARES * CCW - 1 downto 0);
    signal bdoo_s_reg : std_logic_vector(PDI_SHARES * CCW - 1 downto 0);

    -- Internal Flags
    signal n_decrypt_s, decrypt_s : std_logic;
    signal n_hash_s, hash_s : std_logic;
    signal n_empty_hash_s, empty_hash_s : std_logic;
    signal n_msg_auth_s, msg_auth_s : std_logic;
    signal n_eoi_s, eoi_s : std_logic;
    signal n_eot_s, eot_s : std_logic;
    signal n_update_key_s, update_key_s : std_logic;

    -- Utility Signals
    signal bdi_partial_s : std_logic;
    signal pad_added_s : std_logic;
    signal bit_pos_s : integer range 0 to 511;

    -- Ascon Signals
    signal ascon_state_s : std_logic_vector(PDI_SHARES * STATE_SIZE - 1 downto 0);
    signal ascon_state_s_unshared : std_logic_vector(STATE_SIZE - 1 downto 0);

    signal ascon_state_n_s : std_logic_vector(PDI_SHARES * STATE_SIZE - 1 downto 0);
    signal ascon_cnt_s : std_logic_vector(7 downto 0);
    signal delay_cnt_s : std_logic_vector(7 downto 0);

    signal ascon_key_s : std_logic_vector(SDI_SHARES * KEY_SIZE - 1 downto 0);
    signal ascon_nonce_s : std_logic_vector(PDI_SHARES * NPUB_SIZE - 1 downto 0);
    signal ascon_rcon_s : std_logic_vector(3 downto 0);
    signal ascon_hash_cnt_s : integer range 0 to 3;

    -- Ascon-p
    signal asconp_out_s : std_logic_vector(PDI_SHARES * STATE_SIZE - 1 downto 0);
    
	signal bdi_s_unshared : std_logic_vector(CCW - 1 downto 0);
    signal bdoo_s_unshared : std_logic_vector(CCW - 1 downto 0);

BEGIN
    ----------------------------------------------------------------------------
    -- I/O Mappings
    -- Algorithm is specified in Big Endian. However, this is a Little Endian
    -- implementation so reverse_byte/bit functions are used to reorder affected signals.
    ----------------------------------------------------------------------------
    key_s <= reverse_bytes(key);
    bdi_s <= reverse_bytes(bdi);
    bdi_valid_bytes_s <= reverse_bits(bdi_valid_bytes);
    bdi_pad_loc_s <= reverse_bits(bdi_pad_loc);
    rdi_ready <= rdi_ready_s;
    key_ready <= key_ready_s;
    bdi_ready <= bdi_ready_s;
    bdo <= reverse_bytes(bdo_s);
    bdo_valid_bytes <= reverse_bits(bdo_valid_bytes_s);
    bdo_valid <= bdo_valid_s;
    bdo_type <= bdo_type_s;
    end_of_block <= end_of_block_s;
    msg_auth <= msg_auth_s;
    msg_auth_valid <= msg_auth_valid_s;

    ---------------------------------------------------------------------------
    --! Utility Signals
    ---------------------------------------------------------------------------

    -- Used to determine whether 0x80 padding word can be inserted into this last word.
    bdi_partial_s <= or_reduce(bdi_pad_loc_s);

    -- Lowest bit index in state that is currently used for data absorption/extraction.
    bit_pos_s <= (word_idx_s MOD (DBLK_SIZE/CCW)) * CCW;

    -- Round constant for Ascon-p.
    ascon_rcon_s <= ascon_cnt_s(3 DOWNTO 0);

    ---------------------------------------------------------------------------
    --! Ascon-p instantiation
    ---------------------------------------------------------------------------
    bdoo_s_unshared <= (others => '0'); --bdoo_s_reg(1*CCW-1 DOWNTO 0*CCW) xor bdoo_s_reg(2*CCW-1 DOWNTO 1*CCW) xor bdoo_s_reg(3*CCW-1 DOWNTO 2*CCW) xor bdoo_s_reg(4*CCW-1 DOWNTO 3*CCW);
    bdi_s_unshared  <=  (others => '0'); --bdi_s_reg(1*CCW-1 DOWNTO 0*CCW) xor  bdi_s_reg(2*CCW-1 DOWNTO 1*CCW) xor  bdi_s_reg(3*CCW-1 DOWNTO 2*CCW) xor  bdi_s_reg(4*CCW-1 DOWNTO 3*CCW);

    i_Asconp_HPC2_ClockGating_d3: Asconp_HPC2_ClockGating_d3
        port map (
            clk => clk,
            state_in_s0 => ascon_state_s(1 * STATE_SIZE - 1 DOWNTO 0 * STATE_SIZE),
            state_in_s1 => ascon_state_s(2 * STATE_SIZE - 1 DOWNTO 1 * STATE_SIZE),
            state_in_s2 => ascon_state_s(3 * STATE_SIZE - 1 DOWNTO 2 * STATE_SIZE),
            state_in_s3 => ascon_state_s(4 * STATE_SIZE - 1 DOWNTO 3 * STATE_SIZE),
			state_out_s0 => asconp_out_s(1 * STATE_SIZE - 1 DOWNTO 0 * STATE_SIZE),
            state_out_s1 => asconp_out_s(2 * STATE_SIZE - 1 DOWNTO 1 * STATE_SIZE),  
            state_out_s2 => asconp_out_s(3 * STATE_SIZE - 1 DOWNTO 2 * STATE_SIZE),  
            state_out_s3 => asconp_out_s(4 * STATE_SIZE - 1 DOWNTO 3 * STATE_SIZE),  
			rcon => ascon_rcon_s,
            fresh => rdi
        );
    
    -- Quick fix for dynamic slicing
    p_CASE : process (word_idx_s,ascon_state_s,word_idx_offset_s)
        variable sel : INTEGER RANGE 0 TO 9;
    begin
        sel := word_idx_s + word_idx_offset_s;
    case sel is
        when 0 =>
        bdoo_s <= ascon_state_s(3*STATE_SIZE+1*32-1 DOWNTO 3*STATE_SIZE+32*0) & ascon_state_s(2*STATE_SIZE+1*32-1 DOWNTO 2*STATE_SIZE+32*0) & ascon_state_s(1*STATE_SIZE+1*32-1 DOWNTO 1*STATE_SIZE+32*0) & ascon_state_s(0*STATE_SIZE+1*32-1 DOWNTO 0*STATE_SIZE+32*0);
        when 1 =>
        bdoo_s <= ascon_state_s(3*STATE_SIZE+2*32-1 DOWNTO 3*STATE_SIZE+32*1) & ascon_state_s(2*STATE_SIZE+2*32-1 DOWNTO 2*STATE_SIZE+32*1) & ascon_state_s(1*STATE_SIZE+2*32-1 DOWNTO 1*STATE_SIZE+32*1) & ascon_state_s(0*STATE_SIZE+2*32-1 DOWNTO 0*STATE_SIZE+32*1);
        when 2 =>
        bdoo_s <= ascon_state_s(3*STATE_SIZE+3*32-1 DOWNTO 3*STATE_SIZE+32*2) & ascon_state_s(2*STATE_SIZE+3*32-1 DOWNTO 2*STATE_SIZE+32*2) & ascon_state_s(1*STATE_SIZE+3*32-1 DOWNTO 1*STATE_SIZE+32*2) & ascon_state_s(0*STATE_SIZE+3*32-1 DOWNTO 0*STATE_SIZE+32*2);
        when 3 =>
        bdoo_s <= ascon_state_s(3*STATE_SIZE+4*32-1 DOWNTO 3*STATE_SIZE+32*3) & ascon_state_s(2*STATE_SIZE+4*32-1 DOWNTO 2*STATE_SIZE+32*3) & ascon_state_s(1*STATE_SIZE+4*32-1 DOWNTO 1*STATE_SIZE+32*3) & ascon_state_s(0*STATE_SIZE+4*32-1 DOWNTO 0*STATE_SIZE+32*3);
--        when 4 =>
--        bdoo_s <= ascon_state_s(31+32*4 DOWNTO 32*4);
--        when 5 =>
--        bdoo_s <= ascon_state_s(31+32*5 DOWNTO 32*5);
        when 6 =>
        bdoo_s <= ascon_state_s(3*STATE_SIZE+7*32-1 DOWNTO 3*STATE_SIZE+32*6) & ascon_state_s(2*STATE_SIZE+7*32-1 DOWNTO 2*STATE_SIZE+32*6) & ascon_state_s(1*STATE_SIZE+7*32-1 DOWNTO 1*STATE_SIZE+32*6) & ascon_state_s(0*STATE_SIZE+7*32-1 DOWNTO 0*STATE_SIZE+32*6);
        when 7 =>
        bdoo_s <= ascon_state_s(3*STATE_SIZE+8*32-1 DOWNTO 3*STATE_SIZE+32*7) & ascon_state_s(2*STATE_SIZE+8*32-1 DOWNTO 2*STATE_SIZE+32*7) & ascon_state_s(1*STATE_SIZE+8*32-1 DOWNTO 1*STATE_SIZE+32*7) & ascon_state_s(0*STATE_SIZE+8*32-1 DOWNTO 0*STATE_SIZE+32*7);
        when 8 =>
        bdoo_s <= ascon_state_s(3*STATE_SIZE+9*32-1 DOWNTO 3*STATE_SIZE+32*8) & ascon_state_s(2*STATE_SIZE+9*32-1 DOWNTO 2*STATE_SIZE+32*8) & ascon_state_s(1*STATE_SIZE+9*32-1 DOWNTO 1*STATE_SIZE+32*8) & ascon_state_s(0*STATE_SIZE+9*32-1 DOWNTO 0*STATE_SIZE+32*8);
        when 9 =>
        bdoo_s <= ascon_state_s(3*STATE_SIZE+10*32-1 DOWNTO 3*STATE_SIZE+32*9) & ascon_state_s(2*STATE_SIZE+10*32-1 DOWNTO 2*STATE_SIZE+32*9) & ascon_state_s(1*STATE_SIZE+10*32-1 DOWNTO 1*STATE_SIZE+32*9) & ascon_state_s(0*STATE_SIZE+10*32-1 DOWNTO 0*STATE_SIZE+32*9);
        when others =>
        bdoo_s <= (OTHERS => '0');
    end case;
    end process;
    
    -- Quick fix for dynamic slicing 2
    p_CASE2 : process (word_idx_s,ascon_state_s,word_idx_offset_s,state_s,bdi_s,decrypt_s,bdi_valid_bytes_s,bdi_pad_loc_s,bdoo_s_unshared,bdi_eot,bdi_partial_s,bdoo_s)
        variable sel : INTEGER RANGE 0 TO 9;
        variable pad1 : STD_LOGIC_VECTOR(PDI_SHARES * 32 - 1 DOWNTO 0);
        variable pad2 : STD_LOGIC_VECTOR(PDI_SHARES * 32 - 1 DOWNTO 0);

    begin
        sel := word_idx_s + word_idx_offset_s;
        pad1 := pad_bdi(bdi_s, bdi_valid_bytes_s, bdi_pad_loc_s, bdoo_s, '0');
        pad2 := pad_bdi(bdi_s, bdi_valid_bytes_s, bdi_pad_loc_s, bdoo_s, decrypt_s);

    case state_s is
        when ABSORB_AD | ABSORB_HASH_MSG =>
            case word_idx_s is
                when 0 =>
                    ascon_state_n_s <= dyn_slice_fix(pad1,bdi_eot,bdi_partial_s,ascon_state_s,0,state_s);
                when 1 =>
                    ascon_state_n_s <= dyn_slice_fix(pad1,bdi_eot,bdi_partial_s,ascon_state_s,1,state_s);
                when 2 =>
                    ascon_state_n_s <= dyn_slice_fix(pad1,bdi_eot,bdi_partial_s,ascon_state_s,2,state_s);
                when 3 =>
                    ascon_state_n_s <= dyn_slice_fix(pad1,bdi_eot,bdi_partial_s,ascon_state_s,3,state_s);
                when others =>
                    ascon_state_n_s <= ascon_state_s;
            end case;
            
        when ABSORB_MSG =>
            case word_idx_s is
                when 0 =>
                    ascon_state_n_s <= dyn_slice_fix(pad2,bdi_eot,bdi_partial_s,ascon_state_s,0,state_s);
                when 1 =>
                    ascon_state_n_s <= dyn_slice_fix(pad2,bdi_eot,bdi_partial_s,ascon_state_s,1,state_s);
                when 2 =>
                    ascon_state_n_s <= dyn_slice_fix(pad2,bdi_eot,bdi_partial_s,ascon_state_s,2,state_s);
                when 3 =>
                    ascon_state_n_s <= dyn_slice_fix(pad2,bdi_eot,bdi_partial_s,ascon_state_s,3,state_s);
                when others =>
                    ascon_state_n_s <= ascon_state_s;
                end case;

        when others =>
                    ascon_state_n_s <= ascon_state_s;
                end case;
    end process;

    -- Word idx  offset process
    asdf_CASE : process (word_idx_s,state_s)
    begin
        word_idx_offset_s <= 0;

        CASE state_s IS

        WHEN EXTRACT_TAG =>
            word_idx_offset_s <= 6;
        
        WHEN VERIFY_TAG =>
            word_idx_offset_s <= 6;
        
        WHEN others =>
            null;
    end case;
    end process;

    ----------------------------------------------------------------------------
    --! Bdo multiplexer
    ----------------------------------------------------------------------------
    bdo_mux : PROCESS (state_s, bdi_s_unshared, word_idx_s, bdi_ready_s,
        bdi_valid_bytes_s, bdi_valid, bdi_eot, decrypt_s, ascon_state_s,
        hash_s, bit_pos_s, ascon_hash_cnt_s, bdoo_s_unshared,bdoo_s, bdi_s)
    BEGIN

        -- Directly connect bdi and bdo signals and encryp/decrypt data.
        -- No default values so each signal requires an assignment in each case.
        CASE state_s IS

            WHEN ABSORB_MSG =>
                bdo_s <= bdoo_s XOR bdi_s;
                bdo_valid_bytes_s <= bdi_valid_bytes_s;
                bdo_valid_s <= bdi_ready_s;
                end_of_block_s <= bdi_eot;
                IF (decrypt_s = '1') THEN
                    bdo_type_s <= HDR_PT;
                ELSE
                    bdo_type_s <= HDR_CT;
                END IF;

            WHEN EXTRACT_TAG =>
                bdo_s <= bdoo_s;
                bdo_valid_bytes_s <= (OTHERS => '1');
                bdo_valid_s <= '1';
                bdo_type_s <= HDR_TAG;
                IF (word_idx_s = TAG_WORDS_C - 1 AND hash_s = '0')
                    OR (word_idx_s >= HASH_WORDS_C - 1 AND hash_s = '1') THEN
                    end_of_block_s <= '1';
                ELSE
                    end_of_block_s <= '0';
                END IF;

            WHEN EXTRACT_HASH_VALUE =>
                bdo_s <= bdoo_s;
                bdo_valid_bytes_s <= (OTHERS => '1');
                bdo_valid_s <= '1';
                bdo_type_s <= HDR_HASH_VALUE;
                IF (word_idx_s >= BLOCK_HASH_WORDS_C - 1 AND ascon_hash_cnt_s = 3) THEN
                    end_of_block_s <= '1';
                ELSE
                    end_of_block_s <= '0';
                END IF;

            WHEN OTHERS =>
                bdo_s <= (OTHERS => '0');
                bdo_valid_bytes_s <= (OTHERS => '0');
                bdo_valid_s <= '0';
                end_of_block_s <= '0';
                bdo_type_s <= (OTHERS => '0');

        END CASE;
    END PROCESS bdo_mux;

    ----------------------------------------------------------------------------
    --! Registers for state and internal signals
    ----------------------------------------------------------------------------
    p_reg : PROCESS (clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF (rst = '1') THEN
                msg_auth_s <= '1';
                eoi_s <= '0';
                eot_s <= '0';
                update_key_s <= '0';
                decrypt_s <= '0';
                hash_s <= '0';
                empty_hash_s <= '0';
                state_s <= IDLE;
            ELSE
                msg_auth_s <= n_msg_auth_s;
                eoi_s <= n_eoi_s;
                eot_s <= n_eot_s;
                update_key_s <= n_update_key_s;
                decrypt_s <= n_decrypt_s;
                hash_s <= n_hash_s;
                empty_hash_s <= n_empty_hash_s;
                state_s <= n_state_s;
            END IF;
        END IF;
    END PROCESS p_reg;

    ----------------------------------------------------------------------------
    --! Next_state FSM
    ----------------------------------------------------------------------------
    p_next_state : PROCESS (state_s, rdi_valid, rdi_ready_s, key_valid, key_ready_s, key_update, bdi_valid,
        bdi_ready_s, bdi_eot, bdi_eoi, eoi_s, eot_s, bdi_type, bdi_pad_loc_s,
        word_idx_s, hash_in, decrypt_s, bdo_valid_s, bdo_ready,
        msg_auth_valid_s, msg_auth_ready, bdi_partial_s, ascon_cnt_s, hash_s, pad_added_s, bdi_ready_s, ascon_hash_cnt_s)
    BEGIN

        -- Default values preventing latches
        n_state_s <= state_s;

        CASE state_s IS

            WHEN IDLE =>
                -- Wakeup as soon as valid bdi or key is signaled.
                IF (key_valid = '1' OR bdi_valid = '1') THEN
                    n_state_s <= STORE_RND;
                END IF;

            WHEN STORE_RND =>
                IF (rdi_valid = '1' AND rdi_ready_s = '1') THEN
                    IF (hash_in = '1') THEN
                        n_state_s <= INIT_HASH;
                    ELSE
                        n_state_s <= STORE_KEY;
                    END IF;                
                END IF;
                
            WHEN INIT_HASH =>
                n_state_s <= INIT_PROCESS;

            WHEN STORE_KEY =>
                -- Wait until the new key is received.
                -- It is assumed that key is only updated if Npub follows.
                IF (((key_valid = '1' AND key_ready_s = '1') OR key_update = '0') AND word_idx_s >= KEY_WORDS_C - 1) THEN
                    n_state_s <= STORE_NONCE;
                END IF;

            WHEN STORE_NONCE =>
                -- Wait until the whole nonce block is received.
                IF (bdi_valid = '1' AND bdi_ready_s = '1' AND word_idx_s >= NPUB_WORDS_C - 1) THEN
                    n_state_s <= INIT_STATE_SETUP;
                END IF;

            WHEN INIT_STATE_SETUP =>
                n_state_s <= INIT_PROCESS;

            WHEN INIT_PROCESS =>
                -- After state initialization jump to aead or hash routine.
                IF (ascon_cnt_s = std_logic_vector(to_unsigned(ZERRO,ascon_cnt_s'length))) THEN
                    IF (hash_s = '1') THEN
                        IF (eoi_s = '1') THEN
                            n_state_s <= PAD_HASH_MSG;
                        ELSE
                            n_state_s <= ABSORB_HASH_MSG;
                        END IF;
                    ELSE
                        n_state_s <= INIT_KEY_ADD;
                    END IF;
                END IF;

            WHEN INIT_KEY_ADD =>
                -- If ad length is zero then domain seperation follows directly after.
                IF (eoi_s = '1') THEN
                    n_state_s <= DOM_SEP;
                ELSE
                    n_state_s <= ABSORB_AD;
                END IF;

            WHEN ABSORB_AD =>
                -- Absorb and process ad then perform domain seperation.
                IF (bdi_valid = '1' AND bdi_type /= HDR_AD) THEN
                    n_state_s <= DOM_SEP;
                ELSIF (bdi_valid = '1' AND bdi_ready_s = '1' AND (bdi_eot = '1' OR word_idx_s >= BLOCK_WORDS_C - 1)) THEN
                    n_state_s <= PROCESS_AD;
                END IF;

            WHEN PROCESS_AD =>
                -- Absorb ad blocks until rate is reached or end of type is signaled.
                -- Then check whether padding is necessary or not.                
                IF (ascon_cnt_s = std_logic_vector(to_unsigned(ZERRO,ascon_cnt_s'length))) THEN
                    IF (pad_added_s = '0') THEN
                        IF (eot_s = '1') THEN
                            n_state_s <= PAD_AD;
                        ELSE
                            n_state_s <= ABSORB_AD;
                        END IF;
                    ELSE
                        n_state_s <= DOM_SEP;
                    END IF;
                END IF;

            WHEN PAD_AD =>
                -- Absorb empty block with padding.
                n_state_s <= PROCESS_AD;

            WHEN DOM_SEP =>
                -- Perform domain separation.
                -- If there is no more input absorb empty block with padding.
                IF (eoi_s = '1') THEN
                    n_state_s <= PAD_MSG;
                ELSE
                    n_state_s <= ABSORB_MSG;
                END IF;

            WHEN ABSORB_MSG =>
                -- Absorb msb blocks until rate is reached or end of type is signaled.
                -- Then check whether padding is necessary or not.
                IF (bdi_ready_s = '1') THEN
                    IF (eoi_s = '1') THEN
                        n_state_s <= FINAL_KEY_ADD_1;
                    ELSE
                        IF (bdi_eot = '1') THEN
                            IF (word_idx_s < BLOCK_WORDS_C - 1 OR bdi_partial_s = '1') THEN
                                n_state_s <= FINAL_KEY_ADD_1;
                            ELSE
                                n_state_s <= PROCESS_MSG;
                            END IF;
                        ELSIF (word_idx_s >= BLOCK_WORDS_C - 1) THEN
                            n_state_s <= PROCESS_MSG;
                        END IF;
                    END IF;
                END IF;

            WHEN PROCESS_MSG =>
                -- Process state after absorbing msg block.                
                IF (ascon_cnt_s = std_logic_vector(to_unsigned(ZERRO,ascon_cnt_s'length))) THEN
                    IF (eoi_s = '1') THEN
                        n_state_s <= PAD_MSG;
                    ELSE
                        n_state_s <= ABSORB_MSG;
                    END IF;
                END IF;

            WHEN PAD_MSG =>
                -- Absorb empty block with padding.
                n_state_s <= FINAL_KEY_ADD_1;

            WHEN FINAL_KEY_ADD_1 =>
                -- Second to last key addition.
                n_state_s <= FINAL_PROCESS;

            WHEN FINAL_PROCESS =>
                -- Process state during finalization.                
                IF (ascon_cnt_s = std_logic_vector(to_unsigned(ZERRO,ascon_cnt_s'length))) THEN
                    n_state_s <= FINAL_KEY_ADD_2;
                END IF;

            WHEN FINAL_KEY_ADD_2 =>
                -- After last key addition, either verify or extract the tag.
                IF (decrypt_s = '1') THEN
                    n_state_s <= VERIFY_TAG;
                ELSE
                    n_state_s <= EXTRACT_TAG;
                END IF;

            WHEN EXTRACT_TAG =>
                -- Wait until the whole tag block is transferred, then go back to IDLE.
                IF (bdo_valid_s = '1' AND bdo_ready = '1' AND word_idx_s >= TAG_WORDS_C - 1) THEN
                    n_state_s <= IDLE;
                END IF;

            WHEN VERIFY_TAG =>
                -- Wait until the tag being verified is received, continue
                -- with waiting for acknowledgement on msg_auth_valis.
                IF (bdi_valid = '1' AND bdi_ready_s = '1' AND word_idx_s >= TAG_WORDS_C - 1) THEN
                    n_state_s <= WAIT_ACK;
                END IF;

            WHEN WAIT_ACK =>
                -- Wait until message authentication is acknowledged.
                IF (msg_auth_valid_s = '1' AND msg_auth_ready = '1') THEN
                    n_state_s <= IDLE;
                END IF;

            WHEN ABSORB_HASH_MSG =>
                -- Absorb msg words until either the rate is reached or the end of hash input is signaled.
                -- Then process the state.
                IF (bdi_valid = '1' AND bdi_ready_s = '1') THEN
                    IF (bdi_eoi = '1' OR word_idx_s >= BLOCK_HASH_WORDS_C - 1) THEN
                        n_state_s <= PROCESS_HASH;
                    END IF;
                END IF;

            WHEN PAD_HASH_MSG =>
                -- Absorb empty block with padding.
                n_state_s <= PROCESS_HASH;

            WHEN PROCESS_HASH =>
                -- Perform ROUNDS_B permutation rounds.
                -- Afterwards, absorb more msg blocks, absorb padding or start extracting the hash value.                
                IF (ascon_cnt_s = std_logic_vector(to_unsigned(ZERRO,ascon_cnt_s'length))) THEN
                    IF (eoi_s = '1') THEN
                        IF (pad_added_s = '1') THEN
                            n_state_s <= EXTRACT_HASH_VALUE;
                        ELSE
                            n_state_s <= PAD_HASH_MSG;
                        END IF;
                    ELSE
                        n_state_s <= ABSORB_HASH_MSG;
                    END IF;
                END IF;

            WHEN EXTRACT_HASH_VALUE =>
                -- Wait until the whole hash is transferred, then go back to IDLE.
                IF (bdo_valid_s = '1' AND bdo_ready = '1' AND word_idx_s >= BLOCK_HASH_WORDS_C - 1) THEN
                    IF (ascon_hash_cnt_s < 3) THEN
                        n_state_s <= PROCESS_HASH;
                    ELSE
                        n_state_s <= IDLE;
                    END IF;
                END IF;

            WHEN OTHERS =>
                n_state_s <= IDLE;

        END CASE;
    END PROCESS p_next_state;

    ----------------------------------------------------------------------------
    --! Decoder process for control logic
    ----------------------------------------------------------------------------
    p_decoder : PROCESS (state_s, rdi_valid, rdi_ready_s, key_valid, key_ready_s, update_key_s, eot_s,
        bdi_s_unshared, bdi_valid, bdi_ready_s, bdi_eoi, bdi_eot, key_update, bdi_s, bdoo_s,
        bdi_size, bdi_type, eoi_s, hash_in, hash_s, empty_hash_s, decrypt_in, decrypt_s,
        bdo_ready, word_idx_s, msg_auth_s, msg_auth_valid_s,bdoo_s_unshared)
    BEGIN

        -- Default values preventing latches
        rdi_ready_s <= '0';
        key_ready_s <= '0';
        bdi_ready_s <= '0';
        msg_auth_valid_s <= '0';
        n_msg_auth_s <= msg_auth_s;
        n_eoi_s <= eoi_s;
        n_eot_s <= eot_s;
        n_update_key_s <= update_key_s;
        n_hash_s <= hash_s;
        n_empty_hash_s <= empty_hash_s;
        n_decrypt_s <= decrypt_s;
        bdi_s_reg <= (others => '0');
        bdoo_s_reg <= (others => '0');

        CASE state_s IS

            WHEN IDLE =>
                -- Default values.
                n_msg_auth_s <= '1';
                n_eoi_s <= '0';
                n_eot_s <= '0';
                n_update_key_s <= '0';
                n_hash_s <= '0';
                n_empty_hash_s <= '0';
                n_decrypt_s <= '0';
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

            WHEN STORE_RND =>
                rdi_ready_s <= '1';

            WHEN INIT_PROCESS =>
                rdi_ready_s <= '1';

            WHEN PROCESS_AD =>
                rdi_ready_s <= '1';

            WHEN PROCESS_MSG =>
                rdi_ready_s <= '1';

            WHEN FINAL_PROCESS =>
                rdi_ready_s <= '1';

            WHEN PROCESS_HASH =>
                rdi_ready_s <= '1';

            WHEN STORE_KEY =>
                -- If key must be updated, assert key_ready.
                IF (update_key_s = '1') THEN
                    key_ready_s <= '1';
                END IF;

            WHEN STORE_NONCE =>
                -- Store bdi_eoi (will only be effective on last word) and decrypt_in flag.
                bdi_ready_s <= '1';
                n_eoi_s <= bdi_eoi;
                n_decrypt_s <= decrypt_in;

                -- If pt or ct is detected, don't assert bdi_ready, otherwise first word gets lost.
                -- Remember if eoi and eot were raised during a valid transfer. 
            WHEN ABSORB_AD =>
                IF (bdi_valid = '1' AND bdi_type = HDR_AD) THEN
                    bdi_ready_s <= '1';
                    n_eoi_s <= bdi_eoi;
                    n_eot_s <= bdi_eot;
                END IF;

            WHEN ABSORB_MSG =>
                -- Only signal bdi_ready if bdo can receive data.
                -- Remember if eoi or eot were raised during a valid transfer.
                IF (bdi_valid = '1' AND (bdi_type = HDR_PT OR bdi_type = HDR_CT)) THEN
                    bdi_ready_s <= bdo_ready;
                    IF (bdi_ready_s = '1') THEN
                        n_eoi_s <= bdi_eoi;
                        n_eot_s <= bdi_eot;
                    END IF;
                END IF;

            WHEN VERIFY_TAG =>
                -- As soon as bdi input doesn't match with calculated tag, reset msg_auth.
                bdi_ready_s <= '1';
                IF (bdi_valid = '1' AND bdi_ready_s = '1' AND bdi_type = HDR_TAG) THEN
                    bdi_s_reg <= bdi_s;
                    bdoo_s_reg <= bdoo_s;

                    -- IF (bdi_s /= ascon_state_s(192 + (word_idx_s * CCW) + CCW - 1 DOWNTO 192 + (word_idx_s * CCW))) THEN
                    IF (bdi_s_unshared /= bdoo_s_unshared) THEN
                        n_msg_auth_s <= '0';
                    END IF;
                END IF;

            WHEN WAIT_ACK =>
                -- Signal msg auth valid.
                msg_auth_valid_s <= '1';

            WHEN INIT_HASH =>
                -- If empty hash is detected, acknowledge with one cycle bdi_ready.
                -- Afterwards empty_hash_s flag can be deasserted, it's not needed anymore.
                IF (empty_hash_s = '1') THEN
                    bdi_ready_s <= '1';
                    n_empty_hash_s <= '0';
                END IF;

            WHEN ABSORB_HASH_MSG =>
                -- Set bdi_ready and connect the valid hash_msg bytes to tag_ram for absorption.
                IF (bdi_valid = '1' AND bdi_type = HDR_HASH_MSG AND eoi_s = '0') THEN
                    bdi_ready_s <= '1';
                    n_eoi_s <= bdi_eoi;
                    n_eot_s <= bdi_eot;
                END IF;

            WHEN OTHERS =>
                NULL;

        END CASE;
    END PROCESS p_decoder;

    ----------------------------------------------------------------------------
    --! Word counters
    ----------------------------------------------------------------------------
    p_counters : PROCESS (clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF (rst = '1') THEN
                word_idx_s <= 0;
            ELSE
                CASE state_s IS

                    WHEN IDLE =>
                        -- Nothing to do here, reset counters
                        word_idx_s <= 0;

                    WHEN STORE_KEY =>
                        -- If key is to be updated, increase counter on every successful
                        -- data transfer (valid and ready), else just count the cycles.
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
                                word_idx_s <= word_idx_s + 1; -- todo necessary?
                            END IF;
                        END IF;

                    WHEN STORE_NONCE =>
                        -- Every time a nonce word is transferred, increase counter
                        IF (bdi_valid = '1' AND bdi_ready_s = '1') THEN
                            IF (word_idx_s >= NPUB_WORDS_C - 1) THEN
                                word_idx_s <= 0;
                            ELSE
                                word_idx_s <= word_idx_s + 1;
                            END IF;
                        END IF;

                    WHEN ABSORB_AD =>
                        -- On valid transfer, increase word counter until either
                        -- the block size is reached or the last ad word is obtained.
                        IF (bdi_valid = '1' AND bdi_ready_s = '1') THEN
                            IF (word_idx_s >= BLOCK_WORDS_C - 1 OR (bdi_eot = '1' AND bdi_partial_s = '1')) THEN
                                word_idx_s <= 0;
                            ELSE
                                word_idx_s <= word_idx_s + 1;
                            END IF;
                        END IF;

                    WHEN PAD_AD =>
                        word_idx_s <= 0;

                    WHEN DOM_SEP =>
                        word_idx_s <= 0;

                    WHEN ABSORB_MSG =>
                        -- On valid transfer, increase word counter until either
                        -- the block size is reached or the last msg word is obtained.
                        IF (bdi_valid = '1' AND bdi_ready_s = '1') THEN
                            IF (word_idx_s >= BLOCK_WORDS_C - 1 OR (bdi_eot = '1' AND bdi_partial_s = '1')) THEN
                                word_idx_s <= 0;
                            ELSE
                                word_idx_s <= word_idx_s + 1;
                            END IF;
                        END IF;

                    WHEN PAD_MSG =>
                        word_idx_s <= 0;

                    WHEN FINAL_PROCESS | FINAL_KEY_ADD_2 =>
                        word_idx_s <= 0;

                    WHEN EXTRACT_TAG =>
                        -- Increase word counter on valid bdo transfer until tag size is reached.
                        IF (bdo_valid_s = '1' AND bdo_ready = '1') THEN
                            IF (word_idx_s >= TAG_WORDS_C - 1) THEN
                                word_idx_s <= 0;
                            ELSE
                                word_idx_s <= word_idx_s + 1;
                            END IF;
                        END IF;

                    WHEN VERIFY_TAG =>
                        -- Increase word counter when transferring the tag.
                        IF (bdi_valid = '1' AND bdi_ready_s = '1' AND bdi_type = HDR_TAG) THEN
                            IF (n_state_s = WAIT_ACK) THEN
                                word_idx_s <= 0;
                            ELSE
                                word_idx_s <= word_idx_s + 1;
                            END IF;
                        END IF;

                    WHEN INIT_HASH =>
                        word_idx_s <= 0;

                    WHEN ABSORB_HASH_MSG =>
                        -- Increase word counter when transferring data until either the block size
                        -- for hash msg is reached or the last word is transferred.
                        IF (bdi_valid = '1' AND bdi_ready_s = '1') THEN
                            IF (n_state_s = PROCESS_HASH) THEN
                                word_idx_s <= 0;
                            ELSE
                                word_idx_s <= word_idx_s + 1;
                            END IF;
                        END IF;

                    WHEN PAD_HASH_MSG =>
                        word_idx_s <= 0;

                    WHEN EXTRACT_HASH_VALUE =>
                        -- Increase word counter on valid bdo transfer until hash size is reached.
                        IF (bdo_valid_s = '1' AND bdo_ready = '1') THEN
                            IF (n_state_s /= EXTRACT_HASH_VALUE) THEN
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
    END PROCESS p_counters;

    ----------------------------------------------------------------------------
    --! Ascon FSM
    ----------------------------------------------------------------------------
    p_ascon_fsm : PROCESS (clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF (rst = '1') THEN
                NULL;
            ELSE
                CASE state_s IS

                    WHEN IDLE =>
                        NULL;

                    WHEN STORE_KEY =>
                        -- Update key register.
                        IF (key_update = '1') THEN
                            IF (key_valid = '1' AND key_ready_s = '1') THEN
                                ascon_key_s(CCSW*word_idx_s+CCSW-1+0*KEY_SIZE DOWNTO CCSW*word_idx_s+0*KEY_SIZE) <= key_s(1*CCSW-1 downto 0*CCSW);
                                ascon_key_s(CCSW*word_idx_s+CCSW-1+1*KEY_SIZE DOWNTO CCSW*word_idx_s+1*KEY_SIZE) <= key_s(2*CCSW-1 downto 1*CCSW); 
                                ascon_key_s(CCSW*word_idx_s+CCSW-1+2*KEY_SIZE DOWNTO CCSW*word_idx_s+2*KEY_SIZE) <= key_s(3*CCSW-1 downto 2*CCSW);
                                ascon_key_s(CCSW*word_idx_s+CCSW-1+3*KEY_SIZE DOWNTO CCSW*word_idx_s+3*KEY_SIZE) <= key_s(4*CCSW-1 downto 3*CCSW);
                            END IF;
                        END IF;

                    WHEN STORE_NONCE =>
                        -- Update nonce register.
                        IF (bdi_valid = '1' AND bdi_ready_s = '1') THEN
                            ascon_nonce_s(CCW*word_idx_s+CCW-1+0*NPUB_SIZE DOWNTO CCW*word_idx_s+0*NPUB_SIZE) <= bdi_s(1*CCW-1 downto 0*CCW);
                            ascon_nonce_s(CCW*word_idx_s+CCW-1+1*NPUB_SIZE DOWNTO CCW*word_idx_s+1*NPUB_SIZE) <= bdi_s(2*CCW-1 downto 1*CCW);
                            ascon_nonce_s(CCW*word_idx_s+CCW-1+2*NPUB_SIZE DOWNTO CCW*word_idx_s+2*NPUB_SIZE) <= bdi_s(3*CCW-1 downto 2*CCW);   
							ascon_nonce_s(CCW*word_idx_s+CCW-1+3*NPUB_SIZE DOWNTO CCW*word_idx_s+3*NPUB_SIZE) <= bdi_s(4*CCW-1 downto 3*CCW);  
                        END IF;

                    WHEN INIT_STATE_SETUP =>
                        -- Setup state with IV||K||N.                        
                        ascon_state_s(IV_SIZE-1+0*STATE_SIZE DOWNTO 0*STATE_SIZE) <= reverse_bytes(IV_AEAD);
                        ascon_state_s(IV_SIZE-1+1*STATE_SIZE downto 1*STATE_SIZE) <= (others => '0');
                        ascon_state_s(IV_SIZE-1+2*STATE_SIZE downto 2*STATE_SIZE) <= (others => '0');            
                        ascon_state_s(IV_SIZE-1+3*STATE_SIZE downto 3*STATE_SIZE) <= (others => '0');            
                        
                        ascon_state_s(IV_SIZE+KEY_SIZE-1+0*STATE_SIZE DOWNTO IV_SIZE+0*STATE_SIZE) <= ascon_key_s(1*KEY_SIZE-1 downto 0*KEY_SIZE);
                        ascon_state_s(IV_SIZE+KEY_SIZE-1+1*STATE_SIZE DOWNTO IV_SIZE+1*STATE_SIZE) <= ascon_key_s(2*KEY_SIZE-1 downto 1*KEY_SIZE);
                        ascon_state_s(IV_SIZE+KEY_SIZE-1+2*STATE_SIZE DOWNTO IV_SIZE+2*STATE_SIZE) <= ascon_key_s(3*KEY_SIZE-1 downto 2*KEY_SIZE);
                        ascon_state_s(IV_SIZE+KEY_SIZE-1+3*STATE_SIZE DOWNTO IV_SIZE+3*STATE_SIZE) <= ascon_key_s(4*KEY_SIZE-1 downto 3*KEY_SIZE);

                        ascon_state_s(IV_SIZE+KEY_SIZE+NPUB_SIZE-1+0*STATE_SIZE DOWNTO IV_SIZE+KEY_SIZE+0*STATE_SIZE) <= ascon_nonce_s(1*NPUB_SIZE-1 downto 0*NPUB_SIZE);
                        ascon_state_s(IV_SIZE+KEY_SIZE+NPUB_SIZE-1+1*STATE_SIZE DOWNTO IV_SIZE+KEY_SIZE+1*STATE_SIZE) <= ascon_nonce_s(2*NPUB_SIZE-1 downto 1*NPUB_SIZE);
                        ascon_state_s(IV_SIZE+KEY_SIZE+NPUB_SIZE-1+2*STATE_SIZE DOWNTO IV_SIZE+KEY_SIZE+2*STATE_SIZE) <= ascon_nonce_s(3*NPUB_SIZE-1 downto 2*NPUB_SIZE);
                        ascon_state_s(IV_SIZE+KEY_SIZE+NPUB_SIZE-1+3*STATE_SIZE DOWNTO IV_SIZE+KEY_SIZE+3*STATE_SIZE) <= ascon_nonce_s(4*NPUB_SIZE-1 downto 3*NPUB_SIZE);

                        delay_cnt_s <= ASCON_LATENCY;
                        ascon_cnt_s <= ROUNDS_A;
                        pad_added_s <= '0';

                    WHEN INIT_PROCESS =>                    
                        IF (delay_cnt_s > std_logic_vector(to_unsigned(UROL,delay_cnt_s'length))) THEN
                            delay_cnt_s <= std_logic_vector(unsigned(delay_cnt_s) - to_unsigned(UROL,delay_cnt_s'length));
                        END IF;
                        
                         -- Perform ROUNDS_A permutation rounds and load new randomness in parallel.                                                                        
                        IF (delay_cnt_s = std_logic_vector(to_unsigned(UROL,delay_cnt_s'length))) THEN
                            delay_cnt_s <= ASCON_LATENCY;
                            ascon_state_s <= asconp_out_s;
                            ascon_cnt_s <= std_logic_vector(unsigned(ascon_cnt_s) - to_unsigned(UROL,ascon_cnt_s'length));                       
                        END IF;
                        
                    WHEN ABSORB_AD =>
                        -- Absorb ad blocks for aead.
                        IF (bdi_valid = '1' AND bdi_ready_s = '1') THEN
                            -- Absorb ad into the state.
                            ascon_state_s <= ascon_state_n_s; -- todo new
                            IF (bdi_eot = '1') THEN
                                -- Last absorbed ad block.
                                delay_cnt_s <= ASCON_LATENCY;
                                ascon_cnt_s <= ROUNDS_B;
                                IF (bdi_partial_s = '1') THEN
                                    pad_added_s <= '1';
                                ELSIF (word_idx_s < BLOCK_WORDS_C - 1) THEN
                                    pad_added_s <= '1';
                                END IF;
                            END IF;
                            IF (word_idx_s >= BLOCK_WORDS_C - 1) THEN
                                delay_cnt_s <= ASCON_LATENCY;
                                ascon_cnt_s <= ROUNDS_B;
                            END IF;
                        END IF;

                    WHEN INIT_KEY_ADD =>
                        -- Perform the key addition after initialization.
                        delay_cnt_s <= ASCON_LATENCY;
                        ascon_cnt_s <= ROUNDS_B;
                        ascon_state_s(1*STATE_SIZE-1 DOWNTO 1*STATE_SIZE-KEY_SIZE) <= ascon_state_s(1*STATE_SIZE-1 DOWNTO 1*STATE_SIZE-KEY_SIZE) XOR ascon_key_s(1*KEY_SIZE-1 DOWNTO 0*KEY_SIZE);
                        ascon_state_s(2*STATE_SIZE-1 DOWNTO 2*STATE_SIZE-KEY_SIZE) <= ascon_state_s(2*STATE_SIZE-1 DOWNTO 2*STATE_SIZE-KEY_SIZE) XOR ascon_key_s(2*KEY_SIZE-1 DOWNTO 1*KEY_SIZE);
                        ascon_state_s(3*STATE_SIZE-1 DOWNTO 3*STATE_SIZE-KEY_SIZE) <= ascon_state_s(3*STATE_SIZE-1 DOWNTO 3*STATE_SIZE-KEY_SIZE) XOR ascon_key_s(3*KEY_SIZE-1 DOWNTO 2*KEY_SIZE);
                        ascon_state_s(4*STATE_SIZE-1 DOWNTO 4*STATE_SIZE-KEY_SIZE) <= ascon_state_s(4*STATE_SIZE-1 DOWNTO 4*STATE_SIZE-KEY_SIZE) XOR ascon_key_s(4*KEY_SIZE-1 DOWNTO 3*KEY_SIZE);

                    WHEN PROCESS_AD =>                    
                        IF (delay_cnt_s > std_logic_vector(to_unsigned(UROL,delay_cnt_s'length))) THEN
                            delay_cnt_s <= std_logic_vector(unsigned(delay_cnt_s) - to_unsigned(UROL,delay_cnt_s'length));
                        END IF;
                        
                         -- Perform ROUNDS_A permutation rounds and load new randomness in parallel.                                                                        
                        IF (delay_cnt_s = std_logic_vector(to_unsigned(UROL,delay_cnt_s'length))) THEN
                            delay_cnt_s <= ASCON_LATENCY;
                            ascon_state_s <= asconp_out_s;
                            ascon_cnt_s <= std_logic_vector(unsigned(ascon_cnt_s) - to_unsigned(UROL,ascon_cnt_s'length));                       
                        END IF;

                    WHEN PAD_AD =>
                        -- Absorb empty block with padding.
                        -- (state is only reached if not yet inserted).
                        ascon_state_s(7 DOWNTO 0) <= ascon_state_s(7 DOWNTO 0) XOR X"80";
                        pad_added_s <= '1';
                        delay_cnt_s <= ASCON_LATENCY;
                        ascon_cnt_s <= ROUNDS_B;

                    WHEN DOM_SEP =>
                        -- Perform domain separation.
                        ascon_state_s(STATE_SIZE - 8) <= ascon_state_s(STATE_SIZE - 8) XOR '1';
                        pad_added_s <= '0';

                    WHEN ABSORB_MSG =>
                        -- Absorb msg blocks for aead.
                        IF (bdi_valid = '1' AND bdi_ready_s = '1') THEN
                            ascon_state_s <= ascon_state_n_s;
                            IF (bdi_eot = '1') THEN
                                -- Last absorbed msg block.
                                delay_cnt_s <= ASCON_LATENCY;
                                ascon_cnt_s <= ROUNDS_B;
                                IF (bdi_partial_s = '1') THEN
                                    pad_added_s <= '1';
                                ELSIF (word_idx_s < BLOCK_WORDS_C - 1) THEN
                                    pad_added_s <= '1';
                                END IF;
                            ELSIF (word_idx_s >= BLOCK_WORDS_C - 1) THEN
                                delay_cnt_s <= ASCON_LATENCY;
                                ascon_cnt_s <= ROUNDS_B;
                            END IF;
                        END IF;

                    WHEN PROCESS_MSG =>                   
                        IF (delay_cnt_s > std_logic_vector(to_unsigned(UROL,delay_cnt_s'length))) THEN
                            delay_cnt_s <= std_logic_vector(unsigned(delay_cnt_s) - to_unsigned(UROL,delay_cnt_s'length));
                        END IF;
                        
                         -- Perform ROUNDS_A permutation rounds and load new randomness in parallel.                                                                        
                        IF (delay_cnt_s = std_logic_vector(to_unsigned(UROL,delay_cnt_s'length))) THEN
                            delay_cnt_s <= ASCON_LATENCY;
                            ascon_state_s <= asconp_out_s;
                            ascon_cnt_s <= std_logic_vector(unsigned(ascon_cnt_s) - to_unsigned(UROL,ascon_cnt_s'length));                       
                        END IF;

                    WHEN PAD_MSG =>
                        -- Absorb empty block with padding.
                        -- (state is only reached if not yet inserted).
                        ascon_state_s(7 DOWNTO 0) <= ascon_state_s(7 DOWNTO 0) XOR X"80";
                        pad_added_s <= '1';

                    WHEN FINAL_KEY_ADD_1 =>
                        -- Second to last key addition.
                        ascon_state_s(KEY_SIZE+DBLK_SIZE+0*STATE_SIZE-1 DOWNTO DBLK_SIZE+0*STATE_SIZE) <= ascon_state_s(KEY_SIZE+DBLK_SIZE+0*STATE_SIZE-1 DOWNTO DBLK_SIZE+0*STATE_SIZE) XOR ascon_key_s(1*KEY_SIZE-1 downto 0*KEY_SIZE);
                        ascon_state_s(KEY_SIZE+DBLK_SIZE+1*STATE_SIZE-1 DOWNTO DBLK_SIZE+1*STATE_SIZE) <= ascon_state_s(KEY_SIZE+DBLK_SIZE+1*STATE_SIZE-1 DOWNTO DBLK_SIZE+1*STATE_SIZE) XOR ascon_key_s(2*KEY_SIZE-1 downto 1*KEY_SIZE);
                        ascon_state_s(KEY_SIZE+DBLK_SIZE+2*STATE_SIZE-1 DOWNTO DBLK_SIZE+2*STATE_SIZE) <= ascon_state_s(KEY_SIZE+DBLK_SIZE+2*STATE_SIZE-1 DOWNTO DBLK_SIZE+2*STATE_SIZE) XOR ascon_key_s(3*KEY_SIZE-1 downto 2*KEY_SIZE);
                        ascon_state_s(KEY_SIZE+DBLK_SIZE+3*STATE_SIZE-1 DOWNTO DBLK_SIZE+3*STATE_SIZE) <= ascon_state_s(KEY_SIZE+DBLK_SIZE+3*STATE_SIZE-1 DOWNTO DBLK_SIZE+3*STATE_SIZE) XOR ascon_key_s(4*KEY_SIZE-1 downto 3*KEY_SIZE);
                        
                        delay_cnt_s <= ASCON_LATENCY;
                        ascon_cnt_s <= ROUNDS_A;

                    WHEN FINAL_PROCESS =>
                        IF (delay_cnt_s > std_logic_vector(to_unsigned(UROL,delay_cnt_s'length))) THEN
                            delay_cnt_s <= std_logic_vector(unsigned(delay_cnt_s) - to_unsigned(UROL,delay_cnt_s'length));
                        END IF;
                        
                         -- Perform ROUNDS_A permutation rounds and load new randomness in parallel.                                                                        
                        IF (delay_cnt_s = std_logic_vector(to_unsigned(UROL,delay_cnt_s'length))) THEN
                            delay_cnt_s <= ASCON_LATENCY;
                            ascon_state_s <= asconp_out_s;
                            ascon_cnt_s <= std_logic_vector(unsigned(ascon_cnt_s) - to_unsigned(UROL,ascon_cnt_s'length));                       
                        END IF;

                    WHEN FINAL_KEY_ADD_2 =>
                        -- Last key addition.
                        ascon_state_s(1*STATE_SIZE-1 DOWNTO 1*STATE_SIZE-KEY_SIZE) <= ascon_state_s(1*STATE_SIZE-1 DOWNTO 1*STATE_SIZE-KEY_SIZE) XOR ascon_key_s(1*KEY_SIZE-1 DOWNTO 0*KEY_SIZE);
                        ascon_state_s(2*STATE_SIZE-1 DOWNTO 2*STATE_SIZE-KEY_SIZE) <= ascon_state_s(2*STATE_SIZE-1 DOWNTO 2*STATE_SIZE-KEY_SIZE) XOR ascon_key_s(2*KEY_SIZE-1 DOWNTO 1*KEY_SIZE);
                        ascon_state_s(3*STATE_SIZE-1 DOWNTO 3*STATE_SIZE-KEY_SIZE) <= ascon_state_s(3*STATE_SIZE-1 DOWNTO 3*STATE_SIZE-KEY_SIZE) XOR ascon_key_s(3*KEY_SIZE-1 DOWNTO 2*KEY_SIZE);
                        ascon_state_s(4*STATE_SIZE-1 DOWNTO 4*STATE_SIZE-KEY_SIZE) <= ascon_state_s(4*STATE_SIZE-1 DOWNTO 4*STATE_SIZE-KEY_SIZE) XOR ascon_key_s(4*KEY_SIZE-1 DOWNTO 3*KEY_SIZE);

                    WHEN INIT_HASH =>
                        -- Setup state with IV||0*.
                        ascon_state_s(IV_SIZE - 1 DOWNTO 0) <= reverse_bytes(IV_HASH);
                        ascon_state_s(PDI_SHARES * STATE_SIZE - 1 DOWNTO IV_SIZE) <= (OTHERS => '0');
                        delay_cnt_s <= ASCON_LATENCY;
                        ascon_cnt_s <= ROUNDS_A;
                        pad_added_s <= '0';
                        ascon_hash_cnt_s <= 0;

                    WHEN ABSORB_HASH_MSG =>
                        -- Absorb blocks for hashing.
                        IF (bdi_ready_s = '1') THEN
                            -- Absorb full or partial block and add padding if there is space.
                            ascon_state_s <= ascon_state_n_s;
                            IF (bdi_eot = '1') THEN
                                -- Last absorbed block.
                                delay_cnt_s <= ASCON_LATENCY;
                                ascon_cnt_s <= ROUNDS_A;
                                IF (bdi_partial_s = '1') THEN
                                    pad_added_s <= '1';
                                ELSIF (word_idx_s < BLOCK_HASH_WORDS_C - 1) THEN
                                    pad_added_s <= '1';
                                    -- todo see absorb msg.
                                END IF;
                            ELSIF (word_idx_s >= BLOCK_HASH_WORDS_C - 1) THEN
                                delay_cnt_s <= ASCON_LATENCY;
                                ascon_cnt_s <= ROUNDS_A;
                            END IF;
                        END IF;

                    WHEN PAD_HASH_MSG =>
                        -- Absorb empty block with padding.
                        -- (state is only reached if not yet inserted).
                        ascon_state_s(7 DOWNTO 0) <= ascon_state_s(7 DOWNTO 0) XOR X"80";
                        delay_cnt_s <= ASCON_LATENCY;
                        ascon_cnt_s <= ROUNDS_A;
                        pad_added_s <= '1';

                    WHEN PROCESS_HASH =>
                        IF (delay_cnt_s > std_logic_vector(to_unsigned(UROL,delay_cnt_s'length))) THEN
                            delay_cnt_s <= std_logic_vector(unsigned(delay_cnt_s) - to_unsigned(UROL,delay_cnt_s'length));
                        END IF;
                        
                         -- Perform ROUNDS_A permutation rounds and load new randomness in parallel.                                                                        
                        IF (delay_cnt_s = std_logic_vector(to_unsigned(UROL,delay_cnt_s'length))) THEN
                            delay_cnt_s <= ASCON_LATENCY;
                            ascon_state_s <= asconp_out_s;
                            ascon_cnt_s <= std_logic_vector(unsigned(ascon_cnt_s) - to_unsigned(UROL,ascon_cnt_s'length));                       
                        END IF;

                    WHEN EXTRACT_HASH_VALUE =>
                        -- If the current hash block is not the last, set counters accordingly.
                        IF (n_state_s = PROCESS_HASH) THEN
                            delay_cnt_s <= ASCON_LATENCY;
                            ascon_cnt_s <= ROUNDS_A;
                            ascon_hash_cnt_s <= ascon_hash_cnt_s + 1;
                        END IF;

                    WHEN OTHERS =>
                        NULL;

                END CASE;
            END IF;
        END IF;
    END PROCESS p_ascon_fsm;
end behavioral;