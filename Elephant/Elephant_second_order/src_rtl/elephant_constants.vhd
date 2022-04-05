--------------------------------------------------------------------------------
--! @file       elephant_constants.vhd
--! @brief      
--! @author     Richard Haeussler
--! @copyright  Copyright (c) 2020 Cryptographic Engineering Research Group
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
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use ieee.math_real.all;

package elephant_constants is
    constant STATE_SIZE: integer := 160;
    constant CCW_SIZE: integer := 32;
    constant ADDR_BITs: integer := 3;
    constant MASK_ADDR_BITs: integer := 2;
    
    constant KEY_SIZE: integer := 4; --16 Bytes
    constant KEY_SIZE_BITS: integer := KEY_SIZE * CCW_SIZE;
    constant ELE_NPUB_SIZE: integer := 3; --12 Bytes
    constant NPUB_SIZE_BITS : integer := ELE_NPUB_SIZE * CCW_SIZE;
    constant ELE_TAG_SIZE: integer := 2; -- 8 Bytes
    constant TAG_SIZE_BITS: integer := ELE_TAG_SIZE * CCW_SIZE;
    constant BLOCK_SIZE: integer := 5; --20 Bytes --Message full 5
    
    constant PERM_ROUNDS_PER_CYCLE: integer := 1;
    constant PERM_CYCLES: integer := 80/PERM_ROUNDS_PER_CYCLE;
    constant PERM_CYCLES_BITS: integer := 7;
    constant LATENCY: integer := 4;
    
    --16 ~2500 LUTs
    --8  ~1800 LUTs ROM
end package elephant_constants;
