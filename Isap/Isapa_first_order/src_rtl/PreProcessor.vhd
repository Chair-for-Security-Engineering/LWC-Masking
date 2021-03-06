--------------------------------------------------------------------------------
--! @file       PreProcessor.vhd
--! @brief      Pre-processor for NIST LWC API
--!
--! @author     Michael Tempelmeier
--! @copyright  Copyright (c) 2019 Chair of Security in Information Technology
--!             ECE Department, Technical University of Munich, GERMANY
--!
--! @author     Farnoud Farahmand
--! @copyright  Copyright (c) 2019 Cryptographic Engineering Research Group
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
--! Description
--!
--!
--!
--!
--!
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.NIST_LWAPI_pkg.all;
use work.design_pkg.all;


entity PreProcessor is
	generic (
		G_W          : integer;
		G_SW         : integer;
		G_ASYNC_RSTN : boolean	
	);
    port (  
            clk             : in  std_logic;
            rst             : in  std_logic;
            --! Public Data input (pdi) ========================================
            pdi_data        : in  STD_LOGIC_VECTOR(PDI_SHARES * G_W - 1 downto 0);
            pdi_valid       : in  std_logic;
            pdi_ready       : out std_logic;
            --! Secret Data input (sdi) ========================================
            sdi_data        : in  STD_LOGIC_VECTOR(SDI_SHARES * G_SW - 1 downto 0);
            sdi_valid       : in  std_logic;
            sdi_ready       : out std_logic;

            --! Crypto Core ====================================================
            key             : out std_logic_vector(SDI_SHARES * CCSW - 1 downto 0);
            key_valid       : out std_logic;
            key_ready       : in  std_logic;
            bdi             : out std_logic_vector(PDI_SHARES * CCW - 1 downto 0);
            bdi_valid       : out std_logic;
            bdi_ready       : in  std_logic;
            bdi_pad_loc     : out std_logic_vector(CCWdiv8 -1 downto 0);
            bdi_valid_bytes : out std_logic_vector(CCWdiv8 -1 downto 0);
            bdi_size        : out std_logic_vector(2 downto 0);
            bdi_eot         : out std_logic;
            bdi_eoi         : out std_logic;
            bdi_type        : out std_logic_vector(3 downto 0);
            decrypt         : out std_logic;
            hash            : out std_logic;
            key_update      : out std_logic;
            ---! Header FIFO ===================================================
            cmd             : out std_logic_vector(G_W - 1 downto 0);
            cmd_valid       : out std_logic;
            cmd_ready       : in  std_logic
        );
end entity PreProcessor;

architecture PreProcessor of PreProcessor is

    --! Segment counter
    signal len_SegLenCnt   : std_logic;
    signal en_SegLenCnt    : std_logic;
    signal last_flit_of_segment  : std_logic;
    signal dout_SegLenCnt  : std_logic_vector(15 downto 0);
    signal load_SegLenCnt  : std_logic_vector(15 downto 0);

    --! Multiplexer
    signal sel_sdi_length    : boolean;

    --! Flags
    signal bdi_valid_bytes_p : std_logic_vector(3 downto 0);
    signal bdi_pad_loc_p     : std_logic_vector(3 downto 0);

    --!for simulation only
    signal received_wrong_header : boolean;

    --Registers
    signal eoi_flag, nx_eoi_flag                 : std_logic;
    signal eot_flag, nx_eot_flag                 : std_logic;
    signal hash_internal, nx_hash_internal       : std_logic;
    signal decrypt_internal, nx_decrypt_internal : std_logic;


    --Controller
    signal bdi_eoi_internal  : std_logic;
    signal bdi_eot_internal  : std_logic;
    constant zero_data       : std_logic_vector(PDI_SHARES * G_W - 1 downto 0):=(others=>'0');


    ---STATES
    type t_state32 is (S_INT_MODE, S_INT_KEY, S_HDR_KEY, S_LD_KEY, S_HDR_NPUB, S_LD_NPUB,
                       S_HDR_AD, S_LD_AD, S_HDR_MSG, S_LD_MSG, S_HDR_TAG, S_LD_TAG,
                       S_HDR_HASH, S_LD_HASH, S_EMPTY_HASH);                    
