--------------------------------------------------------------------------------
--! @file       Design_pkg.vhd
--! @brief      Package for the Cipher Core.
--!
--! @author     Michael Tempelmeier <michael.tempelmeier@tum.de>
--! @author     Patrick Karl <patrick.karl@tum.de>
--! @copyright  Copyright (c) 2019 Chair of Security in Information Technology
--!             ECE Department, Technical University of Munich, GERMANY
--!             All rights Reserved.
--! @license    This project is released under the GNU Public License.
--!             The license and distribution terms for this file may be
--!             found in the file LICENSE in this distribution or at
--!             http://www.gnu.org/licenses/gpl-3.0.txt
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;

package ascon_pkg is

    --! Select the amount of permutation rounds that are performed within one cycle
    -- If you change this make sure that you also comment in/out the corresponding number of permutation rounds in CryptoCore.vhdl
    constant UROL : INTEGER RANGE 0 TO 4 := 1; -- v1 or v2
    constant ZERRO : INTEGER RANGE 0 TO 4 := 0; -- v1 or v2

    -- constant UROL : INTEGER RANGE 0 TO 4 := 2; -- v3 or v4
    -- constant UROL : INTEGER RANGE 0 TO 4 := 3; -- v5
    -- constant UROL : INTEGER RANGE 0 TO 4 := 4; -- v6

    ---------------------------------------------------------------------------
    --                              _ ____  ___  
    --   __ _ ___  ___ ___  _ __   / |___ \( _ ) 
    --  / _` / __|/ __/ _ \| '_ \  | | __) / _ \ 
    -- | (_| \__ \ (_| (_) | | | | | |/ __/ (_) |
    --  \__,_|___/\___\___/|_| |_| |_|_____\___/ 
    ---------------------------------------------------------------------------

    CONSTANT IV_AEAD : std_logic_vector(63 DOWNTO 0) := X"80400c0600000000";
    CONSTANT ROUNDS_A : std_logic_vector(7 DOWNTO 0) := X"0C";
    CONSTANT ROUNDS_B : std_logic_vector(7 DOWNTO 0) := X"06";
    CONSTANT DBLK_SIZE : INTEGER := 64;
    CONSTANT ASCON_LATENCY : std_logic_vector(7 DOWNTO 0) := X"03";

--------------------------------------------------------------------------------
------------------------- DO NOT CHANGE ANYTHING BELOW -------------------------
--------------------------------------------------------------------------------
    --! Calculate the number of I/O words for a particular size
    function get_words(size: integer; iowidth:integer) return integer; 
    --! Padding the current word.
    function pad_bdi( bdi, bdi_valid_bytes, bdi_pad_loc, state_word : std_logic_vector; pt_ct : std_logic) return std_logic_vector;
    
    --! Return max value
    function max( a, b : integer) return integer;
    
    -- State signals
    TYPE state_t IS (
        IDLE,
        STORE_KEY,
        STORE_NONCE,
        INIT_STATE_SETUP,
        STORE_RND,
        -- AEAD
        INIT_PROCESS,
        INIT_KEY_ADD,
        ABSORB_AD,
        PROCESS_AD,
        PAD_AD,
        DOM_SEP,
        ABSORB_MSG,
        PROCESS_MSG,
        PAD_MSG,
        FINAL_KEY_ADD_1,
        FINAL_PROCESS,
        FINAL_KEY_ADD_2,
        EXTRACT_TAG,
        VERIFY_TAG,
        WAIT_ACK,
        -- HASH
        INIT_HASH,
        ABSORB_HASH_MSG,
        PROCESS_HASH,
        PAD_HASH_MSG,
        EXTRACT_HASH_VALUE);
        
        function dyn_slice_fix( paddy : std_logic_vector; bdi_eot, bdi_partial_s : std_logic; ascon_state_s : std_logic_vector ; word_idx_s : integer; state : state_t) return std_logic_vector;

end ascon_pkg;

package body ascon_pkg is

    --! Calculate the number of words
    function get_words(size: integer; iowidth:integer) return integer is
    begin
        if (size mod iowidth) > 0 then
            return size/iowidth + 1;
        else
            return size/iowidth;
        end if;
    end function get_words;

    --! Padd the data with 0x80 Byte if pad_loc is set.
    function pad_bdi( bdi, bdi_valid_bytes, bdi_pad_loc, state_word : std_logic_vector; pt_ct : std_logic) return std_logic_vector is
        variable res : std_logic_vector(bdi'length - 1 downto 0) := state_word;        
        
    begin
        for i in 0 to (bdi_valid_bytes'length - 1) loop
            if (bdi_valid_bytes(i) = '1') then
                if (pt_ct = '0') then
                    res(8*(i+1)-1+0*32 downto 8*i+0*32) := res(8*(i+1)-1+0*32 downto 8*i+0*32) XOR bdi(8*(i+1)-1+0*32 downto 8*i+0*32);
                    res(8*(i+1)-1+1*32 downto 8*i+1*32) := res(8*(i+1)-1+1*32 downto 8*i+1*32) XOR bdi(8*(i+1)-1+1*32 downto 8*i+1*32);
                    res(8*(i+1)-1+2*32 downto 8*i+2*32) := res(8*(i+1)-1+2*32 downto 8*i+2*32) XOR bdi(8*(i+1)-1+2*32 downto 8*i+2*32);                    
                    res(8*(i+1)-1+3*32 downto 8*i+3*32) := res(8*(i+1)-1+3*32 downto 8*i+3*32) XOR bdi(8*(i+1)-1+3*32 downto 8*i+3*32);                    
				else
                    res(8*(i+1)-1+0*32 downto 8*i+0*32) := bdi(8*(i+1)-1+0*32 downto 8*i+0*32);
                    res(8*(i+1)-1+1*32 downto 8*i+1*32) := bdi(8*(i+1)-1+1*32 downto 8*i+1*32);
                    res(8*(i+1)-1+2*32 downto 8*i+2*32) := bdi(8*(i+1)-1+2*32 downto 8*i+2*32);
                    res(8*(i+1)-1+3*32 downto 8*i+3*32) := bdi(8*(i+1)-1+3*32 downto 8*i+3*32);
				end if;
            elsif (bdi_pad_loc(i) = '1') then
                res(8*(i+1) - 1 downto 8*i) := res(8*(i+1) - 1 downto 8*i) XOR x"80";
            end if;
        end loop;
        return res;
    end function;
    
    function dyn_slice_fix( paddy : std_logic_vector; bdi_eot, bdi_partial_s : std_logic; ascon_state_s : std_logic_vector ; word_idx_s : integer; state : state_t) return std_logic_vector is
        variable res : std_logic_vector(ascon_state_s'length - 1 downto 0) := ascon_state_s;
    begin
  
        if (DBLK_SIZE = 64 or state = ABSORB_HASH_MSG) then
            res(word_idx_s*32+31+0*320 downto word_idx_s*32+0*320) := paddy(1*32-1 downto 0*32);
            res(word_idx_s*32+31+1*320 downto word_idx_s*32+1*320) := paddy(2*32-1 downto 1*32);
            res(word_idx_s*32+31+2*320 downto word_idx_s*32+2*320) := paddy(3*32-1 downto 2*32);
            res(word_idx_s*32+31+3*320 downto word_idx_s*32+3*320) := paddy(4*32-1 downto 3*32);

            IF (word_idx_s = 0 and bdi_eot = '1' and bdi_partial_s = '0' ) THEN
                res(word_idx_s*32+32+7 downto word_idx_s*32+32) := res(word_idx_s*32+32+7 downto word_idx_s*32+32) XOR X"80";
            END IF;
        elsif (DBLK_SIZE = 128) then
            res(word_idx_s*32+31+0*320 downto word_idx_s*32+0*320) := paddy(1*32-1 downto 0*32);
            res(word_idx_s*32+31+1*320 downto word_idx_s*32+1*320) := paddy(2*32-1 downto 1*32);
            res(word_idx_s*32+31+2*320 downto word_idx_s*32+2*320) := paddy(3*32-1 downto 2*32);
            res(word_idx_s*32+31+3*320 downto word_idx_s*32+3*320) := paddy(4*32-1 downto 3*32);

            IF (word_idx_s < 3 and bdi_eot = '1' and bdi_partial_s = '0' ) THEN
                res(word_idx_s*32+32+7 downto word_idx_s*32+32) := res(word_idx_s*32+32+7 downto word_idx_s*32+32) XOR X"80";
            END IF;
        END IF;
    return res;
end function;

--! Return max value.
    function max( a, b : integer) return integer is
    begin
        if (a >= b) then
            return a;
        else
            return b;
        end if;
    end function;

end package body ascon_pkg;
