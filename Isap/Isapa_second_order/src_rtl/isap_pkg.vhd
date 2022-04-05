--------------------------------------------------------------------------------
--! @file       design_pkg.vhd
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
USE work.design_pkg.ALL;

package isap_pkg is

--------------------------------------------------------------------------------
------------------------- DO NOT CHANGE ANYTHING BELOW -------------------------
--------------------------------------------------------------------------------

    --! user specific, algorithm independent parameters
    -- This module implements three different variants of dummy_lwc
    type set_selector is     (lwc_8, lwc_16, lwc_32);

    CONSTANT variant : set_selector := lwc_32;
    CONSTANT LATENCY : std_logic_vector := B"11";

	TYPE isap_t IS (
		ISAPA128A,
		ISAPA128,
		ISAPK128A,
		ISAPK128
    );

    ------------------------------------------------------------------------------------------------------------------
    --  _                           _ ____  ___          
    -- (_)___  __ _ _ __     __ _  / |___ \( _ )    __ _ 
    -- | / __|/ _` | '_ \   / _` | | | __) / _ \   / _` |
    -- | \__ \ (_| | |_) | | (_| | | |/ __/ (_) | | (_| |
    -- |_|___/\__,_| .__/   \__,_| |_|_____\___/   \__,_|
    --             |_|                                   
    -- v1: isapa128av20                                  
    ------------------------------------------------------------------------------------------------------------------
    CONSTANT ISAP_TYPE : isap_t := ISAPA128A;
    CONSTANT p_sH : std_logic_vector := X"0C"; -- 12
    CONSTANT p_sB : std_logic_vector := X"01"; -- 1
    CONSTANT p_sE : std_logic_vector := X"06"; -- 6
    CONSTANT p_sK : std_logic_vector := X"0C"; -- 12
    CONSTANT p_n : INTEGER := 10#320#; -- 320
    CONSTANT p_k : INTEGER := 10#128#; -- 128
    CONSTANT p_rH : INTEGER := 10#64#; -- 64
    CONSTANT p_rB : INTEGER := 10#1#; -- 1
    CONSTANT p_iv_a : std_logic_vector(63 DOWNTO 0) := X"018040010C01060C";
    CONSTANT p_iv_ka : std_logic_vector(63 DOWNTO 0) := X"028040010C01060C";
    CONSTANT p_iv_ke : std_logic_vector(63 DOWNTO 0) := X"038040010C01060C";
    
    ------------------------------------------------------------------------------------------------------------------
    --  _                   _      _ ____  ___          
    -- (_)___  __ _ _ __   | | __ / |___ \( _ )    __ _ 
    -- | / __|/ _` | '_ \  | |/ / | | __) / _ \   / _` |
    -- | \__ \ (_| | |_) | |   <  | |/ __/ (_) | | (_| |
    -- |_|___/\__,_| .__/  |_|\_\ |_|_____\___/   \__,_|
    --             |_|                                  
    -- v2: isapk128av20                                 
    ------------------------------------------------------------------------------------------------------------------
    -- CONSTANT ISAP_TYPE : isap_t := ISAPK128A;
    -- CONSTANT p_n : INTEGER := 10#400#; -- 400
    -- CONSTANT p_k : INTEGER := 10#128#; -- 128
    -- CONSTANT p_sH : std_logic_vector := X"10"; -- 16
    -- CONSTANT p_sB : std_logic_vector := X"01"; -- 1
    -- CONSTANT p_sE : std_logic_vector := X"08"; -- 8
    -- CONSTANT p_sK : std_logic_vector := X"08"; -- 8
    -- CONSTANT p_rH : INTEGER := 10#144#; -- 144
    -- CONSTANT p_rB : INTEGER := 10#1#; -- 1
    -- CONSTANT p_iv_a : std_logic_vector(63 DOWNTO 0) := X"0180900110010808";
    -- CONSTANT p_iv_ka : std_logic_vector(63 DOWNTO 0) := X"0280900110010808";
    -- CONSTANT p_iv_ke : std_logic_vector(63 DOWNTO 0) := X"0380900110010808";

    --! design parameters needed by the PreProcessor, PostProcessor, and LWC; assigned in the package body below!
    --constant TAG_SIZE        : integer; --! Tag size
    --constant TAG_SIZE        : integer; --! Tag size
    --constant HASH_VALUE_SIZE : integer; --! Hash value size
    
    --constant CCSW            : integer; --! variant dependent design parameter!
    --constant CCW             : integer; --! variant dependent design parameter!
    --constant CCWdiv8         : integer; --! derived from parameters above, assigned in body.
    
    CONSTANT FIFO_ENTRIES : INTEGER;
    
    --! design parameters specific to the CryptoCore; assigned in the package body below!
    constant NPUB_SIZE       : integer; --! Npub size

    --! Keccak-p[400]
    constant num_plane : integer := 5;
    constant num_sheet : integer := 5;
    constant logD : integer :=4;
    constant key_pack_size : std_logic_vector(7 downto 0) := "00010010";
    constant key_pack_padding : std_logic_vector(7 downto 0) := "00000001";
    constant start_padding : std_logic_vector(7 downto 0) := "00000001";
    constant end_padding : std_logic_vector(7 downto 0) := "10000000";
    constant N : integer := 16;
    type k_lane is  array ((N-1) downto 0) of std_logic;    
    type k_plane is array ((num_sheet-1) downto 0) of k_lane;    
    type k_state is array ((num_plane-1) downto 0) of k_plane;

    --! place declarations of your functions here
    --! Calculate the number of I/O words for a particular size
    function get_words(size: integer; iowidth:integer) return integer; 
    --! Calculate log2 and round up.
    function log2_ceil (Na: natural) return natural;
    --! Reverse the Byte order of the input word.
    function reverse_byte( vec : std_logic_vector ) return std_logic_vector;
    --! Reverse the Bit order of the input vector.
    function reverse_bit( vec : std_logic_vector ) return std_logic_vector;
    --! Padding the current word.
    function pad_bdi(bdi, bdi_valid_bytes, bdi_pad_loc, state_word : std_logic_vector; pt_ct : std_logic) return std_logic_vector;
    function mask_zero(bdi, bdi_valid_bytes : std_logic_vector) return std_logic_vector;
    --! Return max value
    function max( a, b : integer) return integer;

    function pad_bdi( bdi, bdi_valid_bytes, state_word : std_logic_vector; pt_ct : std_logic) return std_logic_vector;
    
    function dyn_slice(
        paddy : std_logic_vector;
        bdi_eot, bdi_partial_s : std_logic;
        ascon_state_s : std_logic_vector;
        word_idx_s : integer
    )
    return std_logic_vector;

end isap_pkg;

package body isap_pkg is

    -- The following construct is used to specify all varaint dependent parameters
    -- and make them selectable by the constant "variant" of type "set_selector".

    type vector_of_constants_t is array (1 to 2) of integer; -- two variant dependent constants
    type set_of_vector_of_constants_t is array (set_selector) of vector_of_constants_t;
    constant set_of_vector_of_constants : set_of_vector_of_constants_t :=
      --   CCW
      --   |   CCSW
      --   |   |
      (  ( 8,  8), -- lwc_8
         (16, 16), -- lwc_16
         (32, 32)  -- lwc_32
      );
    -- select the correct set of parameters
    alias vector_of_constants is set_of_vector_of_constants(variant);

    --! design parameters needed by the PreProcessor, PostProcessor, and LWC
    --constant TAG_SIZE        : integer := 128; --! Tag size
    --constant HASH_VALUE_SIZE : integer := 256; --! Hash value size
    --constant CCW             : integer := vector_of_constants(1); --! bdo/bdi width
    --constant CCSW            : integer := vector_of_constants(2); --! key width
    --constant CCWdiv8         : integer := CCW/8; -- derived from parameters above
    
    CONSTANT FIFO_ENTRIES : INTEGER := 65536/CCWdiv8; -- 2^16 bytes

    --! design parameters specific to the CryptoCore
    constant NPUB_SIZE       : integer := 128; --! Npub size

    --! Calculate the number of words
    function get_words(size: integer; iowidth:integer) return integer is
    begin
        if (size mod iowidth) > 0 then
            return size/iowidth + 1;
        else
            return size/iowidth;
        end if;
    end function get_words;

    --! Log of base 2
    function log2_ceil (Na: natural) return natural is
    begin
         if ( Na = 0 ) then
             return 0;
         elsif Na <= 2 then
             return 1;
         else
            if (Na mod 2 = 0) then
                return 1 + log2_ceil(Na/2);
            else
                return 1 + log2_ceil((Na+1)/2);
            end if;
         end if;
    end function log2_ceil;

    --! Reverse the Byte order of the input word.
    function reverse_byte( vec : std_logic_vector ) return std_logic_vector is
        variable res : std_logic_vector(vec'length - 1 downto 0);
        constant n_bytes  : integer := vec'length/8;
    begin

        -- Check that vector length is actually byte aligned.
        assert (vec'length mod 8 = 0)
            report "Vector size must be in multiple of Bytes!" severity failure;

        -- Loop over every byte of vec and reorder it in res.
        for i in 0 to (n_bytes - 1) loop
            res(8*(i+1) - 1 downto 8*i) := vec(8*(n_bytes - i) - 1 downto 8*(n_bytes - i - 1));
        end loop;

        return res;
    end function reverse_byte;

    --! Reverse the Bit order of the input vector.
    function reverse_bit( vec : std_logic_vector ) return std_logic_vector is
        variable res : std_logic_vector(vec'length - 1 downto 0);
    begin

        -- Loop over every bit in vec and reorder it in res.
        for i in 0 to (vec'length - 1) loop
            res(i) := vec(vec'length - i - 1);
        end loop;

        return res;
    end function reverse_bit;

   --! Padd the data with 0x80 Byte if pad_loc is set.
    function pad_bdi( bdi, bdi_valid_bytes, bdi_pad_loc, state_word : std_logic_vector; pt_ct : std_logic) return std_logic_vector is
        variable res : std_logic_vector(bdi'length - 1 downto 0) := state_word;
    begin
        for i in 0 to (bdi_valid_bytes'length - 1) loop
            if (bdi_valid_bytes(i) = '1') then
                if (pt_ct = '0') then
                    res(8*(i+1) - 1 downto 8*i) := res(8*(i+1) - 1 downto 8*i) XOR bdi(8*(i+1) - 1 downto 8*i);
                else
                    res(8*(i+1) - 1 downto 8*i) := bdi(8*(i+1) - 1 downto 8*i);
                end if;
            elsif (bdi_pad_loc(i) = '1') then
                res(8*(i+1) - 1 downto 8*i) := res(8*(i+1) - 1 downto 8*i) XOR x"80";
            end if;
        end loop;
        return res;
    end function;

    --! Padd the data with 0x80 Byte if pad_loc is set.
    function pad_bdi( bdi, bdi_valid_bytes, state_word : std_logic_vector; pt_ct : std_logic) return std_logic_vector is
        variable res : std_logic_vector(bdi'length - 1 downto 0) := state_word;
    begin
        for i in 0 to (bdi_valid_bytes'length - 1) loop
            if (bdi_valid_bytes(i) = '1') then
                if (pt_ct = '0') then
                    res(0*32+8*(i+1)-1 downto 0*32+8*i) := res(0*32+8*(i+1)-1 downto 0*32+8*i) XOR bdi(0*32+8*(i+1)-1 downto 0*32+8*i);
                    res(1*32+8*(i+1)-1 downto 1*32+8*i) := res(1*32+8*(i+1)-1 downto 1*32+8*i) XOR bdi(1*32+8*(i+1)-1 downto 1*32+8*i);
                    res(2*32+8*(i+1)-1 downto 2*32+8*i) := res(2*32+8*(i+1)-1 downto 2*32+8*i) XOR bdi(2*32+8*(i+1)-1 downto 2*32+8*i);
				else
                    res(0*32+8*(i+1)-1 downto 0*32+8*i) := bdi(0*32+8*(i+1)-1 downto 0*32+8*i);
                    res(1*32+8*(i+1)-1 downto 1*32+8*i) := bdi(1*32+8*(i+1)-1 downto 1*32+8*i);
					res(2*32+8*(i+1)-1 downto 2*32+8*i) := bdi(2*32+8*(i+1)-1 downto 2*32+8*i);
                end if;
            elsif ((i>0) and (bdi_valid_bytes(i-1)='1')) then
                res(0*32+8*(i+1)-1 downto 0*32+8*i) := res(0*32+8*(i+1)-1 downto 0*32+8*i) XOR x"80";
                res(1*32+8*(i+1)-1 downto 1*32+8*i) := res(1*32+8*(i+1)-1 downto 1*32+8*i) XOR x"00";
                res(2*32+8*(i+1)-1 downto 2*32+8*i) := res(2*32+8*(i+1)-1 downto 2*32+8*i) XOR x"00";
			end if;
        end loop;
        return res;
    end function;

    --! Set invalid bytes to zero.
    FUNCTION mask_zero( bdi, bdi_valid_bytes : std_logic_vector) RETURN std_logic_vector IS
        VARIABLE res : std_logic_vector(bdi'length - 1 DOWNTO 0) := (OTHERS => '0');
    BEGIN

        FOR i IN 0 TO (bdi_valid_bytes'length - 1) LOOP
            IF (bdi_valid_bytes(i) = '1') THEN
                res(0*32+8*(i+1)-1 DOWNTO 0*32+8*i) := bdi(0*32+8*(i+1)-1 DOWNTO 0*32+8*i);
                res(1*32+8*(i+1)-1 DOWNTO 1*32+8*i) := bdi(1*32+8*(i+1)-1 DOWNTO 1*32+8*i);
                res(2*32+8*(i+1)-1 DOWNTO 2*32+8*i) := bdi(2*32+8*(i+1)-1 DOWNTO 2*32+8*i);
			ELSE
                res(0*32+8*(i+1)-1 DOWNTO 0*32+8*i) := x"00";
                res(1*32+8*(i+1)-1 DOWNTO 1*32+8*i) := x"00";
                res(2*32+8*(i+1)-1 DOWNTO 2*32+8*i) := x"00";
			END IF;
        END LOOP;

        RETURN res;
    END FUNCTION;

    function dyn_slice( paddy : std_logic_vector; bdi_eot, bdi_partial_s : std_logic; ascon_state_s : std_logic_vector ; word_idx_s : integer) return std_logic_vector is
        variable res : std_logic_vector(ascon_state_s'length - 1 downto 0) := ascon_state_s;
    begin
        res(0*p_n+word_idx_s*CCW+CCW-1 downto 0*p_n+word_idx_s*CCW) := paddy(1*32-1 downto 0*32);
        res(1*p_n+word_idx_s*CCW+CCW-1 downto 1*p_n+word_idx_s*CCW) := paddy(2*32-1 downto 1*32);
        res(2*p_n+word_idx_s*CCW+CCW-1 downto 2*p_n+word_idx_s*CCW) := paddy(3*32-1 downto 2*32);

            IF (word_idx_s < (((p_rH)/CCW)-1) and bdi_eot = '1' and bdi_partial_s = '0' ) THEN
                res(0*p_n+word_idx_s*CCW+CCW+7 downto 0*p_n+word_idx_s*CCW+CCW) := res(0*p_n+word_idx_s*CCW+CCW+7 downto 0*p_n+word_idx_s*CCW+CCW) XOR X"80";
                res(1*p_n+word_idx_s*CCW+CCW+7 downto 1*p_n+word_idx_s*CCW+CCW) := res(1*p_n+word_idx_s*CCW+CCW+7 downto 1*p_n+word_idx_s*CCW+CCW);
                res(2*p_n+word_idx_s*CCW+CCW+7 downto 2*p_n+word_idx_s*CCW+CCW) := res(2*p_n+word_idx_s*CCW+CCW+7 downto 2*p_n+word_idx_s*CCW+CCW);
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

end package body isap_pkg;