begin

    --! for simulation only
    -- synthesis translate_off
    -- pragma translate_off
    process(clk) begin
        if (rising_edge(clk)) then
            assert not (received_wrong_header = true)
               report "Received unexpected header" severity failure;
        end if;
    end process;
    -- pragma translate_on
    -- synthesis translate_on

    --! Segment Length Counter
    SegLen: entity work.StepDownCountLd(StepDownCountLd)
        generic map(
                N       =>  16,
                step    =>  (G_W/8)
                    )
        port map
                (
                clk     =>  clk ,
                len     =>  len_SegLenCnt,
                load    =>  load_SegLenCnt,
                ena     =>  en_SegLenCnt,
                count   =>  dout_SegLenCnt
            );

    -- if there are (G_W/8) or less bytes left, we processthe last flit
    last_flit_of_segment <= '1' when
        (to_integer(to_01(unsigned(dout_SegLenCnt))) <= (G_W/8)) else '0';

    -- set valid bytes
    with (to_integer(to_01(unsigned(dout_SegLenCnt)))) select
    bdi_valid_bytes_p <= "1110" when 3,
                         "1100" when 2,
                         "1000" when 1,
                         "0000" when 0,
                         "1111" when others;

    -- set padding location
    with (to_integer(to_01(unsigned(dout_SegLenCnt)))) select
    bdi_pad_loc_p     <= "0001" when 3,
                         "0010" when 2,
                         "0100" when 1,
                         "1000" when 0,
                         "0000" when others;

    --! Registers
    process (clk)
    begin
        if rising_edge(clk) then
            hash_internal    <= nx_hash_internal;
            decrypt_internal <= nx_decrypt_internal;
            eoi_flag         <= nx_eoi_flag;
            eot_flag         <= nx_eot_flag;
        end if;
    end process;


    --! output assignment
    hash    <= hash_internal;
    decrypt <= decrypt_internal;
    cmd     <= pdi_data(PDI_SHARES * G_W - 1 downto (PDI_SHARES - 1) * G_W);

   -- ====================================================================================================
   --! 32 bit specific FSM -------------------------------------------------------------------------------
   -- ====================================================================================================

