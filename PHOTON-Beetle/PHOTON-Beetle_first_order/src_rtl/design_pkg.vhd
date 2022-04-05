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

package Design_pkg is
    --! Adjust the bit counter widths to reduce ressource consumption.
    -- Range definition must not change.
    constant AD_CNT_WIDTH    : integer range 4 to 64 := 32;  --! Width of AD Bit counter
    constant MSG_CNT_WIDTH   : integer range 4 to 64 := 32;  --! Width of MSG (PT/CT) Bit counter

--------------------------------------------------------------------------------
------------------------- DO NOT CHANGE ANYTHING BELOW -------------------------
--------------------------------------------------------------------------------
    --! design parameters needed by the Pre- and Postprocessor
    constant TAG_SIZE        : integer := 128; --! Tag size
    constant HASH_VALUE_SIZE : integer := 256; --! Hash value size
    
    constant CCW        : integer := 32; --! bdo/bdi width
    constant CCSW       : integer := 32; --! key width
    constant CCRW       : integer := 32; --! key width
    constant CCWdiv8         : integer; --! derived from parameters above, assigned in body.

    --! design parameters exclusivly used by the LWC core implementations
    constant NPUB_SIZE       : integer := 128;  --! Npub size
    constant DBLK_SIZE       : integer := 32; --! Block size
end Design_pkg;


package body Design_pkg is

    -- derived from parameters above
    constant CCWdiv8    : integer := CCW/8;
end package body Design_pkg;
