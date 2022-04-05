--===============================================================================================--
--! @file       design_pkg.vhd
--! @brief      Template for CryptoCore design package
--!
--! @author     Michael Tempelmeier <michael.tempelmeier@tum.de>
--! @author     Patrick Karl <patrick.karl@tum.de>
--! @copyright  Copyright (c) 2019 Chair of Security in Information Technology
--!             ECE Department, Technical University of Munich, GERMANY
--!             All rights Reserved.
--! @author     Kamyar Mohajerani
--! @license    This project is released under the GNU Public License.
--!             The license and distribution terms for this file may be
--!             found in the file LICENSE in this distribution or at
--!             http://www.gnu.org/licenses/gpl-3.0.txt
--!
--! @note       Assign values to all constants in the package body. Add any
--!             constants, types, and functions used only by your CryptoCore.
--!
--! @note       Copy this file into your implementation's source directory
--!              and make any required changes to the design-specific copy.
--!
--===============================================================================================--

library IEEE;
use IEEE.STD_LOGIC_1164.all;

package design_pkg is
    --!
    --! These parameters are needed by the LWC package implementation.
    --!
    --! Tag size in bits
    constant TAG_SIZE        : natural := 64;
    --! Hash digest size in bits
    constant HASH_VALUE_SIZE : natural := 256; -- WE DO NOT SUPPORT HASHING
    --! CryptoCore BDI data width in bits. Supported values: 32, 16, 8
    constant CCW             : natural := 32;
    constant CCWdiv8         : integer := CCW/8;
    --! CryptoCore key input width in bits
    constant CCSW            : natural := CCW;
    constant CCRW            : natural := CCW;
    constant CONCURRENT      : natural := 32;  -- Valid values: 1, 2, 4, 8, 16, 32

    --! design parameters specific to the CryptoCore; assigned in the package body below!
    --! place declarations of your types here
    type t_slv_array is array (integer range <>) of std_logic_vector (31 downto 0);

    --! place declarations of your constants here

    --! place declarations of your functions here
    function to_slv(slvv : t_slv_array) return std_logic_vector;  
end design_pkg;

package body design_pkg is

    --! define your functions here
    function to_slv(slvv : t_slv_array) return std_logic_vector is
    variable slv : std_logic_vector((slvv'length * 32) - 1 downto 0);
    begin
        for i in slvv'range loop
            slv((i * 32) + 31 downto (i * 32))      := slvv(i);
        end loop;
        return slv;
    end function;
end package body design_pkg;