FSM_32BIT: if (G_W=32) generate

    --! 32 Bit specific declarations
    signal nx_state, pr_state: t_state32;
    signal bdi_valid_p : std_logic;
    signal bdi_ready_p : std_logic;
    signal key_valid_p : std_logic;
    signal key_ready_p : std_logic;
    signal bdi_size_p  : std_logic_vector(2 downto 0);

    ---ALIAS
    alias pdi_opcode     : std_logic_vector( 3 downto 0) is pdi_data((PDI_SHARES - 1) * G_W + 31 downto (PDI_SHARES - 1) * G_W + 28);
    alias sdi_opcode     : std_logic_vector( 3 downto 0) is sdi_data((SDI_SHARES - 1) * G_SW + 31 downto (SDI_SHARES - 1) * G_SW + 28);
    alias pdi_seg_length : std_logic_vector(15 downto 0) is pdi_data((PDI_SHARES - 1) * G_W + 15 downto (PDI_SHARES - 1) * G_W + 0);
    alias sdi_seg_length : std_logic_vector(15 downto 0) is sdi_data((SDI_SHARES - 1) * G_SW + 15 downto (SDI_SHARES - 1) * G_SW + 0);

    begin

    --! Multiplexer
    load_SegLenCnt <= sdi_seg_length when (sel_sdi_length = True) else pdi_seg_length;

    --set size: internally we deal with 32 bits only
    bdi_size_p <= dout_SegLenCnt(2 downto 0) when last_flit_of_segment='1' else "100";

    -- use preserved eoi and eot flags for bdi port
    bdi_eoi_internal  <= eoi_flag and last_flit_of_segment;
    bdi_eot_internal  <= eot_flag and last_flit_of_segment;

    --! KEY PISO
    key <= sdi_data;
    key_valid <= key_valid_p;
    key_ready_p <= key_ready;

    --! DATA PISO
    bdi <= pdi_data;
    bdi_valid <= bdi_valid_p;
    bdi_ready_p <= bdi_ready;
    bdi_valid_bytes <= bdi_valid_bytes_p;
    bdi_pad_loc <= bdi_pad_loc_p;
    bdi_eoi <= bdi_eoi_internal;
    bdi_eot <= bdi_eot_internal;
    bdi_size <= bdi_size_p;    

    --! State register
    GEN_proc_SYNC_RST: if (not G_ASYNC_RSTN) generate
        process (clk)
        begin
            if rising_edge(clk) then
                if(rst='1')  then
                    pr_state <= S_INT_MODE;
                else
                    pr_state <= nx_state;
                end if;
            end if;
        end process;
    end generate GEN_proc_SYNC_RST;
    GEN_proc_ASYNC_RSTN: if (G_ASYNC_RSTN) generate
        process (clk, rst)
        begin
            if(rst='0')  then
                pr_state <= S_INT_MODE;
            elsif rising_edge(clk) then
                pr_state <= nx_state;
            end if;
        end process;
    end generate GEN_proc_ASYNC_RSTN;
 
    --! next state function
    process (pr_state, sdi_valid, last_flit_of_segment, decrypt_internal,
            pdi_valid, key_ready_p, bdi_ready_p, eot_flag, pdi_seg_length,
            pdi_opcode, sdi_opcode, cmd_ready)

    begin

        -- for simulation only
        received_wrong_header <= false;

        case pr_state is

            -- Set mode
            when S_INT_MODE=>
                if (pdi_valid = '1') then
                    if (pdi_opcode = INST_ACTKEY) then
                        nx_state <= S_INT_KEY;
                    elsif ((pdi_opcode = INST_ENC or pdi_opcode = INST_DEC) and cmd_ready = '1') then -- isap todo?
                        nx_state <= S_HDR_NPUB;
                    elsif (pdi_opcode = INST_HASH and cmd_ready = '1') then -- isap todo?
                        nx_state <= S_HDR_HASH;
                    else
                        nx_state <= S_INT_MODE;
                    end if;
                else
                    nx_state <= S_INT_MODE;
                end if;

            -- KEY
            when S_INT_KEY=>
                if (sdi_valid = '1') then
                    received_wrong_header <= sdi_opcode /= INST_LDKEY;
                    nx_state <= S_HDR_KEY;
                else
                    nx_state <= S_INT_KEY;
                end if;

            when S_HDR_KEY=>
                if (sdi_valid = '1') then
                    received_wrong_header <= sdi_opcode /= HDR_KEY;
                    nx_state <= S_LD_KEY;
                else
                    nx_state <= S_HDR_KEY;
                end if;

            when S_LD_KEY=>  --We don't allow for parallel key loading in a lightweight enviroment
                if (sdi_valid = '1' and key_ready_p = '1' and last_flit_of_segment = '1') then
                    nx_state <= S_INT_MODE;
                else
                    nx_state <= S_LD_KEY;
                end if;

            -- NPUB
            when S_HDR_NPUB=>
                if (pdi_valid = '1') then
                    received_wrong_header <= pdi_opcode /= HDR_NPUB;
                    nx_state <= S_LD_NPUB;
                else
                    nx_state <= S_HDR_NPUB;
                end if;

            when S_LD_NPUB =>
                if (pdi_valid = '1' and bdi_ready_p ='1' and last_flit_of_segment = '1') then
                    -- nx_state <= S_HDR_AD;
                    -- isap specific start --
                    IF (decrypt_internal = '1') THEN
                        nx_state <= S_HDR_AD;
                    ELSE
                        nx_state <= S_HDR_MSG;
                    END IF;
                    -- isap specific end --
                else
                    nx_state <= S_LD_NPUB;
                end if;

            -- AD
            when S_HDR_AD=>
                if (pdi_valid = '1') then
                    received_wrong_header <= pdi_opcode /= HDR_AD;
                    if (pdi_seg_length = x"0000" and eot_flag = '1') then
                        -- nx_state <= S_HDR_MSG;
                        -- isap specific start --
                        IF (decrypt_internal = '1') THEN
                            nx_state <= S_HDR_MSG;
                        ELSE
                            nx_state <= S_INT_MODE;
                        END IF;
                        -- isap specific end --
                    else
                        nx_state <= S_LD_AD;
                    end if;
                else
                    nx_state <= S_HDR_AD;
                end if;

            when S_LD_AD =>
                if (pdi_valid = '1' and bdi_ready_p = '1' and last_flit_of_segment = '1') then
                    if (eot_flag = '1') then
                        -- nx_state <= S_HDR_MSG;
                        -- isap specific start --
                        IF (decrypt_internal = '1') THEN
                            nx_state <= S_HDR_MSG;
                        ELSE
                            nx_state <= S_INT_MODE;
                        END IF;
                        -- isap specific end --
                    else
                        nx_state <= S_HDR_AD;
                    end if;
                else
                    nx_state <= S_LD_AD;
                end if;

            -- Plaintext or Ciphertext
            when S_HDR_MSG=>
                if (pdi_valid = '1' and cmd_ready = '1') then -- isap todo?
                    received_wrong_header <= (pdi_opcode /= HDR_PT and pdi_opcode /= HDR_CT);
                    if (pdi_seg_length = x"0000" and eot_flag = '1') then
                        if (decrypt_internal = '1') then
                            nx_state <= S_HDR_TAG;
                        else
                            -- nx_state <= S_INT_MODE;
                            -- isap specific start --
                            nx_state <= S_HDR_AD;
                            -- isap specific end --
                        end if;
                    else
                        nx_state <= S_LD_MSG;
                    end if;
                else
                    nx_state <= S_HDR_MSG;
                end if;

            when S_LD_MSG =>
                if (pdi_valid = '1' and bdi_ready_p = '1' and last_flit_of_segment = '1') then
                    if (eot_flag = '1') then
                        if (decrypt_internal = '1') then
                            nx_state <= S_HDR_TAG;
                        else
                            -- nx_state <= S_INT_MODE;
                            -- isap specific start --
                            nx_state <= S_HDR_AD;
                            -- isap specific end --
                        end if;
                    else
                        nx_state <= S_HDR_MSG;
                    end if;
                else
                    nx_state <= S_LD_MSG;
                end if;

            -- TAG for AEAD
            when S_HDR_TAG=>
                if (pdi_valid = '1') then
                    received_wrong_header <= pdi_opcode /= HDR_TAG;
                    nx_state <= S_LD_TAG;
                else
                    nx_state <= S_HDR_TAG;
                end if;

            when S_LD_TAG =>
                if (pdi_valid = '1' and last_flit_of_segment = '1') then
                    if (bdi_ready_p = '1') then
                        nx_state <= S_INT_MODE;
                    else
                        nx_state <= S_LD_TAG;
                    end if;
                else
                    nx_state <= S_LD_TAG;
                end if;

            --HASH
            when S_HDR_HASH=>
                if (pdi_valid = '1') then
                    received_wrong_header <= pdi_opcode /= HDR_HASH_MSG;
                    if (pdi_seg_length = x"0000") then
                        nx_state <= S_EMPTY_HASH;
                    else
                        nx_state  <= S_LD_HASH;
                    end if;
                else
                    nx_state <= S_HDR_HASH;
                end if;

            when S_EMPTY_HASH=>
                if (bdi_ready_p = '1') then
                    nx_state <= S_INT_MODE;
                else
                    nx_state <= S_EMPTY_HASH;
                end if;

            when S_LD_HASH =>
                if (pdi_valid = '1' and bdi_ready_p = '1' and last_flit_of_segment = '1') then
                    if (eot_flag = '1') then
                        nx_state <= S_INT_MODE;
                    else
                        nx_state <= S_HDR_HASH;
                    end if;
                else
                    nx_state <= S_LD_HASH;
                end if;

            when others =>
                nx_state <= S_INT_MODE;

        end case;
    end process;


    --! output state function
    process(pr_state, sdi_valid, pdi_valid, eoi_flag, eot_flag, hash_internal,
            key_ready_p, bdi_ready_p, cmd_ready, decrypt_internal, pdi_data)

    begin
            -- DEFAULT Values
            -- external interface
            sdi_ready           <='0';
            pdi_ready           <='0';
            -- LWC core
            key_valid_p         <='0';
            key_update          <='0';
            bdi_valid_p         <='0';
            bdi_type            <="0000";
            -- header-FIFO
            cmd_valid           <='0';
            -- counter
            len_SegLenCnt       <='0';
            en_SegLenCnt        <='0';
            -- register
            nx_eoi_flag         <= eoi_flag;
            nx_eot_flag         <= eot_flag;
            nx_hash_internal    <= hash_internal;
            nx_decrypt_internal <= decrypt_internal;
            -- multiplexer
            sel_sdi_length       <= false;

        case pr_state is

            -- Set MODE
            when S_INT_MODE =>
                pdi_ready        <= '1';
                nx_hash_internal <= '0';

                if (pdi_opcode = INST_ENC or pdi_opcode = INST_DEC) then
                    if (pdi_valid = '1') then
                        -- pdi_data(28) is 1 if INST_DEC, else it is '0' if INST_ENC
                        nx_decrypt_internal <= pdi_data((PDI_SHARES - 1) * G_W + 28);
                        cmd_valid           <= '1'; --Forward instruction
                        pdi_ready           <= cmd_ready; -- isap todo?
                    end if;

                elsif (pdi_opcode = INST_HASH) then
                    if (pdi_valid = '1') then
                        nx_hash_internal <= '1';
                        cmd_valid        <= '1'; --Forward instruction
                        pdi_ready        <= cmd_ready; -- isap todo?
                    end if;
                end if;

            -- KEY
            when S_INT_KEY =>
                sdi_ready       <= '1';
                key_update      <= '0';

            when S_HDR_KEY =>
                sdi_ready       <= '1';
                len_SegLenCnt   <= sdi_valid;
                sel_sdi_length  <= true;

            when S_LD_KEY =>
                sdi_ready       <= key_ready_p;
                key_valid_p     <= sdi_valid;
                key_update      <= '1';
                en_SegLenCnt    <= sdi_valid and key_ready_p;

            -- NPUB
            when S_HDR_NPUB =>
                pdi_ready       <= '1';
                len_SegLenCnt   <= pdi_valid;
                if (pdi_valid = '1') then
                    nx_eoi_flag <= pdi_data((PDI_SHARES - 1) * G_W + 26);
                    nx_eot_flag <= pdi_data((PDI_SHARES - 1) * G_W + 25);
                end if;

            when S_LD_NPUB =>
                pdi_ready       <= bdi_ready_p;
                bdi_valid_p     <= pdi_valid;
                bdi_type        <= HDR_NPUB;
                en_SegLenCnt    <= pdi_valid and bdi_ready_p;

            -- AD
            when S_HDR_AD =>
                pdi_ready       <='1';
                len_SegLenCnt   <= pdi_valid;
                if (pdi_valid = '1') then
                    nx_eoi_flag <= pdi_data((PDI_SHARES - 1) * G_W + 26);
                    nx_eot_flag <= pdi_data((PDI_SHARES - 1) * G_W + 25);
                end if;

            when S_LD_AD =>
                pdi_ready       <= bdi_ready_p;
                bdi_valid_p     <= pdi_valid;
                bdi_type        <= HDR_AD;
                en_SegLenCnt    <= pdi_valid and bdi_ready_p;

            -- Plaintext or Ciphertext
            when S_HDR_MSG =>
                cmd_valid       <= pdi_valid;
                pdi_ready       <= cmd_ready;
                len_SegLenCnt   <= pdi_valid and cmd_ready;
                if (pdi_valid = '1' and cmd_ready = '1') then
                    nx_eoi_flag <= pdi_data((PDI_SHARES - 1) * G_W + 26);
                    nx_eot_flag <= pdi_data((PDI_SHARES - 1) * G_W + 25);
                end if;

            when S_LD_MSG =>
                pdi_ready       <= bdi_ready_p;
                bdi_valid_p     <= pdi_valid;
                if (decrypt_internal = '1') then
                    bdi_type    <= HDR_CT;
                else
                    bdi_type    <= HDR_PT;
                end if;
                en_SegLenCnt    <= pdi_valid and bdi_ready_p;

            -- TAG for AEAD
            when S_HDR_TAG =>
                pdi_ready       <= '1';
                len_SegLenCnt   <= pdi_valid;

            when S_LD_TAG =>
                bdi_type        <= HDR_TAG;

                if (decrypt_internal = '1') then
                    bdi_valid_p  <= pdi_valid;
                    pdi_ready    <= bdi_ready_p;
                    en_SegLenCnt <= pdi_valid and bdi_ready_p;
                end if;

            -- HASH
            when S_HDR_HASH =>
                pdi_ready       <= '1';
                len_SegLenCnt   <= pdi_valid;
                if (pdi_valid = '1') then
                    nx_eoi_flag <= pdi_data((PDI_SHARES - 1) * G_W + 26);
                    nx_eot_flag <= pdi_data((PDI_SHARES - 1) * G_W + 25);
                end if;

            when S_LD_HASH =>
                pdi_ready       <= bdi_ready_p;
                bdi_valid_p     <= pdi_valid;
                bdi_type        <= HDR_HASH_MSG;
                en_SegLenCnt    <= pdi_valid and bdi_ready_p;

            when S_EMPTY_HASH  =>
                bdi_valid_p     <= '1';
                bdi_type        <= HDR_HASH_MSG;

            when others =>
                null;
        end case;
    end process;

end generate;

end PreProcessor;
